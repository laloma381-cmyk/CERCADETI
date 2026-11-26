-- Revisión atómica de pagos y publicación. Solo el superadministrador real de CAJUMAV.
create or replace function public.cerca_admin_review_listing(p_listing_id uuid, p_approve boolean)
returns void language plpgsql security definer set search_path = ''
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
