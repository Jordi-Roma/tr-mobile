import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';

import '../../core/constants/app_colors.dart';
import '../../core/session/contexto_sesion.dart';
import '../../models/delivery_models.dart';
import '../../services/delivery_service.dart';

class DetalleDeliveryScreen extends StatefulWidget {
  final int deliveryId;
  final bool esStaff;
  const DetalleDeliveryScreen({
    super.key,
    required this.deliveryId,
    required this.esStaff,
  });
  @override
  State<DetalleDeliveryScreen> createState() => _DetalleDeliveryScreenState();
}

class _DetalleDeliveryScreenState extends State<DetalleDeliveryScreen> {
  late Future<DeliveryDetalle?> _future;
  String? _errorCarga;
  final _observacion = TextEditingController();
  DeliveryDetalle? _actual;
  String _estado = '';
  bool _ocupado = false, _recepcion = false, _sesionCambio = false;
  int _generacion = 0;
  @override
  void initState() {
    super.initState();
    _generacion = ContextoSesion.instance.generacion;
    ContextoSesion.instance.addListener(_cambio);
    _future = _cargar();
  }

  @override
  void dispose() {
    ContextoSesion.instance.removeListener(_cambio);
    _observacion.dispose();
    super.dispose();
  }

  void _cambio() {
    if (mounted && _generacion != ContextoSesion.instance.generacion) {
      setState(() {
        _sesionCambio = true;
        _actual = null;
      });
    }
  }

  Future<DeliveryDetalle?> _cargar() async {
    _errorCarga = null;
    try {
      final d = widget.esStaff
          ? await DeliveryService.obtenerDelivery(widget.deliveryId)
          : await DeliveryService.obtenerMiDelivery(widget.deliveryId);
      _actual = d;
      _estado = d.estado;
      return d;
    } catch (e) {
      _actual = null;
      _errorCarga = e.toString();
      return null;
    }
  }

  void _recargar() {
    if (_ocupado) return;
    setState(() {
      _actual = null;
      _future = _cargar();
    });
  }

