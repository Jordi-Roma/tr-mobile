import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import '../../core/constants/app_colors.dart';
import '../../models/reserva_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/reserva_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/stock_badge.dart';
import '../carrito/pago_stripe_screen.dart';

class ReservaDetalleScreen extends StatefulWidget {
  final int reservaId;

  const ReservaDetalleScreen({super.key, required this.reservaId});

  @override
  State<ReservaDetalleScreen> createState() => _ReservaDetalleScreenState();
}

class _ReservaDetalleScreenState extends State<ReservaDetalleScreen> {
  final _observacionVentaCtrl = TextEditingController();
  final Map<int, int> _cantidadesVenta = {};
  String _metodoPago = 'EFECTIVO';

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<ReservaProvider>().cargarReservaDetalle(widget.reservaId);
    });
  }

  @override
  void dispose() {
    _observacionVentaCtrl.dispose();
    super.dispose();
  }

  void _sincronizarCantidades(ReservaResponse reserva) {
    if (_cantidadesVenta.isNotEmpty) return;
    for (final detalle in reserva.detalles) {
      _cantidadesVenta[detalle.id] = detalle.cantidad;
    }
  }

  void _cancelarReserva(ReservaResponse reserva) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Cancelar Reserva?'),
        content: const Text('¿Deseas cancelar esta reserva? El stock reservado será devuelto al inventario disponible.'),
        actions: [
          TextButton(onPressed: () => Navigator.of(ctx).pop(), child: const Text('Mantener')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () async {
              Navigator.of(ctx).pop();
              final ok = await context.read<ReservaProvider>().cancelarReserva(reserva.id);
              if (ok && mounted) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(
                    content: Text('Reserva cancelada con éxito.'),
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

  double _subtotalSeleccionado(ReservaResponse reserva) {
    return reserva.detalles.fold(0.0, (total, detalle) {
      final cantidad = _cantidadesVenta[detalle.id] ?? 0;
      return total + cantidad * detalle.precioUnitario;
    });
  }

  double _anticipoAplicado(ReservaResponse reserva) {
    if (!reserva.anticipoPagado) return 0;
    final subtotal = _subtotalSeleccionado(reserva);
    return reserva.montoReserva < subtotal ? reserva.montoReserva : subtotal;
  }

  double _saldoVenta(ReservaResponse reserva) {
    final saldo = _subtotalSeleccionado(reserva) - _anticipoAplicado(reserva);
    return saldo < 0 ? 0 : saldo;
  }

  bool _puedeFinalizar(ReservaResponse reserva) {
    return !_requiereAnticipo(reserva)
        && !['COMPLETADA', 'CANCELADA', 'VENCIDA'].contains(reserva.estado)
        && _subtotalSeleccionado(reserva) > 0;
  }

  bool _requiereAnticipo(ReservaResponse reserva) {
    return reserva.montoReserva > 0
        && !reserva.anticipoPagado
        && !['COMPLETADA', 'CANCELADA', 'VENCIDA'].contains(reserva.estado);
  }

  Future<void> _pagarAnticipo(ReservaResponse reserva) async {
    final respuesta = await context.read<ReservaProvider>().pagarAnticipoStripe(reserva.id);
    if (!mounted) return;
    if (respuesta?.checkoutUrl != null && respuesta!.ordenId != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PagoStripeScreen(
            checkoutUrl: respuesta.checkoutUrl!,
            ordenId: respuesta.ordenId!,
          ),
        ),
      );
      if (mounted) {
        await context.read<ReservaProvider>().cargarReservaDetalle(reserva.id);
      }
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(respuesta?.mensaje ?? context.read<ReservaProvider>().error ?? 'No se pudo generar el pago del anticipo.'),
        backgroundColor: respuesta == null ? AppColors.danger : AppColors.success,
      ),
    );
  }

  Future<void> _finalizarVenta(ReservaResponse reserva) async {
    if (!_puedeFinalizar(reserva)) return;
    final ok = await context.read<ReservaProvider>().finalizarComoVenta(
          id: reserva.id,
          metodoPago: _metodoPago,
          observacion: _observacionVentaCtrl.text,
          cantidades: Map<int, int>.from(_cantidadesVenta),
        );
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(ok ? 'Reserva cerrada como venta presencial.' : (context.read<ReservaProvider>().error ?? 'No se pudo finalizar la venta.')),
        backgroundColor: ok ? AppColors.success : AppColors.danger,
      ),
    );
  }

  Future<void> _finalizarMiReserva(ReservaResponse reserva) async {
    if (!_puedeFinalizar(reserva)) return;
    if (_metodoPago == 'QR') {
      _mostrarQrPago(reserva);
      return;
    }
    await _confirmarFinalizarMiReserva(reserva);
  }

  Future<void> _confirmarFinalizarMiReserva(ReservaResponse reserva) async {
    final respuesta = await context.read<ReservaProvider>().finalizarMiReserva(
          id: reserva.id,
          metodoPago: _metodoPago,
          observacion: _observacionVentaCtrl.text,
          cantidades: Map<int, int>.from(_cantidadesVenta),
        );
    if (!mounted) return;
    if (respuesta?.checkoutUrl != null && respuesta!.ordenId != null) {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => PagoStripeScreen(
            checkoutUrl: respuesta.checkoutUrl!,
            ordenId: respuesta.ordenId!,
          ),
        ),
      );
      if (mounted) {
        await context.read<ReservaProvider>().cargarReservaDetalle(reserva.id);
      }
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(respuesta?.mensaje ?? context.read<ReservaProvider>().error ?? 'No se pudo completar la reserva.'),
        backgroundColor: respuesta == null ? AppColors.danger : AppColors.success,
      ),
    );
  }

  String _qrPayload(ReservaResponse reserva, NumberFormat currencyFormat) {
    return 'StyleAR Reserva ${reserva.codigo}\nMonto: ${currencyFormat.format(_saldoVenta(reserva))}\nPago por QR';
  }

  void _mostrarQrPago(ReservaResponse reserva) {
    final currencyFormat = NumberFormat.currency(locale: 'es_BO', symbol: 'Bs. ');
    final payload = _qrPayload(reserva, currencyFormat);

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        title: const Text('Pago por QR'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Escanea este QR para pagar ${currencyFormat.format(_saldoVenta(reserva))}.',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.textSecondary),
            ),
            const SizedBox(height: 16),
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(16),
                boxShadow: const [BoxShadow(color: Color(0x22000000), blurRadius: 14, offset: Offset(0, 6))],
              ),
              child: QrImageView(
                data: payload,
                version: QrVersions.auto,
                size: 210,
                backgroundColor: Colors.white,
                eyeStyle: const QrEyeStyle(
                  eyeShape: QrEyeShape.square,
                  color: Colors.black,
                ),
                dataModuleStyle: const QrDataModuleStyle(
                  dataModuleShape: QrDataModuleShape.square,
                  color: Colors.black,
                ),
              ),
            ),
            const SizedBox(height: 14),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: AppColors.background,
                borderRadius: BorderRadius.circular(12),
              ),
              child: Text(
                payload,
                style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600),
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cambiar método'),
          ),
          ElevatedButton(
            onPressed: () async {
              Navigator.of(ctx).pop();
              await _confirmarFinalizarMiReserva(reserva);
            },
            child: const Text('Confirmar pago QR'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final reservaProv = context.watch<ReservaProvider>();
    final auth = context.watch<AuthProvider>();
    final reserva = reservaProv.reservaDetalle;
    final currencyFormat = NumberFormat.currency(locale: 'es_BO', symbol: 'Bs. ');

    if (reservaProv.cargando || reserva == null) {
      return Scaffold(
        appBar: AppBar(title: const Text('Detalle de Reserva')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    _sincronizarCantidades(reserva);
    final puedeGestionarVenta = auth.esAdmin || auth.esEncargado || (auth.usuario?.esCajero ?? false);
    final puedeClienteGestionar = !puedeGestionarVenta && !['COMPLETADA', 'CANCELADA', 'VENCIDA'].contains(reserva.estado);

    return Scaffold(
      appBar: AppBar(
        title: Text(reserva.codigo),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Tarjeta Resumen
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text(
                            'ESTADO ACTUAL',
                            style: TextStyle(fontSize: 11, fontWeight: FontWeight.w700, color: AppColors.textSecondary),
                          ),
                          StockBadge.fromEstado(reserva.estado),
                        ],
                      ),
                      const SizedBox(height: 14),
                      const Divider(),
                      const SizedBox(height: 14),
                      _buildRow(Icons.confirmation_number_outlined, 'Código', reserva.codigo),
                      const SizedBox(height: 10),
                      _buildRow(Icons.storefront_outlined, 'Sucursal', '${reserva.sucursal} (${reserva.ciudad})'),
                      const SizedBox(height: 10),
                      _buildRow(Icons.calendar_today_outlined, 'Fecha', reserva.fechaReserva.substring(0, 10)),
                      if (reserva.fechaCita != null && reserva.fechaCita!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _buildRow(Icons.event_available_outlined, 'Cita', reserva.fechaCita!),
                      ],
                      const SizedBox(height: 10),
                      _buildRow(
                        Icons.payments_outlined,
                        'Anticipo',
                        '${currencyFormat.format(reserva.montoReserva)} · ${reserva.anticipoPagado ? 'Pagado' : 'Pendiente'}',
                      ),
                      if (reserva.ventaId != null) ...[
                        const SizedBox(height: 10),
                        _buildRow(Icons.receipt_long_outlined, 'Venta generada', '#${reserva.ventaId}'),
                      ],
                      if (reserva.cliente != null && reserva.cliente!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _buildRow(Icons.person_outline, 'Cliente', reserva.cliente!),
                      ],
                      if (reserva.observacion != null && reserva.observacion!.isNotEmpty) ...[
                        const SizedBox(height: 10),
                        _buildRow(Icons.notes_outlined, 'Nota', reserva.observacion!),
                      ],
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Prendas Reservadas
              const Text(
                'PRENDAS EN LA RESERVA',
                style: TextStyle(fontSize: 12, fontWeight: FontWeight.w700, letterSpacing: 0.8, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 10),

              Card(
                child: ListView.separated(
                  shrinkWrap: true,
                  physics: const NeverScrollableScrollPhysics(),
                  itemCount: reserva.detalles.length,
                  separatorBuilder: (context, index) => const Divider(),
                  itemBuilder: (context, index) {
                    final item = reserva.detalles[index];
                    return Padding(
                      padding: const EdgeInsets.all(14),
                      child: Row(
                        children: [
                          Container(
                            width: 48,
                            height: 48,
                            decoration: BoxDecoration(
                              color: AppColors.background,
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: const Icon(Icons.checkroom, color: AppColors.primary, size: 24),
                          ),
                          const SizedBox(width: 14),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  item.producto,
                                  style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14),
                                ),
                                const SizedBox(height: 2),
                                Text(
                                  'Talla: ${item.talla} • Color: ${item.color}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                                Text(
                                  '${item.cantidad} x ${currencyFormat.format(item.precioUnitario)}',
                                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                ),
                              ],
                            ),
                          ),
                          if ((puedeGestionarVenta || puedeClienteGestionar) && !['COMPLETADA', 'CANCELADA', 'VENCIDA'].contains(reserva.estado)) ...[
                            const SizedBox(width: 10),
                            SizedBox(
                              width: 88,
                              child: DropdownButtonFormField<int>(
                                initialValue: _cantidadesVenta[item.id] ?? item.cantidad,
                                decoration: const InputDecoration(
                                  labelText: 'Se lleva',
                                  contentPadding: EdgeInsets.symmetric(horizontal: 8, vertical: 6),
                                ),
                                items: List.generate(
                                  item.cantidad + 1,
                                  (value) => DropdownMenuItem<int>(
                                    value: value,
                                    child: Text('$value'),
                                  ),
                                ),
                                onChanged: (value) {
                                  setState(() => _cantidadesVenta[item.id] = value ?? 0);
                                },
                              ),
                            ),
                          ],
                          Text(
                            currencyFormat.format(item.subtotal),
                            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 20),

              // Total de Reserva
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Valor de prendas:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          Text(currencyFormat.format(reserva.total), style: const TextStyle(fontWeight: FontWeight.w800)),
                        ],
                      ),
                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          const Text('Anticipo:', style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600)),
                          Text(currencyFormat.format(reserva.montoReserva), style: const TextStyle(fontWeight: FontWeight.w800)),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
              if (_requiereAnticipo(reserva)) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        const Text(
                          'PAGAR ANTICIPO',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 8),
                        Text(
                          'Esta reserva requiere ${currencyFormat.format(reserva.montoReserva)} de anticipo no reembolsable.',
                          style: const TextStyle(color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 14),
                        CustomButton(
                          text: 'Pagar anticipo con Stripe',
                          icon: Icons.credit_card_outlined,
                          onPressed: () => _pagarAnticipo(reserva),
                        ),
                      ],
                    ),
                  ),
                ),
              ] else if ((puedeGestionarVenta || puedeClienteGestionar) && !['COMPLETADA', 'CANCELADA', 'VENCIDA'].contains(reserva.estado)) ...[
                const SizedBox(height: 16),
                Card(
                  child: Padding(
                    padding: const EdgeInsets.all(16),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                         Text(
                          puedeGestionarVenta ? 'CERRAR COMO VENTA PRESENCIAL' : 'ELEGIR PRENDAS Y PAGAR',
                          style: TextStyle(fontSize: 12, fontWeight: FontWeight.w800, letterSpacing: 0.6, color: AppColors.textSecondary),
                        ),
                        const SizedBox(height: 12),
                        DropdownButtonFormField<String>(
                          initialValue: _metodoPago,
                          decoration: const InputDecoration(labelText: 'Método de pago'),
                          items: puedeGestionarVenta
                              ? const [
                                  DropdownMenuItem(value: 'EFECTIVO', child: Text('Efectivo')),
                                  DropdownMenuItem(value: 'TARJETA', child: Text('Tarjeta')),
                                  DropdownMenuItem(value: 'QR', child: Text('QR')),
                                  DropdownMenuItem(value: 'TRANSFERENCIA', child: Text('Transferencia')),
                                ]
                              : const [
                                  DropdownMenuItem(value: 'STRIPE', child: Text('Stripe')),
                                  DropdownMenuItem(value: 'QR', child: Text('QR')),
                                  DropdownMenuItem(value: 'EFECTIVO', child: Text('Efectivo')),
                                ],
                          onChanged: (value) => setState(() => _metodoPago = value ?? 'EFECTIVO'),
                        ),
                        const SizedBox(height: 10),
                        TextField(
                          controller: _observacionVentaCtrl,
                          maxLines: 2,
                          decoration: const InputDecoration(labelText: 'Observación', hintText: 'Opcional'),
                        ),
                        const SizedBox(height: 12),
                        _buildRow(Icons.shopping_bag_outlined, 'Subtotal elegido', currencyFormat.format(_subtotalSeleccionado(reserva))),
                        const SizedBox(height: 8),
                        _buildRow(Icons.discount_outlined, 'Anticipo aplicado', '-${currencyFormat.format(_anticipoAplicado(reserva))}'),
                        const SizedBox(height: 8),
                        _buildRow(Icons.payments_outlined, 'Saldo a cobrar', currencyFormat.format(_saldoVenta(reserva))),
                        const SizedBox(height: 14),
                        CustomButton(
                          text: puedeGestionarVenta
                              ? 'Finalizar venta presencial'
                              : (_metodoPago == 'STRIPE' ? 'Pagar reserva con Stripe' : _metodoPago == 'QR' ? 'Generar QR de pago' : 'Completar reserva'),
                          icon: puedeGestionarVenta ? Icons.point_of_sale_outlined : Icons.shopping_bag_outlined,
                          onPressed: _puedeFinalizar(reserva)
                              ? () => puedeGestionarVenta ? _finalizarVenta(reserva) : _finalizarMiReserva(reserva)
                              : null,
                        ),
                      ],
                    ),
                  ),
                ),
              ],
              const SizedBox(height: 24),

              // Botón de Cancelar si está PENDIENTE
              if (reserva.puedeCancelar)
                CustomButton(
                  text: 'Cancelar Reserva',
                  isOutlined: true,
                  backgroundColor: AppColors.danger,
                  textColor: AppColors.danger,
                  onPressed: () => _cancelarReserva(reserva),
                ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildRow(IconData icon, String label, String value) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Icon(icon, size: 16, color: AppColors.textSecondary),
        const SizedBox(width: 8),
        Text(
          '$label: ',
          style: const TextStyle(fontSize: 13, color: AppColors.textSecondary),
        ),
        Expanded(
          child: Text(
            value,
            style: const TextStyle(fontSize: 13, fontWeight: FontWeight.w600, color: AppColors.textPrimary),
          ),
        ),
      ],
    );
  }
}
