import 'delivery_models.dart';

class CrearCheckoutStripeRequest {
  final int? sucursalId;
  final String tipoEntrega;
  final DeliveryCheckoutRequest? delivery;

  const CrearCheckoutStripeRequest({
    this.sucursalId,
    this.tipoEntrega = 'RECOJO_SUCURSAL',
    this.delivery,
  });

  Map<String, dynamic> toJson() => {
        if (sucursalId != null) 'sucursal_id': sucursalId,
        'tipo_entrega': tipoEntrega,
        if (delivery != null) 'delivery': delivery!.toJson(),
      };
}

class CheckoutStripeResponse {
  final int ordenId;
  final int ventaId;
  final String estado;
  final String checkoutUrl;

  const CheckoutStripeResponse({
    required this.ordenId,
    required this.ventaId,
    required this.estado,
    required this.checkoutUrl,
  });

  factory CheckoutStripeResponse.fromJson(Map<String, dynamic> json) {
    return CheckoutStripeResponse(
      ordenId: json['orden_id'] is int
          ? json['orden_id']
          : int.parse(json['orden_id'].toString()),
      ventaId: json['venta_id'] is int
          ? json['venta_id']
          : int.parse(json['venta_id'].toString()),
      estado: json['estado']?.toString() ?? '',
      checkoutUrl: json['checkout_url']?.toString() ?? '',
    );
  }
}

class OrdenPagoResponse {
  final int ordenId;
  final int ventaId;
  final int? clienteId;
  final double montoTotal;
  final String moneda;
  final String metodo;
  final String estado;
  final String proveedor;
  final String? checkoutUrl;
  final String? proveedorSessionId;
  final String? fechaPago;

  const OrdenPagoResponse({
    required this.ordenId,
    required this.ventaId,
    this.clienteId,
    required this.montoTotal,
    required this.moneda,
    required this.metodo,
    required this.estado,
    required this.proveedor,
    this.checkoutUrl,
    this.proveedorSessionId,
    this.fechaPago,
  });

  factory OrdenPagoResponse.fromJson(Map<String, dynamic> json) {
    return OrdenPagoResponse(
      ordenId: json['orden_id'] is int
          ? json['orden_id']
          : int.parse(json['orden_id'].toString()),
      ventaId: json['venta_id'] is int
          ? json['venta_id']
          : int.parse(json['venta_id'].toString()),
      clienteId: json['cliente_id'] != null
          ? int.tryParse(json['cliente_id'].toString())
          : null,
      montoTotal:
          double.tryParse(json['monto_total']?.toString() ?? '0') ?? 0.0,
      moneda: json['moneda']?.toString() ?? 'BOB',
      metodo: json['metodo']?.toString() ?? '',
      estado: json['estado']?.toString() ?? '',
      proveedor: json['proveedor']?.toString() ?? '',
      checkoutUrl: json['checkout_url']?.toString(),
      proveedorSessionId: json['proveedor_session_id']?.toString(),
      fechaPago: json['fecha_pago']?.toString(),
    );
  }

  bool get pagado =>
      estado.toUpperCase() == 'PAGADO' ||
      estado.toUpperCase() == 'COMPLETADO';

  bool get pendiente => estado.toUpperCase() == 'PENDIENTE';

  bool get cancelado =>
      estado.toUpperCase() == 'CANCELADO' ||
      estado.toUpperCase() == 'FALLIDO';
}

class PagoHistorialItem {
  final int ordenId;
  final int ventaId;
  final String? ventaCodigo;
  final int? clienteId;
  final String? clienteNombre;
  final String? clienteCorreo;
  final int? sucursalId;
  final String? sucursalNombre;
  final double montoTotal;
  final String moneda;
  final String metodo;
  final String estado;
  final String proveedor;
  final String fechaCreacion;
  final String? fechaPago;

  const PagoHistorialItem({
    required this.ordenId,
    required this.ventaId,
    this.ventaCodigo,
    this.clienteId,
    this.clienteNombre,
    this.clienteCorreo,
    this.sucursalId,
    this.sucursalNombre,
    required this.montoTotal,
    required this.moneda,
    required this.metodo,
    required this.estado,
    required this.proveedor,
    required this.fechaCreacion,
    this.fechaPago,
  });

