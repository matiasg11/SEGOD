-- Asigna el responsable elegido a todos los ensayos creados junto con la muestra.
create or replace function public.create_sample_with_tests(
  p_sample jsonb,
  p_test_names text[]
)
returns uuid
language plpgsql
set search_path to ''
as $$
declare
  v_id uuid;
  v_name text;
  v_catalog uuid;
  v_standard text;
  v_equipment uuid;
  v_responsible uuid;
begin
  if (select auth.uid()) is null then
    raise exception 'Se requiere una sesión autenticada';
  end if;

  -- Si no se elige uno, se conserva la asignación operativa por defecto a Gonzalo.
  v_responsible := nullif(p_sample->>'assigned_to', '')::uuid;
  if v_responsible is null then
    select id into v_responsible
    from public.staff
    where status = 'Activo'
      and can_run_tests
      and (lower(email) = 'gonzalo.torti@segod.com.ar' or lower(full_name) = 'gonzalo torti')
    order by (lower(email) = 'gonzalo.torti@segod.com.ar') desc
    limit 1;
  else
    if not exists (
      select 1 from public.staff
      where id = v_responsible and status = 'Activo' and can_run_tests
    ) then
      raise exception 'El responsable seleccionado no está habilitado para realizar ensayos';
    end if;
  end if;

  if v_responsible is null then
    raise exception 'Seleccioná un responsable activo habilitado para realizar ensayos';
  end if;

  insert into public.samples(
    received_at, product, requester, model, size, hand, lot, batch, work_order,
    quantity_received, requested_standard, status, location_and_storage,
    conservation_conditions, notes, requested_tests_list, created_by
  ) values (
    coalesce(nullif(p_sample->>'received_at','')::date,current_date), p_sample->>'product',
    coalesce(nullif(p_sample->>'requester',''),'Calidad'), coalesce(nullif(p_sample->>'model',''),'N/A'),
    coalesce(nullif(p_sample->>'size',''),'N/A'), coalesce(nullif(p_sample->>'hand',''),'N/A'),
    nullif(p_sample->>'lot',''), nullif(p_sample->>'batch',''), nullif(p_sample->>'work_order',''),
    coalesce(nullif(p_sample->>'quantity_received','')::numeric,1), nullif(p_sample->>'requested_standard',''),
    'Recibida', coalesce(nullif(p_sample->>'location',''),'N/A'),
    coalesce(nullif(p_sample->>'conservation',''),'N/A'), nullif(p_sample->>'notes',''),
    coalesce(p_test_names,'{}'), (select auth.uid())
  ) returning id into v_id;

  foreach v_name in array coalesce(p_test_names,'{}') loop
    select id, standard, primary_equipment_id into v_catalog, v_standard, v_equipment
    from public.test_catalog
    where name = v_name and active
    order by (standard=p_sample->>'requested_standard') desc nulls last, available_in_house desc
    limit 1;
    if v_catalog is null then
      raise exception 'Ensayo no encontrado o inactivo: %', v_name;
    end if;

    insert into public.sample_tests(
      sample_id, test_catalog_id, test_name, applied_standard, repetition_no,
      status, assigned_to, equipment_id, execution_reason, created_by
    ) values (
      v_id, v_catalog, v_name, coalesce(nullif(p_sample->>'requested_standard',''),v_standard), 1,
      'Pendiente', v_responsible, v_equipment,
      'Asignado y pendiente con el ingreso de la muestra', (select auth.uid())
    );
  end loop;
  return v_id;
end;
$$;
