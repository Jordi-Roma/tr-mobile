import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/admin_catalogo_models.dart';

class AdminCatalogoService {
  AdminCatalogoService._();

  // ── PRODUCTOS ─────────────────────────────────────────

  static Future<List<AdminProductoItem>> listarProductos() async {
    final res = await ApiClient.get(ApiConstants.adminProductos);
    if (res is List) {
      return res.map((e) => AdminProductoItem.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  static Future<AdminProductoItem> obtenerProducto(int id) async {
    final res = await ApiClient.get(ApiConstants.adminProductoDetalle(id));
    return AdminProductoItem.fromJson(res as Map<String, dynamic>);
  }

  static Future<AdminProductoItem> crearProducto({
    required int categoriaId,
    int? marcaId,
    required String nombre,
    String? descripcion,
    String? material,
    String? genero,
    String tipoPrenda = 'SUPERIOR',
    String tipoCorte = 'REGULAR_FIT',
    double? anchoBaseCm,
    double? largoBaseCm,
    List<int> coleccionesIds = const [],
    List<int> proveedoresIds = const [],
    List<AdminProductoImagen> imagenes = const [],
  }) async {
    final body = {
      'categoria_id': categoriaId,
      'marca_id': marcaId,
      'nombre': nombre,
      'descripcion': descripcion,
      'material': material,
      'genero': genero,
      'tipo_prenda': tipoPrenda,
      'tipo_corte': tipoCorte,
      'ancho_base_cm': anchoBaseCm,
      'largo_base_cm': largoBaseCm,
      'colecciones_ids': coleccionesIds,
      'proveedores_ids': proveedoresIds,
      'imagenes': imagenes.map((img) => img.toJson()).toList(),
    };
    final res = await ApiClient.post(ApiConstants.adminProductos, body: body);
    return AdminProductoItem.fromJson(res as Map<String, dynamic>);
  }

  static Future<AdminProductoItem> actualizarProducto({
    required int id,
    required int categoriaId,
    int? marcaId,
    required String nombre,
    String? descripcion,
    String? material,
    String? genero,
    String tipoPrenda = 'SUPERIOR',
    String tipoCorte = 'REGULAR_FIT',
    double? anchoBaseCm,
    double? largoBaseCm,
    List<int> coleccionesIds = const [],
    List<int> proveedoresIds = const [],
    List<AdminProductoImagen> imagenes = const [],
  }) async {
    final body = {
      'categoria_id': categoriaId,
      'marca_id': marcaId,
      'nombre': nombre,
      'descripcion': descripcion,
      'material': material,
      'genero': genero,
      'tipo_prenda': tipoPrenda,
      'tipo_corte': tipoCorte,
      'ancho_base_cm': anchoBaseCm,
      'largo_base_cm': largoBaseCm,
      'colecciones_ids': coleccionesIds,
      'proveedores_ids': proveedoresIds,
      'imagenes': imagenes.map((img) => img.toJson()).toList(),
    };
    final res = await ApiClient.put(ApiConstants.adminProductoDetalle(id), body: body);
    return AdminProductoItem.fromJson(res as Map<String, dynamic>);
  }

  static Future<void> toggleEstadoProducto(int id, bool actualmenteActivo) async {
    final url = actualmenteActivo
        ? ApiConstants.adminProductoDesactivar(id)
        : ApiConstants.adminProductoActivar(id);
    await ApiClient.patch(url);
  }

  // ── CATEGORÍAS ─────────────────────────────────────────

  static Future<List<AdminCategoria>> listarCategorias() async {
    final res = await ApiClient.get(ApiConstants.adminCategorias);
    if (res is List) {
      return res.map((e) => AdminCategoria.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  static Future<AdminCategoria> crearCategoria({
    required String nombre,
    String? descripcion,
    int? categoriaPadreId,
  }) async {
    final body = {
      'nombre': nombre,
      'descripcion': descripcion,
      'categoria_padre_id': categoriaPadreId,
    };
    final res = await ApiClient.post(ApiConstants.adminCategorias, body: body);
    return AdminCategoria.fromJson(res as Map<String, dynamic>);
  }

  static Future<AdminCategoria> actualizarCategoria({
    required int id,
    required String nombre,
    String? descripcion,
    int? categoriaPadreId,
  }) async {
    final body = {
      'nombre': nombre,
      'descripcion': descripcion,
      'categoria_padre_id': categoriaPadreId,
    };
    final res = await ApiClient.put(ApiConstants.adminCategoriaDetalle(id), body: body);
    return AdminCategoria.fromJson(res as Map<String, dynamic>);
  }

  static Future<void> toggleEstadoCategoria(int id, bool actualmenteActivo) async {
    final url = actualmenteActivo
        ? ApiConstants.adminCategoriaDesactivar(id)
        : ApiConstants.adminCategoriaActivar(id);
    await ApiClient.patch(url);
  }

  // ── TALLAS ─────────────────────────────────────────────

  static Future<List<AdminTalla>> listarTallas({String? tipoPrenda}) async {
    final queryParams = <String, String>{};
    if (tipoPrenda != null && tipoPrenda.isNotEmpty) {
      queryParams['tipo_prenda'] = tipoPrenda;
    }
    final res = await ApiClient.get(
      ApiConstants.adminTallas,
      queryParams: queryParams.isNotEmpty ? queryParams : null,
    );
    if (res is List) {
      return res.map((e) => AdminTalla.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  static Future<AdminTalla> crearTalla({
    required String nombre,
    String? descripcion,
    String tipoPrenda = 'SUPERIOR',
    double? anchoCm,
    double? largoCm,
  }) async {
    final body = {
      'nombre': nombre,
      'descripcion': descripcion,
      'tipo_prenda': tipoPrenda,
      'ancho_cm': anchoCm,
      'largo_cm': largoCm,
    };
    final res = await ApiClient.post(ApiConstants.adminTallas, body: body);
    return AdminTalla.fromJson(res as Map<String, dynamic>);
  }

  static Future<AdminTalla> actualizarTalla({
    required int id,
    required String nombre,
    String? descripcion,
    String tipoPrenda = 'SUPERIOR',
    double? anchoCm,
    double? largoCm,
  }) async {
    final body = {
      'nombre': nombre,
      'descripcion': descripcion,
      'tipo_prenda': tipoPrenda,
      'ancho_cm': anchoCm,
      'largo_cm': largoCm,
    };
    final res = await ApiClient.put(ApiConstants.adminTallaDetalle(id), body: body);
    return AdminTalla.fromJson(res as Map<String, dynamic>);
  }

  static Future<void> toggleEstadoTalla(int id, bool actualmenteActivo) async {
    final url = actualmenteActivo
        ? ApiConstants.adminTallaDesactivar(id)
        : ApiConstants.adminTallaActivar(id);
    await ApiClient.patch(url);
  }

  // ── COLORES ────────────────────────────────────────────

  static Future<List<AdminColor>> listarColores() async {
    final res = await ApiClient.get(ApiConstants.adminColores);
    if (res is List) {
      return res.map((e) => AdminColor.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  static Future<AdminColor> crearColor({
    required String nombre,
    String? codigoHex,
  }) async {
    final body = {
      'nombre': nombre,
      'codigo_hex': codigoHex,
    };
    final res = await ApiClient.post(ApiConstants.adminColores, body: body);
    return AdminColor.fromJson(res as Map<String, dynamic>);
  }

  static Future<AdminColor> actualizarColor({
    required int id,
    required String nombre,
    String? codigoHex,
  }) async {
    final body = {
      'nombre': nombre,
      'codigo_hex': codigoHex,
    };
    final res = await ApiClient.put(ApiConstants.adminColorDetalle(id), body: body);
    return AdminColor.fromJson(res as Map<String, dynamic>);
  }

  static Future<void> toggleEstadoColor(int id, bool actualmenteActivo) async {
    final url = actualmenteActivo
        ? ApiConstants.adminColorDesactivar(id)
        : ApiConstants.adminColorActivar(id);
    await ApiClient.patch(url);
  }

  // ── MARCAS ─────────────────────────────────────────────

  static Future<List<AdminMarca>> listarMarcas() async {
    final res = await ApiClient.get(ApiConstants.adminMarcas);
    if (res is List) {
      return res.map((e) => AdminMarca.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  // ── VARIANTES ──────────────────────────────────────────

  static Future<List<AdminVarianteItem>> listarVariantes({int? productoId}) async {
    final queryParams = <String, String>{};
    if (productoId != null) {
      queryParams['producto_id'] = productoId.toString();
    }
    final res = await ApiClient.get(ApiConstants.adminVariantes, queryParams: queryParams);
    if (res is List) {
      return res.map((e) => AdminVarianteItem.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  static Future<AdminVarianteItem> obtenerVariante(int id) async {
    final res = await ApiClient.get(ApiConstants.adminVarianteDetalle(id));
    return AdminVarianteItem.fromJson(res as Map<String, dynamic>);
  }

  static Future<AdminVarianteItem> crearVariante({
    required int productoId,
    int? tallaId,
    int? colorId,
    required String sku,
    double? anchoCm,
    double? largoCm,
  }) async {
    final body = {
      'producto_id': productoId,
      'talla_id': tallaId,
      'color_id': colorId,
      'sku': sku,
      'ancho_cm': anchoCm,
      'largo_cm': largoCm,
    };
    final res = await ApiClient.post(ApiConstants.adminVariantes, body: body);
    return AdminVarianteItem.fromJson(res as Map<String, dynamic>);
  }

  static Future<AdminVarianteItem> actualizarVariante({
    required int id,
    int? tallaId,
    int? colorId,
    required String sku,
    double? anchoCm,
    double? largoCm,
  }) async {
    final body = {
      'talla_id': tallaId,
      'color_id': colorId,
      'sku': sku,
      'ancho_cm': anchoCm,
      'largo_cm': largoCm,
    };
    final res = await ApiClient.put(ApiConstants.adminVarianteDetalle(id), body: body);
    return AdminVarianteItem.fromJson(res as Map<String, dynamic>);
  }

  static Future<void> toggleEstadoVariante(int id, bool actualmenteActivo) async {
    final url = actualmenteActivo
        ? ApiConstants.adminVarianteDesactivar(id)
        : ApiConstants.adminVarianteActivar(id);
    await ApiClient.patch(url);
  }

  static Future<AdminVarianteItem> asignarPrecio({
    required int varianteId,
    required double monto,
    String? fechaInicio,
    String? fechaFin,
  }) async {
    final body = {
      'monto': monto,
      'fecha_inicio': fechaInicio,
      'fecha_fin': fechaFin,
    };
    final res = await ApiClient.post(ApiConstants.adminVariantePrecios(varianteId), body: body);
    return AdminVarianteItem.fromJson(res as Map<String, dynamic>);
  }
}
