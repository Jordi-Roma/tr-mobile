import 'solicitud_cambio_dialog.dart';
import 'selector_variante_cambio.dart';

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
  int? _opcion, _adicional;
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
        _opcion = _adicional = null;
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
    final elegida = await showDialog<SolicitudCambioElegida>(
      context: context,
      builder: (_) => SolicitudCambioDialog(
        venta: v.ventaId,
        linea: l.ventaDetalleId,
        maximo: l.cantidadDisponible,
      ),
    );
    if (elegida == null || !mounted) return;
    await _operar(
      () => CambioService.solicitar(
        v.ventaId,
        l.ventaDetalleId,
        elegida.cantidad,
        elegida.motivo,
        reemplazoId: elegida.variante,
      ),
    );
  }

  Future<void> _opcionesDisponibles(CambioPrenda c) async {
    try {
      final o = await CambioService.opciones(c.id);
      if (mounted && _actual?.id == c.id) {
        setState(() {
          _opciones = o;
          final reemplazos = _reemplazos(c);
          _opcion = reemplazos.any((v) => v['id'] == c.reemplazoId)
              ? c.reemplazoId
              : null;
          _adicional = _adicionales(c).any((v) => v['id'] == c.adicionalId)
              ? c.adicionalId
              : null;
        });
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    }
  }

  List<Map<String, dynamic>> _reemplazos(CambioPrenda c) =>
      _opciones.where((v) => (v['disponible'] as int) >= c.cantidad).toList();

  List<Map<String, dynamic>> _adicionales(CambioPrenda c) {
    final elegida = _reemplazos(c).where((v) => v['id'] == _opcion).firstOrNull;
    if (elegida == null) return [];
    final precio = double.parse('${elegida['precio']}');
    if ((precio * 100).round() * c.cantidad >=
        ((c.credito ?? 0) * 100).round()) {
      return [];
    }
    return _opciones
        .where(
          (v) => v['id'] != _opcion || (v['disponible'] as int) > c.cantidad,
        )
        .toList();
  }

  DropdownMenuItem<int> _opcionPrenda(Map<String, dynamic> o) =>
      DropdownMenuItem(
        value: o['id'] as int,
        child: Text(
          '${o['producto']} · ${o['talla']}/${o['color']} · Bs ${o['precio']}',
          overflow: TextOverflow.ellipsis,
        ),
      );

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
    final reemplazos = _reemplazos(c);
    final adicionales = _adicionales(c);
    final cotizacionEditada =
        _opcion != null &&
        (_opcion != c.reemplazoId || _adicional != c.adicionalId);
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
            if (c.estado == 'SOLICITADO' && c.reemplazo != null)
              const Text(
                'Reemplazo solicitado y diferencia estimada. Se validarán después de inspeccionar la prenda.',
              ),
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
              if (c.reemplazoId != null)
                _boton(
                  c.estado == 'APROBADO'
                      ? 'Continuar con el reemplazo solicitado'
                      : 'Actualizar precio y disponibilidad',
                  () => accion('cotizar', {
                    ...version,
                    'reemplazo_id': c.reemplazoId,
                    'adicional_id': c.adicionalId,
                  }),
                ),

              _boton(
                c.reemplazoId != null
                    ? 'Modificar reemplazo o agregar otra prenda (opcional)'
                    : 'Elegir reemplazo disponible',
                () => _opcionesDisponibles(c),
              ),
              if (reemplazos.isEmpty)
                const Text(
                  'El reemplazo solicitado se muestra abajo. Puedes modificarlo si necesitas otra opción.',
                ),
              if (reemplazos.isNotEmpty) ...[
                SelectorVarianteCambio(
                  opciones: reemplazos,
                  seleccion: _opcion,
                  onChanged: (v) => setState(() {
                    _opcion = v;
                    _adicional = null;
                  }),
                ),
                if (adicionales.isNotEmpty)
                  DropdownButtonFormField<int>(
                    key: ValueKey((c.id, _opcion, _adicional)),
                    isExpanded: true,
                    initialValue: _adicional ?? 0,
                    decoration: const InputDecoration(
                      labelText: 'Usar el saldo en una prenda adicional',
                    ),
                    items: [
                      const DropdownMenuItem(
                        value: 0,
                        child: Text('Recibir el reintegro de la diferencia'),
                      ),
                      ...adicionales.map(_opcionPrenda),
                    ],
                    onChanged: (v) =>
                        setState(() => _adicional = v == 0 ? null : v),
                  ),
                _boton(
                  'Cotizar reemplazo',
                  () => accion('cotizar', {
                    ...version,
                    'reemplazo_id': _opcion,
                    'adicional_id': _adicional,
                  }),
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
            if (c.adicional case final adicional?)
              Text(
                'Prenda adicional: ${adicional['producto']} · ${adicional['talla']}/${adicional['color']} · ${_monto(c.precioAdicional)}',
              ),
            if (!_gestion && c.estado == 'COTIZADO')
              _boton(
                (c.diferencia ?? 0) > 0
                    ? 'Confirmar diferencia y continuar al pago'
                    : (c.diferencia ?? 0) < 0
                    ? 'Confirmar reintegro a mi favor'
                    : 'Confirmar cambio sin diferencia',
                () => _aceptar(c),
                habilitado: !cotizacionEditada,
              ),
            if (!_gestion && c.estado == 'ESPERA_REINTEGRO')
              const Text(
                'Reintegro a tu favor pendiente. La tienda debe procesarlo por el medio original y confirmar la devolución del dinero.',
              ),
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
            if (_gestion &&
                ['LISTO', 'ESPERA_PAGO', 'ESPERA_REINTEGRO'].contains(c.estado))
              _boton(
                'Registrar falta de reemplazo y continuar por devolución',
                () async {
                  final confirmar = await showDialog<bool>(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('Reemplazo no disponible'),
                      content: const Text(
                        'Confirma que las prendas del cambio no se pueden entregar.',
                      ),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.pop(ctx, false),
                          child: const Text('Volver'),
                        ),
                        FilledButton(
                          onPressed: () => Navigator.pop(ctx, true),
                          child: const Text('Continuar por devolución'),
                        ),
                      ],
                    ),
                  );
                  if (confirmar == true && mounted) {
                    accion('sin-reemplazo', version);
                  }
                },
              ),
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
                'Comprobante ${c.comprobante!['codigo']} · venta original ${c.original.ventaCodigo} · crédito Bs ${c.comprobante!['credito']} · diferencia Bs ${c.comprobante!['diferencia']}',
              ),
            if (c.comprobante?['nota_venta_numero'] case final numero?)
              Text('Nota de venta original N.º $numero'),
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
                        ? 'Plazo: ${_politica!['plazo_cambios']} días desde la compra en tienda o la entrega a domicilio. ${_politica!['condiciones_cambios']}'
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
                        _opcion = _adicional = null;
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
