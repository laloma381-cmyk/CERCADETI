-- Consentimiento legal separado para Cerca de Aquí. No toca CAJUMA/CAJUMAV.
create table if not exists public.cerca_user_consents (
  id uuid primary key default gen_random_uuid(),
  user_id uuid not null references auth.users(id) on delete cascade,
  terms_version text not null,
  privacy_version text not null,
  accepted_at timestamptz not null default now(),
  marketing_opt_in boolean not null default false,
  app_version text,
  unique (user_id, terms_version, privacy_version)
);

alter table public.cerca_user_consents enable row level security;
revoke all on public.cerca_user_consents from anon, authenticated;
grant select, insert on public.cerca_user_consents to authenticated;

drop policy if exists "cerca_user_reads_own_consent" on public.cerca_user_consents;
create policy "cerca_user_reads_own_consent"
on public.cerca_user_consents for select to authenticated
using (user_id = (select auth.uid()));

drop policy if exists "cerca_user_records_own_consent" on public.cerca_user_consents;
create policy "cerca_user_records_own_consent"
on public.cerca_user_consents for insert to authenticated
with check (user_id = (select auth.uid()));

create or replace function cerca_private.has_current_consent()
returns boolean
language sql stable security invoker set search_path = ''
as $$
  select exists (
    select 1 from public.cerca_user_consents c
    where c.user_id = (select auth.uid())
      and c.terms_version = '2026-11-26-v1'
      and c.privacy_version = '2026-11-26-v1'
  );
$$;
revoke all on function cerca_private.has_current_consent() from public, anon;
grant execute on function cerca_private.has_current_consent() to authenticated;
grant usage on schema cerca_private to authenticated;

-- El directorio deja de permitir consultas anónimas: el usuario debe iniciar sesión
-- y aceptar los documentos antes de consultar anuncios o publicar.
drop policy if exists "cerca_anon_reads_published" on public.cerca_listings;
drop policy if exists "cerca_public_active_paid" on public.cerca_listings;
revoke select on public.cerca_listings from anon;

drop policy if exists "cerca_authenticated_reads_allowed" on public.cerca_listings;
create policy "cerca_authenticated_reads_allowed"
on public.cerca_listings for select to authenticated
using (
  (select cerca_private.has_current_consent())
  and (
    (publication_status='published' and payment_status='verified'
      and starts_at <= now() and expires_at > now())
    or owner_id=(select auth.uid())
    or (select cerca_private.is_admin())
  )
);

drop policy if exists "cerca_owner_creates_pending" on public.cerca_listings;
create policy "cerca_owner_creates_pending"
on public.cerca_listings for insert to authenticated
with check (
  (select cerca_private.has_current_consent())
  and owner_id=(select auth.uid())
  and payment_status='pending'
  and publication_status='pending'
  and starts_at is null and expires_at is null
);

drop policy if exists "cerca_admin_moderates_listings" on public.cerca_listings;
create policy "cerca_admin_moderates_listings"
on public.cerca_listings for update to authenticated
using ((select cerca_private.has_current_consent()) and (select cerca_private.is_admin()))
with check ((select cerca_private.has_current_consent()) and (select cerca_private.is_admin()));

drop policy if exists "cerca_authenticated_reads_payment_reports" on public.cerca_payment_reports;
drop policy if exists "cerca_owner_reads_payment_reports" on public.cerca_payment_reports;
drop policy if exists "cerca_admin_reads_payment_reports" on public.cerca_payment_reports;
create policy "cerca_authenticated_reads_payment_reports"
on public.cerca_payment_reports for select to authenticated
using (
  (select cerca_private.has_current_consent())
  and (user_id=(select auth.uid()) or (select cerca_private.is_admin()))
);

drop policy if exists "cerca_owner_reports_payment" on public.cerca_payment_reports;
create policy "cerca_owner_reports_payment"
on public.cerca_payment_reports for insert to authenticated
with check (
  (select cerca_private.has_current_consent())
  and user_id=(select auth.uid())
  and status='pending'
  and exists (
    select 1 from public.cerca_listings l
    where l.id=listing_id and l.owner_id=(select auth.uid())
      and l.publication_status='pending' and l.payment_status='pending'
  )
);

drop policy if exists "cerca_admin_reviews_payments" on public.cerca_payment_reports;
create policy "cerca_admin_reviews_payments"
on public.cerca_payment_reports for update to authenticated
using ((select cerca_private.has_current_consent()) and (select cerca_private.is_admin()))
with check ((select cerca_private.has_current_consent()) and (select cerca_private.is_admin()));

create or replace function public.cerca_submit_listing(
  p_listing jsonb, p_method text, p_reference_note text default ''
)
returns uuid language plpgsql security invoker set search_path = ''
as $$
declare v_id uuid; v_plan text; v_price integer;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if not cerca_private.has_current_consent() then raise exception 'legal_consent_required'; end if;
  if p_method not in ('bizum','cash') then raise exception 'invalid_payment_method'; end if;
  v_plan := p_listing->>'plan';
  v_price := case v_plan when 'basic' then 200 when 'standard' then 500
    when 'featured' then 700 when 'business' then 500 when 'business_plus' then 800 else null end;
  if v_price is null then raise exception 'invalid_plan'; end if;
  insert into public.cerca_listings(owner_id,listing_type,title,category,locality,
    description,contact_phone,plan,price_cents)
  values(auth.uid(),case when v_plan in ('business','business_plus') then 'business' else 'ad' end,
    p_listing->>'title',p_listing->>'category',p_listing->>'locality',
    p_listing->>'description',p_listing->>'contact_phone',v_plan,v_price)
  returning id into v_id;
  insert into public.cerca_payment_reports(listing_id,user_id,method,reference_note)
  values(v_id,auth.uid(),p_method,coalesce(p_reference_note,''));
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
  if auth.uid() is null then raise exception 'authentication_required'; end if;
  if not cerca_private.has_current_consent() or not cerca_private.is_admin() then
    raise exception 'not_authorized';
  end if;
  select l.plan into v_plan from public.cerca_listings l
  where l.id = p_listing_id for update;
  if not found then raise exception 'listing_not_found'; end if;
  if not exists (select 1 from public.cerca_payment_reports pr
    where pr.listing_id = p_listing_id and pr.status = 'pending') then
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
