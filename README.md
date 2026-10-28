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

## Catálogo, carrito y reservas — CU11, CU12 y CU13

El catálogo incorpora filtros por talla, color, temporada, colección, precios y
orden, además de paginación. Una búsqueda anterior que responde tarde no
reemplaza la búsqueda actual. El carrito avisa si una prenda deja de estar
habilitada y permite retirarla.

Las reservas nuevas son gratuitas y vencen siete días después de crearse. La
cita se elige dentro de ese plazo, con hasta dos unidades de la misma variante.
Se conserva el importe y la presentación de anticipos de reservas históricas.
Cancelar o vencer libera unidades en el backend. Se envía una clave estable al
reintentar una reserva si se perdió su respuesta; no es sincronización offline.

El cajero tiene navegación a catálogo, reservas y cuenta, sin pantallas nuevas
de inventario CU14 ni venta presencial CU15. En CU13 puede atender las reservas
de su sucursal y finalizar la atención mediante el recorrido existente. No se
permite completar una reserva arbitrariamente desde el selector de estados.
La cancelación administrativa corresponde a administrador/encargado.

CU14 y CU15 se implementan en la web según la tabla de plataformas. El probador
y su cámara se conservan. Se corrigió un desbordamiento del estado vacío en
pantallas de poca altura, manteniendo su contenido desplazable.

Validación: **32 pruebas locales aprobadas**, incluyendo modelo gratuito frente
a histórico, reintento tras respuesta perdida, filtros, paginación, respuestas
tardías y navegación del cajero. Se revisan los archivos cambiados con el
analizador. Esto no reemplaza una prueba en teléfono físico. Requiere la
migración backend `2026_10_27_cu11_cu15_01`; no se aplicó a la base real durante
estas verificaciones. No se publicó este bloque.

El análisis final de los 14 archivos Flutter modificados/nuevos terminó sin
observaciones. Las 32 pruebas finalizaron correctamente.
