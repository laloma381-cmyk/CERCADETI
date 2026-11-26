-- Consolidar políticas SELECT de Cerca de Aquí y añadir índices para claves foráneas.
drop policy if exists "cerca_public_active_paid" on public.cerca_listings;
drop policy if exists "cerca_owner_reads_own" on public.cerca_listings;
drop policy if exists "cerca_admin_reads_all_listings" on public.cerca_listings;
create policy "cerca_anon_reads_published" on public.cerca_listings
for select to anon using (
  publication_status='published' and payment_status='verified'
  and starts_at <= now() and expires_at > now()
);
create policy "cerca_authenticated_reads_allowed" on public.cerca_listings
for select to authenticated using (
  (publication_status='published' and payment_status='verified'
    and starts_at <= now() and expires_at > now())
  or owner_id=(select auth.uid())
  or (select cerca_private.is_admin())
);
drop policy if exists "cerca_owner_reads_payment_reports" on public.cerca_payment_reports;
drop policy if exists "cerca_admin_reads_payment_reports" on public.cerca_payment_reports;
create policy "cerca_authenticated_reads_payment_reports" on public.cerca_payment_reports
for select to authenticated using (
  user_id=(select auth.uid()) or (select cerca_private.is_admin())
);
create index if not exists cerca_payment_reports_user_idx
on public.cerca_payment_reports(user_id);
create index if not exists cerca_payment_reports_reviewed_by_idx
on public.cerca_payment_reports(reviewed_by);
