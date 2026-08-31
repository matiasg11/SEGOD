-- Genera el nombre automático dentro del trigger sin exigir acceso directo
-- a funciones privadas auxiliares.
create or replace function private.set_sample_name()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.sample_name is null or btrim(new.sample_name) = '' then
    new.sample_name := 'M-' || to_char(coalesce(new.received_at,current_date),'YYYY') || '-' ||
      lpad(nextval('public.sample_number_seq')::text,6,'0');
  end if;
  return new;
end;
$$;

revoke all on function private.set_sample_name() from public,anon,authenticated;

-- Todos los usuarios autenticados pueden ingresar muestras y sus ensayos
-- solicitados. El creador queda registrado y no puede ser suplantado.
drop policy if exists samples_insert on public.samples;
create policy samples_insert on public.samples for insert to authenticated
  with check ((select auth.uid()) is not null and created_by=(select auth.uid()));

drop policy if exists tests_insert on public.sample_tests;
create policy tests_insert on public.sample_tests for insert to authenticated
  with check ((select auth.uid()) is not null and created_by=(select auth.uid()));

drop policy if exists samples_update on public.samples;
create policy samples_update on public.samples for update to authenticated
  using (
    created_by=(select auth.uid()) or private.has_lab_permission('run') or
    private.has_lab_permission('review') or private.has_lab_permission('approve') or
    private.has_lab_permission('manage')
  )
  with check (
    created_by=(select auth.uid()) or private.has_lab_permission('run') or
    private.has_lab_permission('review') or private.has_lab_permission('approve') or
    private.has_lab_permission('manage')
  );

revoke all on function public.create_sample_with_tests(jsonb,text[]) from public,anon;
grant execute on function public.create_sample_with_tests(jsonb,text[]) to authenticated;

-- N/A queda disponible en todos los catálogos de formularios.
insert into public.app_options(category,value,label,sort_order,active)
select category,'N/A','N/A · No aplica',999,true
from unnest(array[
  'sample_product','sample_requester','sample_model','sample_size','sample_hand',
  'standard','sample_location','conservation','test_status','equipment_category',
  'equipment_status','equipment_location','event_type','training_type',
  'training_result','document_type','document_status','unit'
]) as category
on conflict(category,value) do update set
  label=excluded.label,sort_order=excluded.sort_order,active=true;
