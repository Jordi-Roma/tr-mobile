import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/pago_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/pago_service.dart';
import 'detalle_pago_screen.dart';

class HistorialPagosScreen extends StatefulWidget {
  const HistorialPagosScreen({super.key});

  @override
  State<HistorialPagosScreen> createState() => _HistorialPagosScreenState();
}

class _HistorialPagosScreenState extends State<HistorialPagosScreen> {
  bool _cargando = true;
  String? _error;
  List<PagoHistorialItem> _pagos = [];

  @override
  void initState() {
    super.initState();
    _cargarPagos();
  }

  Future<void> _cargarPagos() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final auth = context.read<AuthProvider>();
      final pagos = auth.esAdminOEncargado
          ? await PagoService.listarPagos()
          : await PagoService.listarMisPagos();
      if (!mounted) return;
      setState(() {
        _pagos = pagos;
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
    final auth = context.watch<AuthProvider>();
    final esAdmin = auth.esAdminOEncargado;

    return Scaffold(
      appBar: AppBar(
        title: Text(esAdmin ? 'Historial de pagos' : 'Mis pagos'),
      ),
      body: RefreshIndicator(
        onRefresh: _cargarPagos,
        child: _buildBody(esAdmin),
      ),
    );
  }

  Widget _buildBody(bool esAdmin) {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: [
          const Icon(Icons.error_outline, color: AppColors.danger, size: 54),
          const SizedBox(height: 12),
          const Text(
            'No se pudo cargar el historial de pagos.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppColors.textSecondary),
          ),
          const SizedBox(height: 18),
          ElevatedButton(
            onPressed: _cargarPagos,
            child: const Text('Reintentar'),
          ),
        ],
      );
    }

    if (_pagos.isEmpty) {
      return ListView(
        padding: const EdgeInsets.all(24),
        children: const [
          SizedBox(height: 80),
          Icon(Icons.credit_card_off_outlined, color: AppColors.textSecondary, size: 58),
          SizedBox(height: 12),
          Text(
            'Aún no tienes pagos registrados.',
            textAlign: TextAlign.center,
            style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
          ),
        ],
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemBuilder: (context, index) {
        final pago = _pagos[index];
        return _PagoCard(
          pago: pago,
          mostrarCliente: esAdmin,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => DetallePagoScreen(
                  ordenId: pago.ordenId,
                  esAdmin: esAdmin,
                ),
              ),
            );
          },
        );
      },
      separatorBuilder: (_, index) => const SizedBox(height: 12),
      itemCount: _pagos.length,
    );
  }
}

class _PagoCard extends StatelessWidget {
  final PagoHistorialItem pago;
  final bool mostrarCliente;
  final VoidCallback onTap;

  const _PagoCard({
    required this.pago,
    required this.mostrarCliente,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text(
                    'Orden #${pago.ordenId}',
                    style: const TextStyle(fontWeight: FontWeight.w900, fontSize: 16),
                  ),
                  _EstadoBadge(estado: pago.estado),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _formatMonto(pago.montoTotal),
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                  color: AppColors.primary,
                ),
              ),
              const SizedBox(height: 10),
              _InfoLine(icon: Icons.receipt_long_outlined, text: pago.ventaCodigo ?? 'Venta #${pago.ventaId}'),
              _InfoLine(icon: Icons.payment_outlined, text: '${pago.metodo} · ${pago.proveedor}'),
              _InfoLine(icon: Icons.calendar_today_outlined, text: _formatFecha(pago.fechaPago ?? pago.fechaCreacion)),
              if (pago.sucursalNombre != null)
                _InfoLine(icon: Icons.store_outlined, text: pago.sucursalNombre!),
              if (mostrarCliente && pago.clienteCorreo != null)
                _InfoLine(icon: Icons.person_outline, text: pago.clienteCorreo!),
            ],
          ),
        ),
      ),
    );
  }
}

class _InfoLine extends StatelessWidget {
  final IconData icon;
  final String text;

  const _InfoLine({required this.icon, required this.text});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Row(
        children: [
          Icon(icon, size: 16, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              text,
              style: const TextStyle(color: AppColors.textSecondary, fontSize: 13),
            ),
          ),
        ],
      ),
    );
  }
}

class _EstadoBadge extends StatelessWidget {
  final String estado;

  const _EstadoBadge({required this.estado});

  @override
  Widget build(BuildContext context) {
    final color = _estadoColor(estado);
    final background = _estadoBackground(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        estado,
        style: TextStyle(fontWeight: FontWeight.w900, color: color, fontSize: 11),
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

Color _estadoColor(String estado) {
  switch (estado.toUpperCase()) {
    case 'PAGADO':
      return AppColors.success;
    case 'PENDIENTE':
      return AppColors.warning;
    case 'RECHAZADO':
    case 'EXPIRADO':
    case 'CANCELADO':
      return AppColors.danger;
    default:
      return AppColors.textSecondary;
  }
}

Color _estadoBackground(String estado) {
  switch (estado.toUpperCase()) {
    case 'PAGADO':
      return AppColors.successSoft;
    case 'PENDIENTE':
      return AppColors.warningSoft;
    case 'RECHAZADO':
    case 'EXPIRADO':
    case 'CANCELADO':
      return AppColors.dangerSoft;
    default:
      return AppColors.background;
  }
}
