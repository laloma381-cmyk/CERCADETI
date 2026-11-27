-- Cerca de Ti: ficha gratuita, coordenadas opcionales y administración aislada.
-- No altera policies ni datos de public.profiles o public.reports.
-- La lista de administradores se inicializa copiando solo los superadmins actuales.

create schema if not exists cerca_private;

create table if not exists public.cerca_admins (
  user_id uuid primary key references auth.users(id) on delete cascade,
  active boolean not null default true,
  created_at timestamptz not null default now()
);
alter table public.cerca_admins enable row level security;
revoke all on public.cerca_admins from public, anon, authenticated;
insert into public.cerca_admins(user_id, active)
select p.id, true from public.profiles p
where p.role = 'super_admin' and p.is_super_admin is true
  and coalesce(p.is_suspended, false) = false
on conflict (user_id) do nothing;

create or replace function cerca_private.is_admin()
returns boolean language sql stable security definer set search_path = ''
as $$
  select exists (select 1 from public.cerca_admins a
    where a.user_id = (select auth.uid()) and a.active = true);
$$;
revoke all on function cerca_private.is_admin() from public, anon;
grant usage on schema cerca_private to authenticated;
grant execute on function cerca_private.is_admin() to authenticated;

create or replace function public.cerca_is_admin()
returns boolean language sql stable security invoker set search_path = ''
as $$ select cerca_private.is_admin(); $$;
revoke all on function public.cerca_is_admin() from public, anon;
grant execute on function public.cerca_is_admin() to authenticated;

alter table public.cerca_listings
  add column if not exists latitude double precision,
  add column if not exists longitude double precision;

alter table public.cerca_listings
  drop constraint if exists cerca_listings_category_check,
  drop constraint if exists cerca_listings_plan_check,
  drop constraint if exists cerca_listings_payment_status_check,
  drop constraint if exists cerca_plan_price_match,
  drop constraint if exists cerca_published_requires_verified_payment,
  drop constraint if exists cerca_published_payment_valid,
  drop constraint if exists cerca_coordinates_pair_check,
  add constraint cerca_listings_category_check
    check (category in ('Comercios','Servicios','Ofertas','Eventos','Hostelería','Hogar','Otros','Belleza','Salud','Tiendas','Motor')),
  add constraint cerca_listings_plan_check
    check (plan in ('directory_free','basic','standard','featured','business','business_plus')),
  add constraint cerca_listings_payment_status_check
    check (payment_status in ('not_required','pending','reported','verified','rejected')),
  add constraint cerca_plan_price_match check (
    (plan = 'directory_free' and price_cents = 0 and payment_status = 'not_required') or
    (plan = 'basic' and price_cents = 200) or
    (plan = 'standard' and price_cents = 500) or
    (plan = 'featured' and price_cents = 700) or
    (plan = 'business' and price_cents = 500) or
    (plan = 'business_plus' and price_cents = 800)
  ),
  add constraint cerca_published_payment_valid check (
    publication_status <> 'published' or
    (starts_at is not null and (
      (plan = 'directory_free' and payment_status = 'not_required' and expires_at is null) or
      (plan <> 'directory_free' and payment_status = 'verified' and expires_at is not null and expires_at > starts_at)
    ))
  ),
  add constraint cerca_coordinates_pair_check check (
    (latitude is null and longitude is null) or
    (latitude between -90 and 90 and longitude between -180 and 180)
  );

create index if not exists cerca_listings_geo_idx
  on public.cerca_listings(latitude, longitude)
  where latitude is not null and longitude is not null;

drop policy if exists "cerca_public_active_paid" on public.cerca_listings;
drop policy if exists "cerca_public_active_listings" on public.cerca_listings;
drop policy if exists "cerca_anon_reads_published" on public.cerca_listings;
drop policy if exists "cerca_owner_reads_own" on public.cerca_listings;
drop policy if exists "cerca_admin_reads_all_listings" on public.cerca_listings;
drop policy if exists "cerca_authenticated_reads_allowed" on public.cerca_listings;
drop policy if exists "cerca_owner_creates_pending" on public.cerca_listings;
drop policy if exists "cerca_owner_creates_free_business" on public.cerca_listings;
drop policy if exists "cerca_admin_moderates_listings" on public.cerca_listings;

create policy "cerca_anon_reads_published" on public.cerca_listings
for select to anon using (
  publication_status = 'published' and (
    (plan = 'directory_free' and payment_status = 'not_required' and expires_at is null)
    or (payment_status = 'verified' and starts_at <= now() and expires_at > now())
  )
);

create policy "cerca_authenticated_reads_allowed" on public.cerca_listings
for select to authenticated using (
  (select cerca_private.has_current_consent()) and (
    (publication_status = 'published' and (
      (plan = 'directory_free' and payment_status = 'not_required' and expires_at is null)
      or (payment_status = 'verified' and starts_at <= now() and expires_at > now())
    ))
    or owner_id = (select auth.uid())
    or (select cerca_private.is_admin())
  )
);

create policy "cerca_owner_creates_pending" on public.cerca_listings
for insert to authenticated with check (
  (select cerca_private.has_current_consent())
  and owner_id = (select auth.uid())
  and publication_status = 'pending' and starts_at is null and expires_at is null
  and (
    (plan = 'directory_free' and price_cents = 0 and payment_status = 'not_required')
    or (plan <> 'directory_free' and payment_status = 'pending')
  )
);

