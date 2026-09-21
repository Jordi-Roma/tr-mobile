import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/reserva_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reserva_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/stock_badge.dart';
import '../auth/login_screen.dart';
import 'reserva_detalle_screen.dart';

class MisReservasScreen extends StatefulWidget {
  final VoidCallback? onIrAlCatalogo;

  const MisReservasScreen({super.key, this.onIrAlCatalogo});

  @override
  State<MisReservasScreen> createState() => _MisReservasScreenState();
}

class _MisReservasScreenState extends State<MisReservasScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.estaAutenticado) {
        context.read<ReservaProvider>().cargarMisReservas();
      }
    });
  }

  void _confirmarCancelacion(ReservaResponse reserva) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar Reserva?'),
        content: Text('¿Estás seguro de cancelar la reserva ${reserva.codigo}? El stock será liberado.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('No, Mantener'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final ok = await context.read<ReservaProvider>().cancelarReserva(reserva.id);
              if (ok && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reserva cancelada correctamente.'),
                    backgroundColor: AppColors.success,
                  ),
                );
              }
            },
            child: const Text('Sí, Cancelar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final reservaProv = context.watch<ReservaProvider>();
    final currencyFormat = NumberFormat.currency(locale: 'es_BO', symbol: 'Bs. ');

    if (!auth.estaAutenticado) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mis Reservas')),
        body: EmptyState(
          icon: Icons.calendar_today_outlined,
          title: 'Inicia sesión para ver tus reservas',
          subtitle: 'Consulta el estado de tus apartados de prendas y prepara tu visita a tienda.',
          actionText: 'Iniciar Sesión',
          onAction: () {
            Navigator.of(context).push(
              MaterialPageRoute(builder: (_) => const LoginScreen()),
            );
          },
        ),
      );
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Reservas'),
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: () => reservaProv.cargarMisReservas(),
          child: Builder(
            builder: (context) {
              if (reservaProv.cargando && reservaProv.misReservas.isEmpty) {
                return const Center(child: CircularProgressIndicator());
              }

              if (reservaProv.misReservas.isEmpty) {
                return EmptyState(
                  icon: Icons.event_busy_outlined,
                  title: 'No tienes reservas registradas',
                  subtitle: 'Agrega prendas a tu carrito y confirma una reserva para retirarlas en sucursal.',
                  actionText: 'Ir a la Tienda',
                  onAction: widget.onIrAlCatalogo,
                );
              }

              return ListView.separated(
                padding: const EdgeInsets.all(16),
                itemCount: reservaProv.misReservas.length,
                separatorBuilder: (context, index) => const SizedBox(height: 12),
                itemBuilder: (context, index) {
                  final reserva = reservaProv.misReservas[index];
                  return Card(
                    child: InkWell(
                      borderRadius: BorderRadius.circular(12),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => ReservaDetalleScreen(reservaId: reserva.id),
                          ),
                        );
                      },
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            // Código y Badge de Estado
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text(
                                  reserva.codigo,
                                  style: const TextStyle(
                                    fontWeight: FontWeight.w800,
                                    fontSize: 16,
                                    color: AppColors.primary,
                                    letterSpacing: 0.5,
                                  ),
                                ),
                                StockBadge.fromEstado(reserva.estado),
                              ],
                            ),
                            const SizedBox(height: 8),

                            // Sucursal y Fecha
                            Row(
                              children: [
                                const Icon(Icons.store_outlined, size: 16, color: AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Expanded(
                                  child: Text(
                                    '${reserva.sucursal} (${reserva.ciudad})',
                                    style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w500),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 4),
                            Row(
                              children: [
                                const Icon(Icons.access_time, size: 16, color: AppColors.textSecondary),
                                const SizedBox(width: 6),
                                Text(
                                  reserva.fechaReserva.substring(0, 10),
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                            if (reserva.fechaCita != null && reserva.fechaCita!.isNotEmpty) ...[
                              const SizedBox(height: 4),
                              Row(
                                children: [
                                  const Icon(Icons.event_available_outlined, size: 16, color: AppColors.textSecondary),
                                  const SizedBox(width: 6),
                                  Text(
                                    'Cita: ${reserva.fechaCita}',
                                    style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                  ),
                                ],
                              ),
                            ],
                            const SizedBox(height: 12),
                            const Divider(),
                            const SizedBox(height: 10),

                            // Total y Botón de Cancelar (si está pendiente)
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    const Text('Valor prendas:', style: TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                                    Text(
                                      currencyFormat.format(reserva.total),
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                        color: AppColors.primary,
                                      ),
                                    ),
                                    Text(
                                      'Anticipo ${currencyFormat.format(reserva.montoReserva)}',
                                      style: const TextStyle(fontSize: 11, color: AppColors.textSecondary),
                                    ),
                                  ],
                                ),
                                Row(
                                  children: [
                                    if (reserva.puedeCancelar)
                                      TextButton(
                                        onPressed: () => _confirmarCancelacion(reserva),
                                        child: const Text(
                                          'Cancelar',
                                          style: TextStyle(color: AppColors.danger, fontSize: 13),
                                        ),
                                      ),
                                    const Icon(Icons.chevron_right, color: AppColors.textSecondary),
                                  ],
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ),
    );
  }
}
