class ProveedorPerfil {
  final int id;
  final String nombre;
  final String? nit;
  final String? telefono;
  final String? correo;
  final String? direccion;

  ProveedorPerfil({
    required this.id,
    required this.nombre,
    this.nit,
    this.telefono,
    this.correo,
    this.direccion,
  });

  factory ProveedorPerfil.fromJson(Map<String, dynamic> json) {
    return ProveedorPerfil(
      id: _asInt(json['id']),
      nombre: json['nombre']?.toString() ?? '',
      nit: json['nit']?.toString(),
      telefono: json['telefono']?.toString(),
      correo: json['correo']?.toString(),
      direccion: json['direccion']?.toString(),
    );
  }
}

class ProveedorProducto {
  final int id;
  final String nombre;
  final String categoria;
  final String marca;
  final bool activo;
  final int variantes;

  ProveedorProducto({
    required this.id,
    required this.nombre,
    required this.categoria,
    required this.marca,
    required this.activo,
    required this.variantes,
  });

  factory ProveedorProducto.fromJson(Map<String, dynamic> json) {
    return ProveedorProducto(
      id: _asInt(json['producto_id']),
      nombre: json['nombre']?.toString() ?? '',
      categoria: json['categoria']?.toString() ?? 'Sin categoría',
      marca: json['marca']?.toString() ?? 'Sin marca',
      activo: json['activo'] == true,
      variantes: _asInt(json['variantes']),
    );
  }
}

class ProveedorStock {
  final int productoId;
  final String producto;
  final String sku;
  final String talla;
  final String color;
  final String sucursal;
  final int stockDisponible;
  final int stockReservado;
  final int stockReal;

  ProveedorStock({
    required this.productoId,
    required this.producto,
    required this.sku,
    required this.talla,
    required this.color,
    required this.sucursal,
    required this.stockDisponible,
    required this.stockReservado,
    required this.stockReal,
  });

  factory ProveedorStock.fromJson(Map<String, dynamic> json) {
    return ProveedorStock(
      productoId: _asInt(json['producto_id']),
      producto: json['producto']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      talla: json['talla']?.toString() ?? '-',
      color: json['color']?.toString() ?? '-',
      sucursal: json['sucursal']?.toString() ?? '-',
      stockDisponible: _asInt(json['stock_disponible']),
      stockReservado: _asInt(json['stock_reservado']),
      stockReal: _asInt(json['stock_real']),
    );
  }
}

class ProveedorEntrega {
  final int id;
  final String producto;
  final String sku;
  final String sucursal;
  final int cantidad;
  final String? motivo;
  final DateTime fecha;

  ProveedorEntrega({
    required this.id,
    required this.producto,
    required this.sku,
    required this.sucursal,
    required this.cantidad,
    required this.fecha,
    this.motivo,
  });

  factory ProveedorEntrega.fromJson(Map<String, dynamic> json) {
    return ProveedorEntrega(
      id: _asInt(json['id']),
      producto: json['producto']?.toString() ?? '',
      sku: json['sku']?.toString() ?? '',
      sucursal: json['sucursal']?.toString() ?? '-',
      cantidad: _asInt(json['cantidad']),
      motivo: json['motivo']?.toString(),
      fecha: DateTime.tryParse(json['fecha_movimiento']?.toString() ?? '') ?? DateTime.now(),
    );
  }
}

int _asInt(dynamic value) {
  if (value is int) return value;
  if (value is num) return value.toInt();
  return int.tryParse(value?.toString() ?? '') ?? 0;
}
