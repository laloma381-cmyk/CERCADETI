-- Cerca de Aquí: tablas independientes dentro del proyecto Supabase CAJUMAV.
-- No modifica tablas, políticas ni funciones de mensajería familiar.
create schema if not exists cerca_private;

create table if not exists public.cerca_listings (
  id uuid primary key default gen_random_uuid(),
  owner_id uuid not null references auth.users(id) on delete cascade,
  listing_type text not null default 'ad' check (listing_type in ('ad','business')),
  title text not null check (char_length(btrim(title)) between 2 and 80),
  category text not null check (category in ('Comercios','Servicios','Ofertas','Eventos','Hostelería','Hogar','Otros')),
  locality text not null check (char_length(btrim(locality)) between 2 and 80),
  description text not null check (char_length(btrim(description)) between 10 and 700),
  contact_phone text not null check (char_length(contact_phone) between 6 and 30),
  plan text not null check (plan in ('basic','standard','featured','business','business_plus')),
  price_cents integer not null,
  payment_method text check (payment_method in ('bizum','cash')),
  payment_status text not null default 'pending' check (payment_status in ('pending','reported','verified','rejected')),
  publication_status text not null default 'pending' check (publication_status in ('pending','published','rejected','expired','blocked')),
  starts_at timestamptz,
  expires_at timestamptz,
  created_at timestamptz not null default now(),
  updated_at timestamptz not null default now(),
  constraint cerca_plan_price_match check (
    (plan = 'basic' and price_cents = 200) or
    (plan = 'standard' and price_cents = 500) or
    (plan = 'featured' and price_cents = 700) or
    (plan = 'business' and price_cents = 500) or
    (plan = 'business_plus' and price_cents = 800)
  ),
  constraint cerca_published_requires_verified_payment check (
    publication_status <> 'published' or
    (payment_status = 'verified' and starts_at is not null and expires_at is not null and expires_at > starts_at)
  )
);

create index if not exists cerca_listings_public_idx on public.cerca_listings(publication_status, category, expires_at);
create index if not exists cerca_listings_owner_idx on public.cerca_listings(owner_id, created_at desc);

create table if not exists public.cerca_payment_reports (
  id uuid primary key default gen_random_uuid(),
  listing_id uuid not null unique references public.cerca_listings(id) on delete cascade,
  user_id uuid not null references auth.users(id) on delete cascade,
  method text not null check (method in ('bizum','cash')),
  reference_note text not null default '' check (char_length(reference_note) <= 160),
  status text not null default 'pending' check (status in ('pending','verified','rejected')),
  reviewed_by uuid references auth.users(id),
  reviewed_at timestamptz,
  created_at timestamptz not null default now()
);

create or replace function cerca_private.is_admin()
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (
    select 1 from public.profiles p
    where p.id = (select auth.uid())
      and p.role = 'super_admin'
      and p.is_super_admin = true
      and coalesce(p.is_suspended,false) = false
  );
$$;

revoke all on function cerca_private.is_admin() from public, anon;
grant usage on schema cerca_private to authenticated;
grant execute on function cerca_private.is_admin() to authenticated;

alter table public.cerca_listings enable row level security;
alter table public.cerca_payment_reports enable row level security;
grant select, insert on public.cerca_listings to authenticated;
grant select on public.cerca_listings to anon;
grant update on public.cerca_listings to authenticated;
grant select, insert on public.cerca_payment_reports to authenticated;
grant update on public.cerca_payment_reports to authenticated;

create policy "cerca_public_active_paid" on public.cerca_listings
for select to anon, authenticated using (
  publication_status = 'published' and payment_status = 'verified'
  and starts_at <= now() and expires_at > now()
);
create policy "cerca_owner_reads_own" on public.cerca_listings
for select to authenticated using (owner_id = (select auth.uid()));
create policy "cerca_admin_reads_all_listings" on public.cerca_listings
for select to authenticated using ((select cerca_private.is_admin()));
create policy "cerca_owner_creates_pending" on public.cerca_listings
for insert to authenticated with check (
  owner_id = (select auth.uid()) and payment_status = 'pending'
  and publication_status = 'pending' and starts_at is null and expires_at is null
);
create policy "cerca_admin_moderates_listings" on public.cerca_listings
for update to authenticated using ((select cerca_private.is_admin()))
with check ((select cerca_private.is_admin()));

create policy "cerca_owner_reads_payment_reports" on public.cerca_payment_reports
for select to authenticated using (user_id = (select auth.uid()));
create policy "cerca_admin_reads_payment_reports" on public.cerca_payment_reports
for select to authenticated using ((select cerca_private.is_admin()));
create policy "cerca_owner_reports_payment" on public.cerca_payment_reports
for insert to authenticated with check (
  user_id = (select auth.uid()) and status = 'pending'
  and exists (
    select 1 from public.cerca_listings l
    where l.id = listing_id and l.owner_id = (select auth.uid())
      and l.publication_status = 'pending' and l.payment_status = 'pending'
  )
);
create policy "cerca_admin_reviews_payments" on public.cerca_payment_reports
for update to authenticated using ((select cerca_private.is_admin()))
with check ((select cerca_private.is_admin()));
