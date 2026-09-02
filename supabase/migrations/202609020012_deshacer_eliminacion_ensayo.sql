-- Marca las eliminaciones administrativas como reversibles y permite restaurarlas.
create or replace function public.archive_test(p_test_id uuid, p_reason text default null)
returns void
language plpgsql
set search_path to ''
as $$
declare
  v_reason text := 'Eliminado por administrador: ' || coalesce(nullif(btrim(p_reason), ''), 'sin motivo especificado');
begin
  if not private.has_lab_permission('manage') then
    raise exception 'Solo el administrador puede eliminar ensayos';
  end if;
  if not exists (select 1 from public.sample_tests where id = p_test_id and not voided) then
    raise exception 'El ensayo no existe o ya fue eliminado';
  end if;

  update public.raw_test_data
  set voided = true, status = 'Anulado', void_reason = v_reason,
      voided_at = now(), voided_by = (select auth.uid()), modified_by = (select auth.uid()), updated_at = now()
  where sample_test_id = p_test_id and not voided;

  update public.sample_tests
  set voided = true, status = 'Anulado', void_reason = v_reason,
      voided_at = now(), voided_by = (select auth.uid()), locked = false,
      modified_by = (select auth.uid()), updated_at = now()
  where id = p_test_id and not voided;
end;
$$;

create or replace function public.restore_test(p_test_id uuid)
returns void
language plpgsql
set search_path to ''
as $$
declare
  v_has_raw boolean;
begin
  if not private.has_lab_permission('manage') then
    raise exception 'Solo el administrador puede restaurar ensayos';
  end if;
  if not exists (
    select 1 from public.sample_tests
    where id = p_test_id and voided
      and void_reason like 'Eliminado por administrador:%'
  ) then
    raise exception 'Solo se puede deshacer una eliminación administrativa reciente';
  end if;

  select exists(select 1 from public.raw_test_data where sample_test_id = p_test_id) into v_has_raw;
  update public.raw_test_data
  set voided = false, status = 'Datos cargados', void_reason = null,
      voided_at = null, voided_by = null, modified_by = (select auth.uid()), updated_at = now()
  where sample_test_id = p_test_id and voided;
  update public.sample_tests
  set voided = false, status = case when v_has_raw then 'Datos Cargados' else 'Pendiente' end,
      void_reason = null, voided_at = null, voided_by = null, locked = false,
      raw_record_count = case when v_has_raw then (select count(*) from public.raw_test_data where sample_test_id = p_test_id and not voided) else 0 end,
      modified_by = (select auth.uid()), updated_at = now()
  where id = p_test_id;
end;
$$;

revoke all on function public.restore_test(uuid) from public, anon;
grant execute on function public.restore_test(uuid) to authenticated;
