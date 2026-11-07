const recursosChat = [
  'RESERVA',
  'VENTA',
  'ORDEN_PAGO',
  'DELIVERY',
  'CAMBIO',
  'DEVOLUCION',
  'REEMBOLSO_PAGO',
];

class AsistenteContexto {
  final int? productoId, sucursalId, empresaId, varianteId, recursoId;
  final String? recursoTipo;
  final List<String> terminos, colores, tallas;
  final num? precioMax;
  const AsistenteContexto({
    this.productoId,
    this.sucursalId,
    this.empresaId,
    this.varianteId,
    this.recursoTipo,
    this.recursoId,
    this.terminos = const [],
    this.colores = const [],
    this.tallas = const [],
    this.precioMax,
  });
  factory AsistenteContexto.fromJson(Map<String, dynamic> j) =>
      AsistenteContexto(
        productoId: (j['producto_id'] as num?)?.toInt(),
        sucursalId: (j['sucursal_id'] as num?)?.toInt(),
        empresaId: (j['empresa_id'] as num?)?.toInt(),
        varianteId: (j['variante_id'] as num?)?.toInt(),
        recursoTipo: j['recurso_tipo'] as String?,
        recursoId: (j['recurso_id'] as num?)?.toInt(),
        terminos: List<String>.from(j['terminos'] ?? []),
        colores: List<String>.from(j['color_patrones'] ?? []),
        tallas: List<String>.from(j['talla_patrones'] ?? []),
        precioMax: j['precio_max'] as num?,
      );
  Map<String, dynamic> toJson() => {
    if (productoId != null) 'producto_id': productoId,
    if (sucursalId != null) 'sucursal_id': sucursalId,
    if (empresaId != null) 'empresa_id': empresaId,
    if (varianteId != null) 'variante_id': varianteId,
    if (recursoTipo != null) 'recurso_tipo': recursoTipo,
    if (recursoId != null) 'recurso_id': recursoId,
    'terminos': terminos,
    'color_patrones': colores,
    'talla_patrones': tallas,
    if (precioMax != null) 'precio_max': precioMax,
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
  final double? precioFinal;
  final String? precioFinalExacto, descripcion, material, motivo;
  final String moneda;
  final int? varianteId, sucursalId;
  final Map<String, dynamic>? promocion;
  String get precioMostrado {
    final v = precioFinalExacto ?? precioFinal ?? precioVigente;
    return v == null ? 'Precio no disponible' : '$moneda $v';
  }

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
    this.precioFinal,
    this.precioFinalExacto,
    this.descripcion,
    this.material,
    this.motivo,
    this.moneda = 'BOB',
    this.varianteId,
    this.sucursalId,
    this.promocion,
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
      precioFinal: double.tryParse(json['precio_final']?.toString() ?? ''),
      precioFinalExacto: json['precio_final_exacto'] as String?,
      descripcion: json['descripcion'] as String?,
      material: json['material'] as String?,
      motivo: json['motivo'] as String?,
      moneda: json['moneda'] as String? ?? 'BOB',
      varianteId: (json['variante_id'] as num?)?.toInt(),
      sucursalId: (json['sucursal_id'] as num?)?.toInt(),
      promocion: json['promocion'] == null
          ? null
          : Map<String, dynamic>.from(json['promocion'] as Map),
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
  final List<String> fuentes;
  final String? consultadoEn;
  final List<Map<String, dynamic>> datos;
  final AsistenteContexto? contexto;
  final bool aclaracion, hayMas;

  const AsistenteChatResponse({
    required this.respuesta,
    required this.tipo,
    required this.productos,
    required this.alternativas,
    required this.acciones,
    required this.filtrosDetectados,
    required this.requiereLogin,
    this.fuentes = const [],
    this.consultadoEn,
    this.datos = const [],
    this.contexto,
    this.aclaracion = false,
    this.hayMas = false,
  });

  factory AsistenteChatResponse.fromJson(Map<String, dynamic> json) {
    return AsistenteChatResponse(
      respuesta: json['respuesta']?.toString() ?? '',
      tipo: json['tipo']?.toString() ?? '',
      productos: (json['productos'] as List<dynamic>? ?? [])
          .map(
            (e) =>
                AsistenteProductoResponse.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      alternativas: (json['alternativas'] as List<dynamic>? ?? [])
          .map(
            (e) =>
                AsistenteProductoResponse.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      acciones: (json['acciones'] as List<dynamic>? ?? [])
          .map(
            (e) => AsistenteAccionResponse.fromJson(e as Map<String, dynamic>),
          )
          .toList(),
      filtrosDetectados: Map<String, dynamic>.from(
        json['filtros_detectados'] ?? {},
      ),
      requiereLogin: json['requiere_login'] == true,
      fuentes: List<String>.from(json['fuentes'] ?? []),
      consultadoEn: json['consultado_en'] as String?,
      datos: (json['datos'] as List? ?? [])
          .map((e) => Map<String, dynamic>.from(e as Map))
          .toList(),
      contexto: json['contexto'] == null
          ? null
          : AsistenteContexto.fromJson(
              Map<String, dynamic>.from(json['contexto'] as Map),
            ),
      aclaracion: json['aclaracion'] == true,
      hayMas: json['hay_mas'] == true,
    );
  }
}
