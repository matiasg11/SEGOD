-- Identificación visible de muestras, equipo de punzón y gestión administrativa de ensayos.

alter table public.samples add column if not exists display_name text;

create or replace function private.meaningful_sample_value(p_value text)
returns boolean
language sql
immutable
security invoker
set search_path = ''
as $$
  select nullif(btrim(coalesce(p_value, '')), '') is not null
     and lower(btrim(coalesce(p_value, ''))) not in ('n/a', 'na', 'no aplica');
$$;

create or replace function private.sample_display_name(
  p_product text,
  p_model text,
  p_size text,
  p_lot text,
  p_batch text,
  p_sample_name text
)
returns text
language sql
immutable
security invoker
set search_path = ''
as $$
  select case
    when private.meaningful_sample_value(p_model)
     and private.meaningful_sample_value(p_size)
      then concat_ws(' - ', coalesce(nullif(btrim(p_product), ''), 'Muestra'), btrim(p_model), btrim(p_size))
    when private.meaningful_sample_value(p_lot)
     and private.meaningful_sample_value(p_batch)
      then concat_ws(' - ', coalesce(nullif(btrim(p_product), ''), 'Muestra'), btrim(p_lot), btrim(p_batch))
    else concat_ws(' - ', coalesce(nullif(btrim(p_product), ''), 'Muestra'), nullif(btrim(p_sample_name), ''))
  end;
$$;

create or replace function private.set_sample_name()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.received_at is null then new.received_at := current_date; end if;
  if new.sample_name is null or btrim(new.sample_name) = '' then
    new.sample_name := private.next_sample_name(new.received_at);
  end if;
  new.display_name := private.sample_display_name(
    new.product, new.model, new.size, new.lot, new.batch, new.sample_name
  );
  return new;
end;
$$;

create or replace function private.set_sample_display_name()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  new.display_name := private.sample_display_name(
    new.product, new.model, new.size, new.lot, new.batch, new.sample_name
  );
  return new;
end;
$$;

drop trigger if exists samples_set_display_name on public.samples;
create trigger samples_set_display_name
before update of product, model, size, lot, batch, sample_name on public.samples
for each row execute function private.set_sample_display_name();

update public.samples
set display_name = private.sample_display_name(product, model, size, lot, batch, sample_name)
where display_name is distinct from private.sample_display_name(product, model, size, lot, batch, sample_name);

-- Todos los formularios de perforación usan el punzón PUN01L como equipo principal.
update public.test_catalog c
set primary_equipment_id = e.id,
    required_equipment = e.code || ' - ' || e.name
from public.equipment e
where c.raw_schema_key = 'perforacion'
  and e.code = 'PUN01L';

update public.sample_tests t
set equipment_id = e.id,
    equipment_used = e.code || ' - ' || e.name,
    modified_by = coalesce((select auth.uid()), t.modified_by),
    updated_at = now()
from public.test_catalog c, public.equipment e
where t.test_catalog_id = c.id
  and c.raw_schema_key = 'perforacion'
  and e.code = 'PUN01L'
  and not t.voided
  and not t.locked;

create or replace function public.archive_test(p_test_id uuid, p_reason text default null)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_reason text := coalesce(nullif(btrim(p_reason), ''), 'Ensayo eliminado por el administrador');
begin
  if not private.has_lab_permission('manage') then
    raise exception 'Solo el administrador puede eliminar ensayos';
  end if;
  if not exists (select 1 from public.sample_tests where id = p_test_id and not voided) then
    raise exception 'El ensayo no existe o ya fue eliminado';
  end if;

  update public.raw_test_data
  set voided = true,
      status = 'Anulado',
      void_reason = v_reason,
      voided_at = now(),
      voided_by = (select auth.uid()),
      modified_by = (select auth.uid()),
      updated_at = now()
  where sample_test_id = p_test_id and not voided;

  update public.sample_tests
  set voided = true,
      status = 'Anulado',
      void_reason = v_reason,
      voided_at = now(),
      voided_by = (select auth.uid()),
      locked = false,
      modified_by = (select auth.uid()),
      updated_at = now()
  where id = p_test_id and not voided;
end;
$$;

revoke all on function public.archive_test(uuid,text) from public, anon;
grant execute on function public.archive_test(uuid,text) to authenticated;

create or replace function public.admin_update_test(
  p_test_id uuid,
  p_catalog_id uuid,
  p_assigned_to uuid,
  p_status text,
  p_applied_standard text,
  p_scheduled_at date,
  p_reason text
)
returns void
language plpgsql
security invoker
set search_path = ''
as $$
declare
  v_old public.sample_tests;
  v_catalog public.test_catalog;
  v_catalog_changed boolean;
begin
  if not private.has_lab_permission('manage') then
    raise exception 'Solo el administrador puede cambiar el tipo de ensayo';
  end if;
  if nullif(btrim(coalesce(p_reason, '')), '') is null then
    raise exception 'Indicá el motivo del cambio';
  end if;

  select * into v_old from public.sample_tests where id = p_test_id and not voided;
  if v_old.id is null then raise exception 'El ensayo no existe o está anulado'; end if;

  select * into v_catalog from public.test_catalog where id = p_catalog_id and active;
  if v_catalog.id is null then raise exception 'Seleccioná un ensayo activo del catálogo'; end if;
  v_catalog_changed := v_old.test_catalog_id is distinct from v_catalog.id;

  if v_catalog_changed then
    update public.raw_test_data
    set voided = true,
        status = 'Anulado',
        void_reason = 'Obsoleto por cambio de tipo de ensayo: ' || btrim(p_reason),
        voided_at = now(),
        voided_by = (select auth.uid()),
        modified_by = (select auth.uid()),
        updated_at = now()
    where sample_test_id = p_test_id and not voided;
  end if;

  update public.sample_tests
  set test_catalog_id = v_catalog.id,
      test_name = v_catalog.name,
      applied_standard = coalesce(nullif(btrim(p_applied_standard), ''), v_catalog.standard, 'N/A'),
      assigned_to = p_assigned_to,
      equipment_id = case when v_catalog_changed then v_catalog.primary_equipment_id else equipment_id end,
      equipment_used = case when v_catalog_changed then v_catalog.required_equipment else equipment_used end,
      units = case when v_catalog_changed then v_catalog.default_unit else units end,
      status = coalesce(nullif(btrim(p_status), ''), status),
      scheduled_at = p_scheduled_at,
      correction_reason = btrim(p_reason),
      final_result = case when v_catalog_changed then null else final_result end,
      classification = case when v_catalog_changed then null else classification end,
      compliance = case when v_catalog_changed then null else compliance end,
      raw_record_count = case when v_catalog_changed then 0 else raw_record_count end,
      locked = case when v_catalog_changed then false else locked end,
      modified_by = (select auth.uid()),
      updated_at = now()
  where id = p_test_id;
end;
$$;

revoke all on function public.admin_update_test(uuid,uuid,uuid,text,text,date,text) from public, anon;
grant execute on function public.admin_update_test(uuid,uuid,uuid,text,text,date,text) to authenticated;

revoke all on function private.meaningful_sample_value(text) from public, anon, authenticated;
revoke all on function private.sample_display_name(text,text,text,text,text,text) from public, anon, authenticated;
revoke all on function private.set_sample_name() from public, anon, authenticated;
revoke all on function private.set_sample_display_name() from public, anon, authenticated;

