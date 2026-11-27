-- Directorio público propio de Cerca de Ti.
-- Solo expone campos comerciales de anuncios aprobados y vigentes.
-- No hace públicos propietarios, justificantes ni estados internos de pago.
drop policy if exists "cerca_public_active_paid" on public.cerca_listings;
drop policy if exists "cerca_anon_reads_published" on public.cerca_listings;
create policy "cerca_anon_reads_published"
on public.cerca_listings
for select to anon
using (
  publication_status = 'published'
  and payment_status = 'verified'
  and starts_at <= now()
  and expires_at > now()
);

revoke select on public.cerca_listings from anon;
grant select (
  id, title, category, locality, description, contact_phone,
  plan, starts_at, expires_at
) on public.cerca_listings to anon;
