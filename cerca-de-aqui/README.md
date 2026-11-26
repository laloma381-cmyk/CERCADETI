# Cerca de Aquí

Aplicación web móvil para conectar vecinos, comercios y servicios de Pilar de la Horadada, Torre de la Horadada y Mil Palmeras.

## Modelo comercial

- Anuncio básico: 2 € / 7 días.
- Anuncio estándar: 5 € / 30 días.
- Anuncio destacado: 7 € / 30 días.
- Ficha de negocio: 5 € / mes.
- Ficha de negocio destacada: 8 € / mes.
- No hay publicaciones gratuitas.
- Una publicación solo aparece si el superadministrador confirma el pago.

## Implementación actual

- index.html: interfaz móvil, autenticación, recuperación de contraseña, búsqueda y categorías.
- supabase/migrations/: migraciones de cerca_listings y cerca_payment_reports, políticas RLS y funciones de envío y moderación.
- Backend conectado al proyecto Supabase existente de CAJUMAV.
- Las tablas y funciones de Cerca de Aquí llevan prefijo cerca_; no se modifican las tablas de chats, perfiles ni datos familiares.
- La autenticación utiliza Supabase Auth del proyecto existente.
- El administrador se verifica en backend con el rol real super_admin, el indicador is_super_admin y la cuenta no suspendida.
- El usuario puede enviar solicitudes y declarar Bizum o efectivo; eso NO confirma el pago.
- El superadministrador revisa el justificante y la función transaccional publica el anuncio solo tras aprobarlo.
- Las publicaciones públicas deben tener pago verificado y fechas de vigencia válidas.

## Migraciones aplicadas

Estas tres migraciones se han aplicado al proyecto Supabase cxdfejzmeqrjhzupdhdb y se conservan aquí para control de versiones:

1. 20261126054509_cerca_de_aqui_isolated_tables_and_rls.sql
2. 20261126054538_cerca_admin_review_rpc.sql
3. 20261126054551_cerca_secure_listing_submission.sql

## Pendiente antes de considerarla terminada

1. Probar registro, inicio y recuperación de contraseña desde un navegador real.
2. Probar envío de una solicitud con cuenta normal.
3. Probar revisión y publicación con la cuenta superadministradora.
4. Revisar los avisos de seguridad de Supabase y separar los avisos preexistentes de CAJUMAV.
5. Publicar en un alojamiento permanente gratuito que permita expresamente el uso comercial y verificar el dominio HTTPS.

No incluir claves secretas, claves service-role, credenciales ni datos bancarios en archivos públicos. La clave publicable del backend se puede utilizar en el cliente porque la seguridad se aplica mediante RLS y funciones del servidor.
