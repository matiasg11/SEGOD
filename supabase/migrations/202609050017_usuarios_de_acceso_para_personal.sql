alter table public.staff
  add column if not exists username text;

update public.staff as staff_row
set auth_user_id = auth_row.id
from auth.users as auth_row
where staff_row.auth_user_id is null
  and staff_row.email is not null
  and lower(staff_row.email) = lower(auth_row.email);

update public.staff
set username = lower(split_part(email, '@', 1))
where username is null
  and email is not null
  and lower(email) like '%@segod.com.ar';

create unique index if not exists staff_username_unique
  on public.staff (lower(username))
  where username is not null;

drop index if exists public.staff_auth_user_idx;

create unique index if not exists staff_auth_user_unique
  on public.staff (auth_user_id)
  where auth_user_id is not null;

alter table public.staff
  drop constraint if exists staff_username_format;

alter table public.staff
  add constraint staff_username_format
  check (
    username is null
    or username ~ '^[a-z0-9][a-z0-9._-]{2,63}$'
  );
