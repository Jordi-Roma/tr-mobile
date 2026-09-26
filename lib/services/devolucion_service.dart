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

  static Future<List<Devolucion>> listarPropias({String? estado}) async {
    final query = estado != null && estado.isNotEmpty ? '?estado=$estado' : '';
    final response = await ApiClient.get('${ApiConstants.misDevoluciones}$query');
    return (response as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(Devolucion.fromJson)
        .toList();
  }

  static Future<List<Devolucion>> listarGestion({
    String? estado,
    int? ventaId,
    String? cliente,
  }) async {
    final params = <String>[];
    if (estado != null && estado.isNotEmpty) params.add('estado=$estado');
    if (ventaId != null) params.add('venta_id=$ventaId');
    if (cliente != null && cliente.isNotEmpty) params.add('cliente=$cliente');
    final query = params.isNotEmpty ? '?${params.join('&')}' : '';
    final response = await ApiClient.get('${ApiConstants.devoluciones}$query');
    return (response as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(Devolucion.fromJson)
        .toList();
  }

  static Future<Devolucion> obtenerDetalle(int id) async {
    final response = await ApiClient.get(ApiConstants.devolucionDetalle(id));
    return Devolucion.fromJson(response as Map<String, dynamic>);
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

  static Future<Devolucion> revisar({
    required int id,
    required bool aprobar,
    String? observacion,
  }) async {
    final response = await ApiClient.patch(
      ApiConstants.revisarDevolucion(id),
      body: {
        'aprobar': aprobar,
        if (observacion != null && observacion.trim().isNotEmpty) 'observacion': observacion.trim(),
      },
    );
    return Devolucion.fromJson(response as Map<String, dynamic>);
  }

  static Future<Devolucion> recepcionar({
    required int id,
    required List<Map<String, dynamic>> items,
  }) async {
    final response = await ApiClient.patch(
      ApiConstants.recepcionarDevolucion(id),
      body: {
        'items': items,
      },
    );
    return Devolucion.fromJson(response as Map<String, dynamic>);
  }

  static Future<Devolucion> reembolsarStripe(int id) async {
    final response = await ApiClient.post(
      ApiConstants.reembolsoStripeDevolucion(id),
      body: {},
    );
    return Devolucion.fromJson(response as Map<String, dynamic>);
  }

  static Future<Devolucion> reembolsarManual({
    required int id,
    required String metodo,
    required String referencia,
    String? observacion,
  }) async {
    final response = await ApiClient.post(
      ApiConstants.reembolsoManualDevolucion(id),
      body: {
        'metodo': metodo,
        'referencia': referencia.trim(),
        if (observacion != null && observacion.trim().isNotEmpty) 'observacion': observacion.trim(),
      },
    );
    return Devolucion.fromJson(response as Map<String, dynamic>);
  }
}
