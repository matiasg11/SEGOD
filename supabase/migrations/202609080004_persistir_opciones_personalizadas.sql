-- Los valores escritos en listas abiertas pasan a formar parte de sus opciones
-- sin otorgar a los analistas permisos generales sobre la configuración.

create or replace function private.capture_custom_test_field_choices()
returns trigger
language plpgsql
security definer
set search_path = pg_catalog, public, private
as $$
declare
  item record;
begin
  for item in
    select
      field.id,
      btrim(new.raw_values ->> field.field_key) as choice
    from public.sample_tests test
    join public.test_form_fields field
      on field.test_catalog_id = test.test_catalog_id
    where test.id = new.sample_test_id
      and field.active
      and field.input_type = 'list'
      and field.allow_custom
      and nullif(btrim(new.raw_values ->> field.field_key), '') is not null
  loop
    update public.test_form_fields
       set choices = choices || jsonb_build_array(item.choice),
           updated_at = now()
     where id = item.id
       and not (choices ? item.choice);
  end loop;

  return new;
end;
$$;

drop trigger if exists raw_test_data_capture_custom_choices
  on public.raw_test_data;
create trigger raw_test_data_capture_custom_choices
after insert on public.raw_test_data
for each row execute function private.capture_custom_test_field_choices();

revoke all on function private.capture_custom_test_field_choices() from public;

