-- Cerca de Ti: catálogo editorial, administración y fotos de negocios.
-- Solo superadministradores pueden crear fichas sin pago.
alter table public.cerca_listings
 add column if not exists address text not null default '',
 add column if not exists photo_url text,
 add column if not exists opening_hours text not null default '',
 add column if not exists is_featured boolean not null default false,
 add column if not exists created_by_admin boolean not null default false;
alter table public.cerca_listings drop constraint if exists cerca_listings_plan_check, drop constraint if exists cerca_plan_price_match;
alter table public.cerca_listings add constraint cerca_listings_plan_check check(plan in('admin','basic','standard','featured'));
alter table public.cerca_listings add constraint cerca_plan_price_match check(
 (plan='admin' and price_cents=0 and created_by_admin=true) or
 (plan='basic' and price_cents=400) or (plan='standard' and price_cents=600) or (plan='featured' and price_cents=900));
update public.cerca_listings set is_featured=true where plan='featured';

drop policy if exists cerca_admin_inserts_listings on public.cerca_listings;
create policy cerca_admin_inserts_listings on public.cerca_listings for insert to authenticated with check(
 (select cerca_private.is_admin()) and owner_id=(select auth.uid()) and created_by_admin=true
 and plan='admin' and price_cents=0 and payment_status='verified' and publication_status='published'
 and starts_at is not null and expires_at>starts_at);
drop policy if exists cerca_admin_deletes_listings on public.cerca_listings;
create policy cerca_admin_deletes_listings on public.cerca_listings for delete to authenticated using((select cerca_private.is_admin()));
grant delete on public.cerca_listings to authenticated;

create or replace function public.cerca_admin_create_listing(p_listing jsonb)
returns uuid language plpgsql security invoker set search_path=''
as $$
declare v_id uuid; v_lat double precision; v_lon double precision;
begin
 if auth.uid() is null or not cerca_private.is_admin() then raise exception 'not_authorized'; end if;
 if not cerca_private.has_current_consent() then raise exception 'legal_consent_required'; end if;
 v_lat:=nullif(p_listing->>'latitude','')::double precision; v_lon:=nullif(p_listing->>'longitude','')::double precision;
 if (v_lat is null)<>(v_lon is null) then raise exception 'latitude_and_longitude_must_be_provided_together'; end if;
 if v_lat is not null and (v_lat < -90 or v_lat > 90 or v_lon < -180 or v_lon > 180) then raise exception 'invalid_coordinates'; end if;
 insert into public.cerca_listings(owner_id,listing_type,title,category,locality,address,description,contact_phone,plan,price_cents,payment_status,publication_status,starts_at,expires_at,latitude,longitude,photo_url,opening_hours,is_featured,created_by_admin)
 values(auth.uid(),'business',btrim(p_listing->>'title'),p_listing->>'category',btrim(p_listing->>'locality'),coalesce(p_listing->>'address',''),
 coalesce(nullif(btrim(p_listing->>'description'),''),'Negocio local de Cerca de Ti.'),btrim(p_listing->>'contact_phone'),'admin',0,'verified','published',now(),now()+interval '365 days',v_lat,v_lon,
 nullif(p_listing->>'photo_url',''),coalesce(p_listing->>'opening_hours',''),coalesce((p_listing->>'is_featured')::boolean,false),true)
 returning id into v_id;
 return v_id;
end $$;
revoke all on function public.cerca_admin_create_listing(jsonb) from public,anon;
grant execute on function public.cerca_admin_create_listing(jsonb) to authenticated;

create or replace function public.cerca_admin_update_listing(p_listing_id uuid,p_listing jsonb)
returns void language plpgsql security invoker set search_path=''
as $$
begin
 if auth.uid() is null or not cerca_private.is_admin() then raise exception 'not_authorized'; end if;
 update public.cerca_listings set
 title=coalesce(nullif(btrim(p_listing->>'title'),''),title),category=coalesce(p_listing->>'category',category),
 locality=coalesce(nullif(btrim(p_listing->>'locality'),''),locality),address=coalesce(p_listing->>'address',address),
 description=coalesce(p_listing->>'description',description),contact_phone=coalesce(p_listing->>'contact_phone',contact_phone),
 photo_url=coalesce(nullif(p_listing->>'photo_url',''),photo_url),opening_hours=coalesce(p_listing->>'opening_hours',opening_hours),
 is_featured=coalesce((p_listing->>'is_featured')::boolean,is_featured),
 latitude=case when p_listing ? 'latitude' then nullif(p_listing->>'latitude','')::double precision else latitude end,
 longitude=case when p_listing ? 'longitude' then nullif(p_listing->>'longitude','')::double precision else longitude end,
 updated_at=now() where id=p_listing_id;
 if not found then raise exception 'listing_not_found'; end if;
