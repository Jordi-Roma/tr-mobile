import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';

class NotificacionPropia {
  final int id;
  final String titulo, mensaje;
  final bool leida;
  final int? ordenId;
  NotificacionPropia(Map<String, dynamic> json)
    : id = (json['id'] as num).toInt(),
      titulo = json['titulo']?.toString() ?? '',
      mensaje = json['mensaje']?.toString() ?? '',
      leida = json['leida'] == true,
      ordenId = (json['orden_id'] as num?)?.toInt();
}

class NotificacionesService {
  static Future<List<NotificacionPropia>> listar() async {
    final data = await ApiClient.get('${ApiConstants.baseUrl}/notificaciones');
    return (data as List)
        .map((n) => NotificacionPropia(n as Map<String, dynamic>))
        .toList();
  }

  static Future<void> leer(int id) async {
    await ApiClient.patch(
      '${ApiConstants.baseUrl}/notificaciones/$id/leer',
      body: {},
    );
  }

  static Future<List<Map<String, dynamic>>> reembolsos() async {
    final data = await ApiClient.get(
      '${ApiConstants.baseUrl}/pagos-empresa/reembolsos',
    );
    return (data as List).cast<Map<String, dynamic>>();
  }
}
