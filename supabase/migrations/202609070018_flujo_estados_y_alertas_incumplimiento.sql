-- Flujo controlado de ensayos y alertas por incumplimiento.
-- Los datos crudos continúan siendo append-only e inmutables.

alter table public.sample_tests disable trigger sample_tests_protect;

update public.sample_tests
set status = case
  when status = 'Ejecutado' then 'Pendiente de revisión'
  when status in ('Datos Cargados', 'Datos cargados') then 'Datos cargados'
  when status in ('No Ensayado', 'N/A') then 'No ensayado'
  else status
end,
locked = case when status in ('Aprobado', 'Anulado', 'No Ensayado', 'No ensayado', 'N/A', 'Observado') then true else locked end;

alter table public.sample_tests enable trigger sample_tests_protect;

update public.app_options set active = false where category = 'test_status';
insert into public.app_options(category, value, label, sort_order, active) values
  ('test_status', 'Pendiente', 'Pendiente', 10, true),
  ('test_status', 'Datos cargados', 'Datos cargados', 20, true),
  ('test_status', 'Pendiente de revisión', 'Pendiente de revisión', 30, true),
  ('test_status', 'Observado', 'Observado', 40, true),
  ('test_status', 'Aprobado', 'Aprobado', 50, true),
  ('test_status', 'Anulado', 'Anulado', 60, true),
  ('test_status', 'No ensayado', 'No ensayado', 70, true)
on conflict (category, value) do update
set label = excluded.label, sort_order = excluded.sort_order, active = true, updated_at = now();

alter table public.lab_alerts
  add column if not exists recipient_emails text[] not null default '{}',
  add column if not exists email_status text not null default 'Pendiente',
  add column if not exists email_attempted_at timestamptz,
  add column if not exists email_sent_at timestamptz,
  add column if not exists email_error text;

create unique index if not exists lab_alerts_test_noncompliance_unique
  on public.lab_alerts(related_table, related_id, alert_type)
  where related_table = 'sample_tests' and alert_type = 'Ensayo no conforme';

create or replace function private.protect_approved_records()
returns trigger
language plpgsql
set search_path to ''
as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'Los registros técnicos no se eliminan; deben anularse';
  end if;
  if old.status in ('Aprobado', 'Observado', 'Anulado', 'No ensayado')
     and not private.has_lab_permission('manage') then
    raise exception 'El ensayo finalizado está bloqueado; solo el administrador puede modificarlo';
  end if;
  return new;
end;
$$;

create or replace function private.enforce_test_workflow()
returns trigger
language plpgsql
set search_path to ''
as $$
declare
  v_admin boolean := private.has_lab_permission('manage');
  v_allowed boolean := false;
begin
  if new.status not in (
    'Pendiente', 'Datos cargados', 'Pendiente de revisión',
    'Observado', 'Aprobado', 'Anulado', 'No ensayado'
  ) then
    raise exception 'Estado de ensayo no válido';
  end if;

  if tg_op = 'INSERT' then
    if new.status <> 'Pendiente' and not v_admin then
      raise exception 'Los ensayos nuevos deben comenzar en estado Pendiente';
    end if;
  elsif new.status is distinct from old.status and not v_admin then
    v_allowed :=
      (old.status = 'Pendiente' and new.status in ('Datos cargados', 'Anulado', 'No ensayado')) or
      (old.status = 'Datos cargados' and new.status in ('Pendiente de revisión', 'Anulado', 'No ensayado')) or
      (old.status = 'Pendiente de revisión' and new.status in ('Observado', 'Aprobado', 'Anulado', 'No ensayado'));
    if not v_allowed then
      raise exception 'Transición de estado no permitida: % → %', old.status, new.status;
    end if;
  end if;

  if new.status = 'Pendiente' and coalesce(new.raw_record_count, 0) > 0 then
    raise exception 'No se puede volver a Pendiente mientras existan datos cargados';
  end if;
  if new.status in ('Datos cargados', 'Pendiente de revisión')
     and coalesce(new.raw_record_count, 0) < 1 then
    raise exception 'El estado % requiere al menos un registro de datos crudos', new.status;
  end if;

  new.locked := new.status in ('Observado', 'Aprobado', 'Anulado', 'No ensayado');
  return new;
