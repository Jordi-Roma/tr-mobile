class CatalogoCategoria {
  final int id;
  final String nombre;

  CatalogoCategoria({required this.id, required this.nombre});

  factory CatalogoCategoria.fromJson(Map<String, dynamic> json) {
    return CatalogoCategoria(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      nombre: json['nombre'] ?? '',
    );
  }
}

class CatalogoTalla {
  final int id;
  final String nombre;

  CatalogoTalla({required this.id, required this.nombre});

  factory CatalogoTalla.fromJson(Map<String, dynamic> json) {
    return CatalogoTalla(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      nombre: json['nombre'] ?? '',
    );
  }
}

class CatalogoColor {
  final int id;
  final String nombre;
  final String? hex;

  CatalogoColor({required this.id, required this.nombre, this.hex});

  factory CatalogoColor.fromJson(Map<String, dynamic> json) {
    return CatalogoColor(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      nombre: json['nombre'] ?? '',
      hex: json['hex'],
    );
  }
}

class CatalogoSucursal {
  final int id;
  final String nombre;
  final String ciudad;
  final double? latitud;
  final double? longitud;

  CatalogoSucursal({
    required this.id,
    required this.nombre,
    required this.ciudad,
    this.latitud,
    this.longitud,
  });

  factory CatalogoSucursal.fromJson(Map<String, dynamic> json) {
    return CatalogoSucursal(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      nombre: json['nombre'] ?? '',
      ciudad: json['ciudad'] ?? '',
      latitud: json['latitud'] != null ? double.tryParse(json['latitud'].toString()) : null,
      longitud: json['longitud'] != null ? double.tryParse(json['longitud'].toString()) : null,
    );
  }
}

class CatalogoVariante {
  final int id;
  final String sku;
  final int? tallaId;
  final String? talla;
  final int? colorId;
  final String? color;
  final String? colorHex;
  final double precioFinal;
  final double? precioVigente;
  final bool tienePromocion;
  final int stockTotal;
  final bool activo;

  CatalogoVariante({
    required this.id,
    required this.sku,
    this.tallaId,
    this.talla,
    this.colorId,
    this.color,
    this.colorHex,
    required this.precioFinal,
    this.precioVigente,
    required this.tienePromocion,
    required this.stockTotal,
    required this.activo,
  });

  factory CatalogoVariante.fromJson(Map<String, dynamic> json) {
    return CatalogoVariante(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      sku: json['sku'] ?? '',
      tallaId: json['talla_id'] != null ? int.tryParse(json['talla_id'].toString()) : null,
      talla: json['talla'],
      colorId: json['color_id'] != null ? int.tryParse(json['color_id'].toString()) : null,
      color: json['color'],
      colorHex: json['color_hex'],
      precioFinal: double.tryParse(json['precio_final']?.toString() ?? '0') ?? 0.0,
      precioVigente: json['precio_vigente'] != null ? double.tryParse(json['precio_vigente'].toString()) : null,
      tienePromocion: json['tiene_promocion'] ?? false,
      stockTotal: json['stock_total'] is int ? json['stock_total'] : int.tryParse(json['stock_total']?.toString() ?? '0') ?? 0,
      activo: json['activo'] ?? true,
    );
  }
}

class CatalogoDisponibilidad {
  final int sucursalId;
  final String sucursal;
  final String ciudad;
  final int varianteId;
  final String? talla;
  final String? color;
  final int stockDisponible;
  final int stockReservado;
  final bool disponible;

  CatalogoDisponibilidad({
    required this.sucursalId,
    required this.sucursal,
    required this.ciudad,
    required this.varianteId,
    this.talla,
    this.color,
    required this.stockDisponible,
    required this.stockReservado,
    required this.disponible,
  });

  int get stockReal => stockDisponible - stockReservado;

  factory CatalogoDisponibilidad.fromJson(Map<String, dynamic> json) {
    return CatalogoDisponibilidad(
      sucursalId: json['sucursal_id'] is int ? json['sucursal_id'] : int.parse(json['sucursal_id'].toString()),
      sucursal: json['sucursal'] ?? '',
      ciudad: json['ciudad'] ?? '',
      varianteId: json['variante_id'] is int ? json['variante_id'] : int.parse(json['variante_id'].toString()),
      talla: json['talla'],
      color: json['color'],
      stockDisponible: json['stock_disponible'] is int ? json['stock_disponible'] : int.tryParse(json['stock_disponible']?.toString() ?? '0') ?? 0,
      stockReservado: json['stock_reservado'] is int ? json['stock_reservado'] : int.tryParse(json['stock_reservado']?.toString() ?? '0') ?? 0,
      disponible: json['disponible'] ?? true,
    );
  }
}

