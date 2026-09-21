import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/asistente_models.dart';

class AsistenteService {
  AsistenteService._();

  /// Envía un mensaje al asistente virtual IA y devuelve su respuesta.
  /// [usuario] es opcional — si está autenticado se incluye el token automáticamente.
  static Future<AsistenteChatResponse> chat({
    required String mensaje,
    AsistenteContexto? contexto,
    bool estaAutenticado = false,
  }) async {
    final body = AsistenteChatRequest(
      mensaje: mensaje,
      contexto: contexto,
    ).toJson();

    final res = await ApiClient.post(
      ApiConstants.asistenteChat,
      body: body,
      // El endpoint acepta token opcional; si no hay sesión el bearer es ignorado
      withAuth: estaAutenticado,
    );
    return AsistenteChatResponse.fromJson(res as Map<String, dynamic>);
  }
}
