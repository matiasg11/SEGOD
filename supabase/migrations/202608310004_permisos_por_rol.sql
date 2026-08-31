-- Reemplaza las políticas iniciales amplias por permisos acordes al rol del laboratorio.
drop policy if exists staff_authenticated on public.staff;
drop policy if exists test_catalog_authenticated on public.test_catalog;
drop policy if exists equipment_authenticated on public.equipment;
drop policy if exists samples_authenticated on public.samples;
drop policy if exists sample_tests_authenticated on public.sample_tests;
drop policy if exists raw_test_data_authenticated on public.raw_test_data;

create policy staff_read on public.staff for select to authenticated
  using ((select auth.uid()) is not null);
create policy staff_manage on public.staff for all to authenticated
  using (private.has_lab_permission('manage'))
  with check (private.has_lab_permission('manage'));

create policy catalog_read on public.test_catalog for select to authenticated
  using ((select auth.uid()) is not null);
create policy catalog_manage on public.test_catalog for all to authenticated
  using (private.has_lab_permission('manage'))
  with check (private.has_lab_permission('manage'));

create policy equipment_read on public.equipment for select to authenticated
  using ((select auth.uid()) is not null);
create policy equipment_manage on public.equipment for all to authenticated
  using (private.has_lab_permission('manage'))
  with check (private.has_lab_permission('manage'));

create policy samples_read on public.samples for select to authenticated
  using ((select auth.uid()) is not null);
create policy samples_insert on public.samples for insert to authenticated
  with check (private.has_lab_permission('run') or private.has_lab_permission('manage'));
create policy samples_update on public.samples for update to authenticated
  using (private.has_lab_permission('run') or private.has_lab_permission('review') or private.has_lab_permission('approve') or private.has_lab_permission('manage'))
  with check (private.has_lab_permission('run') or private.has_lab_permission('review') or private.has_lab_permission('approve') or private.has_lab_permission('manage'));

create policy tests_read on public.sample_tests for select to authenticated
  using ((select auth.uid()) is not null);
create policy tests_insert on public.sample_tests for insert to authenticated
  with check (private.has_lab_permission('run') or private.has_lab_permission('manage'));
create policy tests_update on public.sample_tests for update to authenticated
  using (private.has_lab_permission('run') or private.has_lab_permission('review') or private.has_lab_permission('approve') or private.has_lab_permission('manage'))
  with check (private.has_lab_permission('run') or private.has_lab_permission('review') or private.has_lab_permission('approve') or private.has_lab_permission('manage'));

create policy raw_read on public.raw_test_data for select to authenticated
  using ((select auth.uid()) is not null);
create policy raw_insert on public.raw_test_data for insert to authenticated
  with check (private.has_lab_permission('run') or private.has_lab_permission('manage'));
create policy raw_update on public.raw_test_data for update to authenticated
  using (private.has_lab_permission('run') or private.has_lab_permission('manage'))
  with check (private.has_lab_permission('run') or private.has_lab_permission('manage'));
