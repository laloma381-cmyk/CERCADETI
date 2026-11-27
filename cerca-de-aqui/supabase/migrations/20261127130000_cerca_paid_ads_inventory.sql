-- Cerca de Ti: solo publicaciones comerciales de pago, tarifas 4/6/9 EUR.
-- Conserva los registros existentes; actualmente se verificó que cerca_listings está vacía.

alter table public.cerca_listings
  drop constraint if exists cerca_listings_plan_check,
  drop constraint if exists cerca_plan_price_match,
  drop constraint if exists cerca_published_payment_valid;

alter table public.cerca_listings
  add constraint cerca_listings_plan_check
    check (plan in ('basic','standard','featured')),
  add constraint cerca_plan_price_match check (
    (plan = 'basic' and price_cents = 400) or
    (plan = 'standard' and price_cents = 600) or
    (plan = 'featured' and price_cents = 900)
  ),
  add constraint cerca_published_payment_valid check (
    publication_status <> 'published' or
    (payment_status = 'verified' and starts_at is not null
      and expires_at is not null and expires_at > starts_at)
  );

drop policy if exists cerca_anon_reads_published on public.cerca_listings;
drop policy if exists cerca_authenticated_reads_allowed on public.cerca_listings;
drop policy if exists cerca_owner_creates_pending on public.cerca_listings;

create policy cerca_anon_reads_published on public.cerca_listings
for select to anon using (
  publication_status='published' and payment_status='verified'
  and starts_at <= now() and expires_at > now()
);

create policy cerca_authenticated_reads_allowed on public.cerca_listings
for select to authenticated using (
  (select cerca_private.has_current_consent()) and (
    (publication_status='published' and payment_status='verified'
      and starts_at <= now() and expires_at > now())
    or owner_id=(select auth.uid())
    or (select cerca_private.is_admin())
  )
);

create policy cerca_owner_creates_pending on public.cerca_listings
for insert to authenticated with check (
  (select cerca_private.has_current_consent())
  and owner_id=(select auth.uid())
  and publication_status='pending'
  and starts_at is null and expires_at is null
  and plan in ('basic','standard','featured')
  and payment_status='pending'
);

create or replace function public.cerca_submit_listing(
  p_listing jsonb, p_method text default null, p_reference_note text default ''
)
returns uuid language plpgsql security invoker set search_path = ''
as $$
declare
  v_id uuid; v_plan text; v_price integer;
  v_lat double precision; v_lon double precision;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if not cerca_private.has_current_consent() then raise exception 'legal_consent_required'; end if;
  v_plan := p_listing->>'plan';
  v_price := case v_plan when 'basic' then 400 when 'standard' then 600 when 'featured' then 900 else null end;
  if v_price is null then raise exception 'invalid_paid_plan'; end if;
  if p_method is null or p_method not in ('bizum','cash') then
    raise exception 'invalid_payment_method';
  end if;
  v_lat := nullif(p_listing->>'latitude','')::double precision;
  v_lon := nullif(p_listing->>'longitude','')::double precision;
  if (v_lat is null) <> (v_lon is null) then raise exception 'latitude_and_longitude_must_be_provided_together'; end if;
  if v_lat is not null and (v_lat < -90 or v_lat > 90 or v_lon < -180 or v_lon > 180) then raise exception 'invalid_coordinates'; end if;
  insert into public.cerca_listings(
    owner_id,listing_type,title,category,locality,description,contact_phone,
    plan,price_cents,payment_status,latitude,longitude
  ) values (
    auth.uid(),case when v_plan='featured' then 'ad' else 'business' end,
    p_listing->>'title',p_listing->>'category',p_listing->>'locality',
    p_listing->>'description',p_listing->>'contact_phone',
    v_plan,v_price,'pending',v_lat,v_lon
  ) returning id into v_id;
  insert into public.cerca_payment_reports(listing_id,user_id,method,reference_note)
  values(v_id,auth.uid(),p_method,coalesce(p_reference_note,''));
  return v_id;
end;
$$;
revoke all on function public.cerca_submit_listing(jsonb,text,text) from public,anon;
grant execute on function public.cerca_submit_listing(jsonb,text,text) to authenticated;

create or replace function public.cerca_admin_review_listing(p_listing_id uuid,p_approve boolean)
returns void language plpgsql security invoker set search_path = ''
as $$
declare v_plan text; v_status text;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if not cerca_private.has_current_consent() or not cerca_private.is_admin() then raise exception 'not_authorized'; end if;
  select l.plan,l.payment_status into v_plan,v_status
  from public.cerca_listings l where l.id=p_listing_id for update;
  if not found then raise exception 'listing_not_found'; end if;
  if v_status<>'pending' or not exists(
    select 1 from public.cerca_payment_reports pr
    where pr.listing_id=p_listing_id and pr.status='pending'
  ) then raise exception 'payment_report_not_pending'; end if;
  if p_approve then
    update public.cerca_payment_reports set status='verified',reviewed_by=auth.uid(),reviewed_at=now()
    where listing_id=p_listing_id and status='pending';
    update public.cerca_listings set payment_status='verified',publication_status='published',
      starts_at=now(),expires_at=now()+case when v_plan='basic' then interval '7 days' else interval '30 days' end,
      updated_at=now() where id=p_listing_id;
  else
    update public.cerca_payment_reports set status='rejected',reviewed_by=auth.uid(),reviewed_at=now()
    where listing_id=p_listing_id and status='pending';
    update public.cerca_listings set payment_status='rejected',publication_status='rejected',updated_at=now()
    where id=p_listing_id;
  end if;
end;
$$;
revoke all on function public.cerca_admin_review_listing(uuid,boolean) from public,anon;
grant execute on function public.cerca_admin_review_listing(uuid,boolean) to authenticated;

create index if not exists cerca_active_paid_directory_idx
on public.cerca_listings(locality,category,plan,starts_at desc)
where publication_status='published' and payment_status='verified';
