-- Los datos crudos son append-only: la aplicación puede leerlos y agregar
-- nuevas secuencias, pero no sobrescribir ni eliminar registros existentes.
alter table public.raw_test_data enable row level security;

drop policy if exists raw_update on public.raw_test_data;
drop policy if exists raw_delete on public.raw_test_data;

revoke update, delete on table public.raw_test_data from anon, authenticated;

comment on table public.raw_test_data is
  'Registro inmutable de mediciones. Las correcciones se agregan como nuevas secuencias.';
