class DeliveryCheckoutRequest {
  final int sucursalId;
  final String direccionEntrega;
  final String? referencia;
  final double latitudEntrega;
  final double longitudEntrega;
  final double? distanciaKm;
  final int? tiempoEstimadoMin;
  final double? costoDelivery;

  const DeliveryCheckoutRequest({
    required this.sucursalId,
    required this.direccionEntrega,
    this.referencia,
    required this.latitudEntrega,
    required this.longitudEntrega,
    this.distanciaKm,
    this.tiempoEstimadoMin,
    this.costoDelivery,
  });

  Map<String, dynamic> toJson() => {
        'sucursal_id': sucursalId,
        'direccion_entrega': direccionEntrega,
        if (referencia != null && referencia!.trim().isNotEmpty) 'referencia': referencia,
        'latitud_entrega': latitudEntrega,
        'longitud_entrega': longitudEntrega,
        if (distanciaKm != null) 'distancia_km': distanciaKm,
        if (tiempoEstimadoMin != null) 'tiempo_estimado_min': tiempoEstimadoMin,
        if (costoDelivery != null) 'costo_delivery': costoDelivery,
      };
}

class DeliveryCotizacion {
  final int sucursalId;
  final double distanciaKm;
  final int tiempoEstimadoMin;
  final double costoDelivery;
  final bool disponible;
  final String? mensaje;

  const DeliveryCotizacion({
    required this.sucursalId,
    required this.distanciaKm,
    required this.tiempoEstimadoMin,
    required this.costoDelivery,
    required this.disponible,
    this.mensaje,
  });

  factory DeliveryCotizacion.fromJson(Map<String, dynamic> json) {
    return DeliveryCotizacion(
      sucursalId: _asInt(json['sucursal_id']),
      distanciaKm: _asDouble(json['distancia_km']),
      tiempoEstimadoMin: _asInt(json['tiempo_estimado_min']),
      costoDelivery: _asDouble(json['costo_delivery']),
      disponible: json['disponible'] == true,
      mensaje: json['mensaje']?.toString(),
    );
  }
}

class DeliveryGeocodificacion {
  final String direccion;
  final double latitud;
  final double longitud;

  const DeliveryGeocodificacion({
    required this.direccion,
    required this.latitud,
    required this.longitud,
  });

  factory DeliveryGeocodificacion.fromJson(Map<String, dynamic> json) {
    return DeliveryGeocodificacion(
      direccion: json['direccion']?.toString() ?? '',
      latitud: _asDouble(json['latitud']),
      longitud: _asDouble(json['longitud']),
    );
  }
}

class DeliveryItem {
  final int id;
  final int ventaId;
  final String? ventaCodigo;
  final String? clienteNombre;
  final String? clienteCorreo;
  final int sucursalId;
  final String? sucursalNombre;
  final String direccionEntrega;
  final String? referencia;
  final double distanciaKm;
  final int tiempoEstimadoMin;
  final double costoDelivery;
  final String estado;
  final double totalVenta;
  final String fechaCreacion;
  final String? fechaEntrega;

  const DeliveryItem({
    required this.id,
    required this.ventaId,
    this.ventaCodigo,
    this.clienteNombre,
    this.clienteCorreo,
    required this.sucursalId,
    this.sucursalNombre,
    required this.direccionEntrega,
    this.referencia,
    required this.distanciaKm,
    required this.tiempoEstimadoMin,
    required this.costoDelivery,
    required this.estado,
    required this.totalVenta,
    required this.fechaCreacion,
    this.fechaEntrega,
  });

  factory DeliveryItem.fromJson(Map<String, dynamic> json) {
    return DeliveryItem(
      id: _asInt(json['id']),
      ventaId: _asInt(json['venta_id']),
      ventaCodigo: json['venta_codigo']?.toString(),
      clienteNombre: json['cliente_nombre']?.toString(),
      clienteCorreo: json['cliente_correo']?.toString(),
      sucursalId: _asInt(json['sucursal_id']),
      sucursalNombre: json['sucursal_nombre']?.toString(),
      direccionEntrega: json['direccion_entrega']?.toString() ?? '',
      referencia: json['referencia']?.toString(),
      distanciaKm: _asDouble(json['distancia_km']),
      tiempoEstimadoMin: _asInt(json['tiempo_estimado_min'] ?? 0),
      costoDelivery: _asDouble(json['costo_delivery']),
      estado: json['estado']?.toString() ?? '',
      totalVenta: _asDouble(json['total_venta']),
      fechaCreacion: json['fecha_creacion']?.toString() ?? '',
      fechaEntrega: json['fecha_entrega']?.toString(),
    );
  }
}

class DeliveryDetalle extends DeliveryItem {
  final String? sucursalDireccion;
  final double? sucursalLatitud;
  final double? sucursalLongitud;
  final double latitudEntrega;
  final double longitudEntrega;
  final String? observacion;

  const DeliveryDetalle({
    required super.id,
    required super.ventaId,
    super.ventaCodigo,
    super.clienteNombre,
    super.clienteCorreo,
    required super.sucursalId,
    super.sucursalNombre,
    required super.direccionEntrega,
    super.referencia,
    required super.distanciaKm,
    required super.tiempoEstimadoMin,
    required super.costoDelivery,
    required super.estado,
    required super.totalVenta,
    required super.fechaCreacion,
    super.fechaEntrega,
    this.sucursalDireccion,
    this.sucursalLatitud,
    this.sucursalLongitud,
    required this.latitudEntrega,
    required this.longitudEntrega,
    this.observacion,
  });

  factory DeliveryDetalle.fromJson(Map<String, dynamic> json) {
    final item = DeliveryItem.fromJson(json);
    return DeliveryDetalle(
      id: item.id,
      ventaId: item.ventaId,
      ventaCodigo: item.ventaCodigo,
      clienteNombre: item.clienteNombre,
      clienteCorreo: item.clienteCorreo,
      sucursalId: item.sucursalId,
      sucursalNombre: item.sucursalNombre,
      direccionEntrega: item.direccionEntrega,
      referencia: item.referencia,
      distanciaKm: item.distanciaKm,
      tiempoEstimadoMin: item.tiempoEstimadoMin,
      costoDelivery: item.costoDelivery,
      estado: item.estado,
      totalVenta: item.totalVenta,
      fechaCreacion: item.fechaCreacion,
      fechaEntrega: item.fechaEntrega,
      sucursalDireccion: json['sucursal_direccion']?.toString(),
      sucursalLatitud: json['sucursal_latitud'] == null ? null : _asDouble(json['sucursal_latitud']),
      sucursalLongitud: json['sucursal_longitud'] == null ? null : _asDouble(json['sucursal_longitud']),
      latitudEntrega: _asDouble(json['latitud_entrega']),
      longitudEntrega: _asDouble(json['longitud_entrega']),
      observacion: json['observacion']?.toString(),
    );
  }
}

int _asInt(dynamic value) => value is int ? value : int.parse(value.toString());

double _asDouble(dynamic value) => double.tryParse(value?.toString() ?? '0') ?? 0.0;
