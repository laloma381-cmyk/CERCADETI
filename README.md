# Cerca de Aquí

Aplicación web local para conectar vecinos, comercios y servicios de Pilar de la Horadada, Torre de la Horadada y Mil Palmeras.

## Proyecto

La aplicación principal está en [`cerca-de-aqui/`](./cerca-de-aqui/).

Incluye búsqueda y categorías, registro e inicio de sesión, recuperación de contraseña, publicación de anuncios y revisión de pagos por superadministrador.

## Despliegue

La configuración de Netlify (`netlify.toml`) utiliza `cerca-de-aqui/` como carpeta base y publica su contenido.

## Estado

El código ya está integrado en `main`. Antes de producción quedan las pruebas reales de registro, recuperación, envío y moderación, además de conectar este repositorio a un sitio Netlify dedicado y verificar el despliegue HTTPS.

El proyecto utiliza tablas propias `cerca_*` en Supabase y no modifica las tablas de mensajería de CAJUMAV.
