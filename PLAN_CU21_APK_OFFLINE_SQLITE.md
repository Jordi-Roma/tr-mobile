# CU21 · Operación offline en el APK de StyleAR

Plan de implementación para Android con Flutter y SQLite. El alcance cubre acceso local, catálogo, historial reciente, reservas, ventas presenciales de contado y sincronización. El contrato con el backend se incluye como requisito para validar el flujo completo del APK. El plan toma como referencia las secciones 6 y 7, los requisitos RNF03 a RNF06 y la sección 11 del enunciado del segundo parcial.

## 1. Qué podrá hacer el usuario sin internet

- Volver a abrir la app después de cerrarla o reiniciar el celular y desbloquear una sesión local previamente habilitada.
- Consultar productos, variantes, tallas, colores, precios y existencias descargadas de las sucursales autorizadas. Mostrar la fecha de última actualización y avisar que el stock puede haber cambiado.
- Ver sus ventas y reservas recientes, junto con las operaciones pendientes, confirmadas y rechazadas que correspondan a su cuenta y sus permisos.
- Registrar reservas y, con los permisos de venta presencial de la sucursal, registrar ventas de contado cuando el cajero haya recibido el efectivo. Mostrar un comprobante provisional con el importe recibido y la referencia local. La nota de venta definitiva se obtiene tras la confirmación del servidor.
- Retomar la sincronización cuando vuelva la conexión o mediante el botón **Reintentar**. Conservar los resultados y los motivos de rechazo.

## 2. SQLite y datos descargados

El repositorio contiene el código de creación y migración de la base. El archivo SQLite se crea en el almacenamiento privado de cada instalación del APK. Flutter descarga los datos mediante `ApiClient`. FastAPI verifica el acceso, consulta PostgreSQL y devuelve el subconjunto autorizado.

| Datos | Contenido y alcance |
|---|---|
| Contexto local | Empresa, usuario, sucursales autorizadas y marcas de última sincronización. |
| Catálogo | Productos, variantes, precios y stock conocido por sucursal. Las fotos son opcionales y se pueden cachear aparte con un límite de espacio. |
| Clientes | Solo las referencias y datos mínimos que las pantallas autorizadas necesiten para reservas o ventas. |
| Historial | Ventas y reservas recientes autorizadas con sus detalles. Los datos confirmados conservan su ID de servidor. |
| Operaciones pendientes | UUID, tipo, cuenta, empresa, sucursal, hora de captura, datos de la operación, estado, número de intentos y resultado. Para una venta, conservar variantes, cantidades, precios, moneda, total y el registro de efectivo recibido. |

- Habilitar claves foráneas y migraciones versionadas. Guardar la operación y su cola en la misma transacción SQLite. Usar un UUID único para cada envío lógico y montos en unidades monetarias menores para evitar redondeos de coma flotante.
- Separar las lecturas y escrituras por empresa y usuario. Aplicar también el alcance de sucursal en las operaciones que lo requieran.
- Descargar el catálogo y el historial por páginas. Aplicar bajas y cambios de alcance al refrescar. Una actualización incompleta conserva la última descarga utilizable. Las políticas de limpieza del catálogo y del historial protegen siempre las operaciones pendientes.
- Mantener el stock descargado como referencia. Si se muestra una disponibilidad local ajustada por las operaciones del dispositivo, distinguirla del stock confirmado por PostgreSQL.

## 3. Acceso offline y manejo de sesión

