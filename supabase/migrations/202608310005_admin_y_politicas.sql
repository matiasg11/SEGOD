update public.staff set
  role='Administrador', can_run_tests=true, can_review=true,
  can_approve_reports=true, can_manage_records=true, can_manage_documents=true
where lower(email)='matias.guarnera@segod.com.ar';

update public.staff set role='Analista', can_manage_records=false
where lower(email)='santiago.diaz@segod.com.ar';

drop policy if exists staff_manage on public.staff;
create policy staff_insert on public.staff for insert to authenticated
  with check (private.has_lab_permission('manage'));
create policy staff_update on public.staff for update to authenticated
  using (private.has_lab_permission('manage')) with check (private.has_lab_permission('manage'));

drop policy if exists catalog_manage on public.test_catalog;
create policy catalog_insert on public.test_catalog for insert to authenticated
  with check (private.has_lab_permission('manage'));
create policy catalog_update on public.test_catalog for update to authenticated
  using (private.has_lab_permission('manage')) with check (private.has_lab_permission('manage'));

drop policy if exists equipment_manage on public.equipment;
create policy equipment_insert on public.equipment for insert to authenticated
  with check (private.has_lab_permission('manage'));
create policy equipment_update on public.equipment for update to authenticated
  using (private.has_lab_permission('manage')) with check (private.has_lab_permission('manage'));
