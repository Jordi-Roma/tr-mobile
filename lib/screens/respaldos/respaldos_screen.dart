import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/network/api_exceptions.dart';
import '../../models/capacidades_plan.dart';
import '../../models/respaldo_models.dart';
import '../../models/saas_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/plan_provider.dart';
import '../../services/respaldos_service.dart';
import '../../services/saas_service.dart';
import '../saas/saas_widgets.dart';

class RespaldosScreen extends StatefulWidget {
  const RespaldosScreen({super.key, this.plataforma = false});
  final bool plataforma;
  @override
  State<RespaldosScreen> createState() => _RespaldosScreenState();
}

class _RespaldosScreenState extends State<RespaldosScreen> with PantallaSesion {
  late final RespaldosService _api;
  final _scroll = ScrollController();
  final _inicio = TextEditingController(),
      _hora = TextEditingController(text: '02:00'),
      _zona = TextEditingController(text: 'America/La_Paz');
  final _form = GlobalKey<FormState>();
  List<Respaldo> _copias = [];
  List<EmpresaSaas> _empresas = [];
  ConfiguracionRespaldos? _config;
  int? _empresa;
  String _estado = '';
  String? _error, _mensaje;
  bool _ocupado = true, _incierto = false, _activa = false;
  @override
  void initState() {
    super.initState();
    _api = RespaldosService(plataforma: widget.plataforma);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _cargar();
    });
  }

  @override
  void dispose() {
    _scroll.dispose();
    _inicio.dispose();
    _hora.dispose();
    _zona.dispose();
    super.dispose();
  }

  CapacidadesPlan? get _capacidades =>
      widget.plataforma ? null : context.read<PlanProvider>().capacidades;
  bool get _puedeCrear =>
      widget.plataforma ||
      (_capacidades?.habilita('respaldos_manuales') == true &&
          _capacidades?.cupos['respaldos_manuales_semana']?.agotado != true);
  void _mostrarAviso() {
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

  String _explicarRespaldo(Object e) => e is ApiException && e.statusCode == 503
      ? 'El servicio de respaldos no está disponible. Contacta a la administración de plataforma para revisar su configuración.'
      : explicar(e);
  Future<void> _cargar() async {
    if (!mounted || !vigente) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final copias = await _api.listar();
      if (!mounted || !vigente) return;
      setState(() => _copias = copias);
      if (widget.plataforma) {
        final empresas = await SaasService.contactos();
        if (vigente) setState(() => _empresas = empresas);
      } else {
        // Un fallo de capacidades no debe ocultar las copias que ya están disponibles.
        final plan = context.read<PlanProvider>();
        await plan.refrescar();
        if (!mounted || !vigente) return;
        final config = await _api.programacion();
        final estado = await _api.estadoEmpresa();
        if (!mounted || !vigente) return;
        setState(() {
          _config = config;
          _estado = estado;
          _activa = config.activa;
          _inicio.text = config.fechaInicio;
          _hora.text = config.hora;
          _zona.text = config.zona;
        });
      }
      if (vigente) {
        setState(() => _incierto = !widget.plataforma && _capacidades == null);
      }
    } catch (e) {
      if (vigente) setState(() => _error = _explicarRespaldo(e));
    } finally {
      if (vigente) setState(() => _ocupado = false);
    }
  }

  Future<void> _ejecutar(Future<void> Function() accion, String mensaje) async {
    if (_ocupado || _incierto) return;
    setState(() {
      _ocupado = true;
      _error = null;
      _mensaje = null;
    });
    try {
      await accion();
      if (!mounted || !vigente) return;
      setState(() => _mensaje = mensaje);
      await _cargar();
    } catch (e) {
      if (vigente) {
        setState(() {
          _incierto =
              e is ApiException &&
              (e.statusCode == null ||
                  [0, 408, 502, 504].contains(e.statusCode));
          _error = _incierto
              ? 'No se pudo confirmar el resultado. No repitas la operación todavía: actualiza las copias y el uso antes de volver a intentarlo.'
              : _explicarRespaldo(e);
        });
        _mostrarAviso();
      }
    } finally {
      if (vigente) setState(() => _ocupado = false);
    }
  }

  Future<void> _crear() async {
    if (!_puedeCrear) return;
    await _ejecutar(
      () => _api.crear(empresaId: widget.plataforma ? _empresa : null),
      'Respaldo creado.',
    );
  }

  Future<void> _eliminar(Respaldo r) async {
    final ok = await confirmarSaas(
      context,
      'Eliminar copia',
      'Esta copia se eliminará definitivamente. Eliminarla no devuelve el cupo manual consumido.',
    );
    if (!vigente || !ok) return;
    await _ejecutar(() => _api.eliminar(r.id), 'Copia eliminada.');
  }

  Future<void> _purgar() async {
    final ok = await confirmarSaas(
      context,
      'Eliminar copias vencidas',
      'Se eliminarán las copias vencidas de la plataforma.',
    );
    if (!vigente || !ok) return;
    await _ejecutar(_api.purgar, 'Copias vencidas procesadas.');
  }

  Future<void> _revisar(Respaldo r) async {
    if (_ocupado || _incierto) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final previa = await _api.previsualizar(r.id);
      bool suspendida = false;
      if (previa.tipo == 'EMPRESA') {
        if (widget.plataforma) {
          final empresas = await SaasService.contactos();
          suspendida =
              empresas
                  .where((e) => e.id == previa.empresaId)
                  .firstOrNull
                  ?.estado ==
              'SUSPENDIDA';
        } else {
          suspendida = await _api.estadoEmpresa() == 'SUSPENDIDA';
        }
      }
      if (!mounted || !vigente) return;
      final confirmar = await Navigator.push<String>(
        context,
        MaterialPageRoute(
          builder: (_) => RevisionRespaldoScreen(
            previa: previa,
            suspendida: suspendida,
            plataforma: widget.plataforma,
          ),
        ),
      );
      if (!mounted || !vigente || confirmar == null) return;
      await _api.restaurar(previa.id, confirmar);
      if (!mounted || !vigente) return;
      if (!widget.plataforma) {
        await context.read<AuthProvider>().contexto.cerrar(
          mensaje: 'Empresa restaurada. Se cerraron sus sesiones; inicia sesión nuevamente. La empresa permanece suspendida para revisión.',
          pedirLogin: true,
        );
        return;
      }
      setState(
        () => _mensaje = previa.tipo == 'GLOBAL'
            ? 'Copia restaurada en el entorno de ensayo.'
            : 'Empresa restaurada; permanece suspendida para revisión.',
      );
      await _cargar();
    } catch (e) {
      if (vigente) {
        setState(() {
          _incierto =
              e is ApiException &&
              (e.statusCode == null ||
                  [0, 408, 502, 504].contains(e.statusCode));
          _error = _incierto
              ? 'No se pudo confirmar la restauración. No la repitas: actualiza el listado y verifica el resultado antes de solicitar otra revisión.'
              : _explicarRespaldo(e);
        });
        _mostrarAviso();
      }
    } finally {
      if (vigente) setState(() => _ocupado = false);
    }
  }

  Future<void> _guardarProgramacion() async {
    if (_ocupado ||
        _incierto ||
        _config == null ||
        _capacidades?.operacionesHabilitadas != true) {
      return;
    }
    if (!_form.currentState!.validate()) return;
    if (_activa &&
        _capacidades?.funciones['respaldos_automaticos']?.incluida != true) {
      setState(() => _error = 'El plan no incluye respaldos automáticos.');
      _mostrarAviso();
      return;
    }
    final editable =
        _capacidades?.funciones['horario_respaldo_configurable']?.incluida ==
        true;
    await _ejecutar(
      () => _api.guardarProgramacion(
        _config!.datos(
          activar: _activa,
          inicio: _inicio.text,
          hora: _hora.text,
          zona: _zona.text.trim(),
          editable: editable,
        ),
      ),
      'Programación guardada.',
    );
  }

  String _nombre(int? id) =>
      _empresas.where((e) => e.id == id).firstOrNull?.nombre ?? 'Empresa $id';
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (widget.plataforma ? !auth.esAdminSaas : !auth.esAdmin) {
      return const SizedBox.shrink();
    }
    final caps = widget.plataforma
        ? null
        : context.watch<PlanProvider>().capacidades;
    final editable =
        caps?.funciones['horario_respaldo_configurable']?.incluida == true;
    final automaticos =
        caps?.funciones['respaldos_automaticos']?.incluida == true;
    final cupo = caps?.cupos['respaldos_manuales_semana'];
    return PopScope(
      canPop: !_ocupado,
      child: Scaffold(
        appBar: AppBar(
          title: Text(
            widget.plataforma
                ? 'Respaldos de plataforma'
                : 'Respaldos de mi empresa',
          ),
          actions: [
            IconButton(
              onPressed: _ocupado ? null : _cargar,
              icon: const Icon(Icons.refresh),
              tooltip: 'Actualizar respaldos',
            ),
          ],
        ),
        body: ListView(
          controller: _scroll,
          padding: const EdgeInsets.all(20),
          children: [
            if (_ocupado) const LinearProgressIndicator(),
            if (_error != null) ErrorSaas(_error!),
            if (_mensaje != null)
              Semantics(liveRegion: true, child: Text(_mensaje!)),
            if (widget.plataforma) ...[
              DropdownButtonFormField<int>(
                key: ValueKey(_empresas.length),
                initialValue: _empresa,
                decoration: const InputDecoration(
                  labelText: 'Alcance de la copia',
                ),
                isExpanded: true,
                items: [
                  const DropdownMenuItem<int>(
                    value: null,
                    child: Text('Global: todas las empresas'),
                  ),
                  ..._empresas.map(
                    (e) => DropdownMenuItem(value: e.id, child: Text(e.nombre)),
                  ),
                ],
                onChanged: _ocupado
                    ? null
                    : (v) => setState(() => _empresa = v),
              ),
              const Text(
                'La copia global se restaura únicamente en un destino de ensayo vacío configurado. No reemplaza la base activa de producción.',
              ),
            ] else ...[
              Text('Estado de mi empresa: $_estado'),
              Text(
                'Copias manuales en los últimos siete días: ${cupo?.uso ?? 0} / ${cupo?.limite ?? 'Sin límite'}. Disponibles: ${cupo?.disponibles ?? 'Sin límite'}.',
              ),
              Text(
                'Retención para copias nuevas: ${caps?.limites['retencion_respaldos_dias'] ?? _config?.retencionDias ?? 'Pendiente de consulta'} días.',
              ),
              const Text(
                'Eliminar copias no libera el cupo manual. Las automáticas y preventivas no lo consumen.',
              ),
              if (!_puedeCrear)
                Text(
                  cupo?.agotado == true
                      ? 'Cupo manual agotado.'
                      : caps?.motivo('respaldos_manuales') ??
                            'Consulta tu plan antes de crear una copia.',
                ),
            ],
            FilledButton(
              onPressed: _ocupado || _incierto || !_puedeCrear ? null : _crear,
              child: const Text('Crear copia cifrada'),
            ),
            if (widget.plataforma)
              OutlinedButton(
                onPressed: _ocupado || _incierto ? null : _purgar,
                child: const Text('Eliminar copias vencidas'),
              ),
            const SizedBox(height: 20),
            Text(
              'Copias registradas',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            if (!_ocupado && _copias.isEmpty)
              const Text('No hay respaldos disponibles.'),
            ..._copias.map(
              (r) => Card(
                child: Padding(
                  padding: const EdgeInsets.all(12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        r.tipo == 'GLOBAL'
                            ? 'Global'
                            : widget.plataforma
                            ? _nombre(r.empresaId)
                            : 'Mi empresa',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text('${r.origenNombre} · ${r.estado}'),
                      Text('Fecha: ${fechaRespaldo(r.fecha)}'),
                      Text('Vence: ${fechaRespaldo(r.venceEn)}'),
                      Text('${(r.bytes / 1024).toStringAsFixed(1)} KB'),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed:
                                _ocupado ||
                                    _incierto ||
                                    r.estado != 'DISPONIBLE'
                                ? null
                                : () => _revisar(r),
                            child: const Text('Revisar restauración'),
                          ),
                          TextButton(
                            onPressed:
                                _ocupado ||
                                    _incierto ||
                                    r.estado != 'DISPONIBLE'
                                ? null
                                : () => _eliminar(r),
                            child: const Text('Eliminar copia'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ),
            if (!widget.plataforma && _config != null) ...[
              const SizedBox(height: 20),
              Text(
                'Programación automática',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              Text(
                automaticos
                    ? 'Frecuencia establecida por el plan: cada ${caps?.limites['frecuencia_respaldo_dias'] ?? _config!.frecuenciaDias} días.'
                    : 'No incluida en el plan.',
              ),
              Text(
                'Último respaldo: ${fechaRespaldo(_config!.ultimoRespaldo)}',
              ),
              Form(
                key: _form,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    SwitchListTile(
                      title: const Text('Activar respaldos automáticos'),
                      value: _activa,
                      onChanged:
                          _ocupado ||
                              _incierto ||
                              caps?.operacionesHabilitadas != true
                          ? null
                          : (v) => setState(() => _activa = v),
                    ),
                    TextFormField(
                      controller: _inicio,
                      enabled:
                          !_ocupado &&
                          !_incierto &&
                          caps?.operacionesHabilitadas == true,
                      decoration: const InputDecoration(
                        labelText: 'Fecha de inicio (AAAA-MM-DD)',
                      ),
                      validator: (v) => validarFechaSaas(v),
                    ),
                    if (editable) ...[
                      TextFormField(
                        controller: _hora,
                        enabled:
                            !_ocupado &&
                            !_incierto &&
                            caps?.operacionesHabilitadas == true,
                        decoration: const InputDecoration(
                          labelText: 'Hora local (HH:MM)',
                        ),
                        validator: (v) =>
                            RegExp(r'^([01]\d|2[0-3]):[0-5]\d$')
                                .hasMatch(v ?? '')
                            ? null
                            : 'Usa una hora HH:MM válida.',
                      ),
                      TextFormField(
                        controller: _zona,
                        enabled:
                            !_ocupado &&
                            !_incierto &&
                            caps?.operacionesHabilitadas == true,
                        decoration: const InputDecoration(
                          labelText: 'Zona horaria',
                        ),
                        maxLength: 80,
                        validator: (v) => v == null || v.trim().isEmpty
                            ? 'Ingresa una zona, por ejemplo America/La_Paz.'
                            : null,
                      ),
                    ] else
                      const Text('Horario fijo: 02:00 · America/La_Paz.'),
                    FilledButton(
                      onPressed:
                          _ocupado ||
                              _incierto ||
                              caps?.operacionesHabilitadas != true
                          ? null
                          : _guardarProgramacion,
                      child: const Text('Guardar programación'),
                    ),
                  ],
                ),
              ),
              if (caps?.operacionesHabilitadas != true)
                const Text(
                  'Puedes consultar esta programación. Para modificarla, la suscripción debe estar vigente.',
                ),
            ],
          ],
        ),
      ),
    );
  }
}

class RevisionRespaldoScreen extends StatefulWidget {
  const RevisionRespaldoScreen({
    super.key,
    required this.previa,
    required this.suspendida,
    required this.plataforma,
  });
  final PreviaRespaldo previa;
  final bool suspendida, plataforma;
  @override
  State<RevisionRespaldoScreen> createState() => _RevisionRespaldoScreenState();
}

class _RevisionRespaldoScreenState extends State<RevisionRespaldoScreen>
    with PantallaSesion {
  final _frase = TextEditingController();
  @override
  void dispose() {
    _frase.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = widget.previa;
    final permitida = p.tipo == 'GLOBAL'
        ? widget.plataforma
        : widget.suspendida;
    return Scaffold(
      appBar: AppBar(title: const Text('Revisar restauración')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          Text(p.destino),
          if (p.tipo == 'GLOBAL')
            const Text(
              'Se restaura en el destino de ensayo vacío configurado, sin reemplazar la base activa de producción.',
            )
          else
            const Text(
              'La empresa debe estar suspendida. Se crea una copia preventiva, se reemplazan sus datos y se cierran sus sesiones. Se conserva la suscripción actual; las otras empresas no se modifican.',
            ),
          if (!permitida)
            const Text(
              'La empresa todavía no está suspendida. Solicita la suspensión a la administración de plataforma y vuelve a revisar la copia.',
            ),
          Text('Archivos incluidos: ${p.archivos}'),
          ExpansionTile(
            title: const Text('Detalle de registros de la copia'),
            children: p.conteos.entries
                .map(
                  (e) => ListTile(
                    title: Text(e.key.replaceAll('_', ' ')),
                    subtitle: Text(
                      'En la copia: ${e.value} · Actuales: ${p.actuales[e.key] ?? '—'}',
                    ),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 20),
          Text('Escribe exactamente: ${p.confirmacion}'),
          TextField(
            controller: _frase,
            decoration: const InputDecoration(
              labelText: 'Confirmación explícita',
            ),
            autocorrect: false,
            enableSuggestions: false,
            onChanged: (_) => setState(() {}),
          ),
          const SizedBox(height: 16),
          FilledButton(
            onPressed: permitida && _frase.text == p.confirmacion && vigente
                ? () => Navigator.pop(context, _frase.text)
                : null,
            child: const Text('Restaurar copia revisada'),
          ),
          OutlinedButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Cancelar'),
          ),
        ],
      ),
    );
  }
}

String fechaRespaldo(String? fecha) {
  if (fecha == null) return 'Sin ejecución registrada';
  final valor = DateTime.tryParse(fecha);
  if (valor == null) return 'Fecha no disponible';
  return DateFormat('dd/MM/yyyy HH:mm')
      .format(valor.toUtc().subtract(const Duration(hours: 4)));
}
