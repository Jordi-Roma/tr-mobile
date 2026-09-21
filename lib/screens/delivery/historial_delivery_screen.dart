import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/delivery_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/delivery_service.dart';
import 'detalle_delivery_screen.dart';

class HistorialDeliveryScreen extends StatefulWidget {
  const HistorialDeliveryScreen({super.key});

  @override
  State<HistorialDeliveryScreen> createState() => _HistorialDeliveryScreenState();
}

class _HistorialDeliveryScreenState extends State<HistorialDeliveryScreen> {
  late Future<List<DeliveryItem>> _future;

  bool _esStaff(BuildContext context) {
    final auth = context.read<AuthProvider>();
    final roles = auth.usuario?.roles ?? [];
    return auth.esAdminOEncargado || roles.contains('CAJERO');
  }

  @override
  void initState() {
    super.initState();
    _future = _cargar(context);
  }

  Future<List<DeliveryItem>> _cargar(BuildContext context) {
    return _esStaff(context) ? DeliveryService.listarDeliveries() : DeliveryService.listarMisDeliveries();
  }

  Future<void> _refrescar() async {
    setState(() {
      _future = _cargar(context);
    });
    await _future;
  }

  @override
  Widget build(BuildContext context) {
    final esStaff = _esStaff(context);
    return Scaffold(
      appBar: AppBar(title: Text(esStaff ? 'Historial de delivery' : 'Mis deliveries')),
      body: RefreshIndicator(
        onRefresh: _refrescar,
        child: FutureBuilder<List<DeliveryItem>>(
          future: _future,
          builder: (context, snapshot) {
            if (snapshot.connectionState == ConnectionState.waiting) {
              return const Center(child: CircularProgressIndicator());
            }
            if (snapshot.hasError) {
              return ListView(
                padding: const EdgeInsets.all(24),
                children: [
                  const Icon(Icons.error_outline, color: AppColors.danger, size: 44),
                  const SizedBox(height: 12),
                  Text(
                    snapshot.error.toString(),
                    textAlign: TextAlign.center,
                    style: const TextStyle(color: AppColors.textSecondary),
                  ),
                ],
              );
            }
            final items = snapshot.data ?? [];
            if (items.isEmpty) {
              return const Center(
                child: Text(
                  'No hay deliveries para mostrar.',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              );
            }
            return ListView.separated(
              padding: const EdgeInsets.all(16),
              itemBuilder: (context, index) {
                final delivery = items[index];
                return Card(
                  child: ListTile(
                    leading: CircleAvatar(
                      backgroundColor: AppColors.accentSoft,
                      child: Icon(_iconoEstado(delivery.estado), color: AppColors.primary),
                    ),
                    title: Text(delivery.ventaCodigo ?? 'Venta #${delivery.ventaId}'),
                    subtitle: Text(
                      '${delivery.direccionEntrega}\n${delivery.distanciaKm.toStringAsFixed(2)} km · Bs ${delivery.costoDelivery.toStringAsFixed(2)}',
                    ),
                    isThreeLine: true,
                    trailing: Chip(
                      label: Text(delivery.estado),
                      visualDensity: VisualDensity.compact,
                    ),
                    onTap: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => DetalleDeliveryScreen(deliveryId: delivery.id, esStaff: esStaff),
                        ),
                      );
                    },
                  ),
                );
              },
              separatorBuilder: (_, index) => const SizedBox(height: 10),
              itemCount: items.length,
            );
          },
        ),
      ),
    );
  }

  IconData _iconoEstado(String estado) {
    switch (estado.toUpperCase()) {
      case 'ENTREGADO':
        return Icons.check_circle_outline;
      case 'EN_CAMINO':
        return Icons.local_shipping_outlined;
      case 'CANCELADO':
        return Icons.cancel_outlined;
      default:
        return Icons.schedule_outlined;
    }
  }
}
