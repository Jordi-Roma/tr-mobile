import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/session/contexto_sesion.dart';
import '../../services/firebase_push_service.dart';
import '../../services/notificaciones_service.dart';
import '../auth/login_screen.dart';
import 'destinos_notificaciones.dart';
import 'notificaciones_screen.dart';

/// A new navigator is created for each session by the parent's generation key.
class PuentePush extends StatefulWidget {
  const PuentePush({super.key, required this.builder});
  final Widget Function(GlobalKey<NavigatorState>) builder;
  @override
  State<PuentePush> createState() => _PuenteState();
}

class _PuenteState extends State<PuentePush> {
  final _navegador = GlobalKey<NavigatorState>();
  bool _resolviendo = false, _login = false;
  final _generacion = ContextoSesion.instance.generacion;
  @override
  void initState() {
    super.initState();
    FirebasePush.pendiente.addListener(_programar);
    _programar();
  }

  @override
  void dispose() {
    FirebasePush.pendiente.removeListener(_programar);
    super.dispose();
  }

  void _programar() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _abrir();
    });
  }

  bool get _vigente =>
      mounted && _generacion == ContextoSesion.instance.generacion;
  Future<void> _abrir() async {
    final r = FirebasePush.pendiente.value, c = ContextoSesion.instance;
    if (r == null ||
        !_vigente ||
        _resolviendo ||
        _navegador.currentState == null) {
      return;
    }
    if (c.empresa == null) {
      return; // Only the minimal reference waits for store/login.
    }
    if (c.empresa!.id != r.empresaId || c.modoPlataforma) {
      FirebasePush.pendiente.value = null;
      return;
    }
    if (c.usuario == null) {
      if (!_login) {
        _login = true;
        await _navegador.currentState!.push(
          MaterialPageRoute(builder: (_) => const LoginScreen()),
        );
        _login = false;
      }
      return;
    }
    _resolviendo = true;
    try {
      final d = await NotificacionesService.destino(r.notificacionId);
      if (!_vigente || FirebasePush.pendiente.value != r) return;
      await NotificacionesService.leer(r.notificacionId);
      if (!_vigente) return;
      final resumen = await NotificacionesService.resumen();
      if (!_vigente) return;
      FirebasePush.noLeidas.value = (resumen['no_leidas'] as num).toInt();
      FirebasePush.pendiente.value = null;
      final pantalla =
          pantallaNotificacion(d) ??
          NotificacionesScreen(
            avisoInicial: d.tipo == 'VENTA'
                ? 'Esta actualización corresponde a una compra. Puedes consultarla en la bandeja.'
                : 'El recurso no está disponible. La actualización se conserva en la bandeja.',
          );
      unawaited(
        _navegador.currentState!.push(
          MaterialPageRoute(builder: (_) => pantalla),
        ),
      );
    } catch (_) {
      if (!_vigente) return;
      FirebasePush.pendiente.value = null;
      unawaited(
        _navegador.currentState!.push(
          MaterialPageRoute(
            builder: (_) => const NotificacionesScreen(
              avisoInicial: 'No se pudo abrir el recurso. Actualiza la bandeja para consultar tu cuenta.',
            ),
          ),
        ),
      );
    } finally {
      if (_vigente) {
        _resolviendo = false;
        if (FirebasePush.pendiente.value != null) _programar();
      }
    }
  }

  @override
  Widget build(BuildContext context) => widget.builder(_navegador);
}
