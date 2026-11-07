import 'package:flutter/material.dart';

import '../../core/session/contexto_sesion.dart';
import '../../services/notificaciones_service.dart';
import '../../services/firebase_push_service.dart';
import '../saas/saas_widgets.dart';
import 'destinos_notificaciones.dart';
import 'preferencias_notificaciones_sheet.dart';

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key, this.avisoInicial});
  final String? avisoInicial;
  @override
  State<NotificacionesScreen> createState() => _NotificacionesState();
}

class _NotificacionesState extends State<NotificacionesScreen> {
  List<NotificacionPropia> _notas = [];
  List<Map<String, dynamic>> _reembolsos = [];
  int _pagina = 1,
      _total = 0,
      _noLeidas = 0,
      _revision = 0,
      _generacion = ContextoSesion.instance.generacion;
  bool _cargando = false, _ocupado = false, _actualizarDespues = false;
  bool _errorPush = false;
  bool? _leida;
  String? _categoria, _error, _aviso, _errorReembolsos;
  @override
  void initState() {
    super.initState();
    _aviso = widget.avisoInicial;
    ContextoSesion.instance.addListener(_sesion);
    FirebasePush.novedades.addListener(_novedad);
    _cargar();
  }

  @override
  void dispose() {
    ContextoSesion.instance.removeListener(_sesion);
    FirebasePush.novedades.removeListener(_novedad);
    super.dispose();
  }

  bool get _vigente =>
      mounted && _generacion == ContextoSesion.instance.generacion;
  void _sesion() {
    if (!mounted || _generacion == ContextoSesion.instance.generacion) return;
    _generacion = ContextoSesion.instance.generacion;
    _revision++;
    setState(() {
      _notas = [];
      _reembolsos = [];
      _pagina = 1;
      _total = 0;
      _noLeidas = 0;
      _leida = null;
      _categoria = null;
      _aviso = null;
      _error = 'Cambió la sesión. Actualiza para consultar tu cuenta actual.';
      _ocupado = false;
      _cargando = false;
    });
  }

  void _novedad() {
    if (!mounted) return;
    if (_cargando || _ocupado) {
      _actualizarDespues = true;
    } else {
      _cargar();
    }
  }

  Future<void> _cargar([int? pagina]) async {
    final gen = _generacion, revision = ++_revision, p = pagina ?? _pagina;
    setState(() {
      _cargando = true;
      _error = null;
      _errorPush = false;
    });
    try {
      final r = await NotificacionesService.bandeja(
        pagina: p,
        leida: _leida,
        categoria: _categoria,
      );
      if (!_vigente || gen != _generacion || revision != _revision) return;
      final ultima = (r.total / 20).ceil().clamp(1, 1000000000);
      if (p > ultima) {
        await _cargar(ultima);
        return;
      }
      setState(() {
        _notas = r.avisos;
        _total = r.total;
        _noLeidas = r.noLeidas;
        _pagina = r.pagina;
      });
      FirebasePush.noLeidas.value = r.noLeidas;
      if (ContextoSesion.instance.usuario?.esCliente == true) {
        try {
          final rs = await NotificacionesService.reembolsos();
          if (_vigente && gen == _generacion && revision == _revision) {
            setState(() {
              _reembolsos = rs;
              _errorReembolsos = null;
            });
          }
        } catch (_) {
          if (_vigente && gen == _generacion && revision == _revision) {
            setState(
              () => _errorReembolsos = 'No se pudieron consultar los reembolsos. Reintenta actualizar.',
            );
          }
        }
      }
    } catch (e) {
      if (_vigente && gen == _generacion && revision == _revision) {
        setState(() => _error = FirebasePush.explicarError(e));
      }
    } finally {
      if (_vigente && gen == _generacion && revision == _revision) {
        setState(() => _cargando = false);
        if (_actualizarDespues) {
          _actualizarDespues = false;
          _cargar();
        }
      }
    }
  }

