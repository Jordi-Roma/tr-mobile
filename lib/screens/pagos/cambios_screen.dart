import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../core/session/contexto_sesion.dart';
import '../../models/cambio_models.dart';
import '../../models/devolucion_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/cambio_service.dart';
import '../../services/devolucion_service.dart';
import 'devoluciones_screen.dart';

class CambiosScreen extends StatefulWidget {
  const CambiosScreen({super.key, this.seleccionInicial});
  final int? seleccionInicial;
  @override
  State<CambiosScreen> createState() => _CambiosScreenState();
}

class _CambiosScreenState extends State<CambiosScreen> {
  bool _gestion = false,
      _cargando = true,
      _ocupado = false,
      _recibida = false,
      _entregada = false;
  int _generacion = ContextoSesion.instance.generacion, _noVendibles = 0;
  String? _error;
  String _condicion = '', _referencia = '';
  List<CambioPrenda> _lista = [];
  List<VentaDevolucionElegible> _ventas = [];
  List<Map<String, dynamic>> _opciones = [];
  int? _opcion;
  Map<String, dynamic>? _politica;
  CambioPrenda? _actual;
  bool _seleccionAplicada = false;
  @override
  void initState() {
    super.initState();
    _gestion = context.read<AuthProvider>().esPersonalDevoluciones;
    ContextoSesion.instance.addListener(_sesion);
    _cargar();
  }

  void _sesion() {
    if (_generacion == ContextoSesion.instance.generacion) return;
    _generacion = ContextoSesion.instance.generacion;
    if (mounted) {
      setState(() {
        _lista = [];
        _ventas = [];
        _actual = null;
        _opciones = [];
        _politica = null;
        _error = 'La sesión cambió. Vuelve a abrir Cambios.';
      });
    }
  }

  @override
  void dispose() {
    ContextoSesion.instance.removeListener(_sesion);
    super.dispose();
  }

