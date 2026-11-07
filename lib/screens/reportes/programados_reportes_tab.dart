import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/reporte_models.dart';
import '../../providers/plan_provider.dart';
import '../../core/network/api_exceptions.dart';
import '../../services/reporte_service.dart';
import '../saas/saas_widgets.dart';

Map<String, dynamic> datosProgramado(ReporteProgramadoItem p) => {
  'titulo': p.titulo,
  'tipo': p.tipo,
  'frecuencia': p.frecuencia,
  'hora': p.hora.substring(0, 5),
  'dia': p.dia,
  'formato': p.formato,
  'destinatario_email': p.destinatarioEmail,
  'sucursal_id': p.sucursalId,
  'solo_bajo_stock': p.soloBajoStock,
  'activo': p.activo,
  'zona_horaria': p.zonaHoraria,
  'periodo': p.periodo,
  'filtros': p.filtros,
};
Map<String, dynamic> cambiosProgramado(
  Map<String, dynamic> original,
  Map<String, dynamic> editado,
  Map<String, dynamic> vigente,
) {
  final r = <String, dynamic>{};
  for (final e in editado.entries) {
    if (e.key != 'filtros' && e.value != original[e.key]) r[e.key] = e.value;
  }
  final anteriores = original['filtros'] as Map<String, dynamic>,
      nuevos = editado['filtros'] as Map<String, dynamic>;
  final cambiados = <String, dynamic>{
    for (final e in nuevos.entries)
      if (e.value != anteriores[e.key]) e.key: e.value,
  };
  if (cambiados.isNotEmpty) {
    r['filtros'] = {
      ...vigente['filtros'] as Map<String, dynamic>,
      ...cambiados,
    };
  }
  return r;
}

class ProgramadosReportesTab extends StatefulWidget {
  const ProgramadosReportesTab({super.key, required this.catalogo});
  final ReporteCatalogo catalogo;
  @override
  State<ProgramadosReportesTab> createState() => _ProgramadosReportesTabState();
}