  Future<void> _operar(
    Future<void> Function() fn, {
    bool registroPush = false,
  }) async {
    if (_ocupado) return;
    final gen = _generacion;
    setState(() {
      _ocupado = true;
      _error = null;
      _aviso = null;
      _errorPush = registroPush;
    });
    try {
      await fn();
    } catch (e) {
      if (_vigente && gen == _generacion) {
        setState(() => _error = FirebasePush.explicarError(e));
      }
    } finally {
      if (_vigente && gen == _generacion) {
        setState(() => _ocupado = false);
        if (_actualizarDespues) {
          _actualizarDespues = false;
          _cargar();
        }
      }
    }
  }

  Future<void> _activarAvisos() => _operar(() async {
    final gen = _generacion;
    final r = await FirebasePush.activar();
    if (_vigente && gen == _generacion) setState(() => _aviso = r);
  }, registroPush: true);
  Future<void> _leer(NotificacionPropia n) async {
    await _operar(() async {
      await NotificacionesService.leer(n.id);
      if (_vigente) await _cargar();
    });
  }

  Future<void> _abrir(NotificacionPropia n) async {
    await _operar(() async {
      final gen = _generacion;
      final d = await NotificacionesService.destino(n.id);
      if (!mounted || !_vigente || gen != _generacion) return;
      final pantalla = pantallaNotificacion(d);
      if (pantalla == null) {
        setState(
          () => _aviso = d.tipo == 'VENTA'
              ? 'Esta actualización corresponde a una compra. Consúltala en la bandeja; no se abrirá otro pago.'
              : 'El recurso no está disponible para esta cuenta. La actualización permanece en la bandeja.',
        );
        return;
      }
      if (!n.leida) await NotificacionesService.leer(n.id);
      if (!mounted || !_vigente || gen != _generacion) return;
      await Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => pantalla),
      );
      if (_vigente && gen == _generacion) await _cargar();
    });
  }

  Future<void> _estado(NotificacionPropia n) async {
    await _operar(() async {
      final gen = _generacion;
      final r = await NotificacionesService.trazabilidad(n.id);
      if (!mounted || !_vigente || gen != _generacion) return;
      await showDialog<void>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Estado del aviso'),
          content: Text(
            'Bandeja: ${r['leida'] == true ? 'leída' : 'sin leer'}\nAceptadas por Firebase: ${r['aceptadas_fcm']}\nPendientes: ${r['pendientes']} · Fallidas: ${r['fallidas']} · Omitidas: ${r['omitidas']}\nLa aceptación de Firebase no confirma que el aviso haya aparecido en pantalla.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx),
              child: const Text('Cerrar'),
            ),
          ],
        ),
      );
    });
  }

  Future<void> _preferencias() async {
    final gen = _generacion;
    await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (_) => const PreferenciasNotificacionesSheet(),
    );
    if (_vigente && gen == _generacion) await _cargar();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Mis notificaciones'),
      actions: [
        IconButton(
          tooltip: 'Actualizar notificaciones',
          onPressed: _cargando || _ocupado ? null : () => _cargar(),
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          '$_noLeidas sin leer en toda tu bandeja · $_total resultados del filtro',
        ),
        DropdownButtonFormField<String>(
          key: ValueKey('lectura$_generacion'),
          initialValue: _leida == null ? '' : _leida.toString(),
          decoration: const InputDecoration(labelText: 'Lectura'),
          items: const [
            DropdownMenuItem(value: '', child: Text('Todas')),
            DropdownMenuItem(value: 'false', child: Text('Sin leer')),
            DropdownMenuItem(value: 'true', child: Text('Leídas')),
          ],
          onChanged: _ocupado
              ? null
              : (v) {
                  _leida = v == '' ? null : v == 'true';
                  _cargar(1);
                },
        ),
        DropdownButtonFormField<String>(
          key: ValueKey('categoria$_generacion'),
          initialValue: _categoria ?? '',
          decoration: const InputDecoration(labelText: 'Categoría'),
          items: [
            const DropdownMenuItem(value: '', child: Text('Todas')),
            ...categoriasNotificacion.map(
              (c) => DropdownMenuItem(value: c, child: Text(c)),
            ),
          ],
          onChanged: _ocupado
              ? null
              : (v) {
                  _categoria = v == '' ? null : v;
                  _cargar(1);
                },
        ),
        Wrap(
          spacing: 8,
          children: [
            TextButton(
              onPressed: _ocupado || _noLeidas == 0
                  ? null
                  : () => _operar(() async {
                      await NotificacionesService.leerTodas();
                      if (_vigente) {
                        setState(
                          () => _aviso = 'Se marcaron todas las notificaciones, incluidos otros filtros y páginas.',
                        );
                        await _cargar();
                      }
                    }),
              child: const Text('Marcar todas como leídas'),
            ),
            TextButton(
              onPressed: _ocupado ? null : _preferencias,
              child: const Text('Preferencias de avisos'),
            ),
            TextButton(
              onPressed: _ocupado ? null : _activarAvisos,
              child: const Text('Activar avisos push'),
            ),
            if (FirebasePush.android)
              TextButton(
                onPressed: FirebasePush.ajustes,
                child: const Text('Ajustes de avisos de Android'),
              ),
          ],
        ),
        if (_aviso != null) Text(_aviso!),
        if (_cargando) const LinearProgressIndicator(),
        if (_error != null) ...[
          Text(_error!),
          TextButton(
            onPressed: _ocupado
                ? null
                : (_errorPush ? _activarAvisos : () => _cargar()),
            child: Text(_errorPush ? 'Reintentar activación' : 'Reintentar'),
          ),
        ],
        if (_notas.isEmpty && !_cargando && _error == null)
          const Text('No hay notificaciones con estos filtros.'),
        ..._notas.map(
          (n) => Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.titulo,
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                  Text(n.mensaje),
                  Text(
                    '${n.categoria} · ${fechaSaas(n.creadoEn)} · ${n.leida ? 'Leída' : 'Sin leer'}',
                  ),
                  Wrap(
                    spacing: 8,
                    children: [
                      TextButton(
                        onPressed: _ocupado ? null : () => _abrir(n),
                        child: const Text('Abrir actualización'),
                      ),
                      if (!n.leida)
                        TextButton(
                          onPressed: _ocupado ? null : () => _leer(n),
                          child: const Text('Marcar como leída'),
                        ),
                      TextButton(
                        onPressed: _ocupado ? null : () => _estado(n),
                        child: const Text('Estado del aviso'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        Row(
          mainAxisAlignment: MainAxisAlignment.spaceBetween,
          children: [
            TextButton(
              onPressed: _cargando || _pagina <= 1
                  ? null
                  : () => _cargar(_pagina - 1),
              child: const Text('Anterior'),
            ),
            Text(
              'Página $_pagina de ${(_total / 20).ceil().clamp(1, 1000000000)}',
            ),
            TextButton(
              onPressed: _cargando || _pagina * 20 >= _total
                  ? null
                  : () => _cargar(_pagina + 1),
              child: const Text('Siguiente'),
            ),
          ],
        ),
        if (ContextoSesion.instance.usuario?.esCliente == true) ...[
          Text(
            'Mis reembolsos de compras no completadas',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          if (_errorReembolsos != null) Text(_errorReembolsos!),
          if (_reembolsos.isEmpty && _errorReembolsos == null)
            const Text('No hay reembolsos registrados.'),
          ..._reembolsos.map(
            (r) => Card(
              child: ListTile(
                title: Text('Orden #${r['orden_id']} · ${r['estado']}'),
                subtitle: Text(
                  '${r['monto']} ${r['moneda']} · ${r['motivo']}\nReferencia: ${r['referencia'] ?? 'Aún no confirmada'}',
                ),
              ),
            ),
          ),
        ],
      ],
    ),
  );
}
