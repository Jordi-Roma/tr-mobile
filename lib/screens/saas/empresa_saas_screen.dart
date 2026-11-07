import 'package:flutter/material.dart';

import '../../models/saas_models.dart';
import '../../models/capacidades_plan.dart';
import '../../services/saas_service.dart';
import '../perfil/mi_plan_screen.dart';
import 'saas_widgets.dart';

class EmpresasSaasScreen extends StatefulWidget {
  const EmpresasSaasScreen({super.key, this.planId});
  final int? planId;
  @override
  State<EmpresasSaasScreen> createState() => _EmpresasSaasScreenState();
}

class _EmpresasSaasScreenState extends State<EmpresasSaasScreen>
    with PantallaSesion {
  final _buscar = TextEditingController();
  List<PlanSaas> _planes = [];
  PaginaEmpresasSaas? _datos;
  int? _plan;
  String _estado = '';
  int _pagina = 1;
  bool _cargando = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _plan = widget.planId;
    _cargar();
  }

  @override
  void dispose() {
    _buscar.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final r = await Future.wait<Object>([
        SaasService.planes(),
        SaasService.empresas(
          planId: _plan,
          estado: _estado,
          buscar: _buscar.text.trim(),
          pagina: _pagina,
        ),
      ]);
      if (vigente) {
        setState(() {
          _planes = r[0] as List<PlanSaas>;
          _datos = r[1] as PaginaEmpresasSaas;
        });
      }
    } catch (e) {
      if (vigente) setState(() => _error = explicar(e));
    } finally {
      if (vigente) setState(() => _cargando = false);
    }
  }

  Future<void> _abrir([EmpresaSaas? empresa]) async {
    await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => EmpresaEditorScreen(empresa: empresa, planes: _planes),
      ),
    );
    if (vigente) await _cargar();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Empresas'),
      actions: [
        IconButton(
          onPressed: _cargando ? null : _cargar,
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualizar empresas',
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _cargando ? null : () => _abrir(),
      icon: const Icon(Icons.add_business),
      label: const Text('Registrar empresa'),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        TextField(
          controller: _buscar,
          decoration: const InputDecoration(labelText: 'Nombre o código'),
          maxLength: 150,
          onSubmitted: (_) {
            if (!_cargando) {
              _pagina = 1;
              _cargar();
            }
          },
        ),
        DropdownButtonFormField<int>(
          key: ValueKey('filtro-plan-${_planes.length}'),
          initialValue: _planes.any((p) => p.id == _plan) ? _plan : null,
          decoration: const InputDecoration(labelText: 'Plan'),
          isExpanded: true,
          items: [
            const DropdownMenuItem<int>(value: null, child: Text('Todos')),
            ..._planes.map(
              (p) => DropdownMenuItem(value: p.id, child: Text(p.nombre)),
            ),
          ],
          onChanged: _cargando ? null : (v) => setState(() => _plan = v),
        ),
        DropdownButtonFormField<String>(
          initialValue: _estado,
          decoration: const InputDecoration(labelText: 'Estado'),
          items: ['', 'ACTIVA', 'SUSPENDIDA', 'PENDIENTE', 'CANCELADA']
              .map(
                (s) => DropdownMenuItem(
                  value: s,
                  child: Text(s.isEmpty ? 'Todos' : s),
                ),
              )
              .toList(),
          onChanged: _cargando
              ? null
              : (v) => setState(() => _estado = v ?? ''),
        ),
        FilledButton(
          onPressed: _cargando
              ? null
              : () {
                  _pagina = 1;
                  _cargar();
                },
          child: const Text('Buscar empresas'),
        ),
        if (_cargando) const LinearProgressIndicator(),
        if (_error != null) ErrorSaas(_error!, reintentar: _cargar),
        ...?_datos?.empresas.map(
          (e) => Card(
            child: ListTile(
              title: Text(e.nombre),
              subtitle: Text(
                '${e.codigo} · ${e.estado}\n${e.planNombre ?? 'Sin plan'} · ${e.fin ?? 'Sin vencimiento'}',
              ),
              isThreeLine: true,
              trailing: const Icon(Icons.chevron_right),
              onTap: _cargando ? null : () => _abrir(e),
            ),
          ),
        ),
        if (!_cargando && _datos?.empresas.isEmpty == true)
          const Text('No se encontraron empresas.'),
        Wrap(
          spacing: 12,
          crossAxisAlignment: WrapCrossAlignment.center,
          children: [
            OutlinedButton(
              onPressed: _cargando || _pagina <= 1
                  ? null
                  : () {
                      _pagina--;
                      _cargar();
                    },
              child: const Text('Anterior'),
            ),
            Text('Página $_pagina · ${_datos?.total ?? 0} empresas'),
            OutlinedButton(
              onPressed: _cargando || _pagina * 20 >= (_datos?.total ?? 0)
                  ? null
                  : () {
                      _pagina++;
                      _cargar();
                    },
              child: const Text('Siguiente'),
            ),
          ],
        ),
      ],
    ),
  );
}

