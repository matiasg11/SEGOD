-- Mantiene raw_test_data inmutable desde la API y permite que la operación
-- administrativa de editar una muestra anule asociaciones con trazabilidad.

alter function public.update_sample_with_tests(uuid, jsonb, text[])
  set schema private;

alter function private.update_sample_with_tests(uuid, jsonb, text[])
  security definer;

alter function private.update_sample_with_tests(uuid, jsonb, text[])
  set search_path = '';

revoke all on function private.update_sample_with_tests(uuid, jsonb, text[])
  from public, anon, authenticated;
grant execute on function private.update_sample_with_tests(uuid, jsonb, text[])
  to authenticated;

create function public.update_sample_with_tests(
  p_sample_id uuid,
  p_sample jsonb,
  p_test_names text[]
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if (select auth.uid()) is null then
    raise exception 'Sesión requerida';
  end if;

  perform private.update_sample_with_tests(
    p_sample_id,
    p_sample,
    p_test_names
  );
end;
$$;

revoke all on function public.update_sample_with_tests(uuid, jsonb, text[])
  from public, anon;
grant execute on function public.update_sample_with_tests(uuid, jsonb, text[])
  to authenticated;

comment on function public.update_sample_with_tests(uuid, jsonb, text[]) is
  'API autenticada para editar una muestra. La implementación privada valida permisos y puede anular datos asociados sin habilitar modificaciones directas de datos crudos.';
