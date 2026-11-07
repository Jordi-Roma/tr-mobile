import '../../core/session/contexto_sesion.dart';

import 'package:flutter/material.dart';

import '../../models/catalogo_models.dart';
import '../../models/recomendacion_models.dart';
import '../../services/recomendacion_service.dart';
import '../saas/saas_widgets.dart';

class PreferenciasRecomendacionesSheet extends StatefulWidget {
  const PreferenciasRecomendacionesSheet({super.key, required this.categorias});
  final List<CatalogoCategoria> categorias;
  @override
  State<PreferenciasRecomendacionesSheet> createState() => _PreferenciasState();
}

class _PreferenciasState extends State<PreferenciasRecomendacionesSheet>
    with PantallaSesion {
  PreferenciasIA? _preferencias;
  bool _cargando = false, _guardando = false;
  String? _error;
  @override
  void initState() {
    super.initState();
    ContextoSesion.instance.addListener(_cambio);
    _cargar();
  }

  void _cambio() {
    if (!vigente && mounted) {
      setState(() {
        _preferencias = null;
        _error = 'Cambió la sesión. Cierra esta vista.';
      });
    }
  }

  @override
  void dispose() {
    ContextoSesion.instance.removeListener(_cambio);
    super.dispose();
  }

  Future<void> _cargar() async {
    if (_cargando) return;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final p = await RecomendacionService.leerPreferencias();
      if (vigente) setState(() => _preferencias = p);
    } catch (e) {
      if (vigente) setState(() => _error = explicar(e));
    } finally {
      if (vigente) setState(() => _cargando = false);
    }
  }

  Future<void> _guardar() async {
    if (_guardando || _preferencias == null) return;
    setState(() {
      _guardando = true;
      _error = null;
    });
    try {
      await RecomendacionService.guardarPreferencias(_preferencias!);
      if (mounted && vigente) Navigator.pop(context, true);
    } catch (e) {
      if (vigente) setState(() => _error = explicar(e));
    } finally {
      if (vigente) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_guardando,
    child: SafeArea(
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          20,
          16,
          20,
          20 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Preferencias de recomendaciones',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              const Text(
                'La personalización usa tus favoritos, compras y categorías. Desactivarla conserva tus favoritos y deja vacía la lista Para ti.',
              ),
              if (_error != null)
                Text(_error!, semanticsLabel: 'Error: $_error'),
              if (_cargando) const LinearProgressIndicator(),
              if (!_cargando && _preferencias == null)
                TextButton(
                  onPressed: _cargar,
                  child: const Text('Reintentar preferencias'),
                ),
              if (_preferencias case final p?) ...[
                SwitchListTile(
                  title: const Text('Usar personalización'),
                  value: p.usarHistorial,
                  onChanged: _guardando
                      ? null
                      : (v) => setState(
                          () => _preferencias = PreferenciasIA(
                            categorias: p.categorias,
                            usarHistorial: v,
                          ),
                        ),
                ),
                const Text('Categorías (máximo 10)'),
                Wrap(
                  spacing: 8,
                  children: widget.categorias
                      .map(
                        (c) => FilterChip(
                          label: Text(c.nombre),
                          selected: p.categorias.contains(c.id),
                          onSelected: _guardando
                              ? null
                              : (v) {
                                  if (v && p.categorias.length >= 10) {
                                    setState(
                                      () => _error = 'Selecciona como máximo 10 categorías.',
                                    );
                                    return;
                                  }
                                  setState(
                                    () => _preferencias = PreferenciasIA(
                                      usarHistorial: p.usarHistorial,
                                      categorias: v
                                          ? [...p.categorias, c.id]
                                          : p.categorias
                                                .where((id) => id != c.id)
                                                .toList(),
                                    ),
                                  );
                                },
                        ),
                      )
                      .toList(),
                ),
                FilledButton(
                  onPressed: _guardando ? null : _guardar,
                  child: Text(
                    _guardando ? 'Guardando…' : 'Guardar preferencias',
                  ),
                ),
              ],
              TextButton(
                onPressed: _guardando ? null : () => Navigator.pop(context),
                child: const Text('Cerrar'),
              ),
            ],
          ),
        ),
      ),
    ),
  );
}
