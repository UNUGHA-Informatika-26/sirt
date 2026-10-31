-- SiRT: profil warga, akses baca profil sendiri, dan profil otomatis saat daftar.
-- Pendaftaran publik selalu membuat role warga. Admin dipromosikan manual.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  nik text not null default '',
  phone text not null default '',
  address text not null default '',
  avatar_url text,
  role text not null default 'warga'
    check (role in ('warga', 'admin')),
  created_at timestamptz not null default now()
);

alter table public.profiles add column if not exists avatar_url text;

alter table public.profiles enable row level security;

revoke all privileges on table public.profiles from anon, authenticated;
grant select on table public.profiles to authenticated;
grant update (avatar_url) on table public.profiles to authenticated;

drop policy if exists "Users can read own profile" on public.profiles;
create policy "Users can read own profile"
  on public.profiles
  for select
  to authenticated
  using ((select auth.uid()) = id);

drop policy if exists "Users can update own profile photo" on public.profiles;
create policy "Users can update own profile photo"
  on public.profiles for update to authenticated
  using ((select auth.uid()) = id)
  with check ((select auth.uid()) = id);

update public.profiles p
set avatar_url = u.raw_user_meta_data ->> 'avatar_url'
from auth.users u
where u.id = p.id
  and p.avatar_url is null
  and nullif(u.raw_user_meta_data ->> 'avatar_url', '') is not null;

-- Simpan fungsi trigger di schema yang tidak diekspos lewat Data API.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create or replace function private.is_current_user_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles
    where id = (select auth.uid()) and role = 'admin'
  );
$$;
revoke all on function private.is_current_user_admin()
  from public, anon, authenticated;
grant usage on schema private to authenticated;
grant execute on function private.is_current_user_admin() to authenticated;

drop policy if exists "Admins can read all resident profiles" on public.profiles;
create policy "Admins can read all resident profiles"
  on public.profiles
  for select
  to authenticated
  using ((select private.is_current_user_admin()));

-- Records entered by admins that do not yet have a SiRT login account.
create table if not exists public.resident_directory (
  id uuid primary key default gen_random_uuid(),
  full_name text not null check (char_length(btrim(full_name)) > 0),
  nik text not null unique check (nik ~ '^[0-9]{16}$'),
  address text not null check (char_length(btrim(address)) > 0),
  created_at timestamptz not null default now()
);

alter table public.resident_directory enable row level security;
revoke all privileges on table public.resident_directory from anon, authenticated;
grant select, insert, delete on table public.resident_directory to authenticated;

drop policy if exists "Admins can read resident directory" on public.resident_directory;
create policy "Admins can read resident directory"
  on public.resident_directory for select to authenticated
  using ((select private.is_current_user_admin()));

drop policy if exists "Admins can add resident directory records" on public.resident_directory;
create policy "Admins can add resident directory records"
  on public.resident_directory for insert to authenticated
  with check ((select private.is_current_user_admin()));

drop policy if exists "Admins can delete resident directory records" on public.resident_directory;
create policy "Admins can delete resident directory records"
  on public.resident_directory for delete to authenticated
  using ((select private.is_current_user_admin()));

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public' and tablename = 'resident_directory'
     ) then
    alter publication supabase_realtime add table public.resident_directory;
  end if;
end
$$;

create or replace function private.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles (id, full_name, nik, phone, address, role)
  values (
    new.id,
    coalesce(new.raw_user_meta_data ->> 'full_name', ''),
    coalesce(new.raw_user_meta_data ->> 'nik', ''),
    coalesce(new.raw_user_meta_data ->> 'phone', ''),
    coalesce(new.raw_user_meta_data ->> 'address', ''),
    'warga'
  );
  return new;
end;
$$;
revoke all on function private.handle_new_user()
  from public, anon, authenticated;

drop trigger if exists on_auth_user_created on auth.users;
create trigger on_auth_user_created
  after insert on auth.users
  for each row execute function private.handle_new_user();

-- Setelah akun admin dibuat melalui aplikasi, jalankan blok ini secara terpisah
-- dengan mengganti alamat email:
-- update public.profiles
-- set role = 'admin'
-- where id = (
--   select id from auth.users where email = 'email-admin-anda@contoh.com'
-- );

-- Jadwal jaga dikelola admin dan dibaca oleh seluruh akun yang masuk.
create table if not exists public.duty_schedules (
  id uuid primary key default gen_random_uuid(),
  resident_name text not null check (char_length(btrim(resident_name)) > 0),
  shift_name text not null check (char_length(btrim(shift_name)) > 0),
  starts_at timestamptz not null,
  ends_at timestamptz not null,
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now(),
  constraint duty_schedules_valid_time check (
    ends_at > starts_at
    and ends_at <= starts_at + interval '24 hours'
  )
);

