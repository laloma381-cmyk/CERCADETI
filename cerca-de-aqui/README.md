# Cerca de Aquí

Aplicación web móvil para conectar vecinos, comercios y servicios de Pilar de la Horadada, Torre de la Horadada y Mil Palmeras.

## Modelo comercial

- Ficha básica de directorio: gratuita, sin pago y sin caducidad; publicación tras revisión.
- Promoción breve: 2 € / 7 días (tarifa propuesta, pendiente de validación).
- Promoción estándar: 5 € / 30 días y destacada: 7 € / 30 días (tarifas propuestas).
- Ficha profesional: 5 € / mes (tarifa propuesta).
- Ficha profesional destacada: 8 € / mes (tarifa propuesta).
- La ficha básica del directorio es siempre gratuita; solo se cobra por servicios opcionales de visibilidad.
- Una publicación solo aparece si el superadministrador confirma el pago.

## Implementación actual

- index.html: interfaz móvil, registro e inicio de sesión, recuperación de contraseña, aceptación obligatoria de términos y política de privacidad, búsqueda y categorías.
- terminos.html y privacidad.html: documentos legales provisionales. Falta completar identidad y correo de contacto del responsable antes de abrir el servicio al público.
- cerca_user_consents: registro de versión y fecha de aceptación por usuario; RLS impide leer o registrar consentimientos de otras cuentas.
- El directorio público muestra solo campos comerciales de fichas aprobadas; enviar una ficha o solicitar una promoción requiere sesión y aceptación legal.
- supabase/migrations/: migraciones de cerca_listings y cerca_payment_reports, políticas RLS y funciones de envío y moderación.
- Backend conectado al proyecto Supabase existente de CAJUMAV.
- Las tablas y funciones de Cerca de Ti llevan prefijo cerca_; la web no consulta ni modifica profiles/reports. El único uso de profiles es una copia inicial de los superadministradores a cerca_admins al aplicar la migración.
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

## Migración pendiente de aplicar

- `20261127110000_cerca_free_listing_and_admin_isolation.sql`: migración consolidada pendiente de aplicar. Habilita fichas gratuitas sin pago ni caducidad, coordenadas opcionales latitude/longitude, publicación pública solo tras aprobación, y administración aislada mediante cerca_admins/cerca_is_admin. Corrige además la revisión de fichas gratuitas sin justificante de pago. No modifica policies de profiles ni reports.

## Verificaciones realizadas

- Se comprobó que las tablas propias de Cerca de Aquí existen y mantienen RLS.
- Se comprobó la relación foránea entre solicitudes de pago y anuncios, utilizada por el panel de administración.
- Se comprobó que el trigger de Supabase crea el perfil de cada usuario nuevo.
- Se comprobó que existe una cuenta con permisos activos de superadministrador.
- Se añadió al sitio el formulario para establecer una contraseña nueva desde el enlace de recuperación.
- Las funciones de envío y revisión de anuncios están configuradas como SECURITY INVOKER.

## Pendiente antes de considerarla terminada

1. Completar en terminos.html y privacidad.html el nombre o razón social, domicilio y correo real del responsable; revisar jurídicamente ambos textos antes del lanzamiento.
2. Probar registro, confirmación de correo, inicio y recuperación de contraseña desde un navegador real.
3. Probar envío de una solicitud con una cuenta normal.
4. Probar revisión y publicación con la cuenta superadministradora.
5. Probar los permisos reales con sesiones de usuario y superadministrador.
6. Conectar el repositorio a Netlify Free y desplegar esta versión; el sitio Netlify actual no está vinculado a este repositorio. Netlify indica que su plan gratuito permite proyectos comerciales, sujeto a un límite mensual de créditos; el alojamiento gratuito no incluye garantía de disponibilidad.

No incluir claves secretas, claves service-role, credenciales ni datos bancarios en archivos públicos. La clave publicable del backend se puede utilizar en el cliente porque la seguridad se aplica mediante RLS y funciones del servidor.


## Monetización visible en la web (rama feature/monetizacion-cercadeti)

- El menú principal incluye accesos a "Contrata y destaca tu negocio" y "Quitar publicidad para siempre".
- `contrata.html`: ficha básica gratuita y tarifas orientativas de promociones, pendientes de validación definitiva por el titular. Las solicitudes se envían por correo a cercadetiapp2026@gmail.com; no hay cobro automático integrado.
- `sin-publicidad.html`: explica la futura compra única vitalicia para eliminar anuncios. El precio queda pendiente de fijar y no se cobra todavía.
- Los términos describen la ficha básica gratuita, los planes de visibilidad, el proceso de contratación por correo y la futura modalidad vitalicia sin anuncios.
- La política de privacidad anticipa la futura integración de publicidad de terceros y exige actualizar proveedor/consentimiento antes de activarla.
- Esta rama no se ha fusionado ni desplegado. No se ha modificado el backend ni se ha activado una red publicitaria o sistema de pagos.


## Aislamiento administrativo y mapa

- El panel de Cerca de Ti administra únicamente cerca_listings y cerca_payment_reports. Se han retirado del panel las consultas y acciones sobre perfiles de mensajería y reportes de CAJUMAV.
- La autorización administrativa se copia una sola vez desde los superadministradores vigentes a public.cerca_admins. Para conceder o retirar acceso administrativo de Cerca en el futuro, se modifica esa tabla desde el SQL Editor; no se alteran los roles globales de CAJUMAV.
- Las coordenadas de negocio son opcionales, deben guardarse en pareja y tienen validación de rango. El formulario actual no las solicita todavía; quedan preparadas para los futuros pines.
- Aplicar en Supabase SQL Editor el archivo completo `cerca-de-aqui/supabase/migrations/20261127110000_cerca_free_listing_and_admin_isolation.sql`. No ejecutar por separado los bloques de esta migración.
