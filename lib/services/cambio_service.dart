import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../core/session/clave_pago.dart';
import '../models/cambio_models.dart';
import '../models/devolucion_models.dart';

class CambioService {
  static String get _base => '${ApiConstants.baseUrl}/posventa/cambios';
  static Future<List<CambioPrenda>> listar(bool gestion) async =>
      (await ApiClient.get('$_base?gestion=$gestion') as List)
          .map((v) => CambioPrenda.fromJson(v as Map<String, dynamic>))
          .toList();
  static Future<List<VentaDevolucionElegible>> elegibles() async =>
      (await ApiClient.get('$_base/elegibles') as List)
          .map(
            (v) => VentaDevolucionElegible.fromJson(v as Map<String, dynamic>),
          )
          .toList();
  static Future<List<Map<String, dynamic>>> opciones(int id) async =>
      (await ApiClient.get('$_base/$id/opciones') as List)
          .cast<Map<String, dynamic>>();
  static Future<CambioPrenda> solicitar(
    int venta,
    int linea,
    int cantidad,
    String motivo,
  ) async {
    final body = await ClavePago.preparar({
      'venta_id': venta,
      'venta_detalle_id': linea,
      'cantidad': cantidad,
      'motivo': motivo,
    }, 'cambio-$venta-$linea');
    final r = await ApiClient.post(_base, body: body);
    await ClavePago.finalizar('cambio-$venta-$linea', 'SOLICITADO');
    return CambioPrenda.fromJson(r as Map<String, dynamic>);
  }

  static Future<CambioPrenda> accion(
    int id,
    String accion,
    Map<String, dynamic> body, {
    bool patch = false,
  }) async {
    final r = patch
        ? await ApiClient.patch('$_base/$id/$accion', body: body)
        : await ApiClient.post('$_base/$id/$accion', body: body);
    return CambioPrenda.fromJson(r as Map<String, dynamic>);
  }

  static Future<void> simular(Map<String, dynamic> pago) async {
    if (pago['simulable'] != true) {
      throw StateError('Este pago no es simulado.');
    }
    final ruta = pago['proveedor'] == 'STRIPE'
        ? 'stripe/confirmar-prueba'
        : 'qr/confirmar';
    await ApiClient.post(
      '${ApiConstants.baseUrl}/pagos/$ruta/${pago['id']}',
      body: {'aprobar': true},
    );
  }
}
