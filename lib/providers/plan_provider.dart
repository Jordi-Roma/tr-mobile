import 'dart:async';

import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../core/session/contexto_sesion.dart';
import '../models/capacidades_plan.dart';

class PlanProvider extends SessionBoundNotifier {
  CapacidadesPlan? capacidades;
  String? error;
  bool cargando = false;
  Future<void>? _pendiente;
  late final Timer _timer;
  late final StreamSubscription<int> _cambios;
  PlanProvider() {
    _cambios = ApiClient.cambiosPlan.stream.listen((gen) {
      if (gen == ContextoSesion.instance.generacion) unawaited(refrescar());
    });
    _timer = Timer.periodic(const Duration(minutes: 1), (_) => refrescar());
    unawaited(refrescar());
  }
  Future<void> refrescar() =>
      _pendiente ??= _refrescar().whenComplete(() => _pendiente = null);
  Future<void> _refrescar() async {
    final c = ContextoSesion.instance;
    if (cargando || c.usuario == null || c.usuario!.esAdminSaas) return;
    final gen = c.generacion;
    cargando = true;
    error = null;
    notifyListeners();
    try {
      final json = await ApiClient.get(
        '${ApiConstants.baseUrl}/mi-empresa/capacidades',
      );
      ApiClient.validarGeneracion(gen);
      final nuevo = CapacidadesPlan.fromJson(json as Map<String, dynamic>);
      if (nuevo.empresaId != c.empresa?.id) {
        throw StateError('Empresa incorrecta');
      }
      capacidades = nuevo;
    } catch (e) {
      if (gen == c.generacion) {
        capacidades = null;
        error = e is ApiException ? e.message : 'No se pudo consultar tu plan.';
      }
    } finally {
      if (gen == c.generacion) {
        cargando = false;
        notifyListeners();
      }
    }
  }

  @override
  void dispose() {
    _timer.cancel();
    _cambios.cancel();
    super.dispose();
  }
}
