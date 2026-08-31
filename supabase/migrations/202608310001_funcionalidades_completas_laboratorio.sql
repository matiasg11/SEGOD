-- Modelo funcional completo del laboratorio SEGOD.
-- Conserva UUID internos y evita el borrado físico de registros técnicos.

alter table public.staff
  add column if not exists email text,
  add column if not exists role text not null default 'Consulta',
  add column if not exists participates_in_lab boolean not null default true,
  add column if not exists can_review boolean not null default false,
  add column if not exists can_manage_documents boolean not null default false,
  add column if not exists auth_user_id uuid references auth.users(id);
create unique index if not exists staff_email_unique on public.staff(lower(email)) where email is not null;

alter table public.samples
  add column if not exists model text,
  add column if not exists size text,
  add column if not exists hand text,
  add column if not exists lot text,
  add column if not exists batch text,
  add column if not exists work_order text,
  add column if not exists conservation_conditions text,
  add column if not exists requested_tests_list text[] not null default '{}',
  add column if not exists modified_by uuid references auth.users(id);

alter table public.sample_tests
  add column if not exists repetition_no integer not null default 1,
  add column if not exists scheduled_at date,
  add column if not exists assigned_to uuid references public.staff(id),
  add column if not exists equipment_id uuid references public.equipment(id),
  add column if not exists execution_reason text,
  add column if not exists repetition_reason text,
  add column if not exists correction_reason text,
  add column if not exists raw_record_count integer not null default 0,
  add column if not exists reviewed_result text,
  add column if not exists review_notes text,
  add column if not exists modified_by uuid references auth.users(id),
  add column if not exists voided boolean not null default false,
  add column if not exists void_reason text,
  add column if not exists voided_at timestamptz,
  add column if not exists voided_by uuid references auth.users(id),
  add column if not exists replacement_test_id uuid references public.sample_tests(id);
create unique index if not exists sample_test_repetition_unique
  on public.sample_tests(sample_id, test_name, repetition_no) where not voided;

alter table public.raw_test_data
  add column if not exists equipment_id uuid references public.equipment(id),
  add column if not exists equipment_status text,
  add column if not exists calculated_result numeric,
  add column if not exists units text,
  add column if not exists classification text,
  add column if not exists compliance text,
  add column if not exists notes text,
  add column if not exists status text not null default 'Datos cargados',
  add column if not exists modified_by uuid references auth.users(id),
  add column if not exists voided boolean not null default false,
  add column if not exists void_reason text,
  add column if not exists voided_at timestamptz,
  add column if not exists voided_by uuid references auth.users(id),
  add column if not exists replacement_raw_id uuid references public.raw_test_data(id),
  add column if not exists updated_at timestamptz not null default now();

