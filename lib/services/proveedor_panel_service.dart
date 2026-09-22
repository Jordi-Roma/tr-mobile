import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/proveedor_panel_models.dart';

class ProveedorPanelService {
  ProveedorPanelService._();

  static Future<ProveedorPerfil> obtenerPerfil() async {
    final res = await ApiClient.get(ApiConstants.proveedorPanelPerfil);
    return ProveedorPerfil.fromJson(res as Map<String, dynamic>);
  }

  static Future<List<ProveedorProducto>> listarProductos() async {
    final res = await ApiClient.get(ApiConstants.proveedorPanelProductos);
    return (res as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(ProveedorProducto.fromJson)
        .toList();
  }

  static Future<List<ProveedorStock>> listarStock() async {
    final res = await ApiClient.get(ApiConstants.proveedorPanelStock);
    return (res as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(ProveedorStock.fromJson)
        .toList();
  }

  static Future<List<ProveedorEntrega>> listarEntregas() async {
    final res = await ApiClient.get(ApiConstants.proveedorPanelEntregas);
    return (res as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(ProveedorEntrega.fromJson)
        .toList();
  }
}
