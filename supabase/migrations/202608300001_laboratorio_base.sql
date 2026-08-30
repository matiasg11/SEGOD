create schema if not exists private;

create sequence if not exists public.sample_number_seq;

create or replace function private.next_sample_name(p_received_at date)
returns text
language sql
security invoker
set search_path = ''
as $$
  select 'M-' || to_char(coalesce(p_received_at, current_date), 'YYYY') || '-' ||
         lpad(nextval('public.sample_number_seq')::text, 6, '0');
$$;

create table if not exists public.staff (
  id uuid primary key default gen_random_uuid(),
  legacy_id text unique,
  full_name text not null,
  job_title text,
  area text,
  can_run_tests boolean not null default false,
  can_approve_reports boolean not null default false,
  can_manage_records boolean not null default false,
  authorized_tests text,
  competence_evidence text,
  impartiality_declared boolean,
  status text not null default 'Activo',
  notes text,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.test_catalog (
  id uuid primary key default gen_random_uuid(),
  name text not null,
  standard text,
  method text,
  required_equipment text,
  available_in_house boolean not null default true,
  raw_schema_key text,
  active boolean not null default true,
  unique (name, standard)
);

create table if not exists public.equipment (
  id uuid primary key default gen_random_uuid(),
  code text unique,
  name text not null,
  category text,
  main_use text,
  controlled_magnitude text,
  requires_calibration boolean,
  requires_verification boolean,
  frequency text,
  status text,
  location text,
  responsible_name text,
  brand text,
  model text,
  acquired_at date,
  last_calibrated_at date,
  last_verified_at date,
  expires_at date,
  certificate_url text,
  notes text,
  source_row jsonb not null default '{}'::jsonb
);

create table if not exists public.samples (
  id uuid primary key default gen_random_uuid(),
  sample_name text not null unique,
  received_at date not null default current_date,
  product text not null,
  requester text,
  model_size_hand text,
  lot_batch_work_order text,
  quantity_received numeric,
  requested_tests text,
  requested_standard text,
  status text not null default 'Ingresada',
  location_and_storage text,
  notes text,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create or replace function private.set_sample_name()
returns trigger
language plpgsql
security invoker
set search_path = ''
as $$
begin
  if new.sample_name is null or btrim(new.sample_name) = '' then
    new.sample_name := private.next_sample_name(new.received_at);
  end if;
  return new;
end;
$$;

drop trigger if exists samples_set_name on public.samples;
create trigger samples_set_name
before insert on public.samples
for each row execute function private.set_sample_name();

create table if not exists public.sample_tests (
  id uuid primary key default gen_random_uuid(),
  sample_id uuid not null references public.samples(id) on delete restrict,
  test_catalog_id uuid references public.test_catalog(id),
  tested_at timestamptz,
  test_name text not null,
  applied_standard text,
  equipment_used text,
  final_result text,
  units text,
  classification text,
  compliance text,
  performed_by uuid references public.staff(id),
  reviewed_at timestamptz,
  reviewed_by uuid references public.staff(id),
  notes text,
  status text not null default 'Pendiente',
  locked boolean not null default false,
  created_by uuid references auth.users(id),
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now()
);

create table if not exists public.raw_test_data (
  id uuid primary key default gen_random_uuid(),
  sample_test_id uuid not null references public.sample_tests(id) on delete restrict,
  sample_id uuid not null references public.samples(id) on delete restrict,
  subtest_id text,
  data_type text not null,
  sequence_no integer not null default 1,
  raw_values jsonb not null,
  source_sheet text,
  source_row_number integer,
  captured_by uuid references auth.users(id),
  captured_at timestamptz not null default now(),
  amended_at timestamptz,
  unique (sample_test_id, data_type, sequence_no)
);

create index if not exists sample_tests_sample_id_idx on public.sample_tests(sample_id);
create index if not exists raw_test_data_sample_test_id_idx on public.raw_test_data(sample_test_id);
create index if not exists raw_test_data_sample_id_idx on public.raw_test_data(sample_id);
create index if not exists raw_test_data_values_gin_idx on public.raw_test_data using gin(raw_values);

create or replace function private.touch_updated_at()
returns trigger language plpgsql security invoker set search_path = '' as $$
begin new.updated_at := now(); return new; end;
$$;

drop trigger if exists staff_touch_updated_at on public.staff;
create trigger staff_touch_updated_at before update on public.staff
for each row execute function private.touch_updated_at();
drop trigger if exists samples_touch_updated_at on public.samples;
create trigger samples_touch_updated_at before update on public.samples
for each row execute function private.touch_updated_at();
drop trigger if exists sample_tests_touch_updated_at on public.sample_tests;
create trigger sample_tests_touch_updated_at before update on public.sample_tests
for each row execute function private.touch_updated_at();

alter table public.staff enable row level security;
alter table public.test_catalog enable row level security;
alter table public.equipment enable row level security;
alter table public.samples enable row level security;
alter table public.sample_tests enable row level security;
alter table public.raw_test_data enable row level security;

revoke all on table public.staff, public.test_catalog, public.equipment,
  public.samples, public.sample_tests, public.raw_test_data from anon, authenticated;
grant select, insert, update on table public.staff, public.test_catalog, public.equipment,
  public.samples, public.sample_tests, public.raw_test_data to authenticated;
grant usage, select on sequence public.sample_number_seq to authenticated;

create policy staff_authenticated on public.staff for all to authenticated
using ((select auth.uid()) is not null) with check ((select auth.uid()) is not null);
create policy test_catalog_authenticated on public.test_catalog for all to authenticated
using ((select auth.uid()) is not null) with check ((select auth.uid()) is not null);
create policy equipment_authenticated on public.equipment for all to authenticated
using ((select auth.uid()) is not null) with check ((select auth.uid()) is not null);
create policy samples_authenticated on public.samples for all to authenticated
using ((select auth.uid()) is not null) with check ((select auth.uid()) is not null);
create policy sample_tests_authenticated on public.sample_tests for all to authenticated
using ((select auth.uid()) is not null) with check ((select auth.uid()) is not null);
create policy raw_test_data_authenticated on public.raw_test_data for all to authenticated
using ((select auth.uid()) is not null) with check ((select auth.uid()) is not null);

comment on column public.samples.id is 'UUID interno único; no cambia y no se usa como nombre visible.';
comment on column public.samples.sample_name is 'Nombre visible automático con formato M-AAAA-000001.';
comment on column public.raw_test_data.raw_values is 'Datos crudos completos del ensayo, conservados como JSONB.';



