-- Completa el dato requerido para personal que ya estaba dado de baja.
update public.staff
set inactivated_at = coalesce(inactivated_at, current_date)
where status = 'Inactivo' and inactivated_at is null;
