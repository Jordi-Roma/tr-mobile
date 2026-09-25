import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/devolucion_models.dart';

class DevolucionService {
  DevolucionService._();

  static Future<List<VentaDevolucionElegible>> listarVentasElegibles() async {
    final response = await ApiClient.get(ApiConstants.devolucionesVentasElegibles);
    return (response as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(VentaDevolucionElegible.fromJson)
        .toList();
  }

  static Future<List<Devolucion>> listarPropias() async {
    final response = await ApiClient.get(ApiConstants.misDevoluciones);
    return (response as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(Devolucion.fromJson)
        .toList();
  }

  static Future<Devolucion> solicitar({
    required int ventaId,
    required String motivo,
    required String observacion,
    required List<Map<String, int>> items,
  }) async {
    final response = await ApiClient.post(
      ApiConstants.solicitarDevolucion(ventaId),
      body: {
        'motivo': motivo,
        if (observacion.trim().isNotEmpty) 'observacion': observacion.trim(),
        'items': items,
      },
    );
    return Devolucion.fromJson(response as Map<String, dynamic>);
  }

  static Future<Devolucion> cancelar(int id) async {
    final response = await ApiClient.patch(ApiConstants.cancelarMiDevolucion(id), body: {});
    return Devolucion.fromJson(response as Map<String, dynamic>);
  }
}
