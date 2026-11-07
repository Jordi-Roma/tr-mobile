import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';

class NotificacionPropia {
  final int id;
  final String titulo, mensaje, categoria, creadoEn;
  final String? recursoTipo;
  final int? recursoId;
  final bool leida;
  final int? ordenId;
  NotificacionPropia(Map<String, dynamic> json)
    : id = (json['id'] as num).toInt(),
      titulo = json['titulo']?.toString() ?? '',
      mensaje = json['mensaje']?.toString() ?? '',
      categoria = json['categoria'] as String? ?? 'GENERAL',
      creadoEn = json['creado_en']?.toString() ?? '',
      recursoTipo = json['recurso_tipo'] as String?,
      recursoId = (json['recurso_id'] as num?)?.toInt(),
      leida = json['leida'] == true,
      ordenId = (json['orden_id'] as num?)?.toInt();
}

const categoriasNotificacion = [
  'GENERAL',
  'COMPRA',
  'PAGO',
  'RESERVA',
  'ENTREGA',
  'CAMBIO',
  'DEVOLUCION',
  'REEMBOLSO',
];

class BandejaNotificaciones {
  final List<NotificacionPropia> avisos;
  final int total, noLeidas, pagina, tamano;
  BandejaNotificaciones(Map<String, dynamic> j)
    : avisos = (j['avisos'] as List)
          .map((e) => NotificacionPropia(Map<String, dynamic>.from(e as Map)))
          .toList(),
      total = (j['total'] as num).toInt(),
      noLeidas = (j['no_leidas'] as num).toInt(),
      pagina = (j['pagina'] as num).toInt(),
      tamano = (j['tamano'] as num).toInt();
}

class DestinoNotificacion {
  final bool disponible;
  final String accion;
  final String? tipo;
  final int? id;
  DestinoNotificacion(Map<String, dynamic> j)
    : disponible = j['disponible'] == true,
      accion = j['accion'] as String? ?? 'ABRIR_BANDEJA',
      tipo = j['recurso_tipo'] as String?,
      id = (j['recurso_id'] as num?)?.toInt();
  bool get valido =>
      disponible &&
      accion == 'VER_DETALLE' &&
      id != null &&
      id! > 0 &&
      [
        'RESERVA',
        'VENTA',
        'ORDEN_PAGO',
        'DELIVERY',
        'CAMBIO',
        'DEVOLUCION',
      ].contains(tipo);
}

class NotificacionesService {
  static Future<BandejaNotificaciones> bandeja({
    int pagina = 1,
    bool? leida,
    String? categoria,
  }) async {
    final q = Uri(
      queryParameters: {
        'pagina': '$pagina',
        'tamano': '20',
        if (leida != null) 'leida': '$leida',
        'categoria': ?categoria,
      },
    ).query;
    return BandejaNotificaciones(
      await ApiClient.get('${ApiConstants.baseUrl}/notificaciones/bandeja?$q')
          as Map<String, dynamic>,
    );
  }

  static Future<Map<String, dynamic>> resumen() async =>
      await ApiClient.get('${ApiConstants.baseUrl}/notificaciones/resumen')
          as Map<String, dynamic>;
  static Future<void> leerTodas() async {
    await ApiClient.patch(
      '${ApiConstants.baseUrl}/notificaciones/leer-todas',
      body: {},
    );
  }

  static Future<Map<String, bool>> preferencias() async =>
      Map<String, bool>.from(
        (await ApiClient.get(
              '${ApiConstants.baseUrl}/notificaciones/preferencias',
            ) as Map)['categorias']
            as Map,
      );
  static Future<Map<String, bool>> guardarPreferencias(
    Map<String, bool> categorias,
  ) async => Map<String, bool>.from(
    (await ApiClient.put(
          '${ApiConstants.baseUrl}/notificaciones/preferencias',
          body: {'categorias': categorias},
        ) as Map)['categorias']
        as Map,
  );
  static Future<DestinoNotificacion> destino(int id) async =>
      DestinoNotificacion(
        await ApiClient.get(
          '${ApiConstants.baseUrl}/notificaciones/$id/destino',
        ) as Map<String, dynamic>,
      );
  static Future<Map<String, dynamic>> trazabilidad(int id) async =>
      await ApiClient.get('${ApiConstants.baseUrl}/notificaciones/$id/estado')
          as Map<String, dynamic>;

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
