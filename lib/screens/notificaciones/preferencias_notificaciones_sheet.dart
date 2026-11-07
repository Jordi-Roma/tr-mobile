import 'package:flutter/material.dart';

import '../../services/notificaciones_service.dart';
import '../../core/session/contexto_sesion.dart';
import '../saas/saas_widgets.dart';

class PreferenciasNotificacionesSheet extends StatefulWidget {
  const PreferenciasNotificacionesSheet({super.key});
  @override
  State<PreferenciasNotificacionesSheet> createState() => _PreferenciasState();
}

class _PreferenciasState extends State<PreferenciasNotificacionesSheet>
    with PantallaSesion {
  Map<String, bool>? _datos;
  Map<String, bool> _original = {};
  bool _ocupado = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    ContextoSesion.instance.addListener(_sesion);
    _cargar();
  }

  @override
  void dispose() {
    ContextoSesion.instance.removeListener(_sesion);
    super.dispose();
  }

  void _sesion() {
    if (!vigente && mounted) {
      setState(() {
        _datos = null;
        _ocupado = false;
        _error = 'Cambió la sesión. Cierra esta vista.';
      });
    }
  }

  Future<void> _cargar() async {
    if (_ocupado || !vigente) return;
    setState(() => _ocupado = true);
    try {
      final r = await NotificacionesService.preferencias();
      if (vigente) {
        setState(() {
          _datos = {...r};
          _original = {...r};
          _error = null;
        });
      }
    } catch (e) {
      if (vigente) setState(() => _error = explicar(e));
    } finally {
      if (vigente) setState(() => _ocupado = false);
    }
  }

  Future<void> _guardar() async {
    if (_ocupado || _datos == null || !vigente) return;
    setState(() => _ocupado = true);
    try {
      await NotificacionesService.guardarPreferencias({
        for (final e in _datos!.entries)
          if (e.value != _original[e.key]) e.key: e.value,
      });
      if (mounted && vigente) Navigator.pop(context, true);
    } catch (e) {
      if (vigente) setState(() => _error = explicar(e));
    } finally {
      if (vigente) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_ocupado,
    child: SafeArea(
      child: SingleChildScrollView(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Preferencias de avisos push',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const Text(
              'Silenciar una categoría no borra ni evita las actualizaciones de la bandeja.',
            ),
            if (_error != null) Text(_error!),
            if (_ocupado) const LinearProgressIndicator(),
            if (_datos case final datos?) ...[
              ...categoriasNotificacion.map(
                (c) => SwitchListTile(
                  title: Text(c),
                  value: datos[c] ?? true,
                  onChanged: _ocupado
                      ? null
                      : (v) => setState(() => _datos = {...datos, c: v}),
                ),
              ),
              FilledButton(
                onPressed: _ocupado ? null : _guardar,
                child: const Text('Guardar preferencias'),
              ),
            ] else if (!_ocupado && vigente)
              TextButton(
                onPressed: _cargar,
                child: const Text('Reintentar preferencias'),
              ),
            TextButton(
              onPressed: _ocupado ? null : () => Navigator.pop(context),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      ),
    ),
  );
}
