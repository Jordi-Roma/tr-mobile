import 'package:flutter/material.dart';

import '../../services/notificaciones_service.dart';
import '../reservas/reserva_detalle_screen.dart';
import '../pagos/detalle_pago_screen.dart';
import '../delivery/detalle_delivery_screen.dart';
import '../pagos/cambios_screen.dart';
import '../pagos/devoluciones_screen.dart';

Widget? pantallaNotificacion(DestinoNotificacion d) {
  if (!d.valido) return null;
  return switch (d.tipo) {
    'RESERVA' => ReservaDetalleScreen(reservaId: d.id!),
    'ORDEN_PAGO' => DetallePagoScreen(ordenId: d.id!, esAdmin: false),
    'DELIVERY' => DetalleDeliveryScreen(deliveryId: d.id!, esStaff: false),
    'CAMBIO' => CambiosScreen(seleccionInicial: d.id!),
    'DEVOLUCION' => DevolucionesScreen(seleccionInicial: d.id!),
    _ => null,
  };
}