create index if not exists duty_schedules_starts_at_idx
  on public.duty_schedules (starts_at);
create index if not exists duty_schedules_created_by_idx
  on public.duty_schedules (created_by);

alter table public.duty_schedules enable row level security;

revoke all privileges on table public.duty_schedules from anon, authenticated;
grant select, insert, delete on table public.duty_schedules to authenticated;

drop policy if exists "Authenticated users can read duty schedules"
  on public.duty_schedules;
create policy "Authenticated users can read duty schedules"
  on public.duty_schedules
  for select to authenticated
  using (true);

drop policy if exists "Admins can create duty schedules"
  on public.duty_schedules;
create policy "Admins can create duty schedules"
  on public.duty_schedules
  for insert to authenticated
  with check (
    created_by = (select auth.uid())
    and exists (
      select 1
      from public.profiles
      where profiles.id = (select auth.uid())
        and profiles.role = 'admin'
    )
  );

drop policy if exists "Admins can delete duty schedules"
  on public.duty_schedules;
create policy "Admins can delete duty schedules"
  on public.duty_schedules
  for delete to authenticated
  using (
    exists (
      select 1
      from public.profiles
      where profiles.id = (select auth.uid())
        and profiles.role = 'admin'
    )
  );

do $$
begin
  if exists (
    select 1 from pg_publication where pubname = 'supabase_realtime'
  ) and not exists (
    select 1
    from pg_publication_tables
    where pubname = 'supabase_realtime'
      and schemaname = 'public'
      and tablename = 'duty_schedules'
  ) then
    alter publication supabase_realtime add table public.duty_schedules;
  end if;
end
$$;

-- Profiles drive the live resident count in the admin dashboard.
do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
     and not exists (
       select 1 from pg_publication_tables
       where pubname = 'supabase_realtime'
         and schemaname = 'public' and tablename = 'profiles'
     ) then
    alter publication supabase_realtime add table public.profiles;
  end if;
end
$$;

-- Inventaris RT yang tampil untuk semua akun warga yang sudah masuk.
create table if not exists public.inventory_items (
  id uuid primary key default gen_random_uuid(),
  name text not null unique check (char_length(btrim(name)) > 0),
  stock integer not null default 0 check (stock >= 0),
  created_at timestamptz not null default now()
);

alter table public.inventory_items enable row level security;
revoke all privileges on table public.inventory_items from anon, authenticated;
grant select, insert, update, delete on table public.inventory_items to authenticated;

drop policy if exists "Authenticated users can read inventory" on public.inventory_items;
create policy "Authenticated users can read inventory"
  on public.inventory_items for select to authenticated using (true);
drop policy if exists "Admins can manage inventory" on public.inventory_items;
create policy "Admins can manage inventory"
  on public.inventory_items for all to authenticated
  using (exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role = 'admin'
  ))
  with check (exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role = 'admin'
  ));

insert into public.inventory_items (name, stock)
values ('Tenda lipat', 2), ('Kursi lipat', 24), ('Proyektor', 1), ('Speaker aktif', 1)
on conflict (name) do nothing;

-- Warga mengirim pengajuan; admin memprosesnya di menu Persetujuan.
create table if not exists public.equipment_loan_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  item_id uuid not null references public.inventory_items(id) on delete restrict,
  item_name text not null,
  resident_name text not null,
  purpose text not null check (char_length(btrim(purpose)) > 0),
  loan_date date not null,
  return_date date not null,
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  constraint loan_dates_valid check (return_date >= loan_date)
);

create index if not exists equipment_loan_requests_user_created_idx
  on public.equipment_loan_requests (user_id, created_at desc);
create index if not exists equipment_loan_requests_status_created_idx
  on public.equipment_loan_requests (status, created_at desc);

alter table public.equipment_loan_requests enable row level security;
revoke all privileges on table public.equipment_loan_requests from anon, authenticated;
grant select, insert, update on table public.equipment_loan_requests to authenticated;

drop policy if exists "Residents and admins can read loan requests"
  on public.equipment_loan_requests;
create policy "Residents and admins can read loan requests"
  on public.equipment_loan_requests for select to authenticated
  using (
    user_id = (select auth.uid())
    or exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.role = 'admin'
    )
  );

drop policy if exists "Residents can submit their own loan requests"
  on public.equipment_loan_requests;
create policy "Residents can submit their own loan requests"
  on public.equipment_loan_requests for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and status = 'pending'
    and reviewed_by is null
    and reviewed_at is null
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.role = 'warga'
    )
  );

drop policy if exists "Admins can review pending loan requests"
  on public.equipment_loan_requests;
