import 'catalogo_models.dart';

class CarritoItemResponse {
  final int id;
  final int productoVarianteId;
  final int productoId;
  final String producto;
  final String categoria;
  final String talla;
  final String color;
  final int? sucursalId;
  final String? sucursal;
  final String? ciudad;
  final int cantidad;
  final double precioUnitario;
  final double subtotal;
  final int stockDisponible;

  CarritoItemResponse({
    required this.id,
    required this.productoVarianteId,
    required this.productoId,
    required this.producto,
    required this.categoria,
    required this.talla,
    required this.color,
    this.sucursalId,
    this.sucursal,
    this.ciudad,
    required this.cantidad,
    required this.precioUnitario,
    required this.subtotal,
    required this.stockDisponible,
  });

  factory CarritoItemResponse.fromJson(Map<String, dynamic> json) {
    return CarritoItemResponse(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      productoVarianteId: json['producto_variante_id'] is int ? json['producto_variante_id'] : int.parse(json['producto_variante_id'].toString()),
      productoId: json['producto_id'] is int ? json['producto_id'] : int.parse(json['producto_id'].toString()),
      producto: json['producto'] ?? '',
      categoria: json['categoria'] ?? '',
      talla: json['talla'] ?? '',
      color: json['color'] ?? '',
      sucursalId: json['sucursal_id'] != null ? int.tryParse(json['sucursal_id'].toString()) : null,
      sucursal: json['sucursal'],
      ciudad: json['ciudad'],
      cantidad: json['cantidad'] is int ? json['cantidad'] : int.parse(json['cantidad'].toString()),
      precioUnitario: double.tryParse(json['precio_unitario']?.toString() ?? '0') ?? 0.0,
      subtotal: double.tryParse(json['subtotal']?.toString() ?? '0') ?? 0.0,
      stockDisponible: json['stock_disponible'] is int ? json['stock_disponible'] : int.tryParse(json['stock_disponible']?.toString() ?? '0') ?? 0,
    );
  }
}

class CarritoResponse {
  final int id;
  final List<CarritoItemResponse> items;
  final double total;
  final List<CatalogoSucursal> sucursalesDisponibles;

  CarritoResponse({
    required this.id,
    required this.items,
    required this.total,
    required this.sucursalesDisponibles,
  });

  int get totalItems => items.fold(0, (acc, item) => acc + item.cantidad);

  factory CarritoResponse.fromJson(Map<String, dynamic> json) {
    return CarritoResponse(
      id: json['id'] is int ? json['id'] : int.parse(json['id'].toString()),
      items: (json['items'] as List<dynamic>?)?.map((e) => CarritoItemResponse.fromJson(e as Map<String, dynamic>)).toList() ?? [],
      total: double.tryParse(json['total']?.toString() ?? '0') ?? 0.0,
      sucursalesDisponibles: (json['sucursales_disponibles'] as List<dynamic>?)
              ?.map((e) => CatalogoSucursal.fromJson(e as Map<String, dynamic>))
              .toList() ??
          [],
    );
  }
}
