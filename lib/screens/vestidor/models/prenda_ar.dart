class TallaAR {
  final int id;
  final String nombre;
  final double anchoCm;
  final double largoCm;

  const TallaAR({
    required this.id,
    required this.nombre,
    required this.anchoCm,
    required this.largoCm,
  });

  factory TallaAR.fromJson(Map<String, dynamic> json) {
    return TallaAR(
      id: json['id'] as int? ?? 0,
      nombre: json['nombre'] as String? ?? '',
      anchoCm: (json['ancho_cm'] as num?)?.toDouble() ?? 50.0,
      largoCm: (json['largo_cm'] as num?)?.toDouble() ?? 70.0,
    );
  }
}

class ColorAR {
  final int id;
  final String nombre;
  final String? hex;
  final String? imagenUrl;

  const ColorAR({
    required this.id,
    required this.nombre,
    this.hex,
    this.imagenUrl,
  });

  factory ColorAR.fromJson(Map<String, dynamic> json) {
    return ColorAR(
      id: json['id'] as int? ?? 0,
      nombre: json['nombre'] as String? ?? 'Color',
      hex: json['hex'] as String?,
      imagenUrl: json['imagen_url'] as String?,
    );
  }
}

class VarianteAR {
  final int id;
  final int? tallaId;
  final String? tallaNombre;
  final int? colorId;
  final String? colorNombre;
  final String sku;
  final double precio;
  final bool disponible;

  const VarianteAR({
    required this.id,
    this.tallaId,
    this.tallaNombre,
    this.colorId,
    this.colorNombre,
    required this.sku,
    required this.precio,
    this.disponible = true,
  });

  factory VarianteAR.fromJson(Map<String, dynamic> json) {
    return VarianteAR(
      id: json['id'] as int? ?? 0,
      tallaId: json['talla_id'] as int?,
      tallaNombre: json['talla_nombre'] as String?,
      colorId: json['color_id'] as int?,
      colorNombre: json['color_nombre'] as String?,
      sku: json['sku'] as String? ?? '',
      precio: (json['precio'] as num?)?.toDouble() ?? 0.0,
      disponible: json['disponible'] as bool? ?? true,
    );
  }
}

class PrendaAR {
  final int productoId;
  final String nombre;
  final String? descripcion;
  final String categoria;
  final String tipoPrenda; // 'SUPERIOR', 'INFERIOR', 'VESTIDO'
  final String tipoCorte; // 'REGULAR_FIT', 'SLIM_FIT', 'OVERSIZE'
  final double anchoBaseCm;
  final double largoBaseCm;
  final String? imagenArUrl;
  final double precio;
  final List<TallaAR> tallas;
  final List<ColorAR> colores;
  final List<VarianteAR> variantes;

  const PrendaAR({
    required this.productoId,
    required this.nombre,
    this.descripcion,
    required this.categoria,
    required this.tipoPrenda,
    required this.tipoCorte,
    required this.anchoBaseCm,
    required this.largoBaseCm,
    this.imagenArUrl,
    required this.precio,
    this.tallas = const [],
    this.colores = const [],
    this.variantes = const [],
  });

  factory PrendaAR.fromJson(Map<String, dynamic> json) {
    return PrendaAR(
      productoId: json['producto_id'] as int? ?? 0,
      nombre: json['nombre'] as String? ?? '',
      descripcion: json['descripcion'] as String?,
      categoria: json['categoria'] as String? ?? '',
      tipoPrenda: json['tipo_prenda'] as String? ?? 'SUPERIOR',
      tipoCorte: json['tipo_corte'] as String? ?? 'REGULAR_FIT',
      anchoBaseCm: (json['ancho_base_cm'] as num?)?.toDouble() ?? 50.0,
      largoBaseCm: (json['largo_base_cm'] as num?)?.toDouble() ?? 70.0,
      imagenArUrl: (json['imagen_ar_url'] ?? json['imagen_url']) as String?,
      precio: ((json['precio'] ?? json['precio_desde']) as num?)?.toDouble() ?? 0.0,
      tallas: (json['tallas'] as List<dynamic>?)
              ?.map((e) => TallaAR.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      colores: (json['colores'] as List<dynamic>?)
              ?.map((e) => ColorAR.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
      variantes: (json['variantes'] as List<dynamic>?)
              ?.map((e) => VarianteAR.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
