import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../models/respaldo_models.dart';

class RespaldosService {
  const RespaldosService({required this.plataforma});
  final bool plataforma;
  String get _base =>
      '${ApiConstants.baseUrl}/${plataforma ? 'saas/respaldos' : 'respaldos'}';
  Future<List<Respaldo>> listar() async => (await ApiClient.get(_base) as List)
      .map((r) => Respaldo.fromJson(r as Map<String, dynamic>))
      .toList();
  Future<void> crear({int? empresaId}) async {
    if (!plataforma && empresaId != null) {
      throw ApiException('La copia corresponde únicamente a tu empresa.');
    }
    await ApiClient.post(
      _base,
      body: plataforma ? {'empresa_id': empresaId} : <String, dynamic>{},
    );
  }

  Future<ConfiguracionRespaldos> programacion() async =>
      ConfiguracionRespaldos.fromJson(
        await ApiClient.get('$_base/programacion') as Map<String, dynamic>,
      );
  Future<void> guardarProgramacion(Map<String, dynamic> datos) async {
    await ApiClient.put('$_base/programacion', body: datos);
  }

  Future<String> estadoEmpresa() async =>
      (await ApiClient.get('${ApiConstants.baseUrl}/mi-empresa/plan')
              as Map)['empresa_estado']
          as String;
  Future<PreviaRespaldo> previsualizar(String id) async =>
      PreviaRespaldo.fromJson(
        await ApiClient.post('$_base/$id/previsualizar', body: {})
            as Map<String, dynamic>,
      );
  Future<void> restaurar(String id, String confirmacion) async {
    await ApiClient.post(
      '$_base/$id/restaurar',
      body: {'confirmacion': confirmacion},
    );
  }

  Future<void> eliminar(String id) async {
    await ApiClient.delete('$_base/$id');
  }

  Future<void> purgar() async {
    if (!plataforma) {
      throw ApiException(
        'Esta operación pertenece a la administración de plataforma.',
      );
    }
    await ApiClient.post('$_base/purgar-vencidos', body: {});
  }
}
