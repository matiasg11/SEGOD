-- Los triggers de nombre visible se ejecutan con los permisos del usuario autenticado.
-- Las funciones auxiliares son puras y sólo transforman texto, por lo que su uso es seguro.
grant execute on function private.meaningful_sample_value(text) to authenticated;
grant execute on function private.sample_display_name(text,text,text,text,text,text) to authenticated;

