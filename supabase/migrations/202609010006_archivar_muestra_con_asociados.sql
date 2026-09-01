-- La eliminación operativa de una muestra archiva también sus ensayos y datos.
-- Se conserva el historial técnico y de auditoría sin borrado físico irreversible.

create or replace function public.archive_sample(p_sample_id uuid,p_reason text default null)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_reason text := coalesce(nullif(trim(p_reason), ''), 'Eliminada desde la aplicación');
begin
  if not private.has_lab_permission('manage_samples') then
    raise exception 'Solo el administrador o responsable del laboratorio puede eliminar muestras';
  end if;

  if not exists (
    select 1 from public.samples where id = p_sample_id and deleted_at is null
  ) then
    raise exception 'La muestra no existe o ya fue eliminada';
  end if;

  update public.raw_test_data
  set voided = true,
      status = 'Anulado',
      void_reason = 'Muestra eliminada: ' || v_reason,
      voided_at = now(),
      voided_by = (select auth.uid()),
      modified_by = (select auth.uid()),
      updated_at = now()
  where sample_id = p_sample_id
    and not voided;

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

revoke all on function public.archive_sample(uuid,text) from public, anon;
grant execute on function public.archive_sample(uuid,text) to authenticated;

