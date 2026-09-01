create index if not exists test_catalog_primary_equipment_idx
  on public.test_catalog(primary_equipment_id)
  where primary_equipment_id is not null;
