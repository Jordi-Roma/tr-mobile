class AdminProductoImagen {
  final int? id;
  final String url;
  final bool esPrincipal;

  AdminProductoImagen({
    this.id,
    required this.url,
    this.esPrincipal = false,
  });

  factory AdminProductoImagen.fromJson(Map<String, dynamic> json) {
    return AdminProductoImagen(
      id: json['id'] != null ? int.tryParse(json['id'].toString()) : null,
      url: json['url'] ?? '',
      esPrincipal: json['es_principal'] ?? false,
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'url': url,
      'es_principal': esPrincipal,
    };
  }
}

class AdminProductoItem {
  final int id;
  final int categoriaId;
  final String categoriaNombre;
  final int? marcaId;
  final String? marcaNombre;
  final String nombre;
  final String? descripcion;
  final String? material;
  final String? genero;
  final String tipoPrenda;
  final String tipoCorte;
  final double? anchoBaseCm;
  final double? largoBaseCm;
  final bool activo;
  final List<int> coleccionesIds;
  final List<int> proveedoresIds;
  final List<AdminProductoImagen> imagenes;

  AdminProductoItem({
    required this.id,
    required this.categoriaId,
    required this.categoriaNombre,
    this.marcaId,
    this.marcaNombre,
    required this.nombre,
    this.descripcion,
    this.material,
    this.genero,
    this.tipoPrenda = 'SUPERIOR',
    this.tipoCorte = 'REGULAR_FIT',
    this.anchoBaseCm,
    this.largoBaseCm,
    required this.activo,
    required this.coleccionesIds,
    required this.proveedoresIds,
    required this.imagenes,
  });

  String get imagenPrincipal {
    if (imagenes.isEmpty) return '';
    final principal = imagenes.where((img) => img.esPrincipal).firstOrNull;
    return principal?.url ?? imagenes.first.url;
  }

  factory AdminProductoItem.fromJson(Map<String, dynamic> json) {
    return AdminProductoItem(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      categoriaId: json['categoria_id'] is int ? json['categoria_id'] : int.parse(json['categoria_id'].toString()),
      categoriaNombre: json['categoria_nombre'] ?? '',
      marcaId: json['marca_id'] != null ? int.tryParse(json['marca_id'].toString()) : null,
      marcaNombre: json['marca_nombre'],
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'],
      material: json['material'],
      genero: json['genero'],
      tipoPrenda: json['tipo_prenda'] ?? 'SUPERIOR',
      tipoCorte: json['tipo_corte'] ?? 'REGULAR_FIT',
      anchoBaseCm: json['ancho_base_cm'] != null ? double.tryParse(json['ancho_base_cm'].toString()) : null,
      largoBaseCm: json['largo_base_cm'] != null ? double.tryParse(json['largo_base_cm'].toString()) : null,
      activo: json['activo'] ?? true,
      coleccionesIds: (json['colecciones_ids'] as List<dynamic>?)?.map((e) => int.parse(e.toString())).toList() ?? [],
      proveedoresIds: (json['proveedores_ids'] as List<dynamic>?)?.map((e) => int.parse(e.toString())).toList() ?? [],
      imagenes: (json['imagenes'] as List<dynamic>?)?.map((e) => AdminProductoImagen.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    );
  }
}

class AdminCategoria {
  final int id;
  final int? categoriaPadreId;
  final String? categoriaPadreNombre;
  final String nombre;
  final String? descripcion;
  final bool activo;

  AdminCategoria({
    required this.id,
    this.categoriaPadreId,
    this.categoriaPadreNombre,
    required this.nombre,
    this.descripcion,
    required this.activo,
  });

  factory AdminCategoria.fromJson(Map<String, dynamic> json) {
    return AdminCategoria(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      categoriaPadreId: json['categoria_padre_id'] != null ? int.tryParse(json['categoria_padre_id'].toString()) : null,
      categoriaPadreNombre: json['categoria_padre_nombre'],
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'],
      activo: json['activo'] ?? true,
    );
  }
}

class AdminTalla {
  final int id;
  final String nombre;
  final String? descripcion;
  final String tipoPrenda;
  final double? anchoCm;
  final double? largoCm;
  final bool activo;

  AdminTalla({
    required this.id,
    required this.nombre,
    this.descripcion,
    this.tipoPrenda = 'SUPERIOR',
    this.anchoCm,
    this.largoCm,
    required this.activo,
  });

  factory AdminTalla.fromJson(Map<String, dynamic> json) {
    return AdminTalla(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'],
      tipoPrenda: json['tipo_prenda'] ?? 'SUPERIOR',
      anchoCm: json['ancho_cm'] != null ? double.tryParse(json['ancho_cm'].toString()) : null,
      largoCm: json['largo_cm'] != null ? double.tryParse(json['largo_cm'].toString()) : null,
      activo: json['activo'] ?? true,
    );
  }
}

class AdminColor {
  final int id;
  final String nombre;
  final String? codigoHex;
  final bool activo;