1. Después de un inicio de sesión en línea, guardar el contexto verificado y habilitar un acceso local de duración limitada. Proteger el token y el permiso local con almacenamiento seguro de Android. El usuario desbloquea la app con el PIN o biometría del dispositivo. La contraseña queda fuera del almacenamiento local.
2. En el arranque sin internet, recuperar ese contexto sin depender de una consulta a la empresa. Habilitar las pantallas autorizadas en la última verificación. El desbloqueo local habilita el uso del APK y la sesión del servidor se vuelve a verificar antes de sincronizar.
3. El primer acceso, el cambio de cuenta o empresa y la recuperación de contraseña requieren internet. Un rechazo explícito del servidor, como sesión revocada o cuenta suspendida, bloquea el acceso correspondiente. Si vence el permiso local, solicitar autenticación en línea.
4. Al cerrar sesión, borrar el permiso local y ocultar el historial y las operaciones de esa cuenta. Conservar las pendientes para que solo su titular pueda recuperarlas después de autenticarse. Cancelar o descartar cualquier respuesta en tránsito de una sesión anterior.
5. Migrar la persistencia existente de `SessionStorage` desde `SharedPreferences` al almacenamiento seguro. Habilitar el modo offline después de verificar la sesión en línea y limpiar la copia antigua del token. Las preferencias de interfaz pueden seguir en `SharedPreferences`.

## 4. Registro local y sincronización

1. **Guardar una vez.** Crear el UUID al confirmar el formulario por primera vez. Bloquear pulsaciones repetidas y hacer que la inserción local sea idempotente. Veinte toques al mismo envío dejan una sola operación. Una compra distinta recibe su propio UUID.
2. **Conservar la operación.** La interfaz puede mostrar **Pendiente**, **Enviando**, **Confirmada**, **Rechazada** o **En conflicto**. Si la app se cierra durante un envío, la próxima ejecución puede retomarlo con el mismo UUID y los mismos datos.
3. **Verificar conexión y sesión.** Intentar al abrir la app, recuperar conectividad o pulsar **Reintentar**. Verificar la sesión antes del envío y procesar la cola de la cuenta activa. Un solo sincronizador reclama cada operación. Si la sesión expiró, pausar hasta que el mismo usuario se autentique.
4. **Reintentar de forma segura.** Una desconexión, un timeout o un fallo temporal mantienen el registro pendiente con reintentos espaciados. Si el servidor procesó la operación y se perdió la respuesta, debe devolver el resultado anterior para el mismo UUID. Un rechazo de negocio se conserva con su motivo y se presenta al usuario para resolverlo. Si el usuario corrige y decide registrar una operación nueva, se genera otro UUID.
5. **Conciliar la respuesta.** Guardar el ID definitivo, el resultado y los datos devueltos en una transacción local. Fusionar la entrada pendiente con el historial confirmado para mostrar una sola fila. Actualizar catálogo, existencias e historial con la información autorizada más reciente.

## 5. Pago, inventario y conflictos

| Situación | Resultado esperado |
|---|---|
| Reserva registrada offline | Se guarda pendiente. El servidor confirma y compromete disponibilidad tras verificar sucursal, fecha y stock vigentes. Si hay conflicto, devuelve el motivo. |
| Venta de contado | El cajero registra el efectivo recibido. El servidor valida la operación, el precio aplicable y las existencias. Al aceptarla, guarda la venta, sus detalles y el movimiento de inventario en una sola transacción. |
| Otra venta agotó el stock | La operación queda en conflicto. Se conserva el motivo y el estado del cobro. El inventario central queda sin descuento por esa operación. |
| Conflicto con efectivo ya recibido | El cajero devuelve el efectivo y registra la devolución. La app distingue el efectivo pendiente de devolver del efectivo devuelto. |
| Conflicto con un pago electrónico confirmado | En el flujo que opera con conexión, el backend concilia el cobro y solicita un único reembolso si la venta fue rechazada definitivamente. La bandeja y el push reutilizan CU27 y comunican la devolución cuando el proveedor la confirma. |

Si el precio válido difiere del importe registrado, mostrar el conflicto para revisión del cajero. Cualquier corrección del importe requiere confirmación explícita. Si una línea impide completar una venta o reserva, conservar la operación completa con su motivo de conflicto y evitar confirmaciones parciales automáticas.

Stripe y QR requieren conexión para confirmar pagos electrónicos. Un error de transporte deja el resultado por verificar. Antes de tramitar una devolución, consultar la operación y el estado del cobro para distinguir una venta rechazada de una venta confirmada cuya respuesta se perdió.

## 6. Integración en el repositorio móvil