create policy "Admins can review pending loan requests"
  on public.equipment_loan_requests for update to authenticated
  using (
    status = 'pending'
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.role = 'admin'
    )
  )
  with check (
    status in ('approved', 'rejected')
    and reviewed_by = (select auth.uid())
    and reviewed_at is not null
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.role = 'admin'
    )
  );

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1 from pg_publication_tables where pubname = 'supabase_realtime'
        and schemaname = 'public' and tablename = 'inventory_items'
    ) then
      alter publication supabase_realtime add table public.inventory_items;
    end if;
    if not exists (
      select 1 from pg_publication_tables where pubname = 'supabase_realtime'
        and schemaname = 'public' and tablename = 'equipment_loan_requests'
    ) then
      alter publication supabase_realtime add table public.equipment_loan_requests;
    end if;
  end if;
end
$$;

-- Pengajuan surat dan laporan tamu dari warga ke antrean persetujuan admin.
create table if not exists public.citizen_service_requests (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  resident_name text not null check (char_length(btrim(resident_name)) > 0),
  request_type text not null check (request_type in ('letter', 'guest')),
  request_data jsonb not null check (jsonb_typeof(request_data) = 'object'),
  status text not null default 'pending'
    check (status in ('pending', 'approved', 'rejected')),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now(),
  constraint citizen_request_payload_valid check (
    (request_type = 'letter' and request_data ?& array['applicant_name', 'purpose', 'letter_name'])
    or
    (request_type = 'guest' and request_data ?& array['guest_name', 'guest_origin', 'purpose', 'starts_at', 'ends_at'])
  )
);

create index if not exists citizen_service_requests_user_created_idx
  on public.citizen_service_requests (user_id, created_at desc);
create index if not exists citizen_service_requests_status_created_idx
  on public.citizen_service_requests (status, created_at desc);

alter table public.citizen_service_requests enable row level security;
revoke all privileges on table public.citizen_service_requests from anon, authenticated;
grant select, insert, update on table public.citizen_service_requests to authenticated;

drop policy if exists "Residents and admins can read service requests"
  on public.citizen_service_requests;
create policy "Residents and admins can read service requests"
  on public.citizen_service_requests for select to authenticated
  using (
    user_id = (select auth.uid())
    or exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.role = 'admin'
    )
  );

drop policy if exists "Residents can submit own service requests"
  on public.citizen_service_requests;
create policy "Residents can submit own service requests"
  on public.citizen_service_requests for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and status = 'pending'
    and reviewed_by is null
    and reviewed_at is null
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.role = 'warga'
    )
  );

drop policy if exists "Admins can review pending service requests"
  on public.citizen_service_requests;
create policy "Admins can review pending service requests"
  on public.citizen_service_requests for update to authenticated
  using (
    status = 'pending'
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.role = 'admin'
    )
  )
  with check (
    status in ('approved', 'rejected')
    and reviewed_by = (select auth.uid())
    and reviewed_at is not null
    and exists (
      select 1 from public.profiles p
      where p.id = (select auth.uid()) and p.role = 'admin'
    )
  );

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime')
    and not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public'
        and tablename = 'citizen_service_requests'
    ) then
    alter publication supabase_realtime
      add table public.citizen_service_requests;
  end if;
end
$$;

-- Polling bersama warga dan admin. Suara individual tidak dapat dibaca akun lain.
create table if not exists public.polls (
  id uuid primary key default gen_random_uuid(),
  title text not null check (char_length(btrim(title)) > 0),
  option_one text not null check (char_length(btrim(option_one)) > 0),
  option_two text not null check (char_length(btrim(option_two)) > 0),
  poll_date date not null,
  option_one_votes integer not null default 0 check (option_one_votes >= 0),
  option_two_votes integer not null default 0 check (option_two_votes >= 0),
  created_by uuid not null references auth.users(id) on delete restrict,
  created_at timestamptz not null default now()
);

