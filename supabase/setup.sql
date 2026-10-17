-- SiRT: profil warga, akses baca profil sendiri, dan profil otomatis saat daftar.
-- Pendaftaran publik selalu membuat role warga. Admin dipromosikan manual.

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  full_name text not null default '',
  nik text not null default '',
  phone text not null default '',
  address text not null default '',
  role text not null default 'warga'
    check (role in ('warga', 'admin')),
  created_at timestamptz not null default now()
);

alter table public.profiles enable row level security;

revoke all privileges on table public.profiles from anon, authenticated;
grant select on table public.profiles to authenticated;

drop policy if exists "Users can read own profile" on public.profiles;
create policy "Users can read own profile"
  on public.profiles
  for select
  to authenticated
  using ((select auth.uid()) = id);

-- Simpan fungsi trigger di schema yang tidak diekspos lewat Data API.
create schema if not exists private;
revoke all on schema private from public, anon, authenticated;

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
