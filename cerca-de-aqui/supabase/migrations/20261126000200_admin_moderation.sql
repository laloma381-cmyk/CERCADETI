-- Acciones de moderación reservadas al administrador verificado.
grant update on public.listings to authenticated;
grant update on public.payment_reports to authenticated;
grant update on public.profiles to authenticated;

create policy "admin updates listings" on public.listings
for update to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

create policy "admin updates payment reports" on public.payment_reports
for update to authenticated
using ((select private.is_admin()))
with check ((select private.is_admin()));

create policy "admin updates profiles" on public.profiles
for update to authenticated
using ((select private.is_admin()))
with check (
  (select private.is_admin())
  and role in ('user','admin')
);