class _ProgramadosReportesTabState extends State<ProgramadosReportesTab>
    with PantallaSesion {
  List<ReporteProgramadoItem> _items = [];
  bool _ocupado = false;
  String? _error, _aviso;
  final _inciertos = <int>{};
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    try {
      final r = await ReporteService.listarProgramados();
      if (vigente) setState(() => _items = r);
    } catch (e) {
      if (vigente) setState(() => _error = explicar(e));
    }
  }

  Future<void> _operar(
    Future<void> Function() fn,
    String aviso, {
    int? envio,
  }) async {
    if (_ocupado) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await fn();
      if (!mounted || !vigente) return;
      setState(() => _aviso = aviso);
      await _cargar();
      if (!mounted || !vigente) return;
      await context.read<PlanProvider>().refrescar();
    } catch (e) {
      if (vigente) {
        setState(() {
          if (envio != null) _inciertos.add(envio);
          _error =
              '${explicar(e)}${envio == null ? '' : ' No se repetirá automáticamente. Revisa el historial antes de autorizar otra ejecución.'}';
        });
      }
    } finally {
      if (vigente) setState(() => _ocupado = false);
    }
  }

  Future<void> _editar([ReporteProgramadoItem? p]) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) =>
            EditorProgramadoScreen(catalogo: widget.catalogo, item: p),
      ),
    );
    if (vigente) await _cargar();
  }

  Future<void> _historial(ReporteProgramadoItem p) async {
    try {
      final h = await ReporteService.ejecuciones(p.id);
      if (!mounted || !vigente) return;
      final autorizar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: Text('Historial de ${p.titulo}'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'INICIADO o FALLIDO puede dejar la entrega incierta. No se reenvía automáticamente.',
                ),
                ...h.map(
                  (e) => ListTile(
                    title: Text('${e['estado']} · ${e['iniciado_en']}'),
                    subtitle: Text(e['detalle'] as String? ?? ''),
                  ),
                ),
                if (h.isEmpty) const Text('Sin ejecuciones.'),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Cerrar'),
            ),
            if (_inciertos.contains(p.id))
              TextButton(
                onPressed: () => Navigator.pop(ctx, true),
                child: const Text(
                  'Revisé el historial; permitir otra ejecución',
                ),
              ),
          ],
        ),
      );
      if (!mounted || !vigente || autorizar != true) return;
      final ok = await confirmarSaas(
        context,
        'Permitir otra ejecución',
        'La entrega anterior podría haberse realizado. ¿Permitir que solicites otra ejecución manual?',
      );
      if (vigente && ok) setState(() => _inciertos.remove(p.id));
    } catch (e) {
      if (vigente) setState(() => _error = explicar(e));
    }
  }

  @override
  Widget build(BuildContext context) {
    final plan = context.watch<PlanProvider>().capacidades;
    bool formato(ReporteProgramadoItem p) =>
        plan?.habilita(
          p.formato == 'PDF' ? 'reportes_pdf' : 'reportes_excel',
        ) ==
        true;
    return RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          const Text(
            'Reportes automáticos programados',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          const Text(
            'El envío usa el transporte configurado. El destinatario efectivo puede estar fijado en el servidor; revisa su resultado e historial.',
          ),
          if (_ocupado) const LinearProgressIndicator(),
          if (_error != null) ErrorSaas(_error!),
          if (_aviso != null) Text(_aviso!),
          FilledButton(
            onPressed:
                _ocupado ||
                    plan?.habilita('reportes_programacion') != true ||
                    plan?.cupos['reportes_programados']?.agotado == true
                ? null
                : () => _editar(),
            child: const Text('Programar nuevo reporte'),
          ),
          if (plan?.habilita('reportes_programacion') != true)
            Text(
              plan?.motivo('reportes_programacion') ?? 'Consulta tu plan. Puedes revisar el historial y pausar programaciones.',
            ),
          ..._items.map(
            (p) => Card(
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      p.titulo,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    Text(
                      '${p.activo ? 'Activa' : 'Pausada'} · ${p.frecuencia} · ${p.hora} · ${p.zonaHoraria} · ${p.periodo} · ${p.formato}',
                    ),
                    Text(p.destinatarioEmail),
                    if (p.motivoPausa != null) Text(p.motivoPausa!),
                    Text('Próxima: ${p.proximaEjecucion ?? 'Sin fecha'}'),
                    Wrap(
                      spacing: 8,
                      children: [
                        OutlinedButton(
                          onPressed:
                              _ocupado ||
                                  plan?.habilita('reportes_programacion') !=
                                      true
                              ? null
                              : () => _editar(p),
                          child: const Text('Editar'),
                        ),
                        OutlinedButton(
                          onPressed:
                              _ocupado ||
                                  (!p.activo &&
                                      (plan?.habilita(
                                                'reportes_programacion',
                                              ) !=
                                              true ||
                                          !formato(p) ||
                                          plan
                                                  ?.cupos['reportes_programados']
                                                  ?.agotado ==
                                              true))
                              ? null
                              : () => _operar(() async {
                                  await ReporteService.actualizarEstadoProgramado(
                                    p.id,
                                    !p.activo,
                                  );
                                }, 'Estado actualizado.'),
                          child: Text(p.activo ? 'Pausar' : 'Activar'),
                        ),
                        FilledButton(
                          onPressed:
                              _ocupado ||
                                  _inciertos.contains(p.id) ||
                                  !p.activo ||
                                  plan?.habilita('reportes_programacion') !=
                                      true ||
                                  !formato(p)
                              ? null
                              : () async {
                                  final ok = await confirmarSaas(
                                    context,
                                    'Ejecutar reporte',
                                    '¿Solicitar un envío manual? Revisa el historial para evitar duplicaciones.',
                                  );
                                  if (vigente && ok) {
                                    await _operar(
                                      () async {
                                        final r =
                                            await ReporteService.ejecutarProgramado(
                                              p.id,
                                            );
                                        if (vigente) {
                                          setState(
                                            () => _aviso =
                                                r['mensaje'] as String? ?? 'Consulta el historial para verificar el resultado.',
                                          );
                                        }
                                      },
                                      'Consulta el historial para verificar el resultado.',
                                      envio: p.id,
                                    );
                                  }
                                },
                          child: const Text('Ejecutar ahora'),
                        ),
                        TextButton(
                          onPressed: _ocupado ? null : () => _historial(p),
                          child: const Text('Historial'),
                        ),
                        TextButton(
                          onPressed: _ocupado
                              ? null
                              : () async {
                                  final ok = await confirmarSaas(
                                    context,
                                    'Eliminar programación',
                                    '¿Eliminar esta programación y su historial?',
                                  );
                                  if (vigente && ok) {
                                    await _operar(() async {
                                      await ReporteService.eliminarProgramado(
                                        p.id,
                                      );
                                    }, 'Programación eliminada.');
                                  }
                                },
                          child: const Text('Eliminar'),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ),
          if (_items.isEmpty) const Text('No hay programaciones.'),
        ],
      ),
    );
  }
}

class EditorProgramadoScreen extends StatefulWidget {
  const EditorProgramadoScreen({super.key, required this.catalogo, this.item});
  final ReporteCatalogo catalogo;
  final ReporteProgramadoItem? item;
  @override
  State<EditorProgramadoScreen> createState() => _EditorProgramadoScreenState();
}

class _EditorProgramadoScreenState extends State<EditorProgramadoScreen>
    with PantallaSesion {
  final _form = GlobalKey<FormState>();
  final _c = <String, TextEditingController>{};
  late Map<String, dynamic> _base;
  int _revision = 1;
  bool _ocupado = false, _conflicto = false, _activo = true, _stock = false;
  String? _error;
  String _tipo = 'VENTAS',
      _frecuencia = 'DIARIA',
      _formato = 'PDF',
      _periodo = 'SEGUN_FRECUENCIA';
  int? _sucursal;
  static const campos = {
    'titulo': 'Título',
    'hora': 'Hora (HH:MM)',
    'dia': 'Día (LUNES a DOMINGO o 1 a 31)',
    'destinatario_email': 'Correo destinatario',
    'zona_horaria': 'Zona horaria',
    'agrupacion': 'Agrupación (DIA o MES)',
    'estado': 'Estado del reporte',
    'metodo_pago': 'Método de pago',
    'proveedor_pago': 'Proveedor de pago',
    'tipo_entrega': 'Entrega (RECOJO_SUCURSAL o DELIVERY)',
    'tipo_venta': 'Canal (PRESENCIAL o DIGITAL)',
    'rol': 'Rol para reporte de usuarios',
    'cuentas': 'Cuentas (true, false o vacío)',
  };
  @override
  void initState() {
    super.initState();
    final p = widget.item;
    _base = p == null ? {} : datosProgramado(p);
    _revision = p?.revision ?? 1;
    _tipo = p?.tipo ?? 'VENTAS';
    _frecuencia = p?.frecuencia ?? 'DIARIA';
    _formato = p?.formato ?? 'PDF';
    _periodo = p?.periodo ?? 'SEGUN_FRECUENCIA';
    _sucursal = p?.sucursalId;
    _activo = p?.activo ?? true;
    _stock = p?.soloBajoStock ?? false;
    for (final k in campos.keys) {
      final f = p?.filtros ?? {};
      final v = switch (k) {
        'titulo' => p?.titulo ?? '',
        'hora' => p?.hora.substring(0, 5) ?? '08:00',
        'dia' => p?.dia ?? '',
        'destinatario_email' => p?.destinatarioEmail ?? '',
        'zona_horaria' => p?.zonaHoraria ?? 'America/La_Paz',
        'agrupacion' => f[k] ?? 'DIA',
        'cuentas' => f['activo'] ?? '',
        _ => f[k] ?? '',
      };
      _c[k] = TextEditingController(text: v.toString());
    }
  }

  @override
  void dispose() {
    for (final c in _c.values) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (_ocupado || _conflicto || !_form.currentState!.validate()) return;
    final filtros = <String, dynamic>{
      for (final k in [
        'agrupacion',
        'estado',
        'metodo_pago',
        'proveedor_pago',
        'tipo_entrega',
        'tipo_venta',
        'rol',
      ])
        k: _c[k]!.text.isEmpty ? null : _c[k]!.text,
      'activo': _c['cuentas']!.text.isEmpty
          ? null
          : _c['cuentas']!.text == 'true',
    };
    final datos = <String, dynamic>{
      'titulo': _c['titulo']!.text,
      'tipo': _tipo,
      'frecuencia': _frecuencia,
      'hora': _c['hora']!.text,
      'dia': _frecuencia == 'DIARIA' ? null : _c['dia']!.text.toUpperCase(),
      'formato': _formato,
      'destinatario_email': _c['destinatario_email']!.text,
      'sucursal_id': _sucursal,
      'solo_bajo_stock': _stock,
      'activo': _activo,
      'zona_horaria': _c['zona_horaria']!.text,
      'periodo': _periodo,
      'filtros': filtros,
    };
    final cap = context.read<PlanProvider>().capacidades;
    if (cap?.habilita('reportes_programacion') != true ||
        cap?.habilita(_formato == 'PDF' ? 'reportes_pdf' : 'reportes_excel') !=
            true) {
      setState(
        () => _error =
            'La programación o el formato no están habilitados en tu plan.',
      );
      return;
    }
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      if (widget.item == null) {
        await ReporteService.crearProgramado(datos);
      } else {
        await ReporteService.editarProgramado(
          widget.item!.id,
          _revision,
          cambiosProgramado(datosProgramado(widget.item!), datos, _base),
        );
      }
      if (mounted && vigente) Navigator.pop(context, true);
    } catch (e) {
      if (vigente) {
        setState(() {
          _error = explicar(e);
          _conflicto = e is ApiException && e.statusCode == 409;
        });
      }
    } finally {
      if (vigente) setState(() => _ocupado = false);
    }
  }

  Future<void> _revisar() async {
    try {
      final p = (await ReporteService.listarProgramados())
          .where((p) => p.id == widget.item!.id)
          .firstOrNull;
      if (vigente && p != null) {
        setState(() {
          _base = datosProgramado(p);
          _revision = p.revision;
          _conflicto = false;
          _error =
              'Revisión actualizada. Revisa el formulario conservado; el estado actual es ${p.activo ? 'activo' : 'pausado'}.';
        });
      }
    } catch (e) {
      if (vigente) setState(() => _error = explicar(e));
    }
  }

  String? _validar(String k, String? valor) {
    final v = valor ?? '';
    if ([
          'titulo',
          'hora',
          'destinatario_email',
          'zona_horaria',
          'agrupacion',
        ].contains(k) &&
        v.isEmpty) {
      return 'Completa este campo.';
    }
    if (k == 'titulo' && (v.trim().length < 3 || v.length > 150)) {
      return 'Usa de 3 a 150 caracteres.';
    }
    if (k == 'hora' && !RegExp(r'^([01]\d|2[0-3]):[0-5]\d$').hasMatch(v)) {
      return 'Usa HH:MM.';
    }
    if (k == 'destinatario_email' &&
        !RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$').hasMatch(v)) {
      return 'Ingresa un correo válido.';
    }
    if (k == 'dia' &&
        _frecuencia == 'SEMANAL' &&
        !RegExp(
          r'^(LUNES|MARTES|MIERCOLES|JUEVES|VIERNES|SABADO|DOMINGO|[0-6])$',
        ).hasMatch(v.toUpperCase())) {
      return 'Indica un día semanal válido.';
    }
    if (k == 'dia' &&
        _frecuencia == 'MENSUAL' &&
        (int.tryParse(v) == null || int.parse(v) < 1 || int.parse(v) > 31)) {
      return 'Usa un día de 1 a 31.';
    }
    if (k == 'agrupacion' && !['DIA', 'MES'].contains(v)) {
      return 'Usa DIA o MES.';
    }
    if (k == 'tipo_entrega' &&
        v.isNotEmpty &&
        !['RECOJO_SUCURSAL', 'DELIVERY'].contains(v)) {
      return 'Usa RECOJO_SUCURSAL o DELIVERY.';
    }
    if (k == 'tipo_venta' &&
        v.isNotEmpty &&
        !['PRESENCIAL', 'DIGITAL'].contains(v)) {
      return 'Usa PRESENCIAL o DIGITAL.';
    }
    if (k == 'cuentas' && v.isNotEmpty && !['true', 'false'].contains(v)) {
      return 'Usa true, false o vacío.';
    }
    return null;
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_ocupado,
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.item == null ? 'Nueva programación' : 'Editar programación',
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_ocupado) const LinearProgressIndicator(),
          if (_error != null) ErrorSaas(_error!),
          if (_conflicto)
            OutlinedButton(
              onPressed: _ocupado ? null : _revisar,
              child: const Text('Revisar versión vigente'),
            ),
          const Text(
            'La edición conserva una pausa mientras no solicites activación. En meses cortos, el servidor ajusta el día mensual al último disponible.',
          ),
          Form(
            key: _form,
            child: Column(
              children: [
                DropdownButtonFormField<String>(
                  initialValue: _tipo,
                  decoration: const InputDecoration(labelText: 'Tipo'),
                  items: widget.catalogo.tipos
                      .map(
                        (t) => DropdownMenuItem(
                          value: t.id,
                          child: Text(t.nombre),
                        ),
                      )
                      .toList(),
                  onChanged: _ocupado
                      ? null
                      : (v) => setState(() => _tipo = v!),
                ),
                DropdownButtonFormField<int>(
                  initialValue: _sucursal,
                  decoration: const InputDecoration(labelText: 'Sucursal'),
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<int>(
                      value: null,
                      child: Text('Todas'),
                    ),
                    ...widget.catalogo.sucursales.map(
                      (s) =>
                          DropdownMenuItem(value: s.id, child: Text(s.nombre)),
                    ),
                  ],
                  onChanged: _ocupado
                      ? null
                      : (v) => setState(() => _sucursal = v),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _frecuencia,
                  decoration: const InputDecoration(labelText: 'Frecuencia'),
                  items: ['DIARIA', 'SEMANAL', 'MENSUAL']
                      .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                      .toList(),
                  onChanged: _ocupado
                      ? null
                      : (v) => setState(() => _frecuencia = v!),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _formato,
                  decoration: const InputDecoration(labelText: 'Formato'),
                  items: ['PDF', 'EXCEL']
                      .map((x) => DropdownMenuItem(value: x, child: Text(x)))
                      .toList(),
                  onChanged: _ocupado
                      ? null
                      : (v) => setState(() => _formato = v!),
                ),
                DropdownButtonFormField<String>(
                  initialValue: _periodo,
                  decoration: const InputDecoration(labelText: 'Período'),
                  items:
                      [
                            'SEGUN_FRECUENCIA',
                            'DIA_ANTERIOR',
                            'SEMANA_ANTERIOR',
                            'MES_ANTERIOR',
                          ]
                          .map(
                            (x) => DropdownMenuItem(
                              value: x,
                              child: Text(x.replaceAll('_', ' ')),
                            ),
                          )
                          .toList(),
                  onChanged: _ocupado
                      ? null
                      : (v) => setState(() => _periodo = v!),
                ),
                ...campos.entries.map(
                  (e) => TextFormField(
                    controller: _c[e.key],
                    enabled: !_ocupado,
                    decoration: InputDecoration(labelText: e.value),
                    validator: (v) => _validar(e.key, v),
                  ),
                ),
                SwitchListTile(
                  title: const Text('Solo bajo stock'),
                  value: _stock,
                  onChanged: _ocupado
                      ? null
                      : (v) => setState(() => _stock = v),
                ),
                SwitchListTile(
                  title: const Text('Programación activa'),
                  value: _activo,
                  onChanged: _ocupado
                      ? null
                      : (v) => setState(() => _activo = v),
                ),
                FilledButton(
                  onPressed: _ocupado || _conflicto ? null : _guardar,
                  child: const Text('Guardar programación'),
                ),
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
