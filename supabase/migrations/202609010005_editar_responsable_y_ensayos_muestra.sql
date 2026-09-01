-- Edición trazable de responsables y de los ensayos asignados a una muestra.

-- Corrige ejecuciones históricas creadas antes del responsable automático.
update public.sample_tests t
set assigned_to = s.id,
    modified_by = coalesce(t.modified_by, t.created_by),
    updated_at = now()
from public.staff s
where not t.voided
  and t.assigned_to is null
  and s.status = 'Activo'
  and lower(s.email) = 'gonzalo.torti@segod.com.ar';

-- El administrador y el responsable del laboratorio pueden corregir registros
-- aprobados cuando actúan dentro de la gestión de muestras.
create or replace function private.protect_approved_records()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin
  if tg_op = 'DELETE' then
    raise exception 'Los registros técnicos no se eliminan; deben anularse';
  end if;
  if old.locked and not private.has_lab_permission('manage_samples') then
    raise exception 'El ensayo aprobado está bloqueado y requiere una corrección formal';
  end if;
  return new;
end;
$$;

create or replace function private.protect_raw_records()
returns trigger language plpgsql security invoker set search_path = '' as $$
declare v_locked boolean;
begin
  if tg_op = 'DELETE' then
    raise exception 'Los datos crudos no se eliminan; deben anularse';
  end if;
  select locked into v_locked from public.sample_tests where id = old.sample_test_id;
  if v_locked and not private.has_lab_permission('manage_samples') then
    raise exception 'Los datos de un ensayo aprobado están bloqueados';
  end if;
  return new;
end;
$$;

create or replace function public.update_sample_with_tests(
  p_sample_id uuid,
  p_sample jsonb,
  p_test_names text[]
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_name text;
  v_catalog uuid;
  v_catalog_standard text;
  v_equipment uuid;
  v_responsible uuid;
  v_test_id uuid;
  v_names text[] := coalesce(p_test_names, '{}'::text[]);
begin
  if not private.has_lab_permission('manage_samples') then
    raise exception 'Solo el administrador o responsable del laboratorio puede editar muestras';
  end if;
  if not exists (select 1 from public.samples where id = p_sample_id and deleted_at is null) then
    raise exception 'La muestra no existe o fue eliminada';
  end if;
  if cardinality(v_names) = 0 then
    raise exception 'Seleccioná al menos un ensayo';
  end if;

  select id into v_responsible
  from public.staff
  where status = 'Activo'
    and (lower(email) = 'gonzalo.torti@segod.com.ar' or lower(full_name) = 'gonzalo torti')
  order by (lower(email) = 'gonzalo.torti@segod.com.ar') desc
  limit 1;

  if v_responsible is null then
    raise exception 'No se encontró un responsable de laboratorio activo';
  end if;

  update public.samples
  set received_at = coalesce(nullif(p_sample->>'received_at', '')::date, received_at),
      product = coalesce(nullif(p_sample->>'product', ''), product),
      requester = coalesce(nullif(p_sample->>'requester', ''), 'N/A'),
      model = coalesce(nullif(p_sample->>'model', ''), 'N/A'),
      size = coalesce(nullif(p_sample->>'size', ''), 'N/A'),
      hand = coalesce(nullif(p_sample->>'hand', ''), 'N/A'),
      lot = coalesce(nullif(p_sample->>'lot', ''), 'N/A'),
      batch = coalesce(nullif(p_sample->>'batch', ''), 'N/A'),
      work_order = coalesce(nullif(p_sample->>'work_order', ''), 'N/A'),
      quantity_received = coalesce(nullif(p_sample->>'quantity_received', '')::numeric, 1),
      requested_standard = coalesce(nullif(p_sample->>'requested_standard', ''), 'N/A'),
      location_and_storage = coalesce(nullif(p_sample->>'location_and_storage', ''), 'N/A'),
      conservation_conditions = coalesce(nullif(p_sample->>'conservation_conditions', ''), 'N/A'),
      notes = coalesce(nullif(p_sample->>'notes', ''), 'N/A'),
      requested_tests_list = v_names,
      modified_by = (select auth.uid()),
      updated_at = now()
  where id = p_sample_id;

  -- Quita lógicamente los ensayos desmarcados y conserva su historial.
  for v_test_id in
    select id
    from public.sample_tests
    where sample_id = p_sample_id
      and not voided
      and not (test_name = any(v_names))
  loop
    update public.raw_test_data
    set voided = true,
        status = 'Anulado',
        void_reason = 'Obsoleto: ensayo quitado de la muestra',
        voided_at = now(),
        voided_by = (select auth.uid()),
        modified_by = (select auth.uid()),
        updated_at = now()
    where sample_test_id = v_test_id
      and not voided;

    update public.sample_tests
    set voided = true,
        status = 'Anulado',
        void_reason = 'Quitado al editar la muestra',
        voided_at = now(),
        voided_by = (select auth.uid()),
        modified_by = (select auth.uid()),
        updated_at = now()
    where id = v_test_id;
  end loop;

  -- Mantiene las ejecuciones seleccionadas y crea únicamente las faltantes.
  foreach v_name in array v_names
  loop
    if not exists (
      select 1 from public.sample_tests
      where sample_id = p_sample_id and test_name = v_name and not voided
    ) then
      select id, standard, primary_equipment_id
      into v_catalog, v_catalog_standard, v_equipment
      from public.test_catalog
      where name = v_name and active
      order by
        (standard = nullif(p_sample->>'requested_standard', '')) desc nulls last,
        available_in_house desc
      limit 1;

      if v_catalog is null then
        raise exception 'Ensayo no encontrado o inactivo: %', v_name;
      end if;

      insert into public.sample_tests(
        sample_id, test_catalog_id, test_name, applied_standard,
        repetition_no, status, assigned_to, equipment_id,
        execution_reason, created_by
      )
      values(
        p_sample_id, v_catalog, v_name,
        coalesce(nullif(p_sample->>'requested_standard', ''), v_catalog_standard),
        1, 'Pendiente', v_responsible, v_equipment,
        'Ensayo agregado al editar la muestra', (select auth.uid())
      );
    end if;
  end loop;
end;
$$;

revoke all on function public.update_sample_with_tests(uuid,jsonb,text[]) from public, anon;
grant execute on function public.update_sample_with_tests(uuid,jsonb,text[]) to authenticated;

create or replace function public.send_test_to_review(p_test_id uuid)
returns void language plpgsql security invoker set search_path = '' as $$
declare
  v public.sample_tests;
  v_eq public.equipment;
begin
  if not private.has_lab_permission('run') then
    raise exception 'Sin permiso para enviar a revisión';
  end if;

  select * into v from public.sample_tests where id = p_test_id and not voided;
  if v.id is null then raise exception 'Ensayo inexistente o anulado'; end if;
  if v.raw_record_count < 1 then raise exception 'Debe existir al menos un registro de datos crudos'; end if;
  if v.assigned_to is null then raise exception 'Falta asignar un responsable'; end if;
  if v.final_result is null
     and coalesce(v.compliance, '') not in ('Cumple', 'No cumple', 'No Cumple', 'N/A') then
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
  set status = 'Ejecutado',
      modified_by = (select auth.uid()),
      updated_at = now()
  where id = p_test_id;
end;
$$;

revoke all on function public.send_test_to_review(uuid) from public, anon;
grant execute on function public.send_test_to_review(uuid) to authenticated;