create table if not exists public.staff_training (
  id uuid primary key default gen_random_uuid(),
  staff_id uuid not null references public.staff(id) on delete restrict,
  topic text not null,
  training_type text,
  instructor text,
  trained_at date not null default current_date,
  expires_at date,
  result text,
  evidence_url text,
  related_document text,
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.equipment_events (
  id uuid primary key default gen_random_uuid(),
  equipment_id uuid not null references public.equipment(id) on delete restrict,
  event_date date not null default current_date,
  event_type text not null,
  result text,
  fit_for_use boolean,
  next_due_at date,
  responsible text,
  certificate_url text,
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now()
);

create table if not exists public.documents (
  id uuid primary key default gen_random_uuid(),
  code text not null,
  title text not null,
  document_type text,
  version text,
  status text not null default 'Vigente',
  effective_from date,
  effective_until date,
  responsible text,
  location_url text,
  retention text,
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  unique(code, version)
);

create table if not exists public.audit_log (
  id bigint generated always as identity primary key,
  table_name text not null,
  record_id uuid,
  action text not null,
  old_values jsonb,
  new_values jsonb,
  reason text,
  changed_by uuid references auth.users(id),
  changed_at timestamptz not null default now()
);

create table if not exists public.lab_alerts (
  id uuid primary key default gen_random_uuid(),
  alert_type text not null,
  title text not null,
  detail text,
  due_at timestamptz,
  related_table text,
  related_id uuid,
  resolved boolean not null default false,
  resolved_by uuid references auth.users(id),
  resolved_at timestamptz,
  created_at timestamptz not null default now()
);

create or replace function private.has_lab_permission(p_permission text)
returns boolean language sql stable security definer set search_path = '' as $$
  select case
    when (select auth.uid()) is null then false
    else exists (
      select 1 from public.staff s
      where s.status = 'Activo' and s.participates_in_lab
        and (s.auth_user_id = (select auth.uid()) or lower(s.email) = lower((select auth.jwt()->>'email')))
        and case p_permission
          when 'run' then s.can_run_tests
          when 'review' then s.can_review
          when 'approve' then s.can_approve_reports
          when 'manage' then s.can_manage_records
          when 'documents' then s.can_manage_documents or s.can_manage_records
          else true
        end
    )
  end;
$$;
revoke all on function private.has_lab_permission(text) from public;
grant execute on function private.has_lab_permission(text) to authenticated;

create or replace function private.audit_technical_change()
returns trigger language plpgsql security definer set search_path = '' as $$
begin
  insert into public.audit_log(table_name,record_id,action,old_values,new_values,changed_by)
  values (tg_table_name, coalesce(new.id,old.id), tg_op,
          case when tg_op in ('UPDATE','DELETE') then to_jsonb(old) end,
          case when tg_op in ('INSERT','UPDATE') then to_jsonb(new) end,
          (select auth.uid()));
  return coalesce(new,old);
end;
$$;
revoke all on function private.audit_technical_change() from public;

create or replace function private.protect_approved_records()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if tg_op = 'DELETE' then raise exception 'Los registros técnicos no se eliminan; deben anularse'; end if;
  if old.locked and not private.has_lab_permission('manage') then
    raise exception 'El ensayo aprobado está bloqueado y requiere una corrección formal';
  end if;
  return new;
end;
$$;

create or replace function private.protect_raw_records()
returns trigger language plpgsql security invoker set search_path = '' as $$
declare v_locked boolean;
begin
  if tg_op = 'DELETE' then raise exception 'Los datos crudos no se eliminan; deben anularse'; end if;
  select locked into v_locked from public.sample_tests where id=old.sample_test_id;
  if v_locked and not private.has_lab_permission('manage') then
    raise exception 'Los datos de un ensayo aprobado están bloqueados';
  end if;
  return new;
end;
$$;

create or replace function private.sync_raw_parent()
returns trigger language plpgsql security invoker set search_path = '' as $$
declare v_sample uuid; v_status text;
begin
  select sample_id into v_sample from public.sample_tests where id=new.sample_test_id;
  new.sample_id := v_sample;
  if new.equipment_id is not null then select status into v_status from public.equipment where id=new.equipment_id; end if;
  new.equipment_status := coalesce(new.equipment_status,v_status);
  new.modified_by := coalesce(new.modified_by,(select auth.uid()));
  new.updated_at := now();
  return new;
end;
$$;

create or replace function private.refresh_test_raw_count()
returns trigger language plpgsql security invoker set search_path = '' as $$
declare v_test uuid;
begin
  v_test := coalesce(new.sample_test_id,old.sample_test_id);
  update public.sample_tests t set
    raw_record_count=(select count(*) from public.raw_test_data r where r.sample_test_id=v_test and not r.voided),
    status=case when t.status in ('Solicitado','Pendiente','Asignado','En preparación','En ejecución') then 'Datos cargados' else t.status end,
    updated_at=now(), modified_by=(select auth.uid())
  where t.id=v_test;
  return coalesce(new,old);
end;
$$;

create or replace function private.refresh_sample_status()
returns trigger language plpgsql security invoker set search_path = '' as $$
declare v_sample uuid; v_total int; v_approved int; v_review int;
begin
  v_sample:=coalesce(new.sample_id,old.sample_id);
  select count(*),count(*) filter(where status='Aprobado'),count(*) filter(where status in ('Pendiente de revisión','Observado','Revisado'))
    into v_total,v_approved,v_review from public.sample_tests where sample_id=v_sample and not voided;
  update public.samples set status=case
    when v_total>0 and v_total=v_approved then 'Finalizada'
    when v_review>0 then 'Pendiente de revisión'
    when exists(select 1 from public.sample_tests where sample_id=v_sample and status in ('En preparación','En ejecución','Datos cargados')) then 'En ensayo'
    else 'Pendiente de asignación' end,
    updated_at=now(),modified_by=(select auth.uid()) where id=v_sample;
  return coalesce(new,old);
end;
$$;

drop trigger if exists sample_tests_protect on public.sample_tests;
create trigger sample_tests_protect before update or delete on public.sample_tests for each row execute function private.protect_approved_records();
drop trigger if exists raw_data_protect on public.raw_test_data;
create trigger raw_data_protect before update or delete on public.raw_test_data for each row execute function private.protect_raw_records();
drop trigger if exists raw_data_sync_parent on public.raw_test_data;
create trigger raw_data_sync_parent before insert or update on public.raw_test_data for each row execute function private.sync_raw_parent();
drop trigger if exists raw_data_refresh_parent on public.raw_test_data;
create trigger raw_data_refresh_parent after insert or update on public.raw_test_data for each row execute function private.refresh_test_raw_count();
drop trigger if exists test_refresh_sample on public.sample_tests;
create trigger test_refresh_sample after insert or update on public.sample_tests for each row execute function private.refresh_sample_status();

drop trigger if exists samples_audit on public.samples;
create trigger samples_audit after insert or update on public.samples for each row execute function private.audit_technical_change();
drop trigger if exists tests_audit on public.sample_tests;
create trigger tests_audit after insert or update on public.sample_tests for each row execute function private.audit_technical_change();
drop trigger if exists raw_audit on public.raw_test_data;
create trigger raw_audit after insert or update on public.raw_test_data for each row execute function private.audit_technical_change();

create or replace function public.create_sample_with_tests(p_sample jsonb,p_test_names text[])
returns uuid language plpgsql security invoker set search_path='' as $$
declare v_id uuid; v_name text; v_catalog uuid; v_standard text;
begin
  insert into public.samples(received_at,product,requester,model,size,hand,lot,batch,work_order,quantity_received,requested_standard,status,location_and_storage,conservation_conditions,notes,requested_tests_list,created_by)
  values(coalesce((p_sample->>'received_at')::date,current_date),p_sample->>'product',nullif(p_sample->>'requester',''),nullif(p_sample->>'model',''),nullif(p_sample->>'size',''),nullif(p_sample->>'hand',''),nullif(p_sample->>'lot',''),nullif(p_sample->>'batch',''),nullif(p_sample->>'work_order',''),nullif(p_sample->>'quantity_received','')::numeric,nullif(p_sample->>'requested_standard',''),'Recibida',nullif(p_sample->>'location',''),nullif(p_sample->>'conservation',''),nullif(p_sample->>'notes',''),coalesce(p_test_names,'{}'),(select auth.uid())) returning id into v_id;
  foreach v_name in array coalesce(p_test_names,'{}') loop
    select id,standard into v_catalog,v_standard from public.test_catalog where name=v_name and active order by available_in_house desc limit 1;
    insert into public.sample_tests(sample_id,test_catalog_id,test_name,applied_standard,repetition_no,status,execution_reason,created_by)
    values(v_id,v_catalog,v_name,coalesce(v_standard,p_sample->>'requested_standard'),1,'Pendiente','Ensayo solicitado con el ingreso de la muestra',(select auth.uid()));
  end loop;
  return v_id;
end;
$$;

create or replace function public.repeat_test(p_test_id uuid,p_reason text)
returns uuid language plpgsql security invoker set search_path='' as $$
declare v_old public.sample_tests; v_new uuid; v_rep int;
begin
  if not private.has_lab_permission('run') then raise exception 'Sin permiso para ejecutar ensayos'; end if;
  select * into v_old from public.sample_tests where id=p_test_id;
  select coalesce(max(repetition_no),0)+1 into v_rep from public.sample_tests where sample_id=v_old.sample_id and test_name=v_old.test_name;
  insert into public.sample_tests(sample_id,test_catalog_id,test_name,applied_standard,repetition_no,status,repetition_reason,execution_reason,created_by)
  values(v_old.sample_id,v_old.test_catalog_id,v_old.test_name,v_old.applied_standard,v_rep,'Pendiente',p_reason,'Repetición del ensayo '||p_test_id,(select auth.uid())) returning id into v_new;
  update public.sample_tests set status='Repetición requerida',replacement_test_id=v_new,modified_by=(select auth.uid()) where id=p_test_id;
  return v_new;
end;
$$;

create or replace function public.send_test_to_review(p_test_id uuid)
returns void language plpgsql security invoker set search_path='' as $$
declare v public.sample_tests; v_eq public.equipment;
begin
  if not private.has_lab_permission('run') then raise exception 'Sin permiso para enviar a revisión'; end if;
  select * into v from public.sample_tests where id=p_test_id;
  if v.raw_record_count<1 then raise exception 'Debe existir al menos un registro de datos crudos'; end if;
  if v.final_result is null or v.units is null or v.assigned_to is null then raise exception 'Faltan resultado, unidades o responsable'; end if;
  if v.equipment_id is not null then
    select * into v_eq from public.equipment where id=v.equipment_id;
    if v_eq.status is distinct from 'Apto' or (v_eq.expires_at is not null and v_eq.expires_at<current_date) then raise exception 'El equipo no está apto o está vencido'; end if;
  end if;
  update public.sample_tests set status='Pendiente de revisión',modified_by=(select auth.uid()),updated_at=now() where id=p_test_id;
end;
$$;

create or replace function public.review_test(p_test_id uuid,p_decision text,p_notes text default null)
returns void language plpgsql security invoker set search_path='' as $$
declare v_staff uuid;
begin
  if p_decision='Aprobado' and not private.has_lab_permission('approve') then raise exception 'Sin permiso para aprobar'; end if;
  if p_decision<>'Aprobado' and not private.has_lab_permission('review') then raise exception 'Sin permiso para revisar'; end if;
  if p_decision not in ('Aprobado','Observado','Rechazado','Repetición requerida') then raise exception 'Decisión no válida'; end if;
  select id into v_staff from public.staff where auth_user_id=(select auth.uid()) or lower(email)=lower((select auth.jwt()->>'email')) limit 1;
  update public.sample_tests set status=p_decision,review_notes=p_notes,reviewed_at=now(),reviewed_by=v_staff,reviewed_result=final_result,locked=(p_decision='Aprobado'),modified_by=(select auth.uid()) where id=p_test_id;
end;
$$;

alter table public.staff_training enable row level security;
alter table public.equipment_events enable row level security;
alter table public.documents enable row level security;
alter table public.audit_log enable row level security;
alter table public.lab_alerts enable row level security;

revoke all on table public.staff_training,public.equipment_events,public.documents,public.audit_log,public.lab_alerts from anon,authenticated;
grant select,insert,update on table public.staff_training,public.equipment_events,public.documents,public.lab_alerts to authenticated;
grant select on table public.audit_log to authenticated;

create policy training_read on public.staff_training for select to authenticated using ((select auth.uid()) is not null);
create policy training_manage on public.staff_training for all to authenticated using (private.has_lab_permission('manage')) with check (private.has_lab_permission('manage'));
create policy equipment_events_read on public.equipment_events for select to authenticated using ((select auth.uid()) is not null);
create policy equipment_events_manage on public.equipment_events for all to authenticated using (private.has_lab_permission('manage')) with check (private.has_lab_permission('manage'));
create policy documents_read on public.documents for select to authenticated using ((select auth.uid()) is not null);
create policy documents_manage on public.documents for all to authenticated using (private.has_lab_permission('documents')) with check (private.has_lab_permission('documents'));
create policy audit_read on public.audit_log for select to authenticated using (private.has_lab_permission('review') or private.has_lab_permission('manage'));
create policy alerts_read on public.lab_alerts for select to authenticated using ((select auth.uid()) is not null);
create policy alerts_manage on public.lab_alerts for all to authenticated using (private.has_lab_permission('manage')) with check (private.has_lab_permission('manage'));

grant execute on function public.create_sample_with_tests(jsonb,text[]) to authenticated;
grant execute on function public.repeat_test(uuid,text) to authenticated;
grant execute on function public.send_test_to_review(uuid) to authenticated;
grant execute on function public.review_test(uuid,text,text) to authenticated;

create index if not exists tests_status_idx on public.sample_tests(status);
create index if not exists tests_assigned_idx on public.sample_tests(assigned_to);
create index if not exists equipment_expiry_idx on public.equipment(expires_at);
create index if not exists training_expiry_idx on public.staff_training(expires_at);
create index if not exists documents_status_idx on public.documents(status);

update public.staff set email='matias.guarnera@segod.com.ar',role='Administrador',can_review=true,can_manage_documents=true where legacy_id='JT-01';
update public.staff set email='santiago.diaz@segod.com.ar',role='Analista',can_review=false where legacy_id='IP-01';
update public.staff set email='gonzalo.torti@segod.com.ar',role='Responsable del laboratorio',can_review=true,can_manage_documents=false where legacy_id='RL-01';

-- Mantener las diez denominaciones normalizadas requeridas por la especificación.
insert into public.test_catalog(name,standard,raw_schema_key,active) values
('Marcado',null,'marcado',true),('Medición',null,'medicion',true),('Desteridad',null,'desteridad',true),
('Cromo VI',null,'cromo_vi',true),('pH',null,'ph',true),('Impacto',null,'impacto',true),
('Corte por cuchilla',null,'corte_cuchilla',true),('Perforación',null,'perforacion',true),
('Rasgado',null,'rasgado',true),('Abrasión',null,'abrasion',true)
on conflict(name,standard) do update set raw_schema_key=excluded.raw_schema_key,active=true;
