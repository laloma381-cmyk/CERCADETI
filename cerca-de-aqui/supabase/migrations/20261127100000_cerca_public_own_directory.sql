-- Directorio público de Cerca de Ti: solo fichas aprobadas y activas.
-- Incluye ficha gratuita sin caducidad y promociones pagadas vigentes.
-- Nunca expone propietario, justificantes ni estados internos de moderación.

drop policy if exists "cerca_public_active_paid" on public.cerca_listings;
drop policy if exists "cerca_anon_reads_published" on public.cerca_listings;
create policy "cerca_anon_reads_published"
on public.cerca_listings
for select to anon
using (
  publication_status = 'published'
  and (
    (plan = 'directory_free' and payment_status = 'not_required' and expires_at is null)
    or (payment_status = 'verified' and starts_at <= now() and expires_at > now())
  )
);

revoke select on public.cerca_listings from anon;
grant select (
  id, title, category, locality, description, contact_phone,
  plan, starts_at, expires_at, latitude, longitude
) on public.cerca_listings to anon;
