-- Evita evaluar dos políticas permisivas para cada lectura y cubre la FK usada
-- al actualizar o eliminar definiciones del catálogo.

drop policy if exists test_form_fields_manage on public.test_form_fields;
drop policy if exists test_selection_rules_manage on public.test_selection_rules;

create policy test_form_fields_insert on public.test_form_fields
  for insert to authenticated
  with check (private.has_lab_permission('manage'));
create policy test_form_fields_update on public.test_form_fields
  for update to authenticated
  using (private.has_lab_permission('manage'))
  with check (private.has_lab_permission('manage'));
create policy test_form_fields_delete on public.test_form_fields
  for delete to authenticated
  using (private.has_lab_permission('manage'));

create policy test_selection_rules_insert on public.test_selection_rules
  for insert to authenticated
  with check (private.has_lab_permission('manage'));
create policy test_selection_rules_update on public.test_selection_rules
  for update to authenticated
  using (private.has_lab_permission('manage'))
  with check (private.has_lab_permission('manage'));
create policy test_selection_rules_delete on public.test_selection_rules
  for delete to authenticated
  using (private.has_lab_permission('manage'));

create index if not exists test_selection_rules_catalog_idx
  on public.test_selection_rules(test_catalog_id);
