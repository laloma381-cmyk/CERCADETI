# Cerca de Aquí — Android nativo

Aplicación Android Kotlin + Jetpack Compose. No es una web empaquetada ni necesita Chrome.

## Compilación
El workflow `.github/workflows/android-apk.yml` compila el APK de depuración al actualizar esta rama o al ejecutarlo manualmente desde GitHub Actions. Descarga el artefacto `cerca-de-aqui-debug-apk`.

## Primera entrega
- Interfaz Android nativa.
- Búsqueda por texto y filtros por categoría.
- Carga de anuncios publicados y con pago verificado desde Supabase.
- Diseño oscuro adaptado a pantallas móviles.

## Seguridad
La app usa exclusivamente la clave publicable de Supabase. Nunca incluir la service_role key en el APK. Las políticas RLS del backend son la autoridad para los datos públicos.

## Pendiente
Autenticación y recuperación de contraseña, alta de negocios y anuncios con justificante, panel de superadministrador, mapa OSM real con atribución y pruebas integrales.
