class DeliveryCheckoutRequest {
  final String? cotizacionId;
  final int? direccionId;
  final int sucursalId;
  final String direccionEntrega;
  final String? referencia;
  final double latitudEntrega;
  final double longitudEntrega;
  final double? distanciaKm;
  final int? tiempoEstimadoMin;
  final double? costoDelivery;

  const DeliveryCheckoutRequest({
    this.cotizacionId,
    this.direccionId,
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
    if (cotizacionId != null) 'cotizacion_id': cotizacionId,
    if (direccionId != null) 'direccion_id': direccionId,
    'sucursal_id': sucursalId,
    'direccion_entrega': direccionEntrega,
    if (referencia != null && referencia!.trim().isNotEmpty)
      'referencia': referencia,
    'latitud_entrega': latitudEntrega,
    'longitud_entrega': longitudEntrega,
    if (distanciaKm != null) 'distancia_km': distanciaKm,
    if (tiempoEstimadoMin != null) 'tiempo_estimado_min': tiempoEstimadoMin,
    if (costoDelivery != null) 'costo_delivery': costoDelivery,
  };
}

class DeliveryCotizacion {
  final String? cotizacionId, venceEn;
  final List<List<double>> ruta;
  final int sucursalId;
  final double distanciaKm;
  final int tiempoEstimadoMin;
  final double costoDelivery;
  final bool disponible;
  final String? mensaje;

  const DeliveryCotizacion({
    this.cotizacionId,
    this.venceEn,
    this.ruta = const [],
    required this.sucursalId,
    required this.distanciaKm,
    required this.tiempoEstimadoMin,
    required this.costoDelivery,
    required this.disponible,
    this.mensaje,
  });

  factory DeliveryCotizacion.fromJson(Map<String, dynamic> json) {
    return DeliveryCotizacion(
      cotizacionId: json['cotizacion_id']?.toString(),
      venceEn: json['vence_en']?.toString(),
      ruta: _ruta(json['ruta']),
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
  final int version;
  final bool pagoConfirmado, incidenciaAbierta;
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
    this.version = 1,
    this.pagoConfirmado = false,
    this.incidenciaAbierta = false,
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
      version: _asInt(json['version'] ?? 1),
      pagoConfirmado: json['pago_confirmado'] == true,
      incidenciaAbierta: json['incidencia_abierta'] == true,
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
  final List<List<double>> ruta;
  final List<Map<String, dynamic>> historial;
  final List<String> transiciones;
  final bool puedeGestionar;
  final String? sucursalDireccion;
  final double? sucursalLatitud;
  final double? sucursalLongitud;
  final double latitudEntrega;
  final double longitudEntrega;
  final String? observacion;

  const DeliveryDetalle({
    super.version,
    super.pagoConfirmado,
    super.incidenciaAbierta,
    this.ruta = const [],
    this.historial = const [],
    this.transiciones = const [],
    this.puedeGestionar = false,
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
      version: item.version,
      pagoConfirmado: item.pagoConfirmado,
      incidenciaAbierta: item.incidenciaAbierta,
      ruta: _ruta(json['ruta']),
      historial: (json['historial'] as List? ?? [])
          .cast<Map<String, dynamic>>(),
      transiciones: (json['transiciones'] as List? ?? []).cast<String>(),
      puedeGestionar: json['puede_gestionar'] == true,
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
      sucursalLatitud: json['sucursal_latitud'] == null
          ? null
          : _asDouble(json['sucursal_latitud']),
      sucursalLongitud: json['sucursal_longitud'] == null
          ? null
          : _asDouble(json['sucursal_longitud']),
      latitudEntrega: _asDouble(json['latitud_entrega']),
      longitudEntrega: _asDouble(json['longitud_entrega']),
      observacion: json['observacion']?.toString(),
    );
  }
}

int _asInt(dynamic value) => value is int ? value : int.parse(value.toString());

double _asDouble(dynamic value) =>
    double.tryParse(value?.toString() ?? '0') ?? 0.0;

List<List<double>> _ruta(dynamic data) => (data as List? ?? [])
    .map((p) => (p as List).map((n) => (n as num).toDouble()).toList())
    .toList();
