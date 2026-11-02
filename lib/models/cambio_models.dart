import 'devolucion_models.dart';

class CambioPrenda {
  final int id, version, cantidad;
  final String estado;
  final double? credito, precioReemplazo, diferencia;
  final Devolucion original;
  final Map<String, dynamic>? reemplazo, comprobante, pago;
  const CambioPrenda({
    required this.id,
    required this.version,
    required this.cantidad,
    required this.estado,
    required this.original,
    this.credito,
    this.precioReemplazo,
    this.diferencia,
    this.reemplazo,
    this.comprobante,
    this.pago,
  });
  factory CambioPrenda.fromJson(Map<String, dynamic> j) => CambioPrenda(
    id: j['id'] as int,
    version: j['version'] as int,
    cantidad: j['cantidad'] as int,
    estado: j['estado'] as String,
    original: Devolucion.fromJson(j['original'] as Map<String, dynamic>),
    credito: double.tryParse('${j['credito']}'),
    precioReemplazo: double.tryParse('${j['precio_reemplazo']}'),
    diferencia: double.tryParse('${j['diferencia']}'),
    reemplazo: j['reemplazo'] as Map<String, dynamic>?,
    comprobante: j['comprobante'] as Map<String, dynamic>?,
    pago: j['pago'] as Map<String, dynamic>?,
  );
}
