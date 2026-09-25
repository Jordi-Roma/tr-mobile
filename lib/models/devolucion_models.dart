class VentaDevolucionDetalle {
  final int ventaDetalleId;
  final String producto;
  final String talla;
  final String color;
  final int cantidadVendida;
  final int cantidadDisponible;
  final double subtotal;

  const VentaDevolucionDetalle({
    required this.ventaDetalleId,
    required this.producto,
    required this.talla,
    required this.color,
    required this.cantidadVendida,
    required this.cantidadDisponible,
    required this.subtotal,
  });

  factory VentaDevolucionDetalle.fromJson(Map<String, dynamic> json) => VentaDevolucionDetalle(
        ventaDetalleId: _int(json['venta_detalle_id']),
        producto: json['producto']?.toString() ?? '',
        talla: json['talla']?.toString() ?? '',
        color: json['color']?.toString() ?? '',
        cantidadVendida: _int(json['cantidad_vendida']),
        cantidadDisponible: _int(json['cantidad_disponible']),
        subtotal: _double(json['subtotal']),
      );
}

class VentaDevolucionElegible {
  final int ventaId;
  final String codigo;
  final String sucursal;
  final String fecha;
  final double total;
  final List<VentaDevolucionDetalle> detalles;

  const VentaDevolucionElegible({
    required this.ventaId,
    required this.codigo,
    required this.sucursal,
    required this.fecha,
    required this.total,
    required this.detalles,
  });

  factory VentaDevolucionElegible.fromJson(Map<String, dynamic> json) => VentaDevolucionElegible(
        ventaId: _int(json['venta_id']),
        codigo: json['venta_codigo']?.toString() ?? '',
        sucursal: json['sucursal']?.toString() ?? '',
        fecha: json['fecha_venta']?.toString() ?? '',
        total: _double(json['total']),
        detalles: (json['detalles'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(VentaDevolucionDetalle.fromJson)
            .toList(),
      );
}

class DevolucionDetalle {
  final int id;
  final String producto;
  final String talla;
  final String color;
  final int cantidadSolicitada;
  final int cantidadAceptada;
  final int cantidadRechazada;
  final double montoAprobado;

  const DevolucionDetalle({
    required this.id,
    required this.producto,
    required this.talla,
    required this.color,
    required this.cantidadSolicitada,
    required this.cantidadAceptada,
    required this.cantidadRechazada,
    required this.montoAprobado,
  });

  factory DevolucionDetalle.fromJson(Map<String, dynamic> json) => DevolucionDetalle(
        id: _int(json['id']),
        producto: json['producto']?.toString() ?? '',
        talla: json['talla']?.toString() ?? '',
        color: json['color']?.toString() ?? '',
        cantidadSolicitada: _int(json['cantidad_solicitada']),
        cantidadAceptada: _int(json['cantidad_aceptada']),
        cantidadRechazada: _int(json['cantidad_rechazada']),
        montoAprobado: _double(json['monto_aprobado']),
      );
}

class Devolucion {
  final int id;
  final String codigo;
  final String ventaCodigo;
  final String estado;
  final String motivo;
  final double montoSolicitado;
  final double montoAprobado;
  final String fechaSolicitud;
  final String? metodoReembolso;
  final String? referenciaReembolso;
  final List<DevolucionDetalle> detalles;

  const Devolucion({
    required this.id,
    required this.codigo,
    required this.ventaCodigo,
    required this.estado,
    required this.motivo,
    required this.montoSolicitado,
    required this.montoAprobado,
    required this.fechaSolicitud,
    this.metodoReembolso,
    this.referenciaReembolso,
    required this.detalles,
  });

  factory Devolucion.fromJson(Map<String, dynamic> json) => Devolucion(
        id: _int(json['id']),
        codigo: json['codigo']?.toString() ?? '',
        ventaCodigo: json['venta_codigo']?.toString() ?? '',
        estado: json['estado']?.toString() ?? '',
        motivo: json['motivo']?.toString() ?? '',
        montoSolicitado: _double(json['monto_solicitado']),
        montoAprobado: _double(json['monto_aprobado']),
        fechaSolicitud: json['fecha_solicitud']?.toString() ?? '',
        metodoReembolso: json['metodo_reembolso']?.toString(),
        referenciaReembolso: json['referencia_reembolso']?.toString(),
        detalles: (json['detalles'] as List<dynamic>? ?? [])
            .whereType<Map<String, dynamic>>()
            .map(DevolucionDetalle.fromJson)
            .toList(),
      );
}

int _int(dynamic value) => value is int ? value : int.tryParse(value?.toString() ?? '') ?? 0;
double _double(dynamic value) => double.tryParse(value?.toString() ?? '0') ?? 0;
