-- Gestión trazable del personal: estado y fechas de vigencia.
alter table public.staff
  add column if not exists activated_at date,
  add column if not exists inactivated_at date;

update public.staff
set activated_at = coalesce(activated_at, created_at::date, current_date)
where status = 'Activo' and activated_at is null;

update public.staff
set inactivated_at = coalesce(inactivated_at, current_date)
where status = 'Inactivo' and inactivated_at is null;

create or replace function public.set_staff_status_dates()
returns trigger
language plpgsql
set search_path = ''
as $$
begin
  if new.status = 'Activo' and (tg_op = 'INSERT' or old.status is distinct from 'Activo') then
    new.activated_at := coalesce(new.activated_at, current_date);
    new.inactivated_at := null;
  elsif new.status = 'Inactivo' and (tg_op = 'INSERT' or old.status is distinct from 'Inactivo') then
    new.inactivated_at := coalesce(new.inactivated_at, current_date);
  end if;
  return new;
end;
$$;

drop trigger if exists staff_status_dates on public.staff;
create trigger staff_status_dates
before insert or update of status on public.staff
for each row execute function public.set_staff_status_dates();

revoke all on function public.set_staff_status_dates() from public, anon, authenticated;