  Future<void> _guardar({bool incidencia = false}) async {
    final d = _actual;
    if (d == null || _ocupado) return;
    setState(() => _ocupado = true);
    try {
      final r = incidencia
          ? await DeliveryService.incidencia(
              d.id,
              d.version,
              _observacion.text.trim(),
              d.incidenciaAbierta,
            )
          : await DeliveryService.actualizarEstado(
              deliveryId: d.id,
              estado: _estado,
              version: d.version,
              observacion: _observacion.text.trim(),
              recepcionConfirmada: _recepcion,
            );
      if (!mounted || _sesionCambio) return;
      setState(() {
        _actual = r;
        _estado = r.estado;
        _recepcion = false;
        _observacion.clear();
        _future = Future.value(r);
      });
    } catch (e) {
      if (mounted && !_sesionCambio) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('$e. Actualiza el seguimiento antes de reintentar.'),
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Seguimiento de entrega'),
      actions: [
        IconButton(
          onPressed: _ocupado || _sesionCambio ? null : _recargar,
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualizar seguimiento',
        ),
      ],
    ),
    body: _sesionCambio
        ? const Center(
            child: Text(
              'La sesión cambió. Vuelve al historial de tu cuenta actual.',
            ),
          )
        : FutureBuilder<DeliveryDetalle?>(
            future: _future,
            builder: (context, snapshot) {
              if (snapshot.connectionState == ConnectionState.waiting) {
                return const Center(child: CircularProgressIndicator());
              }
              if (snapshot.hasError || snapshot.data == null) {
                return Center(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        'No se pudo consultar la entrega: ${_errorCarga ?? snapshot.error}',
                      ),
                      TextButton(
                        onPressed: _recargar,
                        child: const Text('Reintentar'),
                      ),
                    ],
                  ),
                );
              }
              final d = snapshot.data!;
              final destino = LatLng(d.latitudEntrega, d.longitudEntrega);
              return ListView(
                padding: const EdgeInsets.all(16),
                children: [
                  Text(
                    'Entrega #${d.id} · ${d.estado}',
                    style: Theme.of(context).textTheme.headlineSmall,
                  ),
                  Text(d.direccionEntrega),
                  if (d.referencia != null) Text('Referencia: ${d.referencia}'),
                  Text(
                    '${d.distanciaKm.toStringAsFixed(2)} km · ${d.tiempoEstimadoMin} min · Bs ${d.costoDelivery.toStringAsFixed(2)} de envío',
                  ),
                  Text(
                    'Total pagado de compra y envío: Bs ${d.totalVenta.toStringAsFixed(2)}',
                  ),
                  if (!d.pagoConfirmado)
                    const Text(
                      'No se puede despachar: compra y envío sin pago confirmado.',
                    ),
                  if (d.incidenciaAbierta)
                    const Card(
                      child: Padding(
                        padding: EdgeInsets.all(12),
                        child: Text(
                          'Hay una incidencia pendiente de coordinación. Cancelar el envío no confirma que el dinero ya se reembolsó.',
                        ),
                      ),
                    ),
                  if (d.ruta.isNotEmpty)
                    SizedBox(
                      height: 260,
                      child: FlutterMap(
                        options: MapOptions(
                          initialCenter: destino,
                          initialZoom: 13,
                        ),
                        children: [
                          TileLayer(
                            urlTemplate: 'https://tile.openstreetmap.org/{z}/{x}/{y}.png',
                            userAgentPackageName: 'com.stylear.mobile',
                          ),
                          PolylineLayer(
                            polylines: [
                              Polyline(
                                points: d.ruta
                                    .map((p) => LatLng(p[1], p[0]))
                                    .toList(),
                                strokeWidth: 4,
                                color: AppColors.primary,
                              ),
                            ],
                          ),
                          MarkerLayer(
                            markers: [
                              Marker(
                                point: destino,
                                child: const Icon(
                                  Icons.home,
                                  color: AppColors.danger,
                                ),
                              ),
                              Marker(
                                point: LatLng(d.ruta.first[1], d.ruta.first[0]),
                                child: const Icon(
                                  Icons.storefront,
                                  color: AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                        ],
                      ),
                    )
                  else
                    const Text(
                      'Esta entrega anterior no conserva un trazado de ruta.',
                    ),
                  const Text(
                    'La ruta es la aceptada al comprar, no un rastreo del repartidor en tiempo real.',
                  ),
                  if (widget.esStaff && d.puedeGestionar)
                    Card(
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          children: [
                            const Text('Actualizar estado'),
                            DropdownButtonFormField<String>(
                              key: ValueKey('estado-${d.version}'),
                              initialValue: _estado,
                              decoration: const InputDecoration(
                                labelText: 'Estado',
                              ),
                              items: [d.estado, ...d.transiciones]
                                  .map(
                                    (s) => DropdownMenuItem(
                                      value: s,
                                      child: Text(s),
                                    ),
                                  )
                                  .toList(),
                              onChanged: _ocupado
                                  ? null
                                  : (s) =>
                                        setState(() => _estado = s ?? d.estado),
                            ),
                            TextField(
                              controller: _observacion,
                              maxLength: 500,
                              maxLines: 3,
                              decoration: const InputDecoration(
                                labelText: 'Observación',
                                helperText: 'Al menos cinco caracteres para una incidencia o cancelación.',
                              ),
                              onChanged: (_) => setState(() {}),
                            ),
                            if (_estado == 'ENTREGADO')
                              CheckboxListTile(
                                value: _recepcion,
                                onChanged: _ocupado
                                    ? null
                                    : (v) => setState(
                                        () => _recepcion = v ?? false,
                                      ),
                                title: const Text(
                                  'Confirmo que la entrega física se realizó',
                                ),
                              ),
                            ElevatedButton(
                              onPressed:
                                  _ocupado ||
                                      !d.transiciones.contains(_estado) ||
                                      (_estado == 'ENTREGADO' &&
                                          (!_recepcion || d.incidenciaAbierta))
                                  ? null
                                  : () => _guardar(),
                              child: const Text('Guardar estado'),
                            ),
                            TextButton(
                              onPressed:
                                  _ocupado ||
                                      _observacion.text.trim().length < 5
                                  ? null
                                  : () => _guardar(incidencia: true),
                              child: Text(
                                d.incidenciaAbierta
                                    ? 'Resolver incidencia'
                                    : 'Registrar incidencia',
                              ),
                            ),
                          ],
                        ),
                      ),
                    ),
                  const SizedBox(height: 16),
                  Text(
                    'Historial del seguimiento',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  for (final h in d.historial)
                    Card(
                      child: ListTile(
                        title: Text('${h['tipo']} · ${h['estado_nuevo']}'),
                        subtitle: Text(
                          '${h['fecha']}\n${h['observacion'] ?? ''}',
                        ),
                      ),
                    ),
                  if (d.historial.isEmpty)
                    const Text(
                      'No hay eventos registrados para esta entrega anterior.',
                    ),
                ],
              );
            },
          ),
  );
}
