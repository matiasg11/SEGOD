-- Permite que las políticas RLS resuelvan la función de autorización sin
-- exponer las demás funciones internas del laboratorio.
revoke execute on all functions in schema private from public, anon, authenticated;
grant usage on schema private to authenticated;
grant execute on function private.has_lab_permission(text) to authenticated;

-- Las funciones privadas nuevas no quedan ejecutables por PUBLIC por defecto.
alter default privileges for role postgres in schema private
  revoke execute on functions from public;
