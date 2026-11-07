import 'dart:convert';

import 'package:flutter/material.dart';

import '../../core/network/api_exceptions.dart';
import '../../models/saas_models.dart';
import '../../services/saas_service.dart';
import 'saas_widgets.dart';

class PlanEditorScreen extends StatefulWidget {
  const PlanEditorScreen({super.key, required this.catalogo, this.plan});
  final CatalogoSaas catalogo;
  final PlanSaas? plan;
  @override
  State<PlanEditorScreen> createState() => _PlanEditorScreenState();
}

class _PlanEditorScreenState extends State<PlanEditorScreen>
    with PantallaSesion {
  final _form = GlobalKey<FormState>();
  final _scroll = ScrollController();
  void _mostrarError() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (vigente && _scroll.hasClients) {
        _scroll.animateTo(
          0,
          duration: const Duration(milliseconds: 200),
          curve: Curves.easeOut,
        );
      }
    });
  }

  final _codigo = TextEditingController(),
      _nombre = TextEditingController(),
      _descripcion = TextEditingController(),
      _condiciones = TextEditingController(),
      _precio = TextEditingController(),
      _moneda = TextEditingController();
  final Map<String, TextEditingController> _limites = {};
  final Map<String, bool> _funciones = {};
  bool _activo = true, _publico = false, _ocupado = false;
  String? _error;
  PreviaPlanSaas? _previa;
  Map<String, dynamic>? _confirmados;
  @override
  void initState() {
    super.initState();
    final p = widget.plan;
    _codigo.text = p?.codigo ?? '';
    _nombre.text = p?.nombre ?? '';
    _descripcion.text = p?.descripcion ?? '';
    _condiciones.text = p?.condiciones ?? '';
    _precio.text = p?.precio ?? '0';
    _moneda.text = p?.moneda ?? 'BOB';
    _activo = p?.activo ?? true;
    _publico = p?.publico ?? false;
    for (final l in widget.catalogo.limites) {
      _limites[l.clave] = TextEditingController(
        text:
            p?.limites[l.clave]?.toString() ??
            (p == null
                ? ({
                        'respaldos_manuales_semana': 5,
                        'retencion_respaldos_dias': 30,
                        'frecuencia_respaldo_dias': 1,
                      }[l.clave]?.toString() ??
                      '')
                : ''),
      );
    }
    for (final f in widget.catalogo.funciones) {
      _funciones[f.clave] = p == null ? false : (p.funciones[f.clave] ?? true);
    }
  }

  @override
  void dispose() {
    for (final c in [
      _codigo,
      _nombre,
      _descripcion,
      _condiciones,
      _precio,
      _moneda,
      ..._limites.values,
    ]) {
      c.dispose();
    }
    _scroll.dispose();
    super.dispose();
  }

  Map<String, dynamic> _datos() => {
    'codigo': _codigo.text.trim(),
    'nombre': _nombre.text.trim(),
    'descripcion': _descripcion.text.trim(),
    'condiciones': _condiciones.text.trim(),
    'precio': _precio.text.trim(),
    'moneda': _moneda.text.trim(),
    'publico': _publico,
    if (widget.plan != null) 'activo': _activo,
    'limites': {
      for (final e in _limites.entries)
        if (e.value.text.trim().isNotEmpty) e.key: int.parse(e.value.text),
    },
    'funciones': Map<String, bool>.from(_funciones),
  };
  Future<void> _guardar() async {
    if (_ocupado || !_form.currentState!.validate()) return;
    final completos = _datos();
    final error = validarPoliticaSaas(
      widget.catalogo,
      (completos['limites'] as Map).cast<String, int>(),
      _funciones,
    );
    if (error != null) {
      setState(() => _error = error);
      _mostrarError();
      return;
    }
    final datos = widget.plan == null
        ? completos
        : cambiosPlanSaas(widget.plan!, completos);
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      if (widget.plan == null) {
        await SaasService.crearPlan(datos);
        if (mounted && vigente) Navigator.pop(context, true);
      } else {
        final p = await SaasService.previsualizar(widget.plan!.id, datos);
        if (vigente) {
          setState(() {
            _previa = p;
            _confirmados =
                jsonDecode(jsonEncode(datos)) as Map<String, dynamic>;
          });
        }
      }
    } catch (e) {
      if (vigente) {
        setState(() => _error = explicar(e));
        _mostrarError();
      }
    } finally {
      if (vigente) setState(() => _ocupado = false);
    }
  }

  Future<void> _confirmar() async {
    if (_ocupado || _previa == null || _confirmados == null) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await SaasService.editarPlan(
        widget.plan!.id,
        _confirmados!,
        _previa!.token,
      );
      if (mounted && vigente) Navigator.pop(context, true);
    } catch (e) {
      if (vigente) {
        setState(() {
          _previa = null;
          _confirmados = null;
          _error =
              '${explicar(e)}${e is ApiException && e.statusCode == 409 ? ' Revisa nuevamente el impacto y confirma.' : ''}';
        });
      }
      if (vigente) _mostrarError();
    } finally {
      if (vigente) setState(() => _ocupado = false);
    }
  }

  String? _texto(String? v, int min) => v == null || v.trim().length < min
      ? 'Ingresa al menos $min caracteres.'
      : null;
  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_ocupado,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.plan == null ? 'Crear plan' : 'Editar plan'),
      ),
      body: ListView(
        controller: _scroll,
        padding: const EdgeInsets.all(20),
        children: [
          if (_ocupado) const LinearProgressIndicator(),
          if (_error != null) ErrorSaas(_error!),
          Form(
            key: _form,
            child: AbsorbPointer(
              absorbing: _ocupado || _previa != null,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  TextFormField(
                    enabled: !_ocupado && _previa == null,
                    controller: _codigo,
                    readOnly: widget.plan?.codigo == 'STYLEAR_LEGADO',
                    decoration: const InputDecoration(labelText: 'Código'),
                    maxLength: 50,
                    validator: (v) =>
                        RegExp(r'^[A-Z0-9_]{2,50}$').hasMatch(v ?? '')
                        ? null
                        : 'Usa 2 a 50 mayúsculas, números o guion bajo.',
                  ),
                  TextFormField(
                    enabled: !_ocupado && _previa == null,
                    controller: _nombre,
                    decoration: const InputDecoration(labelText: 'Nombre'),
                    maxLength: 120,
                    validator: (v) => _texto(v, 2),
                  ),
                  TextFormField(
                    enabled: !_ocupado && _previa == null,
                    controller: _descripcion,
                    decoration: const InputDecoration(labelText: 'Descripción'),
                    maxLength: 4000,
                    maxLines: 3,
                  ),
                  TextFormField(
                    enabled: !_ocupado && _previa == null,
                    controller: _precio,
                    decoration: const InputDecoration(
                      labelText: 'Precio de referencia',
                    ),
                    keyboardType: const TextInputType.numberWithOptions(
                      decimal: true,
                    ),
                    validator: (v) =>
                        RegExp(r'^\d+(\.\d{1,2})?$').hasMatch(v ?? '') &&
                            (double.tryParse(v!) ?? double.infinity) <=
                                9999999999.99
                        ? null
                        : 'Precio no negativo con máximo dos decimales.',
                  ),
                  const Text(
                    'El precio de referencia no genera cobros automáticos.',
                  ),
                  TextFormField(
                    enabled: !_ocupado && _previa == null,
                    controller: _moneda,
                    decoration: const InputDecoration(labelText: 'Moneda'),
                    maxLength: 3,
                    validator: (v) => RegExp(r'^[A-Z]{3}$').hasMatch(v ?? '')
                        ? null
                        : 'Usa tres letras mayúsculas, por ejemplo BOB.',
                  ),
                  TextFormField(
                    enabled: !_ocupado && _previa == null,
                    controller: _condiciones,
                    decoration: const InputDecoration(labelText: 'Condiciones'),
                    maxLength: 10000,
                    maxLines: 3,
                  ),
                  if (widget.plan != null)
                    SwitchListTile(
                      title: const Text('Plan activo'),
                      value: _activo,
                      onChanged: _ocupado || _previa != null
                          ? null
                          : (v) => setState(() => _activo = v),
                    ),
                  SwitchListTile(
                    title: const Text('Disponible en registro público'),
                    value: _publico,
                    onChanged: _ocupado || _previa != null
                        ? null
                        : (v) => setState(() => _publico = v),
                  ),
                  const Text(
                    'Cupos y políticas',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Un empleado con cuenta consume también un usuario. Cero impide nuevas altas cuando está permitido. Dejar vacío no elimina un límite existente.',
                  ),
                  ...widget.catalogo.limites.map(
                    (l) => Padding(
                      padding: const EdgeInsets.only(top: 12),
                      child: TextFormField(
                        enabled: !_ocupado && _previa == null,
                        controller: _limites[l.clave],
                        decoration: InputDecoration(
                          labelText: l.nombre,
                          helperText: l.unidad,
                        ),
                        keyboardType: TextInputType.number,
                        validator: (v) {
                          if (v == null || v.isEmpty) {
                            return widget.plan?.limites.containsKey(l.clave) ==
                                    true
                                ? 'Conserva un límite numérico existente.'
                                : null;
                          }
                          final n = int.tryParse(v);
                          final maximo =
                              [
                                'retencion_respaldos_dias',
                                'frecuencia_respaldo_dias',
                              ].contains(l.clave)
                              ? 3650
                              : 2147483647;
                          return n != null && n >= l.minimo && n <= maximo
                              ? null
                              : 'Ingresa un entero entre ${l.minimo} y $maximo.';
                        },
                      ),
                    ),
                  ),
                  const SizedBox(height: 16),
                  const Text(
                    'Funciones editables',
                    style: TextStyle(fontWeight: FontWeight.bold),
                  ),
                  const Text(
                    'Reportes básicos, mayorista, delivery, asistente, recomendaciones y vestidor se conservan sin diferenciar planes.',
                  ),
                  ...widget.catalogo.funciones.map(
                    (f) => SwitchListTile(
                      title: Text(f.nombre),
                      subtitle: Text(f.descripcion),
                      value: _funciones[f.clave]!,
                      onChanged: _ocupado || _previa != null
                          ? null
                          : (v) => setState(() => _funciones[f.clave] = v),
                    ),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          if (_previa == null)
            FilledButton(
              onPressed: _ocupado ? null : _guardar,
              child: Text(
                widget.plan == null ? 'Crear plan' : 'Revisar impacto',
              ),
            ),
          if (_previa != null) ...[
            Text(
              'Revisar impacto antes de guardar',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text('${_previa!.total} empresas afectadas.'),
            ..._previa!.empresas.map(
              (e) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        e['nombre'] as String,
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                      if (e['operaciones_bloqueadas_por_desactivar_plan'] ==
                          true)
                        const Text(
                          'Desactivar bloqueará sus operaciones nuevas.',
                        ),
                      ...((e['excesos'] as Map<String, dynamic>).entries.map(
                        (x) => Text(
                          '${widget.catalogo.nombre(x.key)}: uso ${(x.value as Map)['uso']}, nuevo límite ${(x.value as Map)['limite']}. No se eliminan registros.',
                        ),
                      )),
                      Text(
                        'Reportes que se pausarán: ${(e['reportes_a_pausar'] as List).length}.',
                      ),
                      if (e['restablecer_horario_respaldo'] == true)
                        const Text(
                          'El respaldo volverá a las 02:00, America/La_Paz.',
                        ),
                    ],
                  ),
                ),
              ),
            ),
            const Text(
              'Mejorar el plan no reactiva automáticamente programaciones pausadas.',
            ),
            FilledButton(
              onPressed: _ocupado ? null : _confirmar,
              child: const Text('Confirmar cambios del plan'),
            ),
            OutlinedButton(
              onPressed: _ocupado
                  ? null
                  : () => setState(() {
                      _previa = null;
                      _confirmados = null;
                    }),
              child: const Text('Volver a editar'),
            ),
          ],
        ],
      ),
    ),
  );
}
