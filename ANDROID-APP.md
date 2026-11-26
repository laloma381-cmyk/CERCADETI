# Cerca de Aquí para Android

Este repositorio conserva la web original en `cerca-de-aqui/` y añade una aplicación Android independiente en `app/`. La APK incluye los HTML y documentos legales como recursos locales y utiliza Android System WebView para ejecutar la interfaz, con conexión HTTPS a Supabase.

## Compilación
La rama `android-app` compila una APK de depuración mediante GitHub Actions. Ejecuta el workflow **Build Android APK** y descarga el artefacto `cerca-de-aqui-android-debug`. No se publica automáticamente en ninguna tienda ni se despliega la web.

## Identidad
- Nombre: Cerca de Aquí
- Application ID: `com.cercadeaqui.app`
- Enlace profundo para recuperación: `cercadeaqui://auth-callback`

## Configuración pendiente de autenticación móvil
Para que la recuperación de contraseña vuelva a la app, hay que añadir exactamente `cercadeaqui://auth-callback` a la lista de Redirect URLs permitidas en Supabase Auth. Hasta entonces, el registro/inicio de sesión y las funciones de datos usan el mismo proyecto Supabase, pero el retorno de recuperación desde correo no debe darse por verificado.

## Seguridad
La APK no contiene claves service-role ni secretos. La clave publicable permanece en el cliente y el control de acceso sigue dependiendo de RLS y funciones del backend. Los enlaces web externos se abren en el navegador del dispositivo.