create table if not exists public.poll_votes (
  poll_id uuid not null references public.polls(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  option_index smallint not null check (option_index in (1, 2)),
  created_at timestamptz not null default now(),
  primary key (poll_id, user_id)
);

create index if not exists polls_created_at_idx
  on public.polls (created_at desc);
create index if not exists poll_votes_user_id_idx
  on public.poll_votes (user_id);

alter table public.polls enable row level security;
alter table public.poll_votes enable row level security;

revoke all privileges on table public.polls from anon, authenticated;
grant select, insert, delete on table public.polls to authenticated;

drop policy if exists "Authenticated users can read polls" on public.polls;
create policy "Authenticated users can read polls"
  on public.polls for select to authenticated using (true);

drop policy if exists "Admins can create polls" on public.polls;
create policy "Admins can create polls"
  on public.polls for insert to authenticated
  with check (
    created_by = (select auth.uid())
    and exists (
      select 1 from public.profiles
      where profiles.id = (select auth.uid()) and profiles.role = 'admin'
    )
  );

drop policy if exists "Admins can delete polls" on public.polls;
create policy "Admins can delete polls"
  on public.polls for delete to authenticated
  using (
    exists (
      select 1 from public.profiles
      where profiles.id = (select auth.uid()) and profiles.role = 'admin'
    )
  );

revoke all privileges on table public.poll_votes from anon, authenticated;
grant select, insert on table public.poll_votes to authenticated;

drop policy if exists "Users can read their own poll votes" on public.poll_votes;
create policy "Users can read their own poll votes"
  on public.poll_votes for select to authenticated
  using ((select auth.uid()) = user_id);

drop policy if exists "Residents can submit their own poll vote"
  on public.poll_votes;
create policy "Residents can submit their own poll vote"
  on public.poll_votes for insert to authenticated
  with check (
    user_id = (select auth.uid())
    and exists (
      select 1 from public.profiles
      where profiles.id = (select auth.uid()) and profiles.role = 'warga'
    )
  );

create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

create or replace function private.increment_poll_vote_count()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  update public.polls
  set option_one_votes = option_one_votes + case when new.option_index = 1 then 1 else 0 end,
      option_two_votes = option_two_votes + case when new.option_index = 2 then 1 else 0 end
  where id = new.poll_id;
  if not found then
    raise exception 'Poll not found';
  end if;
  return new;
end;
$$;

revoke all on function private.increment_poll_vote_count()
  from public, anon, authenticated;

drop trigger if exists increment_poll_vote_count_after_insert
  on public.poll_votes;
create trigger increment_poll_vote_count_after_insert
  after insert on public.poll_votes
  for each row execute function private.increment_poll_vote_count();

do $$
begin
  if exists (select 1 from pg_publication where pubname = 'supabase_realtime') then
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public' and tablename = 'polls'
    ) then
      alter publication supabase_realtime add table public.polls;
    end if;
    if not exists (
      select 1 from pg_publication_tables
      where pubname = 'supabase_realtime'
        and schemaname = 'public' and tablename = 'poll_votes'
    ) then
      alter publication supabase_realtime add table public.poll_votes;
    end if;
  end if;
end
$$;
-- Citizen profile photos stored in Supabase Storage.
insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'profile-photos',
  'profile-photos',
  true,
  5242880,
  array['image/jpeg', 'image/png', 'image/webp']
)
on conflict (id) do update
set public = excluded.public,
    file_size_limit = excluded.file_size_limit,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Public can view profile photos" on storage.objects;
create policy "Public can view profile photos"
  on storage.objects for select to public
  using (bucket_id = 'profile-photos');

drop policy if exists "Users upload own profile photos" on storage.objects;
create policy "Users upload own profile photos"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "Users update own profile photos" on storage.objects;
create policy "Users update own profile photos"
  on storage.objects for update to authenticated
  using (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  )
  with check (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

drop policy if exists "Users delete own profile photos" on storage.objects;
create policy "Users delete own profile photos"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'profile-photos'
    and (storage.foldername(name))[1] = (select auth.uid())::text
  );

-- Decision letters uploaded by admins for residents' service and loan requests.
alter table public.citizen_service_requests
  add column if not exists decision_document_path text;
alter table public.equipment_loan_requests
  add column if not exists decision_document_path text;

insert into storage.buckets (id, name, public, file_size_limit, allowed_mime_types)
values (
  'decision-documents',
  'decision-documents',
  false,
  10485760,
  array[
    'application/pdf',
    'application/msword',
    'application/vnd.openxmlformats-officedocument.wordprocessingml.document'
  ]
)
on conflict (id) do update
set public = false,
    file_size_limit = 10485760,
    allowed_mime_types = excluded.allowed_mime_types;

drop policy if exists "Residents and admins can read own decision documents" on storage.objects;
create policy "Residents and admins can read own decision documents"
  on storage.objects for select to authenticated
  using (
    bucket_id = 'decision-documents'
    and (
      (storage.foldername(name))[1] = (select auth.uid())::text
      or (select private.is_current_user_admin())
    )
  );

drop policy if exists "Admins can upload decision documents" on storage.objects;
create policy "Admins can upload decision documents"
  on storage.objects for insert to authenticated
  with check (
    bucket_id = 'decision-documents'
    and (select private.is_current_user_admin())
  );

drop policy if exists "Admins can delete decision documents" on storage.objects;
create policy "Admins can delete decision documents"
  on storage.objects for delete to authenticated
  using (
    bucket_id = 'decision-documents'
    and (select private.is_current_user_admin())
  );