end $$;
revoke all on function public.cerca_admin_update_listing(uuid,jsonb) from public,anon;
grant execute on function public.cerca_admin_update_listing(uuid,jsonb) to authenticated;

create or replace function public.cerca_admin_set_listing_status(p_listing_id uuid,p_status text)
returns void language plpgsql security invoker set search_path=''
as $$
declare v_admin boolean; v_exp timestamptz; v_created boolean;
begin
 if auth.uid() is null or not cerca_private.is_admin() then raise exception 'not_authorized'; end if;
 if p_status not in('published','blocked') then raise exception 'invalid_status'; end if;
 select created_by_admin,expires_at into v_created,v_exp from public.cerca_listings where id=p_listing_id for update;
 if not found then raise exception 'listing_not_found'; end if;
 update public.cerca_listings set publication_status=p_status,
 starts_at=case when p_status='published' and (starts_at is null or expires_at<=now()) then now() else starts_at end,
 expires_at=case when p_status='published' and (expires_at is null or expires_at<=now()) then now()+case when v_created then interval '365 days' else interval '30 days' end else expires_at end,
 updated_at=now() where id=p_listing_id;
end $$;
revoke all on function public.cerca_admin_set_listing_status(uuid,text) from public,anon;
grant execute on function public.cerca_admin_set_listing_status(uuid,text) to authenticated;

create or replace function public.cerca_admin_delete_listing(p_listing_id uuid)
returns void language plpgsql security invoker set search_path=''
as $$ begin
 if auth.uid() is null or not cerca_private.is_admin() then raise exception 'not_authorized'; end if;
 delete from public.cerca_listings where id=p_listing_id;
 if not found then raise exception 'listing_not_found'; end if;
end $$;
revoke all on function public.cerca_admin_delete_listing(uuid) from public,anon;
grant execute on function public.cerca_admin_delete_listing(uuid) to authenticated;

create or replace function public.cerca_admin_dashboard_stats()
returns jsonb language plpgsql stable security definer set search_path=''
as $$ begin
 if auth.uid() is null or not cerca_private.is_admin() then raise exception 'not_authorized'; end if;
 return jsonb_build_object(
 'active_listings',(select count(*) from public.cerca_listings where publication_status='published' and payment_status='verified' and starts_at<=now() and expires_at>now()),
 'pending_listings',(select count(*) from public.cerca_listings where publication_status='pending'),
 'registered_users',(select count(*) from auth.users),
 'total_listings',(select count(*) from public.cerca_listings));
end $$;
revoke all on function public.cerca_admin_dashboard_stats() from public,anon;
grant execute on function public.cerca_admin_dashboard_stats() to authenticated;

insert into storage.buckets(id,name,public,file_size_limit,allowed_mime_types)
values('cerca-business-photos','cerca-business-photos',true,5242880,array['image/jpeg','image/png','image/webp'])
on conflict(id) do update set public=true,file_size_limit=5242880,allowed_mime_types=array['image/jpeg','image/png','image/webp'];
drop policy if exists cerca_photo_public_read on storage.objects;
create policy cerca_photo_public_read on storage.objects for select to anon,authenticated using(bucket_id='cerca-business-photos');
drop policy if exists cerca_photo_admin_insert on storage.objects;
create policy cerca_photo_admin_insert on storage.objects for insert to authenticated with check(bucket_id='cerca-business-photos' and (select cerca_private.is_admin()));
drop policy if exists cerca_photo_admin_update on storage.objects;
create policy cerca_photo_admin_update on storage.objects for update to authenticated using(bucket_id='cerca-business-photos' and (select cerca_private.is_admin())) with check(bucket_id='cerca-business-photos' and (select cerca_private.is_admin()));
drop policy if exists cerca_photo_admin_delete on storage.objects;
create policy cerca_photo_admin_delete on storage.objects for delete to authenticated using(bucket_id='cerca-business-photos' and (select cerca_private.is_admin()));
grant select(address,photo_url,opening_hours,is_featured,created_by_admin) on public.cerca_listings to anon,authenticated;