| Ubicación existente | Trabajo previsto |
|---|---|
| `lib/core/storage/` | Crear la base, su esquema y migraciones. Integrar la persistencia segura de sesión. |
| `lib/core/session/contexto_sesion.dart`, `lib/providers/auth_provider.dart` y `lib/screens/auth/login_screen.dart` | Recuperar y desbloquear el contexto local, controlar su vigencia y respetar el cierre de sesión y cambio de contexto. |
| `lib/core/network/api_client.dart` y `lib/core/network/api_exceptions.dart` | Distinguir fallos de conexión, sesión y reglas de negocio. Reutilizar el cliente para descargas y sincronización. |
| `lib/providers/catalogo_provider.dart`, `lib/screens/catalogo/` y `lib/providers/carrito_provider.dart` | Mostrar el catálogo descargado y reutilizar la selección de variantes para armar la operación local. |
| `lib/providers/reserva_provider.dart`, `lib/screens/carrito/carrito_screen.dart` y `lib/screens/reservas/` | Integrar reserva offline, estado pendiente e historial combinado. Persistir las variantes y cantidades de la reserva en el momento del registro. |
| `lib/screens/home/main_navigation_screen.dart` | Dar acceso al registro e historial de ventas presenciales para los roles autorizados. Incorporar la pantalla móvil de contado dentro del flujo comercial, porque ese registro requiere una interfaz para el cajero. |
| `lib/services/` y `lib/screens/notificaciones/` | Incorporar el servicio de sincronización y reutilizar la bandeja y navegación de notificaciones de CU27. |

### Contrato que requiere el APK del backend

- Reutilizar autenticación, catálogo e historiales existentes donde el contrato entregue los datos autorizados. Mantener las reglas comerciales en los módulos `reservas` y `ventas_inventario`.
- Revisar `POST /api/v1/reservas/desde-carrito`. Hoy usa el carrito del servidor y acepta `clave_operacion`. La sincronización offline necesita enviar la selección persistida con sus variantes y cantidades, sin depender del contenido que tenga el carrito remoto al reconectar.
- Reutilizar la lógica de `POST /api/v1/ventas-presenciales` para validar y registrar la venta. Acordar el contrato de sincronización antes de conectarlo al APK. El servidor debe persistir el UUID y el resultado de cada operación, validar empresa, sucursal, usuario y datos del envío, y rechazar la reutilización del UUID con un contenido diferente.
- La deduplicación tiene que ser segura ante solicitudes simultáneas y ante una respuesta perdida después del commit. El registro de idempotencia y los efectos comerciales de una confirmación deben quedar en la misma transacción. Las respuestas deben permitir distinguir resultado definitivo, conflicto, error temporal y sesión que requiere autenticación.

## 7. Orden de implementación y verificación

1. **Base y acceso.** Crear migraciones, almacenamiento seguro y desbloqueo offline. Verificar un reinicio en modo avión y probar que salir de la cuenta o cambiar de empresa impida ver el historial anterior.
2. **Catálogo e historial.** Verificar que los datos cargados en línea se lean después de cerrar y abrir el APK sin conexión, con su fecha de actualización y el alcance correcto.
3. **Registro y cola.** Probar reserva y venta de contado, veinte toques a **Enviar**, reinicio en medio de un envío y conservación de la operación ante timeout o sesión expirada.
4. **Confirmación y conflictos.** Probar un reintento tras perder la respuesta, dos dispositivos intentando vender la última unidad, una reserva rechazada y una venta sin stock. Comprobar en PostgreSQL que se creó una sola venta y un solo conjunto de movimientos por operación aceptada.
5. **Devolución y aviso.** Comprobar que el efectivo quede registrado como devuelto cuando lo confirme el cajero. Para el flujo electrónico, usar el entorno de prueba y comprobar que un evento repetido genere un solo reembolso y que el aviso push aparezca en un Android físico al confirmarse.

La aceptación combina pruebas automatizadas de SQLite, sesión y sincronización con una prueba del APK en Android físico. Para la demostración, registrar una reserva y una venta en modo avión, cerrar y abrir la app, recuperar la conexión y mostrar el resultado en el historial y en PostgreSQL.
