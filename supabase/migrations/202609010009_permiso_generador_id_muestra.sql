-- El trigger de alta de muestras requiere ejecutar este generador interno.
-- La función sólo consume la secuencia y devuelve el ID técnico, sin exponer datos.
grant execute on function private.next_sample_name(date) to authenticated;