end;
$$;

drop trigger if exists sample_tests_workflow on public.sample_tests;
create trigger sample_tests_workflow
before insert or update on public.sample_tests
for each row execute function private.enforce_test_workflow();

create or replace function private.refresh_test_raw_count()
returns trigger
language plpgsql
set search_path to ''
as $$
declare
  v_test uuid;
  v_count integer;
begin
  v_test := coalesce(new.sample_test_id, old.sample_test_id);
  select count(*) into v_count
  from public.raw_test_data r
  where r.sample_test_id = v_test and not r.voided;

  update public.sample_tests t
  set raw_record_count = v_count,
      status = case
        when v_count > 0 and t.status = 'Pendiente' then 'Datos cargados'
        when v_count = 0 and t.status = 'Datos cargados' then 'Pendiente'
        else t.status
      end,
      updated_at = now(),
      modified_by = (select auth.uid())
  where t.id = v_test;
  return coalesce(new, old);
end;
$$;

create or replace function public.send_test_to_review(p_test_id uuid)
returns void
language plpgsql
set search_path to ''
as $$
declare
  v public.sample_tests;
  v_eq public.equipment;
  v_responsible uuid;
begin
  if not private.has_lab_permission('run') then
    raise exception 'Sin permiso para enviar a revisión';
  end if;
  select * into v from public.sample_tests where id = p_test_id and not voided for update;
  if v.id is null then raise exception 'Ensayo inexistente o anulado'; end if;
  if v.status <> 'Datos cargados' then
    raise exception 'Solo se pueden enviar a revisión ensayos con Datos cargados';
  end if;
  if v.assigned_to is null then
    select id into v_responsible
    from public.staff
    where status = 'Activo' and can_run_tests
      and (lower(email) = 'gonzalo.torti@segod.com.ar' or lower(full_name) = 'gonzalo torti')
    order by (lower(email) = 'gonzalo.torti@segod.com.ar') desc
    limit 1;
    if v_responsible is null then raise exception 'No se encontró un responsable activo'; end if;
    update public.sample_tests set assigned_to = v_responsible where id = p_test_id;
  end if;
  if v.raw_record_count < 1 then raise exception 'Debe existir al menos un registro de datos crudos'; end if;
  if v.final_result is null and lower(coalesce(v.compliance, '')) not in ('cumple', 'no cumple') then
    raise exception 'Falta un resultado o evaluación de cumplimiento';
  end if;
  if v.equipment_id is not null then
    select * into v_eq from public.equipment where id = v.equipment_id;
    if v_eq.status is distinct from 'Apto'
       or (v_eq.expires_at is not null and v_eq.expires_at < current_date) then
      raise exception 'El equipo no está apto o está vencido';
    end if;
  end if;
  update public.sample_tests
  set status = 'Pendiente de revisión', modified_by = (select auth.uid()), updated_at = now()
  where id = p_test_id;
end;
$$;

create or replace function public.review_test(
  p_test_id uuid,
  p_decision text,
  p_notes text default null
)
returns void
language plpgsql
set search_path to ''
as $$
declare
  v public.sample_tests;
  v_staff uuid;
  v_new uuid;
  v_rep integer;
