class AsistenteContexto {
  final int? productoId;
  final int? sucursalId;

  const AsistenteContexto({this.productoId, this.sucursalId});

  Map<String, dynamic> toJson() => {
        if (productoId != null) 'producto_id': productoId,
        if (sucursalId != null) 'sucursal_id': sucursalId,
      };
}

class AsistenteChatRequest {
  final String mensaje;
  final AsistenteContexto? contexto;

  const AsistenteChatRequest({required this.mensaje, this.contexto});

  Map<String, dynamic> toJson() => {
        'mensaje': mensaje,
        if (contexto != null) 'contexto': contexto!.toJson(),
      };
}

class AsistenteProductoResponse {
  final int productoId;
  final String nombre;
  final String? categoria;
  final String? marca;
  final String? talla;
  final String? color;
  final String? sucursal;
  final String? ciudad;
  final int? stockDisponible;
  final int? stockReservado;
  final int? stockReal;
  final double? precioVigente;

  const AsistenteProductoResponse({
    required this.productoId,
    required this.nombre,
    this.categoria,
    this.marca,
    this.talla,
    this.color,
    this.sucursal,
    this.ciudad,
    this.stockDisponible,
    this.stockReservado,
    this.stockReal,
    this.precioVigente,
  });

  factory AsistenteProductoResponse.fromJson(Map<String, dynamic> json) {
    return AsistenteProductoResponse(
      productoId: json['producto_id'] is int
          ? json['producto_id']
          : int.parse(json['producto_id'].toString()),
      nombre: json['nombre']?.toString() ?? '',
      categoria: json['categoria']?.toString(),
      marca: json['marca']?.toString(),
      talla: json['talla']?.toString(),
      color: json['color']?.toString(),
      sucursal: json['sucursal']?.toString(),
      ciudad: json['ciudad']?.toString(),
      stockDisponible: json['stock_disponible'] != null
          ? int.tryParse(json['stock_disponible'].toString())
          : null,
      stockReservado: json['stock_reservado'] != null
          ? int.tryParse(json['stock_reservado'].toString())
          : null,
      stockReal: json['stock_real'] != null
          ? int.tryParse(json['stock_real'].toString())
          : null,
      precioVigente: json['precio_vigente'] != null
          ? double.tryParse(json['precio_vigente'].toString())
          : null,
    );
  }
}

class AsistenteAccionResponse {
  final String tipo;
  final String label;
  final String? url;

  const AsistenteAccionResponse({
    required this.tipo,
    required this.label,
    this.url,
  });

  factory AsistenteAccionResponse.fromJson(Map<String, dynamic> json) {
    return AsistenteAccionResponse(
      tipo: json['tipo']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      url: json['url']?.toString(),
    );
  }
}

class AsistenteChatResponse {
  final String respuesta;
  final String tipo;
  final List<AsistenteProductoResponse> productos;
  final List<AsistenteProductoResponse> alternativas;
  final List<AsistenteAccionResponse> acciones;
  final Map<String, dynamic> filtrosDetectados;
  final bool requiereLogin;

  const AsistenteChatResponse({
    required this.respuesta,
    required this.tipo,
    required this.productos,
    required this.alternativas,
    required this.acciones,
    required this.filtrosDetectados,
    required this.requiereLogin,
  });

  factory AsistenteChatResponse.fromJson(Map<String, dynamic> json) {
    return AsistenteChatResponse(
      respuesta: json['respuesta']?.toString() ?? '',
      tipo: json['tipo']?.toString() ?? '',
      productos: (json['productos'] as List<dynamic>? ?? [])
          .map((e) =>
              AsistenteProductoResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
      alternativas: (json['alternativas'] as List<dynamic>? ?? [])
          .map((e) =>
              AsistenteProductoResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
      acciones: (json['acciones'] as List<dynamic>? ?? [])
          .map((e) =>
              AsistenteAccionResponse.fromJson(e as Map<String, dynamic>))
          .toList(),
      filtrosDetectados:
          Map<String, dynamic>.from(json['filtros_detectados'] ?? {}),
      requiereLogin: json['requiere_login'] == true,
    );
  }
}
