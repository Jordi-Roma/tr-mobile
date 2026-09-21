import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../models/reserva_models.dart';
import '../../providers/catalogo_provider.dart';
import '../../providers/reserva_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/stock_badge.dart';
import 'reserva_detalle_screen.dart';

class ReservasAdminScreen extends StatefulWidget {
  const ReservasAdminScreen({super.key});

  @override
  State<ReservasAdminScreen> createState() => _ReservasAdminScreenState();
}

class _ReservasAdminScreenState extends State<ReservasAdminScreen> {
  String? _filtroEstado;
  int? _filtroSucursalId;

  final List<String> _estados = [
    'PENDIENTE',
    'PREPARADA',
    'EN_ATENCION',
    'COMPLETADA',
    'CANCELADA',
    'VENCIDA',
  ];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _cargar();
      context.read<CatalogoProvider>().cargarSucursales();
    });
  }

  void _cargar() {
    context.read<ReservaProvider>().cargarReservasAdmin(
          estado: _filtroEstado,
          sucursalId: _filtroSucursalId,
        );
  }

  void _abrirCambioEstado(ReservaResponse reserva) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Text(
                'Cambiar Estado - ${reserva.codigo}',
                style: const TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 20,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 6),
              Text(
                'Cliente: ${reserva.cliente ?? "Desconocido"} • Total: Bs. ${reserva.total}',
                style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              const Divider(),
              const SizedBox(height: 12),
              ..._estados.map((estado) {
                final isCurrent = reserva.estado == estado;
                return ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: StockBadge.fromEstado(estado),
                  title: Text(
                    estado.replaceAll('_', ' '),
                    style: TextStyle(
                      fontWeight: isCurrent ? FontWeight.bold : FontWeight.normal,
                      color: isCurrent ? AppColors.primary : AppColors.textPrimary,
                    ),
                  ),
                  trailing: isCurrent ? const Icon(Icons.check, color: AppColors.primary) : null,
                  onTap: () async {
                    Navigator.of(ctx).pop();
                    final ok = await context.read<ReservaProvider>().cambiarEstado(reserva.id, estado);
                    if (ok && mounted) {
                      _cargar();
                      ScaffoldMessenger.of(context).showSnackBar(
                        SnackBar(
                          content: Text('Estado actualizado a ${estado.replaceAll("_", " ")}'),
                          backgroundColor: AppColors.success,
                        ),
                      );
                    }
                  },
                );
              }),
            ],
          ),
        );
      },
    );
  }

  @override
  Widget build(BuildContext context) {
    final reservaProv = context.watch<ReservaProvider>();
    final catalogo = context.watch<CatalogoProvider>();
    final currencyFormat = NumberFormat.currency(locale: 'es_BO', symbol: 'Bs. ');

    return Scaffold(
      appBar: AppBar(
        title: const Text('Gestión de Reservas'),
      ),
      body: SafeArea(
        child: Column(
          children: [
            // Filtros por Estado (Chips)
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: Row(
                children: [
                  FilterChip(
                    label: const Text('Todos'),
                    selected: _filtroEstado == null,
                    selectedColor: AppColors.primary,
                    labelStyle: TextStyle(
                      color: _filtroEstado == null ? Colors.white : AppColors.textPrimary,
                      fontSize: 12,
                    ),
                    onSelected: (_) {
                      setState(() => _filtroEstado = null);
                      _cargar();
                    },
                  ),
                  const SizedBox(width: 8),
                  ..._estados.map((estado) {
                    final selected = _filtroEstado == estado;
                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: FilterChip(
                        label: Text(estado.replaceAll('_', ' ')),
                        selected: selected,
                        selectedColor: AppColors.getStatusColor(estado),
                        labelStyle: TextStyle(
                          color: selected ? Colors.white : AppColors.textPrimary,
                          fontSize: 12,
                        ),
                        onSelected: (_) {
                          setState(() => _filtroEstado = selected ? null : estado);
                          _cargar();
                        },
                      ),
                    );
                  }),
                ],
              ),
            ),

            // Filtro por Sucursal (para Administrador)
            if (catalogo.sucursales.isNotEmpty)
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
                child: Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    color: AppColors.surface,
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.border),
                  ),
                  child: DropdownButtonHideUnderline(
                    child: DropdownButton<int?>(
                      value: _filtroSucursalId,
                      isExpanded: true,
                      hint: const Text('Filtrar por sucursal', style: TextStyle(fontSize: 13)),
                      items: [
                        const DropdownMenuItem<int?>(
                          value: null,
                          child: Text('Todas las sucursales', style: TextStyle(fontSize: 13)),
                        ),
                        ...catalogo.sucursales.map((s) {
                          return DropdownMenuItem<int?>(
                            value: s.id,
                            child: Text('${s.nombre} (${s.ciudad})', style: const TextStyle(fontSize: 13)),
                          );
                        }),
                      ],
                      onChanged: (val) {
                        setState(() => _filtroSucursalId = val);
                        _cargar();
                      },
                    ),
                  ),
                ),
              ),

            const SizedBox(height: 8),

            // Lista de Reservas
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async => _cargar(),
                child: Builder(
                  builder: (context) {
                    if (reservaProv.cargando && reservaProv.reservasAdmin.isEmpty) {
                      return const Center(child: CircularProgressIndicator());
                    }

                    if (reservaProv.reservasAdmin.isEmpty) {
                      return EmptyState(
                        icon: Icons.inventory_2_outlined,
                        title: 'No hay reservas registradas',
                        subtitle: 'No se encontraron reservas con los filtros aplicados.',
                        actionText: 'Limpiar Filtros',
                        onAction: () {
                          setState(() {
                            _filtroEstado = null;
                            _filtroSucursalId = null;
                          });
                          _cargar();
                        },
                      );
                    }

                    return ListView.separated(
                      padding: const EdgeInsets.all(16),
                      itemCount: reservaProv.reservasAdmin.length,
                      separatorBuilder: (context, index) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final reserva = reservaProv.reservasAdmin[index];
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
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        reserva.codigo,
                                        style: const TextStyle(
                                          fontWeight: FontWeight.w800,
                                          fontSize: 16,
                                          color: AppColors.primary,
                                        ),
                                      ),
                                      StockBadge.fromEstado(reserva.estado),
                                    ],
                                  ),
                                  const SizedBox(height: 8),
                                  if (reserva.cliente != null)
                                    Row(
                                      children: [
                                        const Icon(Icons.person_outline, size: 16, color: AppColors.textSecondary),
                                        const SizedBox(width: 6),
                                        Text(
                                          reserva.cliente!,
                                          style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600),
                                        ),
                                      ],
                                    ),
                                  const SizedBox(height: 4),
                                  Row(
                                    children: [
                                      const Icon(Icons.storefront_outlined, size: 16, color: AppColors.textSecondary),
                                      const SizedBox(width: 6),
                                      Text(
                                        '${reserva.sucursal} (${reserva.ciudad})',
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
                                          'Cita: ${reserva.fechaCita} · Anticipo: ${currencyFormat.format(reserva.montoReserva)}',
                                          style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                        ),
                                      ],
                                    ),
                                  ],
                                  const SizedBox(height: 12),
                                  const Divider(),
                                  const SizedBox(height: 8),
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      Text(
                                        currencyFormat.format(reserva.total),
                                        style: const TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
                                      ),
                                      ElevatedButton.icon(
                                        icon: const Icon(Icons.swap_horiz, size: 16),
                                        label: const Text('Cambiar Estado'),
                                        style: ElevatedButton.styleFrom(
                                          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                                          textStyle: const TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                                        ),
                                        onPressed: () => _abrirCambioEstado(reserva),
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
          ],
        ),
      ),
    );
  }
}