begin
  if p_decision = 'Aprobado' and not private.has_lab_permission('approve') then
    raise exception 'Sin permiso para aprobar';
  end if;
  if p_decision = 'Observado' and not private.has_lab_permission('review') then
    raise exception 'Sin permiso para observar';
  end if;
  if p_decision not in ('Aprobado', 'Observado') then raise exception 'Decisión no válida'; end if;

  select * into v from public.sample_tests where id = p_test_id and not voided for update;
  if v.id is null then raise exception 'Ensayo inexistente o anulado'; end if;
  if v.status <> 'Pendiente de revisión' then
    raise exception 'El ensayo debe estar Pendiente de revisión';
  end if;
  select id into v_staff
  from public.staff
  where auth_user_id = (select auth.uid())
     or lower(email) = lower((select auth.jwt()->>'email'))
  limit 1;

  if p_decision = 'Aprobado' then
    update public.sample_tests
    set status = 'Aprobado', review_notes = p_notes, reviewed_at = now(), reviewed_by = v_staff,
        reviewed_result = final_result, locked = true, modified_by = (select auth.uid()), updated_at = now()
    where id = p_test_id;
    return;
  end if;

  if nullif(btrim(coalesce(p_notes, '')), '') is null then
    raise exception 'Indicá el motivo de la observación';
  end if;
  select coalesce(max(repetition_no), 0) + 1 into v_rep
  from public.sample_tests
  where sample_id = v.sample_id and test_name = v.test_name;

  insert into public.sample_tests(
    sample_id, test_catalog_id, test_name, applied_standard, repetition_no,
    status, assigned_to, equipment_id, equipment_used, units,
    repetition_reason, execution_reason, created_by
  ) values (
    v.sample_id, v.test_catalog_id, v.test_name, v.applied_standard, v_rep,
    'Pendiente', v.assigned_to, v.equipment_id, v.equipment_used, v.units,
    btrim(p_notes), 'Repetición automática del ensayo observado ' || p_test_id, (select auth.uid())
  ) returning id into v_new;

  update public.sample_tests
  set status = 'Observado', review_notes = p_notes, reviewed_at = now(), reviewed_by = v_staff,
      reviewed_result = final_result, replacement_test_id = v_new, locked = true,
      modified_by = (select auth.uid()), updated_at = now()
  where id = p_test_id;
  return;
end;
$$;

create or replace function public.set_test_status(p_test_id uuid, p_status text)
returns void
language plpgsql
set search_path to ''
as $$
declare
  v public.sample_tests;
  v_status text := case
    when p_status in ('No Ensayado', 'No ensayado') then 'No ensayado'
    else p_status
  end;
begin
  if not (
    private.has_lab_permission('run') or private.has_lab_permission('review')
    or private.has_lab_permission('approve') or private.has_lab_permission('manage')
  ) then
    raise exception 'Sin permiso para modificar el estado del ensayo';
  end if;
  if v_status not in ('Anulado', 'No ensayado') then
    raise exception 'Pendiente y Datos cargados son automáticos; la revisión usa sus acciones específicas';
  end if;
  select * into v from public.sample_tests where id = p_test_id and not voided for update;
  if v.id is null then raise exception 'Ensayo no encontrado'; end if;

  update public.sample_tests
  set status = v_status,
      final_result = case when v_status = 'No ensayado' then null else final_result end,
      classification = case when v_status = 'No ensayado' then 'No ensayado' else classification end,
      compliance = case when v_status = 'No ensayado' then null else compliance end,
      locked = true, modified_by = (select auth.uid()), updated_at = now()
  where id = p_test_id;
end;
$$;

create or replace function public.repeat_test(p_test_id uuid, p_reason text)
returns uuid
language plpgsql
set search_path to ''
as $$
begin
  raise exception 'Las repeticiones se crean automáticamente al observar un ensayo en revisión';
end;
$$;

create or replace function public.bulk_sample_test_action(
  p_sample_ids uuid[],
  p_action text,
  p_notes text default null
)
returns integer
language plpgsql
set search_path to ''
as $$
declare
  v_test public.sample_tests;
  v_count integer := 0;