create policy "cerca_admin_moderates_listings" on public.cerca_listings
for update to authenticated
using ((select cerca_private.has_current_consent()) and (select cerca_private.is_admin()))
with check ((select cerca_private.has_current_consent()) and (select cerca_private.is_admin()));

revoke select on public.cerca_listings from anon;
grant select (
  id, title, category, locality, description, contact_phone,
  plan, starts_at, expires_at, latitude, longitude
) on public.cerca_listings to anon;

create or replace function public.cerca_submit_listing(
  p_listing jsonb, p_method text default null, p_reference_note text default ''
)
returns uuid language plpgsql security invoker set search_path = ''
as $$
declare
  v_id uuid; v_plan text; v_price integer; v_payment_status text;
  v_lat double precision; v_lon double precision;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if not cerca_private.has_current_consent() then raise exception 'legal_consent_required'; end if;
  v_plan := p_listing->>'plan';
  v_price := case v_plan when 'directory_free' then 0 when 'basic' then 200
    when 'standard' then 500 when 'featured' then 700
    when 'business' then 500 when 'business_plus' then 800 else null end;
  if v_price is null then raise exception 'invalid_plan'; end if;

  if v_plan = 'directory_free' then
    if p_method is not null and p_method not in ('none','') then
      raise exception 'free_listing_has_no_payment';
    end if;
    v_payment_status := 'not_required';
  else
    if p_method is null or p_method not in ('bizum','cash') then
      raise exception 'invalid_payment_method';
    end if;
    v_payment_status := 'pending';
  end if;

  v_lat := nullif(p_listing->>'latitude','')::double precision;
  v_lon := nullif(p_listing->>'longitude','')::double precision;
  if (v_lat is null) <> (v_lon is null) then
    raise exception 'latitude_and_longitude_must_be_provided_together';
  end if;
  if v_lat is not null and (v_lat < -90 or v_lat > 90 or v_lon < -180 or v_lon > 180) then
    raise exception 'invalid_coordinates';
  end if;

  insert into public.cerca_listings(
    owner_id, listing_type, title, category, locality, description, contact_phone,
    plan, price_cents, payment_status, latitude, longitude
  ) values (
    auth.uid(),
    case when v_plan in ('business','business_plus','directory_free') then 'business' else 'ad' end,
    p_listing->>'title', p_listing->>'category', p_listing->>'locality',
    p_listing->>'description', p_listing->>'contact_phone',
    v_plan, v_price, v_payment_status, v_lat, v_lon
  ) returning id into v_id;

  if v_plan <> 'directory_free' then
    insert into public.cerca_payment_reports(listing_id,user_id,method,reference_note)
    values(v_id,auth.uid(),p_method,coalesce(p_reference_note,''));
  end if;
  return v_id;
end;
$$;
revoke all on function public.cerca_submit_listing(jsonb,text,text) from public, anon;
grant execute on function public.cerca_submit_listing(jsonb,text,text) to authenticated;

create or replace function public.cerca_admin_review_listing(p_listing_id uuid, p_approve boolean)
returns void language plpgsql security invoker set search_path = ''
as $$
declare v_plan text; v_payment_status text;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if not cerca_private.has_current_consent() or not cerca_private.is_admin() then
    raise exception 'not_authorized';
  end if;
  select l.plan, l.payment_status into v_plan, v_payment_status
  from public.cerca_listings l where l.id = p_listing_id for update;
  if not found then raise exception 'listing_not_found'; end if;

  if v_plan = 'directory_free' then
    if v_payment_status <> 'not_required' then raise exception 'invalid_free_listing_state'; end if;
    if p_approve then
      update public.cerca_listings set publication_status='published',
        starts_at=now(), expires_at=null, updated_at=now()
      where id=p_listing_id and publication_status='pending';
    else
      update public.cerca_listings set publication_status='rejected', updated_at=now()
      where id=p_listing_id and publication_status='pending';
    end if;
    return;
  end if;

  if not exists (select 1 from public.cerca_payment_reports pr
    where pr.listing_id=p_listing_id and pr.status='pending') then
    raise exception 'payment_report_not_pending';
  end if;
  if p_approve then
    update public.cerca_payment_reports set status='verified',
      reviewed_by=auth.uid(), reviewed_at=now()
    where listing_id=p_listing_id and status='pending';
    update public.cerca_listings set payment_status='verified',
      publication_status='published', starts_at=now(),
      expires_at=now()+case when v_plan='basic' then interval '7 days' else interval '30 days' end,
      updated_at=now() where id=p_listing_id;
  else
    update public.cerca_payment_reports set status='rejected',
      reviewed_by=auth.uid(), reviewed_at=now()
    where listing_id=p_listing_id and status='pending';
    update public.cerca_listings set payment_status='rejected',
      publication_status='rejected', updated_at=now() where id=p_listing_id;
  end if;
end;
$$;
revoke all on function public.cerca_admin_review_listing(uuid,boolean) from public, anon;
grant execute on function public.cerca_admin_review_listing(uuid,boolean) to authenticated;
