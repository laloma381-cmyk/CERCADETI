-- Vincular cada tarifa al importe exacto; evita alterar el precio desde clientes.
alter table public.listings
  drop constraint if exists listings_price_cents_check;

alter table public.listings
  add constraint listings_plan_price_match check (
    (plan = 'basic' and price_cents = 200) or
    (plan = 'standard' and price_cents = 500) or
    (plan = 'featured' and price_cents = 700) or
    (plan = 'business' and price_cents = 500) or
    (plan = 'business_plus' and price_cents = 800)
  );
