import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/saas_models.dart';
import '../models/capacidades_plan.dart';

class SaasService {
  static String get _base => '${ApiConstants.baseUrl}/saas';
  static Future<List<PlanSaas>> planes() async =>
      (await ApiClient.get('$_base/planes') as List)
          .map((p) => PlanSaas.fromJson(p as Map<String, dynamic>))
          .toList();
  static Future<CatalogoSaas> catalogo() async => CatalogoSaas.fromJson(
    await ApiClient.get('$_base/planes/catalogo') as Map<String, dynamic>,
  );
  static Future<List<Map<String, dynamic>>> resumen() async =>
      (await ApiClient.get('$_base/planes/resumen') as List)
          .cast<Map<String, dynamic>>();
  static Future<List<PlanSaas>> comparacion() async {
    final r = await ApiClient.get(
      '$_base/planes/comparacion',
    ) as Map<String, dynamic>;
    return (r['planes'] as List)
        .map((p) => PlanSaas.fromJson(p as Map<String, dynamic>))
        .toList();
  }

  static Future<void> crearPlan(Map<String, dynamic> datos) async {
    await ApiClient.post('$_base/planes', body: datos);
  }

  static Future<PreviaPlanSaas> previsualizar(
    int id,
    Map<String, dynamic> datos,
  ) async => PreviaPlanSaas.fromJson(
    await ApiClient.post('$_base/planes/$id/previsualizar', body: datos)
        as Map<String, dynamic>,
  );
  static Future<void> editarPlan(
    int id,
    Map<String, dynamic> datos,
    String token,
  ) async {
    await ApiClient.put(
      '$_base/planes/$id',
      body: {...datos, 'token_previsualizacion': token},
    );
  }

  static Future<List<Map<String, dynamic>>> historial(int id) async =>
      (await ApiClient.get('$_base/planes/$id/historial') as List)
          .cast<Map<String, dynamic>>();
  static Future<PaginaEmpresasSaas> empresas({
    int? planId,
    String estado = '',
    String buscar = '',
    int pagina = 1,
  }) async => PaginaEmpresasSaas.fromJson(
    await ApiClient.get(
      '$_base/planes/empresas',
      queryParams: {
        'pagina': '$pagina',
        'tamano': '20',
        if (planId != null) 'plan_id': '$planId',
        if (estado.isNotEmpty) 'estado': estado,
        if (buscar.isNotEmpty) 'buscar': buscar,
      },
    ) as Map<String, dynamic>,
  );
  static Future<List<EmpresaSaas>> contactos() async =>
      (await ApiClient.get('$_base/empresas') as List)
          .map((e) => EmpresaSaas.fromJson(e as Map<String, dynamic>))
          .toList();
  static Future<void> crearEmpresa(Map<String, dynamic> datos) async {
    await ApiClient.post('$_base/empresas', body: datos);
  }

  static Future<void> editarEmpresa(int id, String nombre) async {
    await ApiClient.patch('$_base/empresas/$id', body: {'nombre': nombre});
  }

  static Future<void> estadoEmpresa(int id, String estado) async {
    await ApiClient.patch(
      '$_base/empresas/$id/estado',
      body: {'estado': estado},
    );
  }

  static Future<void> suscribir(
    int id,
    int plan,
    String inicio,
    String? fin,
  ) async {
    await ApiClient.post(
      '$_base/empresas/$id/suscripcion',
      body: {'plan_id': plan, 'fecha_inicio': inicio, 'fecha_vencimiento': fin},
    );
  }

  static Future<CapacidadesPlan> capacidades(int id) async =>
      CapacidadesPlan.fromJson(
        await ApiClient.get('$_base/empresas/$id/plan') as Map<String, dynamic>,
      );
  static Future<List<Map<String, dynamic>>> suscripciones(int id) async =>
      (await ApiClient.get('$_base/empresas/$id/suscripciones') as List)
          .cast<Map<String, dynamic>>();
  static Future<List<Map<String, dynamic>>> eventos() async =>
      (await ApiClient.get('$_base/eventos') as List)
          .cast<Map<String, dynamic>>();
}
