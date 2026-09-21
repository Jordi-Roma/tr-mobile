import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/pago_models.dart';
import '../models/delivery_models.dart';

class PagoService {
  PagoService._();

  /// Crea una sesión de Stripe Checkout a partir del carrito activo del usuario.
  /// [sucursalId] opcional: la sucursal asociada a la venta.
  static Future<CheckoutStripeResponse> crearCheckoutStripe({
    int? sucursalId,
    String tipoEntrega = 'RECOJO_SUCURSAL',
    DeliveryCheckoutRequest? delivery,
  }) async {
    final body = CrearCheckoutStripeRequest(
      sucursalId: sucursalId,
      tipoEntrega: tipoEntrega,
      delivery: delivery,
    ).toJson();
    final res = await ApiClient.post(ApiConstants.pagoStripeCheckout, body: body);
    return CheckoutStripeResponse.fromJson(res as Map<String, dynamic>);
  }

  /// Obtiene el estado actual de una orden de pago.
  static Future<OrdenPagoResponse> obtenerOrden(int ordenId) async {
    final res = await ApiClient.get(ApiConstants.pagoOrden(ordenId));
    return OrdenPagoResponse.fromJson(res as Map<String, dynamic>);
  }

  /// Confirma un pago en modo prueba (aprobar o rechazar).
  static Future<OrdenPagoResponse> confirmarPagoPrueba({
    required int ordenId,
    required bool aprobar,
  }) async {
    final res = await ApiClient.post(
      ApiConstants.pagoConfirmarPrueba(ordenId),
      body: {'aprobar': aprobar},
    );
    return OrdenPagoResponse.fromJson(res as Map<String, dynamic>);
  }

  static Future<List<PagoHistorialItem>> listarMisPagos() async {
    final res = await ApiClient.get(ApiConstants.misPagos);
    return (res as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(PagoHistorialItem.fromJson)
        .toList();
  }

  static Future<PagoHistorialDetalle> obtenerMiPago(int ordenId) async {
    final res = await ApiClient.get(ApiConstants.miPagoDetalle(ordenId));
    return PagoHistorialDetalle.fromJson(res as Map<String, dynamic>);
  }

  static Future<List<PagoHistorialItem>> listarPagos() async {
    final res = await ApiClient.get(ApiConstants.pagosHistorial);
    return (res as List<dynamic>)
        .whereType<Map<String, dynamic>>()
        .map(PagoHistorialItem.fromJson)
        .toList();
  }

  static Future<PagoHistorialDetalle> obtenerPago(int ordenId) async {
    final res = await ApiClient.get(ApiConstants.pagoDetalleAdmin(ordenId));
    return PagoHistorialDetalle.fromJson(res as Map<String, dynamic>);
  }
}
