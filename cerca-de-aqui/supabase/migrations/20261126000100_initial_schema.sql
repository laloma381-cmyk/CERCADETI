-- Cerca de Aquí: esquema aislado. Ejecutar solo en el proyecto Supabase propio de esta app.
create extension if not exists pgcrypto;

create schema if not exists private;

create table if not exists public.profiles (
  id uuid primary key references auth.users(id) on delete cascade,
  display_name text not null default '',
  role text not null default 'user' check (role in ('user','admin')),
  blocked boolean not null default false,
  created_at timestamptz not null default now()
);

create table if not exists public.listings (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  title text not null check (char_length(title) between 2 and 80),
  category text not null check (category in ('Comercios','Servicios','Ofertas','Eventos','Hostelería','Hogar','Otros')),
  locality text not null check (char_length(locality) between 2 and 80),
  description text not null check (char_length(description) between 10 and 700),
  contact_phone text not null check (char_length(contact_phone) between 6 and 30),
  plan text not null check (plan in ('basic','standard','featured','business','business_plus')),
  price_cents integer not null check (price_cents in (200,500,700,500,800)),
  payment_method text check (payment_method in ('bizum','cash')),
  payment_status text not null default 'pending' check (payment_status in ('pending','reported','verified','rejected')),
  publication_status text not null default 'pending' check (publication_status in ('pending','published','rejected','expired','blocked')),
  starts_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint verified_required check (publication_status <> 'published' or (payment_status = 'verified' and starts_at is not null and expires_at is not null))
);

create index if not exists listings_public_idx on public.listings(publication_status, category, expires_at);
create index if not exists listings_owner_idx on public.listings(owner_id, created_at desc);

create table if not exists public.payment_reports (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null unique references public.listings(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  method text not null check (method in ('bizum','cash')),
  reference_note text not null default '' check (char_length(reference_note) <= 160),
  status text not null default 'pending' check (status in ('pending','verified','rejected')),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

create or replace function private.is_admin()
returns boolean
language sql
stable
security definer
set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid()) and p.role = 'admin' and p.blocked = false
  );
$$;

revoke all on function private.is_admin() from public, anon;
grant usage on schema private to authenticated;
grant execute on function private.is_admin() to authenticated;

create or replace function public.handle_new_user()
returns trigger
language plpgsql
security definer
set search_path = ''
as $$
begin
  insert into public.profiles(id, display_name)
  values (new.id, coalesce(new.raw_user_meta_data->>'display_name',''));
  return new;
end;
$$;

drop trigger if exists on_auth_user_created_cerca on auth.users;
create trigger on_auth_user_created_cerca
after insert on auth.users
for each row execute function public.handle_new_user();

alter table public.profiles enable row level security;
alter table public.listings enable row level security;
alter table public.payment_reports enable row level security;

grant select on public.profiles to authenticated;
grant insert, select on public.listings to authenticated;
grant select on public.listings to anon, authenticated;
grant insert, select on public.payment_reports to authenticated;

create policy "profile owner or admin read" on public.profiles
for select to authenticated
using (id = (select auth.uid()) or (select private.is_admin()));

create policy "public sees only paid active listings" on public.listings
for select to anon, authenticated
using (
  publication_status = 'published'
  and payment_status = 'verified'
  and starts_at <= now()
  and expires_at > now()
);

create policy "owners see own listings" on public.listings
for select to authenticated
using (owner_id = (select auth.uid()) or (select private.is_admin()));

create policy "signed users submit pending listings" on public.listings
for insert to authenticated
with check (
  owner_id = (select auth.uid())
  and payment_status = 'pending'
  and publication_status = 'pending'
  and starts_at is null
  and expires_at is null
);

create policy "users submit own payment report" on public.payment_reports
for insert to authenticated
with check (
  user_id = (select auth.uid())
  and status = 'pending'
  and exists (
    select 1 from public.listings l
    where l.id = listing_id and l.owner_id = (select auth.uid())
      and l.publication_status = 'pending' and l.payment_status = 'pending'
  )
);

create policy "owners see own payment reports" on public.payment_reports
for select to authenticated
using (user_id = (select auth.uid()) or (select private.is_admin()));

-- No se concede UPDATE/DELETE a usuarios normales. El administrador revisa
-- pagos y publica desde un entorno autenticado con rol admin.