  factory PagoHistorialItem.fromJson(Map<String, dynamic> json) {
    return PagoHistorialItem(
      ordenId: _asInt(json['orden_id']),
      ventaId: _asInt(json['venta_id']),
      ventaCodigo: json['venta_codigo']?.toString(),
      clienteId: json['cliente_id'] == null ? null : _asInt(json['cliente_id']),
      clienteNombre: json['cliente_nombre']?.toString(),
      clienteCorreo: json['cliente_correo']?.toString(),
      sucursalId: json['sucursal_id'] == null ? null : _asInt(json['sucursal_id']),
      sucursalNombre: json['sucursal_nombre']?.toString(),
      montoTotal: _asDouble(json['monto_total']),
      moneda: json['moneda']?.toString() ?? 'BOB',
      metodo: json['metodo']?.toString() ?? '',
      estado: json['estado']?.toString() ?? '',
      proveedor: json['proveedor']?.toString() ?? '',
      fechaCreacion: json['fecha_creacion']?.toString() ?? '',
      fechaPago: json['fecha_pago']?.toString(),
    );
  }
}

class PagoProductoDetalle {
  final String producto;
  final String? categoria;
  final String? talla;
  final String? color;
  final int cantidad;
  final double precioUnitario;
  final double subtotal;

  const PagoProductoDetalle({
    required this.producto,
    this.categoria,
    this.talla,
    this.color,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
  });

  factory PagoProductoDetalle.fromJson(Map<String, dynamic> json) {
    return PagoProductoDetalle(
      producto: json['producto']?.toString() ?? '',
      categoria: json['categoria']?.toString(),
      talla: json['talla']?.toString(),
      color: json['color']?.toString(),
      cantidad: _asInt(json['cantidad']),
      precioUnitario: _asDouble(json['precio_unitario']),
      subtotal: _asDouble(json['subtotal']),
    );
  }
}

class PagoHistorialDetalle extends PagoHistorialItem {
  final String? proveedorSessionId;
  final String? proveedorPaymentIntentId;
  final String? checkoutUrl;
  final List<PagoProductoDetalle> productos;

  const PagoHistorialDetalle({
    required super.ordenId,
    required super.ventaId,
    super.ventaCodigo,
    super.clienteId,
    super.clienteNombre,
    super.clienteCorreo,
    super.sucursalId,
    super.sucursalNombre,
    required super.montoTotal,
    required super.moneda,
    required super.metodo,
    required super.estado,
    required super.proveedor,
    required super.fechaCreacion,
    super.fechaPago,
    this.proveedorSessionId,
    this.proveedorPaymentIntentId,
    this.checkoutUrl,
    required this.productos,
  });

  factory PagoHistorialDetalle.fromJson(Map<String, dynamic> json) {
    final item = PagoHistorialItem.fromJson(json);
    return PagoHistorialDetalle(
      ordenId: item.ordenId,
      ventaId: item.ventaId,
      ventaCodigo: item.ventaCodigo,
      clienteId: item.clienteId,
      clienteNombre: item.clienteNombre,
      clienteCorreo: item.clienteCorreo,
      sucursalId: item.sucursalId,
      sucursalNombre: item.sucursalNombre,
      montoTotal: item.montoTotal,
      moneda: item.moneda,
      metodo: item.metodo,
      estado: item.estado,
      proveedor: item.proveedor,
      fechaCreacion: item.fechaCreacion,
      fechaPago: item.fechaPago,
      proveedorSessionId: json['proveedor_session_id']?.toString(),
      proveedorPaymentIntentId: json['proveedor_payment_intent_id']?.toString(),
      checkoutUrl: json['checkout_url']?.toString(),
      productos: (json['productos'] as List<dynamic>? ?? [])
          .whereType<Map<String, dynamic>>()
          .map(PagoProductoDetalle.fromJson)
          .toList(),
    );
  }
}

int _asInt(dynamic value) => value is int ? value : int.parse(value.toString());

double _asDouble(dynamic value) => double.tryParse(value?.toString() ?? '0') ?? 0.0;
