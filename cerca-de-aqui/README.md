# Cerca de Aquí

Aplicación web móvil para conectar vecinos, comercios y servicios de Pilar de la Horadada, Torre de la Horadada y Mil Palmeras.

## Modelo comercial

- Anuncio básico: 2 € / 7 días.
- Anuncio estándar: 5 € / 30 días.
- Anuncio destacado: 7 € / 30 días.
- Ficha de negocio: 5 € / mes.
- Ficha de negocio destacada: 8 € / mes.
- No hay publicaciones gratuitas.
- Una publicación solo puede mostrarse si administración confirma el pago y la activa.

## Estructura incluida

- `index.html`: interfaz móvil inicial.
- `supabase/migrations/`: esquema SQL, políticas RLS, pagos pendientes y moderación.
- Los usuarios solo pueden crear solicitudes pendientes y comunicar un pago; no pueden aprobarse ni publicarse a sí mismos.
- Las publicaciones públicas requieren estado publicado, pago verificado y fecha de vigencia.
- La función de autorización administrativa está aislada en el esquema privado.

## Estado real de la implementación

La interfaz visual y las migraciones SQL están en esta rama. **Las migraciones todavía no se han aplicado y la aplicación aún no es operativa**: falta un backend aislado y un alojamiento web.

Se intentó crear un proyecto Supabase independiente con coste mensual de 0 €. La cuenta indica que ya se ha alcanzado el límite de dos proyectos gratuitos activos. No se ha pausado ni eliminado ningún proyecto existente y no se ha reutilizado la base de datos de CAJUMA, para mantener los datos de ambas aplicaciones separados.

## Requisitos para completar el despliegue

1. Disponer de un proyecto backend independiente gratuito para Cerca de Aquí.
2. Aplicar las migraciones de esta carpeta y verificar RLS/advisors.
3. Conectar autenticación, envío de solicitudes y panel de moderación.
4. Configurar el administrador desde el backend; nunca desde el navegador.
5. Publicar en un alojamiento gratuito que permita expresamente el uso comercial.

No incluir claves secretas, claves service-role, credenciales ni datos bancarios en archivos públicos. La clave publicable del backend sí puede usarse en el cliente cuando RLS esté correctamente configurado.
