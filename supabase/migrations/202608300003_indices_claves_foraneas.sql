create index if not exists samples_created_by_idx
  on public.samples(created_by);

create index if not exists sample_tests_test_catalog_id_idx
  on public.sample_tests(test_catalog_id);

create index if not exists sample_tests_performed_by_idx
  on public.sample_tests(performed_by);

create index if not exists sample_tests_reviewed_by_idx
  on public.sample_tests(reviewed_by);

create index if not exists sample_tests_created_by_idx
  on public.sample_tests(created_by);

create index if not exists raw_test_data_captured_by_idx
  on public.raw_test_data(captured_by);

