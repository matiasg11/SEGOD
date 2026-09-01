create or replace function private.set_test_defaults()
returns trigger language plpgsql security invoker set search_path='' as $$
declare v_unit text; v_equipment uuid; v_gonzalo uuid;
begin
  if new.test_catalog_id is not null then
    select default_unit,primary_equipment_id into v_unit,v_equipment
    from public.test_catalog where id=new.test_catalog_id;
  end if;
  if new.units is null then new.units:=v_unit; end if;
  if new.equipment_id is null then new.equipment_id:=v_equipment; end if;
  if new.assigned_to is null then
    select id into v_gonzalo from public.staff
    where status='Activo' and lower(email)='gonzalo.torti@segod.com.ar' limit 1;
    new.assigned_to:=v_gonzalo;
  end if;
  return new;
end;
$$;
revoke all on function private.set_test_defaults() from public,anon,authenticated;

drop trigger if exists sample_tests_defaults on public.sample_tests;
create trigger sample_tests_defaults before insert or update of test_catalog_id
on public.sample_tests for each row execute function private.set_test_defaults();

update public.sample_tests t set units=c.default_unit
from public.test_catalog c where c.id=t.test_catalog_id and t.units is null;
