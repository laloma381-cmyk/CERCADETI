-- Revisión atómica de pagos y publicación. Solo el superadministrador real de CAJUMAV.
create or replace function public.cerca_admin_review_listing(p_listing_id uuid, p_approve boolean)
returns void language plpgsql security invoker set search_path = ''
as $$
declare v_plan text;
begin
  if not cerca_private.is_admin() then raise exception 'not_authorized'; end if;
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

-- Alta transaccional: guarda anuncio y justificante de pago juntos.
create or replace function public.cerca_submit_listing(
  p_listing jsonb, p_method text, p_reference_note text default ''
)
returns uuid language plpgsql security invoker set search_path = ''
as $$
declare v_id uuid; v_plan text; v_price integer;
begin
  if auth.uid() is null then raise exception 'authentication_required'; end if;
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
