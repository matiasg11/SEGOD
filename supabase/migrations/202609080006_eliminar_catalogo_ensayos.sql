-- Permite al administrador retirar ensayos del catálogo sin perder la
-- trazabilidad de los que ya fueron utilizados en muestras.

grant delete on table public.test_catalog to authenticated;

drop policy if exists catalog_delete on public.test_catalog;
create policy catalog_delete on public.test_catalog
  for delete to authenticated
  using (private.has_lab_permission('manage'));

create or replace function public.remove_test_catalog_item(p_catalog_id uuid)
returns text
language plpgsql
set search_path = ''
as $$
begin
  if not private.has_lab_permission('manage') then
    raise exception 'Solo el administrador puede eliminar ensayos del catálogo';
  end if;

  if not exists (
    select 1 from public.test_catalog where id = p_catalog_id
  ) then
    raise exception 'El ensayo no existe en el catálogo';
  end if;

  if exists (
    select 1 from public.sample_tests where test_catalog_id = p_catalog_id
  ) then
    update public.test_catalog
       set active = false,
           updated_at = now()
     where id = p_catalog_id;
    return 'deactivated';
  end if;

  delete from public.test_catalog where id = p_catalog_id;
  return 'deleted';
end;
$$;

revoke all on function public.remove_test_catalog_item(uuid) from public, anon;
grant execute on function public.remove_test_catalog_item(uuid) to authenticated;
