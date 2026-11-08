import 'dart:typed_data';

import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/analitica_models.dart';

class AnaliticaService {
  static String get _base => '${ApiConstants.baseUrl}/reportes/analitica';
  static Future<EstadoAnalitica> estado() async => EstadoAnalitica(
    await ApiClient.get('$_base/estado') as Map<String, dynamic>,
  );
  static Future<ResultadoAnalitica> consultar(
    String tipo,
    Map<String, String> filtros,
  ) async {
    if (!{'predicciones', 'segmentos'}.contains(tipo)) {
      throw ArgumentError('Análisis no válido.');
    }
    return ResultadoAnalitica(
      await ApiClient.get('$_base/$tipo', queryParams: filtros)
          as Map<String, dynamic>,
    );
  }

  static Future<Map<String, dynamic>> interpretar(
    String texto,
    String origen,
    String entrada,
  ) async => await ApiClient.post(
    '$_base/interpretar',
    body: {'texto': texto, 'origen': origen, 'origen_entrada': entrada},
  ) as Map<String, dynamic>;
  static Future<Uint8List> exportar(
    Map<String, dynamic> solicitud,
    String formato,
  ) {
    if (!{'pdf', 'excel'}.contains(formato)) {
      throw ArgumentError('Formato no válido.');
    }
    return ApiClient.postBytes('$_base/exportar/$formato', body: solicitud);
  }
}