class EmpresaEditorScreen extends StatefulWidget {
  const EmpresaEditorScreen({super.key, this.empresa, required this.planes});
  final EmpresaSaas? empresa;
  final List<PlanSaas> planes;
  @override
  State<EmpresaEditorScreen> createState() => _EmpresaEditorScreenState();
}

class _EmpresaEditorScreenState extends State<EmpresaEditorScreen>
    with PantallaSesion {
  final _form = GlobalKey<FormState>(),
      _formNombre = GlobalKey<FormState>(),
      _formSuscripcion = GlobalKey<FormState>();
  final _nombre = TextEditingController(),
      _codigo = TextEditingController(),
      _inicio = TextEditingController(text: hoyBolivia()),
      _fin = TextEditingController(),
      _adminNombre = TextEditingController(),
      _apellido = TextEditingController(),
      _usuario = TextEditingController(),
      _correo = TextEditingController(),
      _password = TextEditingController();
  late String _estado;
  int? _plan;
  bool _ocupado = false, _cargando = false, _cambio = false;
  String? _error, _aviso;
  CapacidadesPlan? _capacidades;
  List<Map<String, dynamic>> _historial = [];
  EmpresaSaas? _contacto;
  @override
  void initState() {
    super.initState();
    _nombre.text = widget.empresa?.nombre ?? '';
    _codigo.text = widget.empresa?.codigo ?? '';
    _estado = widget.empresa?.estado ?? 'ACTIVA';
    _plan = widget.empresa?.planId;
    if (widget.empresa != null) _cargar();
  }

  @override
  void dispose() {
    for (final c in [
      _nombre,
      _codigo,
      _inicio,
      _fin,
      _adminNombre,
      _apellido,
      _usuario,
      _correo,
      _password,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final id = widget.empresa!.id;
      final r = await Future.wait<Object>([
        SaasService.capacidades(id),
        SaasService.suscripciones(id),
        SaasService.contactos(),
      ]);
      if (vigente) {
        setState(() {
          _capacidades = r[0] as CapacidadesPlan;
          _historial = r[1] as List<Map<String, dynamic>>;
          _contacto = (r[2] as List<EmpresaSaas>)
              .where((e) => e.id == id)
              .firstOrNull;
          _estado = _contacto?.estado ?? _estado;
        });
      }
    } catch (e) {
      if (vigente) setState(() => _error = explicar(e));
    } finally {
      if (vigente) setState(() => _cargando = false);
    }
  }

  Future<void> _operar(
    Future<void> Function() accion,
    String mensaje, {
    bool cerrar = false,
  }) async {
    if (_ocupado) return;
    setState(() {
      _ocupado = true;
      _error = null;
      _aviso = null;
    });
    try {
      await accion();
      if (!mounted || !vigente) return;
      _cambio = true;
      if (cerrar) {
        Navigator.pop(context, true);
      } else {
        setState(() => _aviso = mensaje);
        await _cargar();
      }
    } catch (e) {
      if (vigente) setState(() => _error = explicar(e));
    } finally {
      if (vigente) setState(() => _ocupado = false);
    }
  }

  String? _texto(String? v, int min) => v == null || v.trim().length < min
      ? 'Ingresa al menos $min caracteres.'
      : null;
  bool _fechas() {
    if (_fin.text.isNotEmpty && _fin.text.compareTo(_inicio.text) < 0) {
      setState(
        () => _error = 'El vencimiento debe ser igual o posterior al inicio.',
      );
      return false;
    }
    return true;
  }

  List<Widget> _suscripcion() => [
    DropdownButtonFormField<int>(
      initialValue: widget.planes.any((p) => p.id == _plan && p.activo)
          ? _plan
          : null,
      decoration: const InputDecoration(labelText: 'Plan'),
      isExpanded: true,
      items: widget.planes
          .where((p) => p.activo)
          .map((p) => DropdownMenuItem(value: p.id, child: Text(p.nombre)))
          .toList(),
      onChanged: (v) => _plan = v,
      validator: (v) => v == null ? 'Selecciona un plan activo.' : null,
    ),
    TextFormField(
      controller: _inicio,
      decoration: const InputDecoration(labelText: 'Inicio (AAAA-MM-DD)'),
      validator: (v) => validarFechaSaas(v),
    ),
    TextFormField(
      controller: _fin,
      decoration: const InputDecoration(
        labelText: 'Vencimiento opcional (AAAA-MM-DD)',
      ),
      validator: (v) => validarFechaSaas(v, opcional: true),
    ),
  ];
  void _crear() {
    if (!_form.currentState!.validate() || !_fechas()) return;
    _operar(
      () => SaasService.crearEmpresa({
        'codigo': _codigo.text.trim(),
        'nombre': _nombre.text.trim(),
        'plan_id': _plan,
        'fecha_inicio': _inicio.text,
        'fecha_vencimiento': _fin.text.isEmpty ? null : _fin.text,
        'administrador': {
          'nombre': _adminNombre.text.trim(),
          'apellido': _apellido.text.trim(),
          'username': _usuario.text.trim(),
          'correo': _correo.text.trim(),
          'password': _password.text,
        },
      }),
      'Empresa creada.',
      cerrar: true,
    );
  }

  Future<void> _estadoGuardar() async {
    if (_ocupado) return;
    final ok = await confirmarSaas(
      context,
      'Cambiar estado de empresa',
      '${widget.empresa!.nombre}: $_estado. Suspender conserva consultas y pendientes; cancelar impide el acceso.',
    );
    if (!vigente || !ok) return;
    await _operar(
      () => SaasService.estadoEmpresa(widget.empresa!.id, _estado),
      'Estado actualizado.',
    );
  }

  Future<void> _asignar() async {
    if (!_formSuscripcion.currentState!.validate() || !_fechas() || _ocupado) {
      return;
    }
    final ok = await confirmarSaas(
      context,
      'Guardar suscripción',
      'Se reemplazará la suscripción vigente y se conservará el historial. Las programaciones afectadas pueden pausarse; mejorar el plan no las reactiva automáticamente.',
    );
    if (!vigente || !ok) return;
    await _operar(
      () => SaasService.suscribir(
        widget.empresa!.id,
        _plan!,
        _inicio.text,
        _fin.text.isEmpty ? null : _fin.text,
      ),
      'Suscripción guardada.',
    );
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_ocupado,
    onPopInvokedWithResult: (didPop, result) {},
    child: Scaffold(
      appBar: AppBar(
        title: Text(
          widget.empresa == null ? 'Registrar empresa' : widget.empresa!.nombre,
        ),
        leading: BackButton(
          onPressed: _ocupado ? null : () => Navigator.pop(context, _cambio),
        ),
      ),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_ocupado || _cargando) const LinearProgressIndicator(),
          if (_error != null)
            ErrorSaas(
              _error!,
              reintentar: widget.empresa != null && !_ocupado ? _cargar : null,
            ),
          if (_aviso != null) Semantics(liveRegion: true, child: Text(_aviso!)),
          AbsorbPointer(
            absorbing: _ocupado,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                if (widget.empresa == null)
                  Form(
                    key: _form,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'La empresa, su suscripción y el administrador inicial se crean juntos.',
                        ),
                        TextFormField(
                          controller: _codigo,
                          decoration: const InputDecoration(
                            labelText: 'Código público',
                          ),
                          maxLength: 40,
                          validator: (v) =>
                              RegExp(r'^[a-z0-9][a-z0-9-]{1,39}$')
                                  .hasMatch(v ?? '')
                              ? null
                              : 'Usa 2 a 40 minúsculas, números o guiones.',
                        ),
                        TextFormField(
                          controller: _nombre,
                          decoration: const InputDecoration(
                            labelText: 'Nombre de empresa',
                          ),
                          maxLength: 150,
                          validator: (v) => _texto(v, 2),
                        ),
                        ..._suscripcion(),
                        const SizedBox(height: 16),
                        Text(
                          'Administrador inicial',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        TextFormField(
                          controller: _adminNombre,
                          decoration: const InputDecoration(
                            labelText: 'Nombre del administrador',
                          ),
                          maxLength: 120,
                          validator: (v) => _texto(v, 1),
                        ),
                        TextFormField(
                          controller: _apellido,
                          decoration: const InputDecoration(
                            labelText: 'Apellido',
                          ),
                          maxLength: 120,
                          validator: (v) => _texto(v, 1),
                        ),
                        TextFormField(
                          controller: _usuario,
                          decoration: const InputDecoration(
                            labelText: 'Usuario',
                          ),
                          maxLength: 80,
                          validator: (v) => _texto(v, 4),
                        ),
                        TextFormField(
                          controller: _correo,
                          decoration: const InputDecoration(
                            labelText: 'Correo',
                          ),
                          maxLength: 150,
                          keyboardType: TextInputType.emailAddress,
                          validator: (v) =>
                              RegExp(r'^[^\s@]+@[^\s@]+\.[^\s@]+$')
                                  .hasMatch(v ?? '')
                              ? null
                              : 'Ingresa un correo válido.',
                        ),
                        TextFormField(
                          controller: _password,
                          decoration: const InputDecoration(
                            labelText: 'Contraseña inicial',
                          ),
                          obscureText: true,
                          enableSuggestions: false,
                          autocorrect: false,
                          validator: (v) => _texto(v, 8),
                        ),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _ocupado ? null : _crear,
                          child: const Text('Crear empresa'),
                        ),
                      ],
                    ),
                  ),
                if (widget.empresa != null) ...[
                  Text('Código: ${widget.empresa!.codigo}'),
                  if (_contacto?.contacto != null)
                    Text(
                      'Responsable: ${_contacto!.responsable ?? ''}\n${_contacto!.contacto} (correo sin verificar)',
                    ),
                  Form(
                    key: _formNombre,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        TextFormField(
                          controller: _nombre,
                          decoration: const InputDecoration(
                            labelText: 'Nombre de empresa',
                          ),
                          maxLength: 150,
                          validator: (v) => _texto(v, 2),
                        ),
                        OutlinedButton(
                          onPressed: _ocupado
                              ? null
                              : () {
                                  if (_formNombre.currentState!.validate()) {
                                    _operar(
                                      () => SaasService.editarEmpresa(
                                        widget.empresa!.id,
                                        _nombre.text.trim(),
                                      ),
                                      'Nombre actualizado.',
                                    );
                                  }
                                },
                          child: const Text('Guardar nombre'),
                        ),
                      ],
                    ),
                  ),
                  ExpansionTile(
                    title: const Text('Plan y capacidades actuales'),
                    children: [
                      if (_capacidades != null)
                        CapacidadesPlanVista(_capacidades!),
                    ],
                  ),
                  ExpansionTile(
                    title: const Text('Historial de suscripciones'),
                    children: [
                      ..._historial.map(
                        (s) => ListTile(
                          title: Text(s['plan_nombre'] as String),
                          subtitle: Text(
                            '${s['estado']} · ${s['fecha_inicio']} → ${s['fecha_vencimiento'] ?? 'Sin vencimiento'}',
                          ),
                        ),
                      ),
                      if (!_cargando && _historial.isEmpty)
                        const ListTile(
                          title: Text('Sin suscripciones registradas.'),
                        ),
                    ],
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Estado de acceso',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  if (_contacto?.estado == 'PENDIENTE' ||
                      widget.empresa!.estado == 'PENDIENTE')
                    const Text(
                      'Para aprobar una empresa pendiente, asigna el plan y la vigencia. El correo de contacto no fue verificado.',
                    ),
                  DropdownButtonFormField<String>(
                    key: ValueKey(
                      'estado-${_contacto?.estado ?? widget.empresa!.estado}',
                    ),
                    initialValue: _estado,
                    decoration: const InputDecoration(labelText: 'Estado'),
                    items:
                        (widget.empresa!.estado == 'PENDIENTE' &&
                                    _contacto?.estado != 'ACTIVA'
                                ? ['PENDIENTE', 'CANCELADA']
                                : ['ACTIVA', 'SUSPENDIDA', 'CANCELADA'])
                            .map(
                              (s) => DropdownMenuItem(value: s, child: Text(s)),
                            )
                            .toList(),
                    onChanged: (v) => setState(() => _estado = v ?? _estado),
                  ),
                  OutlinedButton(
                    onPressed: _ocupado || _estado == 'PENDIENTE'
                        ? null
                        : _estadoGuardar,
                    child: const Text('Aplicar estado'),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    'Asignar o renovar suscripción',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Form(
                    key: _formSuscripcion,
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        ..._suscripcion(),
                        const SizedBox(height: 16),
                        FilledButton(
                          onPressed: _ocupado ? null : _asignar,
                          child: Text(
                            _contacto?.estado == 'PENDIENTE'
                                ? 'Aprobar y activar empresa'
                                : 'Guardar suscripción',
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    ),
  );
}
