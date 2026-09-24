import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/pago_models.dart';
import '../../services/pago_service.dart';
import '../../widgets/payment_status_badge.dart';

class DetallePagoScreen extends StatefulWidget {
  final int ordenId;
  final bool esAdmin;

  const DetallePagoScreen({
    super.key,
    required this.ordenId,
    required this.esAdmin,
  });

  @override
  State<DetallePagoScreen> createState() => _DetallePagoScreenState();
}

class _DetallePagoScreenState extends State<DetallePagoScreen> {
  bool _cargando = true;
  String? _error;
  PagoHistorialDetalle? _pago;

  @override
  void initState() {
    super.initState();
    _cargarDetalle();
  }

  Future<void> _cargarDetalle() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final pago = widget.esAdmin
          ? await PagoService.obtenerPago(widget.ordenId)
          : await PagoService.obtenerMiPago(widget.ordenId);
      if (!mounted) return;
      setState(() {
        _pago = pago;
        _cargando = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _cargando = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Detalle del pago')),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline, color: AppColors.danger, size: 54),
              const SizedBox(height: 12),
              const Text(
                'No se pudo consultar el pago.',
                textAlign: TextAlign.center,
                style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              const SizedBox(height: 8),
              Text(
                _error!,
                textAlign: TextAlign.center,
                style: const TextStyle(color: AppColors.textSecondary),
              ),
            ],
          ),
        ),
      );
    }

    final pago = _pago;
    if (pago == null) {
      return const Center(child: Text('Pago no encontrado.'));
    }
    final estadoVisual = paymentStatusVisual(pago.estado);

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                PaymentStatusBadge(estado: pago.estado, showIcon: true),
                const SizedBox(height: 8),
                Text(
                  estadoVisual.description,
                  style: const TextStyle(color: AppColors.textSecondary, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 14),
                Text(
                  'Orden #${pago.ordenId}',
                  style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 28,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  pago.ventaCodigo ?? 'Venta #${pago.ventaId}',
                  style: const TextStyle(color: AppColors.textSecondary),
                ),
                const SizedBox(height: 18),
                Text(
                  _formatMonto(pago.montoTotal),
                  style: const TextStyle(fontSize: 26, fontWeight: FontWeight.w900),
                ),
              ],
            ),
          ),
        ),
        const SizedBox(height: 12),
        Card(
          child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              children: [
                _DetailRow(label: 'Método', value: pago.metodo),
                _DetailRow(label: 'Proveedor', value: pago.proveedor),
                _DetailRow(label: 'Fecha creación', value: _formatFecha(pago.fechaCreacion)),
                _DetailRow(label: 'Fecha pago', value: pago.fechaPago == null ? '-' : _formatFecha(pago.fechaPago!)),
                _DetailRow(label: 'Sucursal', value: pago.sucursalNombre ?? '-'),
                if (widget.esAdmin) ...[
                  _DetailRow(label: 'Cliente', value: pago.clienteNombre ?? '-'),
                  _DetailRow(label: 'Correo', value: pago.clienteCorreo ?? '-'),
                ],
              ],
            ),
          ),
        ),
        const SizedBox(height: 16),
        const Text(
          'Productos',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900),
        ),
        const SizedBox(height: 8),
        ...pago.productos.map((producto) => Card(
              child: ListTile(
                title: Text(
                  producto.producto,
                  style: const TextStyle(fontWeight: FontWeight.w800),
                ),
                subtitle: Text(
                  '${producto.categoria ?? '-'} · ${producto.talla ?? '-'} / ${producto.color ?? '-'}\nCantidad: ${producto.cantidad}',
                ),
                trailing: Text(
                  _formatMonto(producto.subtotal),
                  style: const TextStyle(fontWeight: FontWeight.w900),
                ),
              ),
            )),
      ],
    );
  }
}

class _DetailRow extends StatelessWidget {
  final String label;
  final String value;

  const _DetailRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: const TextStyle(color: AppColors.textSecondary)),
          const SizedBox(width: 16),
          Expanded(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: const TextStyle(fontWeight: FontWeight.w800),
            ),
          ),
        ],
      ),
    );
  }
}

String _formatMonto(double value) => 'Bs ${value.toStringAsFixed(2)}';

String _formatFecha(String value) {
  final fecha = DateTime.tryParse(value);
  if (fecha == null) return value;
  final local = fecha.toLocal();
  return '${local.day.toString().padLeft(2, '0')}/${local.month.toString().padLeft(2, '0')}/${local.year} ${local.hour.toString().padLeft(2, '0')}:${local.minute.toString().padLeft(2, '0')}';
}