  String _monto(num? n) => 'Bs ${(n ?? 0).toStringAsFixed(2)}';
  Future<void> _cargar() async {
    final g = _generacion;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final lista = await CambioService.listar(_gestion);
      final ventas = _gestion
          ? <VentaDevolucionElegible>[]
          : await CambioService.elegibles();
      final politica = _gestion ? null : await DevolucionService.politica();
      if (!mounted || g != _generacion) return;
      setState(() {
        _lista = lista;
        _ventas = ventas;
        _politica = politica;
        final id =
            _actual?.id ??
            (!_seleccionAplicada ? widget.seleccionInicial : null);
        _seleccionAplicada = true;
        _actual = null;
        for (final c in lista) {
          if (c.id == id) _actual = c;
        }
      });
    } catch (e) {
      if (mounted && g == _generacion) {
        setState(() {
          _lista = [];
          _ventas = [];
          _actual = null;
          _error = '$e';
        });
      }
    } finally {
      if (mounted && g == _generacion) setState(() => _cargando = false);
    }
  }

  Future<void> _operar(Future<CambioPrenda> Function() operacion) async {
    if (_ocupado) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final c = await operacion();
      if (!mounted) return;
      setState(() {
        _actual = c;
        _entregada = false;
      });
      await _cargar();
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _solicitar(
    VentaDevolucionElegible v,
    VentaDevolucionDetalle l,
  ) async {
    final cantidad = TextEditingController(text: '1'),
        motivo = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Solicitar cambio'),
        content: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '${l.producto} · ${l.talla}/${l.color} · Máximo ${l.cantidadDisponible}',
              ),
              TextField(
                controller: cantidad,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cantidad a cambiar',
                ),
              ),
              TextField(
                controller: motivo,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Motivo del cambio',
                ),
              ),
            ],
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Enviar solicitud'),
          ),
        ],
      ),
    );
    final n = int.tryParse(cantidad.text), m = motivo.text.trim();
    cantidad.dispose();
    motivo.dispose();
    if (ok != true || !mounted) return;
    if (n == null || n < 1 || n > l.cantidadDisponible || m.length < 5) {
      setState(() => _error = 'Indica motivo y cantidad elegible.');
      return;
    }
    await _operar(
      () => CambioService.solicitar(v.ventaId, l.ventaDetalleId, n, m),
    );
  }

  Future<void> _opcionesDisponibles(CambioPrenda c) async {
    try {
      final o = await CambioService.opciones(c.id);
      if (mounted && _actual?.id == c.id) {
        setState(() {
          _opciones = o;
          _opcion = o.isEmpty ? null : o.first['id'] as int;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  Future<void> _aceptar(CambioPrenda c) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Aceptar reemplazo y diferencia'),
        content: Text(
          'Diferencia: ${_monto(c.diferencia)}. Positivo: pagar; negativo: reintegro. ¿Aceptas estas condiciones?',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Aceptar'),
          ),
        ],
      ),
    );
    if (ok == true && mounted) {
      await _operar(
        () => CambioService.accion(c.id, 'aceptar', {
          'version': c.version,
          'diferencia': c.diferencia!.toStringAsFixed(2),
        }),
      );
    }
  }

  Widget _boton(String texto, VoidCallback accion, {bool habilitado = true}) =>
      FilledButton(
        onPressed: _ocupado || !habilitado ? null : accion,
        child: Text(texto),
      );
  Widget _detalle(CambioPrenda c) {
    void accion(String a, Map<String, dynamic> b, {bool patch = false}) {
      _operar(() => CambioService.accion(c.id, a, b, patch: patch));
    }

    final version = {'version': c.version};
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Cambio ${c.id} · ${c.estado}',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            Text('Motivo: ${c.original.motivo}'),
            Text('Inspección: ${c.original.observacion ?? "Pendiente"}'),
            for (final l in c.original.detalles)
              Text(
                '${l.producto} · ${l.talla}/${l.color} · Aceptadas ${l.cantidadAceptada} · No vendibles ${l.cantidadNoVendible}',
              ),
            if (c.credito != null)
              Text('Crédito reconocido: ${_monto(c.credito)}'),
            if (_gestion && c.estado == 'SOLICITADO') ...[
              TextFormField(
                key: ValueKey('condicion-${c.id}'),
                decoration: const InputDecoration(
                  labelText: 'Condición / motivo del rechazo',
                ),
                maxLength: 500,
                onChanged: (v) => _condicion = v,
              ),
              TextFormField(
                key: ValueKey('no-vendibles-${c.id}'),
                initialValue: '0',
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Unidades no vendibles',
                ),
                onChanged: (v) => _noVendibles = int.tryParse(v) ?? -1,
              ),
              CheckboxListTile(
                value: _recibida,
                onChanged: (v) => setState(() => _recibida = v ?? false),
                title: const Text('Confirmo recepción física e inspección'),
              ),
              Wrap(
                spacing: 8,
                children: [
                  _boton(
                    'Aceptar cambio inspeccionado',
                    () => accion('revision', {
                      ...version,
                      'aceptar': true,
                      'recepcion_confirmada': _recibida,
                      'no_vendibles': _noVendibles,
                      'condicion': _condicion,
                    }, patch: true),
                    habilitado: _recibida,
                  ),
                  _boton(
                    'Rechazar cambio',
                    () => accion('revision', {
                      ...version,
                      'aceptar': false,
                      'no_vendibles': 0,
                      'condicion': _condicion,
                    }, patch: true),
                  ),
                ],
              ),
            ],
            if (!_gestion && ['APROBADO', 'COTIZADO'].contains(c.estado)) ...[
              _boton(
                'Consultar reemplazos disponibles',
                () => _opcionesDisponibles(c),
              ),
              if (_opciones.isEmpty)
                const Text(
                  'Consulta disponibilidad o continúa por devolución.',
                ),
              if (_opciones.isNotEmpty) ...[
                DropdownButtonFormField<int>(
                  isExpanded: true,
                  initialValue: _opcion,
                  decoration: const InputDecoration(
                    labelText: 'Prenda de reemplazo',
                  ),
                  items: _opciones
                      .map(
                        (o) => DropdownMenuItem(
                          value: o['id'] as int,
                          child: Text(
                            '${o['producto']} · ${o['talla']}/${o['color']} · Bs ${o['precio']}',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _opcion = v),
                ),
                _boton(
                  'Cotizar reemplazo',
                  () =>
                      accion('cotizar', {...version, 'reemplazo_id': _opcion}),
                  habilitado: _opcion != null,
                ),
              ],
              _boton('Continuar por devolución', () async {
                final ok = await showDialog<bool>(
                  context: context,
                  builder: (ctx) => AlertDialog(
                    title: const Text('Continuar por devolución'),
                    content: const Text(
                      'La solicitud pasará a devoluciones para aceptar el importe y procesar el reintegro. ¿Deseas continuar?',
                    ),
                    actions: [
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, false),
                        child: const Text('Volver'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.pop(ctx, true),
                        child: const Text('Continuar'),
                      ),
                    ],
                  ),
                );
                if (ok == true && mounted) accion('devolucion', version);
              }),
            ],
            if (c.reemplazo != null)
              Text(
                'Reemplazo: ${c.reemplazo!['producto']} · ${c.reemplazo!['talla']}/${c.reemplazo!['color']} · ${_monto(c.precioReemplazo)} por prenda',
              ),
            if (c.diferencia != null)
              Text(
                'Diferencia: ${_monto(c.diferencia)} (positivo: pagar; negativo: reintegro)',
              ),
            if (!_gestion && c.estado == 'COTIZADO')
              _boton('Aceptar reemplazo y diferencia', () => _aceptar(c)),
            if (!_gestion && c.estado == 'ESPERA_PAGO') ...[
              if (c.pago == null)
                Wrap(
                  spacing: 8,
                  children: [
                    _boton(
                      'Pagar diferencia con QR',
                      () => accion('pago', {...version, 'medio': 'QR_BCP'}),
                    ),
                    _boton(
                      'Pagar diferencia con Stripe',
                      () => accion('pago', {...version, 'medio': 'STRIPE'}),
                    ),
                  ],
                ),
              if (c.pago != null) ...[
                Text(
                  'Pago ${c.pago!['id']}: ${c.pago!['estado']} · Bs ${c.pago!['monto_total']}',
                ),
                if (c.pago!['simulable'] == true) ...[
                  const Text('Pago simulado de prueba. No mueve dinero real.'),
                  _boton('Simular pago de diferencia aprobado', () async {
                    try {
                      await CambioService.simular(c.pago!);
                      await _cargar();
                    } catch (e) {
                      if (mounted) setState(() => _error = '$e');
                    }
                  }),
                ] else if (c.pago!['checkout_url'] != null)
                  _boton(
                    'Abrir pago de diferencia',
                    () =>
                        launchUrl(Uri.parse(c.pago!['checkout_url'] as String)),
                  ),
              ],
            ],
            if (_gestion && c.estado == 'ESPERA_REINTEGRO') ...[
              const Text('El excedente se reintegra por el medio original.'),
              if (c.original.metodoPagoOriginal == 'EFECTIVO' &&
                  c.original.proveedorPagoOriginal == null) ...[
                TextField(
                  decoration: const InputDecoration(
                    labelText: 'Referencia del recibo de efectivo',
                  ),
                  onChanged: (v) => _referencia = v,
                ),
                _boton(
                  'Registrar entrega del excedente en efectivo',
                  () =>
                      accion('reintegro-efectivo', {'referencia': _referencia}),
                ),
              ] else
                _boton(
                  'Procesar reintegro del excedente',
                  () => accion('reintegro', {}),
                ),
            ],
            if (_gestion && c.estado == 'LISTO') ...[
              CheckboxListTile(
                value: _entregada,
                onChanged: (v) => setState(() => _entregada = v ?? false),
                title: const Text('Confirmo entrega física del reemplazo'),
              ),
              _boton(
                'Completar cambio y emitir comprobante',
                () => accion('completar', {
                  ...version,
                  'entrega_confirmada': _entregada,
                }),
                habilitado: _entregada,
              ),
            ],
            if (!_gestion &&
                [
                  'SOLICITADO',
                  'APROBADO',
                  'COTIZADO',
                  'ESPERA_PAGO',
                ].contains(c.estado))
              _boton('Desistir del cambio', () => accion('cancelar', version)),
            if (c.estado == 'DEVOLUCION')
              _boton(
                'Abrir devoluciones',
                () => Navigator.push(
                  context,
                  MaterialPageRoute(builder: (_) => const DevolucionesScreen()),
                ),
              ),
            if (c.comprobante != null)
              Text(
                'Comprobante ${c.comprobante!['codigo']} · crédito Bs ${c.comprobante!['credito']} · diferencia Bs ${c.comprobante!['diferencia']}',
              ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final personal = context.watch<AuthProvider>().esPersonalDevoluciones;
    return Scaffold(
      appBar: AppBar(
        title: Text(_gestion ? 'Gestión de cambios' : 'Mis cambios'),
        actions: [
          IconButton(
            onPressed: _cargar,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar cambios',
          ),
        ],
      ),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                if (personal)
                  TextButton(
                    onPressed: () {
                      setState(() {
                        _gestion = !_gestion;
                        _actual = null;
                      });
                      _cargar();
                    },
                    child: Text(
                      _gestion ? 'Ver mis cambios' : 'Gestionar sucursal',
                    ),
                  ),
                if (_error != null)
                  Text(_error!, style: const TextStyle(color: Colors.red)),
                if (!_gestion) ...[
                  Text(
                    _politica?['cambios_habilitados'] == true
                        ? 'Plazo: ${_politica!['plazo_cambios']} días. ${_politica!['condiciones_cambios']}'
                        : 'La empresa no habilitó cambios.',
                  ),
                  const Text(
                    'El crédito usa el importe pagado por la prenda original. El reemplazo se cotiza por unidad, con el precio y promoción vigentes.',
                  ),
                  for (final v in _ventas)
                    Card(
                      child: Column(
                        children: [
                          Text(v.codigo),
                          for (final l in v.detalles)
                            if (l.cantidadDisponible > 0)
                              ListTile(
                                title: Text(
                                  '${l.producto} · ${l.talla}/${l.color}',
                                ),
                                subtitle: Text(
                                  'Disponibles ${l.cantidadDisponible}',
                                ),
                                trailing: TextButton(
                                  onPressed: _ocupado
                                      ? null
                                      : () => _solicitar(v, l),
                                  child: const Text('Solicitar cambio'),
                                ),
                              ),
                        ],
                      ),
                    ),
                ],
                if (_lista.isEmpty) const Text('No hay solicitudes de cambio.'),
                for (final c in _lista)
                  Card(
                    child: ListTile(
                      title: Text('Cambio ${c.id} · ${c.estado}'),
                      subtitle: Text(c.original.ventaCodigo),
                      onTap: () => setState(() {
                        _actual = c;
                        _opciones = [];
                        _opcion = null;
                        _condicion = '';
                        _noVendibles = 0;
                        _recibida = false;
                        _entregada = false;
                        _referencia = '';
                      }),
                    ),
                  ),
                if (_actual != null) _detalle(_actual!),
              ],
            ),
    );
  }
}