  AdminColor({
    required this.id,
    required this.nombre,
    this.codigoHex,
    required this.activo,
  });

  factory AdminColor.fromJson(Map<String, dynamic> json) {
    return AdminColor(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      nombre: json['nombre'] ?? '',
      codigoHex: json['codigo_hex'],
      activo: json['activo'] ?? true,
    );
  }
}

class AdminMarca {
  final int id;
  final String nombre;
  final String? descripcion;
  final bool activo;

  AdminMarca({
    required this.id,
    required this.nombre,
    this.descripcion,
    required this.activo,
  });

  factory AdminMarca.fromJson(Map<String, dynamic> json) {
    return AdminMarca(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'],
      activo: json['activo'] ?? true,
    );
  }
}

class AdminPrecioItem {
  final int id;
  final int varianteId;
  final double monto;
  final String? fechaInicio;
  final String? fechaFin;
  final bool activo;

  AdminPrecioItem({
    required this.id,
    required this.varianteId,
    required this.monto,
    this.fechaInicio,
    this.fechaFin,
    required this.activo,
  });

  factory AdminPrecioItem.fromJson(Map<String, dynamic> json) {
    return AdminPrecioItem(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      varianteId: json['variante_id'] is int ? json['variante_id'] : int.parse(json['variante_id'].toString()),
      monto: double.tryParse(json['monto']?.toString() ?? '0') ?? 0.0,
      fechaInicio: json['fecha_inicio'],
      fechaFin: json['fecha_fin'],
      activo: json['activo'] ?? true,
    );
  }
}

class AdminVarianteItem {
  final int id;
  final int productoId;
  final String productoNombre;
  final int? tallaId;
  final String? tallaNombre;
  final int? colorId;
  final String? colorNombre;
  final String sku;
  final double? anchoCm;
  final double? largoCm;
  final bool activo;
  final List<AdminPrecioItem> precios;

  AdminVarianteItem({
    required this.id,
    required this.productoId,
    required this.productoNombre,
    this.tallaId,
    this.tallaNombre,
    this.colorId,
    this.colorNombre,
    required this.sku,
    this.anchoCm,
    this.largoCm,
    required this.activo,
    required this.precios,
  });

  double? get precioActual {
    if (precios.isEmpty) return null;
    return precios.first.monto;
  }

  factory AdminVarianteItem.fromJson(Map<String, dynamic> json) {
    return AdminVarianteItem(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      productoId: json['producto_id'] is int ? json['producto_id'] : int.parse(json['producto_id'].toString()),
      productoNombre: json['producto_nombre'] ?? '',
      tallaId: json['talla_id'] != null ? int.tryParse(json['talla_id'].toString()) : null,
      tallaNombre: json['talla_nombre'],
      colorId: json['color_id'] != null ? int.tryParse(json['color_id'].toString()) : null,
      colorNombre: json['color_nombre'],
      sku: json['sku'] ?? '',
      anchoCm: json['ancho_cm'] != null ? double.tryParse(json['ancho_cm'].toString()) : null,
      largoCm: json['largo_cm'] != null ? double.tryParse(json['largo_cm'].toString()) : null,
      activo: json['activo'] ?? true,
      precios: (json['precios'] as List<dynamic>?)?.map((e) => AdminPrecioItem.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    );
  }
}

class TipoCorteOption {
  final String key;
  final String label;
  final String description;

  const TipoCorteOption({
    required this.key,
    required this.label,
    required this.description,
  });
}

const List<TipoCorteOption> kTiposCorte = [
  TipoCorteOption(
    key: 'REGULAR_FIT',
    label: 'Regular Fit (Corte Estándar)',
    description: 'Recto y equilibrado, caída tradicional clásica al cuerpo.',
  ),
  TipoCorteOption(
    key: 'SLIM_FIT',
    label: 'Slim Fit (Corte Ajustado / Ceñido)',
    description: 'Entallado al torso y silueta ceñida que resalta la figura.',
  ),
  TipoCorteOption(
    key: 'OVERSIZE',
    label: 'Oversize (Corte Holgado / Amplio)',
    description: 'Holgado, suelto con hombros caídos y volumen extra.',
  ),
];

class TipoPrendaOption {
  final String key;
  final String label;

  const TipoPrendaOption({
    required this.key,
    required this.label,
  });
}

const List<TipoPrendaOption> kTiposPrenda = [
  TipoPrendaOption(key: 'SUPERIOR', label: 'Prenda Superior (Polera, Camisa, Casaca)'),
  TipoPrendaOption(key: 'INFERIOR', label: 'Prenda Inferior (Pantalón, Short, Falda)'),
  TipoPrendaOption(key: 'VESTIDO', label: 'Cuerpo Completo / Vestido'),
];
