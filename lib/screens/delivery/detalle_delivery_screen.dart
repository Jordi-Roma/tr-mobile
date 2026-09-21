import 'package:flutter/material.dart';
import 'package:flutter_map/flutter_map.dart';
import 'package:latlong2/latlong.dart';
import '../../core/constants/app_colors.dart';
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
  late Future<DeliveryDetalle> _future;
  final _observacionController = TextEditingController();
  String _estado = '';
  bool _guardando = false;

  @override
  void initState() {
    super.initState();
    _future = _cargar();
  }

  @override
  void dispose() {
    _observacionController.dispose();
    super.dispose();
  }

  Future<DeliveryDetalle> _cargar() async {
    final delivery = widget.esStaff
        ? await DeliveryService.obtenerDelivery(widget.deliveryId)
        : await DeliveryService.obtenerMiDelivery(widget.deliveryId);
    _estado = delivery.estado;
    return delivery;
  }

  Future<void> _actualizarEstado() async {
    setState(() => _guardando = true);
    try {
      final actualizado = await DeliveryService.actualizarEstado(
        deliveryId: widget.deliveryId,
        estado: _estado,
        observacion: _observacionController.text,
      );
      if (!mounted) return;
      setState(() {
        _future = Future.value(actualizado);
      });
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Estado actualizado correctamente.')),
      );
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle delivery')),
      body: FutureBuilder<DeliveryDetalle>(
        future: _future,
        builder: (context, snapshot) {
          if (snapshot.connectionState == ConnectionState.waiting) {
            return const Center(child: CircularProgressIndicator());
          }
          if (snapshot.hasError) {
            return Center(child: Text(snapshot.error.toString()));
          }
          final delivery = snapshot.data!;
          final destino = LatLng(delivery.latitudEntrega, delivery.longitudEntrega);
          final origen = LatLng(
            delivery.sucursalLatitud ?? delivery.latitudEntrega,
            delivery.sucursalLongitud ?? delivery.longitudEntrega,
          );

          return ListView(
            padding: const EdgeInsets.all(16),
            children: [
              Card(
                color: AppColors.primary,
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        delivery.estado == 'ENTREGADO' ? '¡Tu pedido ha sido entregado!' : 'Seguimiento de delivery',
                        style: const TextStyle(
                          color: Colors.white,
                          fontSize: 22,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        delivery.direccionEntrega,
                        style: const TextStyle(color: Colors.white70),
                      ),
                      const SizedBox(height: 12),
                      Chip(label: Text(delivery.estado)),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                height: 260,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
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
                          Polyline(points: [origen, destino], strokeWidth: 4, color: AppColors.primary),
                        ],
                      ),
                      MarkerLayer(
                        markers: [
                          Marker(
                            point: origen,
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.storefront, color: AppColors.primary, size: 34),
                          ),
                          Marker(
                            point: destino,
                            width: 40,
                            height: 40,
                            child: const Icon(Icons.home, color: AppColors.danger, size: 34),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 12),
              _InfoCard(delivery: delivery),
              if (widget.esStaff) ...[
                const SizedBox(height: 12),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text('Actualizar estado', style: TextStyle(fontWeight: FontWeight.bold)),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _estado.isEmpty ? delivery.estado : _estado,
                          items: const [
                            DropdownMenuItem(value: 'PENDIENTE', child: Text('Pendiente')),
                            DropdownMenuItem(value: 'EN_PREPARACION', child: Text('En preparación')),
                            DropdownMenuItem(value: 'EN_CAMINO', child: Text('En camino')),
                            DropdownMenuItem(value: 'ENTREGADO', child: Text('Entregado')),
                            DropdownMenuItem(value: 'CANCELADO', child: Text('Cancelado')),
                          ],
                          onChanged: (value) => setState(() => _estado = value ?? delivery.estado),
                        ),
                        const SizedBox(height: 12),
                        TextField(
                          controller: _observacionController,
                          maxLines: 3,
                          decoration: const InputDecoration(labelText: 'Observación'),
                        ),
                        const SizedBox(height: 12),
                        ElevatedButton(
                          onPressed: _guardando ? null : _actualizarEstado,
                          child: Text(_guardando ? 'Guardando...' : 'Guardar estado'),
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ],
          );
        },
      ),
    );
  }
}

class _InfoCard extends StatelessWidget {
  final DeliveryDetalle delivery;

  const _InfoCard({required this.delivery});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            _row('Sucursal', delivery.sucursalNombre ?? '-'),
            _row('Dirección', delivery.direccionEntrega),
            _row('Referencia', delivery.referencia ?? '-'),
            _row('Distancia', '${delivery.distanciaKm.toStringAsFixed(2)} km'),
            _row('Tiempo estimado', '${delivery.tiempoEstimadoMin} min'),
            _row('Costo delivery', 'Bs ${delivery.costoDelivery.toStringAsFixed(2)}'),
            _row('Total venta', 'Bs ${delivery.totalVenta.toStringAsFixed(2)}'),
          ],
        ),
      ),
    );
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(child: Text(label, style: const TextStyle(color: AppColors.textSecondary))),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.right,
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          ),
        ],
      ),
    );
  }
}
