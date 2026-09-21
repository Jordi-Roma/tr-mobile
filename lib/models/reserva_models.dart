class ReservaDetalleResponse {
  final int id;
  final int productoVarianteId;
  final int productoId;
  final String producto;
  final String categoria;
  final String talla;
  final String color;
  final int cantidad;
  final double precioUnitario;
  final double subtotal;

  ReservaDetalleResponse({
    required this.id,
    required this.productoVarianteId,
    required this.productoId,
    required this.producto,
    required this.categoria,
    required this.talla,
    required this.color,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
  });

  factory ReservaDetalleResponse.fromJson(Map<String, dynamic> json) {
    return ReservaDetalleResponse(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      productoVarianteId: json['producto_variante_id'] is int ? json['producto_variante_id'] : int.parse(json['producto_variante_id'].toString()),
      productoId: json['producto_id'] is int ? json['producto_id'] : int.parse(json['producto_id'].toString()),
      producto: json['producto'] ?? '',
      categoria: json['categoria'] ?? '',
      talla: json['talla'] ?? '',
      color: json['color'] ?? '',
      cantidad: json['cantidad'] is int ? json['cantidad'] : int.parse(json['cantidad'].toString()),
      precioUnitario: double.tryParse(json['precio_unitario']?.toString() ?? '0') ?? 0.0,
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0.0,
    );
  }
}

class ReservaResponse {
  final int id;
  final String codigo;
  final int clienteId;
  final String? cliente;
  final int sucursalId;
  final String sucursal;
  final String ciudad;
  final String estado;
  final double total;
  final double montoReserva;
  final double montoAplicado;
  final bool anticipoPagado;
  final int? anticipoOrdenId;
  final int? ventaId;
  final String? fechaCita;
  final String fechaReserva;
  final String? fechaExpiracion;
  final String? observacion;
  final List<ReservaDetalleResponse> detalles;

  ReservaResponse({
    required this.id,
    required this.codigo,
    required this.clienteId,
    this.cliente,
    required this.sucursalId,
    required this.sucursal,
    required this.ciudad,
    required this.estado,
    required this.total,
    required this.montoReserva,
    required this.montoAplicado,
    required this.anticipoPagado,
    this.anticipoOrdenId,
    this.ventaId,
    this.fechaCita,
    required this.fechaReserva,
    this.fechaExpiracion,
    this.observacion,
    required this.detalles,
  });

  bool get puedeCancelar => !['COMPLETADA', 'CANCELADA', 'VENCIDA'].contains(estado);

  factory ReservaResponse.fromJson(Map<String, dynamic> json) {
    return ReservaResponse(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      codigo: json['codigo'] ?? '',
      clienteId: json['cliente_id'] is int ? json['cliente_id'] : int.parse(json['cliente_id'].toString()),
      cliente: json['cliente'],
      sucursalId: json['sucursal_id'] is int ? json['sucursal_id'] : int.parse(json['sucursal_id'].toString()),
      sucursal: json['sucursal'] ?? '',
      ciudad: json['ciudad'] ?? '',
      estado: json['estado'] ?? 'PENDIENTE',
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0.0,
      montoReserva: double.tryParse(json['monto_reserva']?.toString() ?? '0') ?? 0.0,
      montoAplicado: double.tryParse(json['monto_aplicado']?.toString() ?? '0') ?? 0.0,
      anticipoPagado: json['anticipo_pagado'] == true || json['anticipo_pagado']?.toString().toLowerCase() == 'true',
      anticipoOrdenId: json['anticipo_orden_id'] != null ? int.tryParse(json['anticipo_orden_id'].toString()) : null,
      ventaId: json['venta_id'] != null ? int.tryParse(json['venta_id'].toString()) : null,
      fechaCita: json['fecha_cita']?.toString(),
      fechaReserva: json['fecha_reserva'] ?? '',
      fechaExpiracion: json['fecha_expiracion'],
      observacion: json['observacion'],
      detalles: (json['detalles'] as List<dynamic>?)?.map((e) => ReservaDetalleResponse.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    );
  }
}

class ReservaPagoResponse {
  final ReservaResponse reserva;
  final bool requiereCheckout;
  final int? ordenId;
  final int? ventaId;
  final String? checkoutUrl;
  final String? mensaje;

  ReservaPagoResponse({
    required this.reserva,
    required this.requiereCheckout,
    this.ordenId,
    this.ventaId,
    this.checkoutUrl,
    this.mensaje,
  });

  factory ReservaPagoResponse.fromJson(Map<String, dynamic> json) {
    return ReservaPagoResponse(
      reserva: ReservaResponse.fromJson(json['reserva'] as Map<String, dynamic>),
      requiereCheckout: json['requiere_checkout'] == true,
      ordenId: json['orden_id'] != null ? int.tryParse(json['orden_id'].toString()) : null,
      ventaId: json['venta_id'] != null ? int.tryParse(json['venta_id'].toString()) : null,
      checkoutUrl: json['checkout_url']?.toString(),
      mensaje: json['mensaje']?.toString(),
    );
  }
}
