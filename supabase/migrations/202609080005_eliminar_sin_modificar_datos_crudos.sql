-- Las bajas lógicas de muestras y ensayos no deben alterar datos crudos.
-- Los datos quedan íntegros para auditoría/backup y se ocultan por la baja
-- de su registro padre.

create or replace function public.archive_sample(
  p_sample_id uuid,
  p_reason text default null
)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_reason text := coalesce(
    nullif(trim(p_reason), ''),
    'Eliminada desde la aplicación'
  );
begin
  if not private.has_lab_permission('manage_samples') then
    raise exception 'Solo el administrador o responsable del laboratorio puede eliminar muestras';
  end if;

  if not exists (
    select 1
      from public.samples
     where id = p_sample_id
       and deleted_at is null
  ) then
    raise exception 'La muestra no existe o ya fue eliminada';
  end if;

  update public.sample_tests
     set voided = true,
         status = 'Anulado',
         void_reason = 'Muestra eliminada: ' || v_reason,
         voided_at = now(),
         voided_by = (select auth.uid()),
         locked = false,
         modified_by = (select auth.uid()),
         updated_at = now()
   where sample_id = p_sample_id
     and not voided;

  update public.samples
     set status = 'Anulada',
         deleted_at = now(),
         deleted_by = (select auth.uid()),
         deletion_reason = v_reason,
         requested_tests_list = '{}'::text[],
         modified_by = (select auth.uid()),
         updated_at = now()
   where id = p_sample_id
     and deleted_at is null;
end;
$$;

create or replace function public.archive_test(
  p_test_id uuid,
  p_reason text default null
)
returns void
language plpgsql
set search_path = ''
as $$
declare
  v_reason text := 'Eliminado por administrador: ' || coalesce(
    nullif(btrim(p_reason), ''),
    'sin motivo especificado'
  );
begin
  if not private.has_lab_permission('manage') then
    raise exception 'Solo el administrador puede eliminar ensayos';
  end if;

  if not exists (
    select 1
      from public.sample_tests
     where id = p_test_id
       and not voided
  ) then
    raise exception 'El ensayo no existe o ya fue eliminado';
  end if;

  update public.sample_tests
     set voided = true,
         status = 'Anulado',
         void_reason = v_reason,
         voided_at = now(),
         voided_by = (select auth.uid()),
         locked = false,
         modified_by = (select auth.uid()),
         updated_at = now()
   where id = p_test_id
     and not voided;
end;
$$;

revoke all on function public.archive_sample(uuid, text) from public, anon;
grant execute on function public.archive_sample(uuid, text) to authenticated;
revoke all on function public.archive_test(uuid, text) from public, anon;
grant execute on function public.archive_test(uuid, text) to authenticated;

