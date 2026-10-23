# StyleAR móvil

Aplicación Flutter de StyleAR, conectada al backend FastAPI del proyecto.

## Cuenta y acceso — CU02 y CU03

La primera pantalla permite elegir una empresa del directorio del servidor y buscarla por nombre. Las cuentas conservan su empresa. Cambiar de empresa con una sesión abierta requiere confirmar el cierre y limpia los datos de esa sesión del dispositivo.

El cliente puede registrarse, ingresar, cerrar sesión, recuperar acceso con código de correo, editar datos personales/usuario/correo, cambiar contraseña, gestionar direcciones y desactivar su cuenta conservando el historial. Cambiar credenciales obliga a ingresar nuevamente; modificar sólo datos personales mantiene la sesión.

Se conserva el motor y la cámara del probador. Sus solicitudes incorporan el contexto de empresa de la app.

## Configuración

`API_URL` puede indicarse mediante `--dart-define` para usar otra API. Debe ser la URL base del backend; el cliente agrega `/api/v1` si hace falta. La configuración existente por plataforma permanece en `lib/core/constants/api_constants.dart`.

La recuperación real requiere SMTP configurado en el backend. No hay cuentas ni empresas ficticias en las pantallas: los ejemplos se limitan a las pruebas.

## Verificación local

```shell
flutter analyze
flutter test
flutter build web
```

Se incluyen 14 pruebas de sesión/cuenta y seis de pantallas. Las pruebas usan HTTP y almacenamiento simulados; no envían correos reales. La compilación Web y el análisis no sustituyen una prueba en teléfono físico.

Para validar contra la API actualizada se debe aplicar primero su migración `2026_10_23_cu02_cu03_01`. Ver el [informe CU02/CU03](../tr-backend/IMPLEMENTACION_CU02_CU03_2026-10-23.md) para alcance, migración y resultados de backend/web.
