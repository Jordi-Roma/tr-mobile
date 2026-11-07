import 'package:flutter/material.dart';

import '../../models/asistente_models.dart';
import '../catalogo/catalogo_screen.dart';
import '../catalogo/producto_detalle_screen.dart';
import '../reservas/reserva_detalle_screen.dart';
import '../pagos/detalle_pago_screen.dart';
import '../delivery/detalle_delivery_screen.dart';

const etiquetasChat = {
  'fecha_expiracion': 'Vencimiento',
  'fecha_pago': 'Fecha de pago',
  'tiempo_estimado_min': 'Tiempo estimado registrado (min)',
  'concepto': 'Concepto',
  'plazo': 'Plazo (días)',
  'condiciones': 'Condiciones',
  'aceptado_en': 'Aceptado',
  'cotizacion_vence': 'Vigencia de cotización',
  'codigo': 'Código',
  'estado': 'Estado registrado',
  'importe': 'Importe',
  'moneda': 'Moneda',
  'fecha': 'Fecha',
  'fecha_creacion': 'Registrado',
  'fecha_cita': 'Cita',
  'fecha_vencimiento': 'Vencimiento',
  'vencimiento': 'Vencimiento',
  'sucursal': 'Sucursal',
  'nombre': 'Nombre',
  'ciudad': 'Ciudad',
  'direccion': 'Dirección publicada',
  'telefono': 'Teléfono',
  'fecha_reembolso': 'Fecha de reembolso',
  'reembolso_confirmado': 'Reembolso confirmado',
  'siguiente_paso': 'Siguiente paso',
  'politica_aplicada': 'Política aplicada',
  'plazo_cambios': 'Plazo para cambios',
  'plazo_devoluciones': 'Plazo para devoluciones',
  'condiciones_cambios': 'Condiciones de cambios',
  'condiciones_devoluciones': 'Condiciones de devoluciones',
  'cambios_habilitados': 'Cambios habilitados',
  'devoluciones_habilitadas': 'Devoluciones habilitadas',
  'modo': 'Modo de pagos',
  'medios': 'Medios habilitados',
  'diferencia': 'Diferencia',
  'fecha_estimada': 'Estimación registrada',
  'fecha_entrega': 'Entrega registrada',
};
String valorChat(Object? v) => v == null
    ? 'Sin dato'
    : v is bool
    ? (v ? 'Sí' : 'No')
    : v is List
    ? v.map(valorChat).join(', ')
    : v is Map
    ? v.entries
          .where((e) => etiquetasChat.containsKey(e.key))
          .map((e) => '${etiquetasChat[e.key]}: ${valorChat(e.value)}')
          .join('; ')
    : v.toString();
AsistenteContexto? operacionChat(Map<String, dynamic> d) =>
    recursosChat.contains(d['recurso_tipo']) &&
        d['id'] is int &&
        (d['id'] as int) > 0
    ? AsistenteContexto(
        recursoTipo: d['recurso_tipo'] as String,
        recursoId: d['id'] as int,
      )
    : null;
Widget? destinoChat(String? url) {
  if (url == '/catalogo') return const CatalogoScreen();
  final m = RegExp(r'^/(producto|reservas|mis-pagos|mis-deliveries)/(\d+)$')
      .firstMatch(url ?? '');
  if (m == null) return null;
  final id = int.parse(m[2]!);
  return switch (m[1]) {
    'producto' => ProductoDetalleScreen(productoId: id),
    'reservas' => ReservaDetalleScreen(reservaId: id),
    'mis-pagos' => DetallePagoScreen(ordenId: id, esAdmin: false),
    'mis-deliveries' => DetalleDeliveryScreen(deliveryId: id, esStaff: false),
    _ => null,
  };
}

String? rutaOperacionChat(Map<String, dynamic> d) {
  final c = operacionChat(d);
  if (c == null) return null;
  final base = switch (c.recursoTipo) {
    'RESERVA' => '/reservas/',
    'ORDEN_PAGO' => '/mis-pagos/',
    'DELIVERY' => '/mis-deliveries/',
    _ => null,
  };
  return base == null ? null : '$base${c.recursoId}';
}

class DatosChat extends StatelessWidget {
  const DatosChat({
    super.key,
    required this.respuesta,
    required this.onSeleccionar,
  });
  final AsistenteChatResponse respuesta;
  final ValueChanged<AsistenteContexto> onSeleccionar;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      if (respuesta.aclaracion)
        const Text(
          'Selecciona una prenda u operación para precisar tu consulta.',
        ),
      if (respuesta.hayMas)
        const Text('Hay más resultados. Precisa tu consulta.'),
      ...respuesta.datos.map(
        (d) => Card(
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                ...d.entries
                    .where((e) => etiquetasChat.containsKey(e.key))
                    .map(
                      (e) => Text(
                        '${etiquetasChat[e.key]}: ${valorChat(e.value)}',
                      ),
                    ),
                if (operacionChat(d) case final c?)
                  TextButton(
                    onPressed: () => onSeleccionar(c),
                    child: Text('Consultar ${c.recursoTipo} #${c.recursoId}'),
                  ),
                if (rutaOperacionChat(d) case final ruta?)
                  TextButton(
                    onPressed: () => Navigator.push(
                      context,
                      MaterialPageRoute(builder: (_) => destinoChat(ruta)!),
                    ),
                    child: const Text('Abrir detalle'),
                  ),
              ],
            ),
          ),
        ),
      ),
      if (respuesta.fuentes.isNotEmpty)
        Text('Fuentes: ${respuesta.fuentes.join(', ')}'),
      if (respuesta.consultadoEn != null)
        Text('Consultado: ${respuesta.consultadoEn}'),
      ...respuesta.acciones
          .where((a) => destinoChat(a.url) != null)
          .map(
            (a) => TextButton(
              onPressed: () => Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => destinoChat(a.url)!),
              ),
              child: Text(a.label),
            ),
          ),
    ],
  );
}
