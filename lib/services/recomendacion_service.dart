import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/catalogo_models.dart';
import '../models/recomendacion_models.dart';

class RecomendacionService {
  RecomendacionService._();

  /// Obtiene prendas recomendadas personalizadas para el cliente logueado.
  static Future<List<RecomendacionPrendaItem>> obtenerParaMi({int limite = 8}) async {
    final url = '${ApiConstants.recomendacionesParaMi}?limite=$limite';
    final res = await ApiClient.get(url);
    if (res is List) {
      return res.map((e) => RecomendacionPrendaItem.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// Obtiene recomendaciones similares a partir de una prenda específica.
  static Future<List<RecomendacionPrendaItem>> obtenerPorProducto(
    int productoId, {
    int? sucursalId,
    int? tallaId,
    int limite = 6,
  }) async {
    final params = <String>['limite=$limite'];
    if (sucursalId != null) params.add('sucursal_id=$sucursalId');
    if (tallaId != null) params.add('talla_id=$tallaId');

    final query = params.join('&');
    final url = '${ApiConstants.recomendacionesProducto(productoId)}?$query';
    final res = await ApiClient.get(url, withAuth: false);
    if (res is List) {
      return res.map((e) => RecomendacionPrendaItem.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// Lista las prendas marcadas como favoritas del usuario.
  static Future<List<CatalogoPrendaItem>> listarFavoritos() async {
    final res = await ApiClient.get(ApiConstants.recomendacionesFavoritos);
    if (res is List) {
      return res.map((e) => CatalogoPrendaItem.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// Agrega una prenda a favoritos del usuario.
  static Future<List<CatalogoPrendaItem>> agregarFavorito(int productoId) async {
    final res = await ApiClient.put(
      ApiConstants.recomendacionesFavoritoDetalle(productoId),
      body: {},
    );
    if (res is List) {
      return res.map((e) => CatalogoPrendaItem.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }

  /// Elimina una prenda de favoritos del usuario.
  static Future<List<CatalogoPrendaItem>> eliminarFavorito(int productoId) async {
    final res = await ApiClient.delete(
      ApiConstants.recomendacionesFavoritoDetalle(productoId),
    );
    if (res is List) {
      return res.map((e) => CatalogoPrendaItem.fromJson(e as Map<String, dynamic>)).toList();
    }
    return [];
  }
}