begin
  if coalesce(cardinality(p_sample_ids), 0) = 0 then
    raise exception 'Seleccioná al menos una muestra';
  end if;
  if p_action not in ('review', 'approve', 'observe', 'not_tested', 'cancel') then
    raise exception 'Acción en lote no válida';
  end if;

  for v_test in
    select * from public.sample_tests
    where sample_id = any(p_sample_ids) and not voided
      and (
        (p_action = 'review' and status = 'Datos cargados') or
        (p_action in ('approve', 'observe') and status = 'Pendiente de revisión') or
        (p_action in ('not_tested', 'cancel') and status not in ('Aprobado', 'Observado', 'Anulado', 'No ensayado'))
      )
    order by sample_id, created_at, id
  loop
    if p_action = 'review' then
      perform public.send_test_to_review(v_test.id);
    elsif p_action = 'approve' then
      perform public.review_test(v_test.id, 'Aprobado', coalesce(p_notes, 'Aprobado en lote'));
    elsif p_action = 'observe' then
      perform public.review_test(v_test.id, 'Observado', coalesce(nullif(p_notes, ''), 'Observado en lote'));
    elsif p_action = 'not_tested' then
      perform public.set_test_status(v_test.id, 'No ensayado');
    else
      perform public.set_test_status(v_test.id, 'Anulado');
    end if;
    v_count := v_count + 1;
  end loop;
  if v_count = 0 then raise exception 'No hay ensayos compatibles con esa acción'; end if;
  return v_count;
end;
$$;

create or replace function private.refresh_sample_status()
returns trigger
language plpgsql
set search_path to ''
as $$
declare
  v_sample uuid;
  v_total integer;
  v_final integer;
  v_review integer;
  v_data integer;
begin
  v_sample := coalesce(new.sample_id, old.sample_id);
  select count(*),
         count(*) filter (where status in ('Aprobado', 'Anulado', 'No ensayado')),
         count(*) filter (where status = 'Pendiente de revisión'),
         count(*) filter (where status = 'Datos cargados')
  into v_total, v_final, v_review, v_data
  from public.sample_tests where sample_id = v_sample and not voided;

  update public.samples
  set status = case
        when v_total > 0 and v_total = v_final then 'Finalizada'
        when v_review > 0 then 'Pendiente de revisión'
        when v_data > 0 then 'En ensayo'
        else 'Pendiente de asignación'
      end,
      updated_at = now(), modified_by = (select auth.uid())
  where id = v_sample;
  return coalesce(new, old);
end;
$$;

create or replace function private.queue_test_noncompliance_alert()
returns trigger
language plpgsql
security definer
set search_path to ''
as $$
declare
  v_sample public.samples;
  v_recipients text[];
begin
  if lower(coalesce(new.compliance, '')) <> 'no cumple'
     or lower(coalesce(old.compliance, '')) = 'no cumple' then
    return new;
  end if;
  select * into v_sample from public.samples where id = new.sample_id;
  select coalesce(array_agg(distinct lower(email)) filter (where email is not null), '{}')
  into v_recipients
  from public.staff
  where status = 'Activo'
    and (id = new.assigned_to or can_manage_records);

  insert into public.lab_alerts(
    alert_type, title, detail, related_table, related_id,
    recipient_emails, email_status
  ) values (
    'Ensayo no conforme',
    'Ensayo no conforme: ' || new.test_name,
    'Muestra ' || coalesce(v_sample.sample_name, v_sample.id::text) ||
      ' · Resultado ' || coalesce(new.final_result, 'sin valor') ||
      case when new.units is null then '' else ' ' || new.units end,
    'sample_tests', new.id, v_recipients, 'Pendiente'
  ) on conflict do nothing;
  return new;
end;
$$;

drop trigger if exists sample_tests_noncompliance_alert on public.sample_tests;
create trigger sample_tests_noncompliance_alert
after update of compliance on public.sample_tests
for each row execute function private.queue_test_noncompliance_alert();

revoke all on function private.enforce_test_workflow() from public, anon, authenticated;
revoke all on function private.queue_test_noncompliance_alert() from public, anon, authenticated;
revoke all on function public.send_test_to_review(uuid) from public, anon;
revoke all on function public.review_test(uuid, text, text) from public, anon;
revoke all on function public.set_test_status(uuid, text) from public, anon;
revoke all on function public.repeat_test(uuid, text) from public, anon;
revoke all on function public.bulk_sample_test_action(uuid[], text, text) from public, anon;
grant execute on function public.send_test_to_review(uuid) to authenticated;
grant execute on function public.review_test(uuid, text, text) to authenticated;
grant execute on function public.set_test_status(uuid, text) to authenticated;
grant execute on function public.repeat_test(uuid, text) to authenticated;
grant execute on function public.bulk_sample_test_action(uuid[], text, text) to authenticated;
