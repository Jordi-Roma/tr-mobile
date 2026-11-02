import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/delivery_models.dart';

class DeliveryService {
  DeliveryService._();

  static Future<DeliveryCotizacion> cotizar(
    DeliveryCheckoutRequest request,
  ) async {
    final res = await ApiClient.post(
      ApiConstants.deliveryCotizar,
      body: request.toJson(),
    );
    return DeliveryCotizacion.fromJson(res as Map<String, dynamic>);
  }

  static Future<DeliveryGeocodificacion> geocodificar(String direccion) async {
    final res = await ApiClient.get(
      ApiConstants.deliveryGeocodificar,
      queryParams: {'direccion': direccion},
    );
    return DeliveryGeocodificacion.fromJson(res as Map<String, dynamic>);
  }

  static Future<List<DeliveryItem>> listarMisDeliveries() async {
    final res = await ApiClient.get(ApiConstants.misDeliveries);
    return (res as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(DeliveryItem.fromJson)
        .toList();
  }

  static Future<DeliveryDetalle> obtenerMiDelivery(int deliveryId) async {
    final res = await ApiClient.get(ApiConstants.miDeliveryDetalle(deliveryId));
    return DeliveryDetalle.fromJson(res as Map<String, dynamic>);
  }

  static Future<List<DeliveryItem>> listarDeliveries() async {
    final res = await ApiClient.get(ApiConstants.deliveries);
    return (res as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(DeliveryItem.fromJson)
        .toList();
  }

  static Future<DeliveryDetalle> obtenerDelivery(int deliveryId) async {
    final res = await ApiClient.get(ApiConstants.deliveryDetalle(deliveryId));
    return DeliveryDetalle.fromJson(res as Map<String, dynamic>);
  }

  static Future<DeliveryDetalle> incidencia(
    int id,
    int version,
    String observacion,
    bool resolver,
  ) async {
    final res = await ApiClient.post(
      '${ApiConstants.baseUrl}/delivery/$id/incidencias',
      body: {
        'version': version,
        'observacion': observacion,
        'resolver': resolver,
      },
    );
    return DeliveryDetalle.fromJson(
      (res as Map<String, dynamic>)['delivery'] as Map<String, dynamic>,
    );
  }

  static Future<DeliveryDetalle> actualizarEstado({
    required int deliveryId,
    required String estado,
    required int version,
    bool recepcionConfirmada = false,
    String? observacion,
  }) async {
    final res = await ApiClient.patch(
      ApiConstants.deliveryEstado(deliveryId),
      body: {
        'version': version,
        'recepcion_confirmada': recepcionConfirmada,
        'estado': estado,
        if (observacion != null && observacion.trim().isNotEmpty)
          'observacion': observacion.trim(),
      },
    );
    final data = res as Map<String, dynamic>;
    return DeliveryDetalle.fromJson(data['delivery'] as Map<String, dynamic>);
  }
}
