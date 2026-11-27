-- Ficha básica gratuita para negocios de Cerca de Ti.
-- No requiere Bizum, efectivo ni justificante. La aprobación editorial sigue siendo manual.
alter table public.cerca_listings
  drop constraint if exists cerca_plan_price_match,
  drop constraint if exists cerca_published_requires_verified_payment,
  drop constraint if exists cerca_listings_payment_status_check,
  drop constraint if exists cerca_listings_plan_check;

alter table public.cerca_listings drop constraint if exists cerca_listings_category_check;

alter table public.cerca_listings
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
    (
      starts_at is not null and
      (
        (plan = 'directory_free' and payment_status = 'not_required' and expires_at is null) or
        (plan <> 'directory_free' and payment_status = 'verified' and expires_at is not null and expires_at > starts_at)
      )
    )
  );

drop policy if exists "cerca_public_active_paid" on public.cerca_listings;
create policy "cerca_owner_creates_free_business" on public.cerca_listings
for insert to authenticated with check (
  owner_id = (select auth.uid()) and plan = 'directory_free'
  and price_cents = 0 and payment_status = 'not_required'
  and publication_status = 'pending' and starts_at is null and expires_at is null
);

create policy "cerca_public_active_listings" on public.cerca_listings
for select to anon, authenticated using (
  publication_status = 'published' and
  (
    (plan = 'directory_free' and payment_status = 'not_required' and expires_at is null) or
    (payment_status = 'verified' and starts_at <= now() and expires_at > now())
  )
);

create or replace function public.cerca_submit_listing(
  p_listing jsonb, p_method text default null, p_reference_note text default ''
)
returns uuid language plpgsql security invoker set search_path = ''
as $$
declare v_id uuid; v_plan text; v_price integer; v_payment_status text;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  v_plan := p_listing->>'plan';
  v_price := case v_plan when 'directory_free' then 0 when 'basic' then 200
    when 'standard' then 500 when 'featured' then 700
    when 'business' then 500 when 'business_plus' then 800 else null end;
  if v_price is null then raise exception 'invalid_plan'; end if;
  if v_plan = 'directory_free' then
    if p_method is not null and p_method <> 'none' then raise exception 'free_listing_has_no_payment'; end if;
    v_payment_status := 'not_required';
  else
    if p_method not in ('bizum','cash') then raise exception 'invalid_payment_method'; end if;
    v_payment_status := 'pending';
  end if;

  insert into public.cerca_listings(owner_id,listing_type,title,category,locality,
    description,contact_phone,plan,price_cents,payment_status)
  values(auth.uid(),case when v_plan in ('business','business_plus','directory_free') then 'business' else 'ad' end,
    p_listing->>'title',p_listing->>'category',p_listing->>'locality',
    p_listing->>'description',p_listing->>'contact_phone',v_plan,v_price,v_payment_status)
  returning id into v_id;

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
declare v_plan text;
begin
  if not cerca_private.is_admin() then raise exception 'not_authorized'; end if;
  select l.plan into v_plan from public.cerca_listings l
  where l.id = p_listing_id for update;
  if not found then raise exception 'listing_not_found'; end if;

  if v_plan = 'directory_free' then
    if p_approve then
      update public.cerca_listings set publication_status='published',
        starts_at=now(), expires_at=null, updated_at=now()
      where id=p_listing_id and payment_status='not_required';
    else
      update public.cerca_listings set publication_status='rejected', updated_at=now()
      where id=p_listing_id and payment_status='not_required';
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