class CatalogoPrendaItem {
  final int productoId;
  final String nombre;
  final String? descripcion;
  final int categoriaId;
  final String categoria;
  final String? marca;
  final String? material;
  final String? genero;
  final double precioFinal;
  final double? precioVigente;
  final bool tienePromocion;
  final int stockTotal;
  final List<CatalogoTalla> tallas;
  final List<CatalogoColor> colores;
  final String? imagenPrincipal;
  final bool activo;

  CatalogoPrendaItem({
    required this.productoId,
    required this.nombre,
    this.descripcion,
    required this.categoriaId,
    required this.categoria,
    this.marca,
    this.material,
    this.genero,
    required this.precioFinal,
    this.precioVigente,
    required this.tienePromocion,
    required this.stockTotal,
    required this.tallas,
    required this.colores,
    this.imagenPrincipal,
    required this.activo,
  });

  factory CatalogoPrendaItem.fromJson(Map<String, dynamic> json) {
    return CatalogoPrendaItem(
      productoId: json['producto_id'] is int ? json['producto_id'] : int.parse(json['producto_id'].toString()),
      nombre: json['nombre'] ?? '',
      descripcion: json['descripcion'],
      categoriaId: json['categoria_id'] is int ? json['categoria_id'] : int.parse(json['categoria_id'].toString()),
      categoria: json['categoria'] ?? '',
      marca: json['marca'],
      material: json['material'],
      genero: json['genero'],
      precioFinal: double.tryParse(json['precio_final']?.toString() ?? '0') ?? 0.0,
      precioVigente: json['precio_vigente'] != null ? double.tryParse(json['precio_vigente'].toString()) : null,
      tienePromocion: json['tiene_promocion'] ?? false,
      stockTotal: json['stock_total'] is int ? json['stock_total'] : int.tryParse(json['stock_total']?.toString() ?? '0') ?? 0,
      tallas: (json['tallas'] as List<dynamic>?)?.map((e) => CatalogoTalla.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      colores: (json['colores'] as List<dynamic>?)?.map((e) => CatalogoColor.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      imagenPrincipal: json['imagen_principal'],
      activo: json['activo'] ?? true,
    );
  }
}

class CatalogoPrendaDetalle extends CatalogoPrendaItem {
  final List<String> colecciones;
  final List<CatalogoVariante> variantes;
  final List<CatalogoDisponibilidad> disponibilidad;

  CatalogoPrendaDetalle({
    required super.productoId,
    required super.nombre,
    super.descripcion,
    required super.categoriaId,
    required super.categoria,
    super.marca,
    super.material,
    super.genero,
    required super.precioFinal,
    super.precioVigente,
    required super.tienePromocion,
    required super.stockTotal,
    required super.tallas,
    required super.colores,
    super.imagenPrincipal,
    required super.activo,
    required this.colecciones,
    required this.variantes,
    required this.disponibilidad,
  });

  factory CatalogoPrendaDetalle.fromJson(Map<String, dynamic> json) {
    final item = CatalogoPrendaItem.fromJson(json);
    return CatalogoPrendaDetalle(
      productoId: item.productoId,
      nombre: item.nombre,
      descripcion: item.descripcion,
      categoriaId: item.categoriaId,
      categoria: item.categoria,
      marca: item.marca,
      material: item.material,
      genero: item.genero,
      precioFinal: item.precioFinal,
      precioVigente: item.precioVigente,
      tienePromocion: item.tienePromocion,
      stockTotal: item.stockTotal,
      tallas: item.tallas,
      colores: item.colores,
      imagenPrincipal: item.imagenPrincipal,
      activo: item.activo,
      colecciones: (json['colecciones'] as List<dynamic>?)?.map((e) => e.toString()).toList() ?? [],
      variantes: (json['variantes'] as List<dynamic>?)?.map((e) => CatalogoVariante.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      disponibilidad: (json['disponibilidad'] as List<dynamic>?)?.map((e) => CatalogoDisponibilidad.fromJson(e as Map<String, dynamic>)).toList() ?? [],
    );
  }
}
