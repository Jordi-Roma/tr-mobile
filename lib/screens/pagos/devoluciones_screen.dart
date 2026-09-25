import 'package:flutter/material.dart';

import '../../core/constants/app_colors.dart';
import '../../models/devolucion_models.dart';
import '../../services/devolucion_service.dart';

class DevolucionesScreen extends StatefulWidget {
  const DevolucionesScreen({super.key});

  @override
  State<DevolucionesScreen> createState() => _DevolucionesScreenState();
}

class _DevolucionesScreenState extends State<DevolucionesScreen> {
  bool _cargando = true;
  bool _guardando = false;
  String? _error;
  List<VentaDevolucionElegible> _ventas = [];
  List<Devolucion> _devoluciones = [];

  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final resultados = await Future.wait([
        DevolucionService.listarVentasElegibles(),
        DevolucionService.listarPropias(),
      ]);
      if (!mounted) return;
      setState(() {
        _ventas = resultados[0] as List<VentaDevolucionElegible>;
        _devoluciones = resultados[1] as List<Devolucion>;
        _cargando = false;
      });
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _cargando = false;
      });
    }
  }

  Future<void> _solicitar(VentaDevolucionElegible venta) async {
    final datos = await showModalBottomSheet<_SolicitudDevolucionData>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      backgroundColor: Colors.transparent,
      builder: (_) => _SolicitudDevolucionSheet(venta: venta),
    );
    if (datos == null || !mounted) return;
    setState(() => _guardando = true);
    try {
      await DevolucionService.solicitar(
        ventaId: venta.ventaId,
        motivo: datos.motivo,
        observacion: datos.observacion,
        items: datos.items,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud de devolución enviada.')),
      );
      await _cargar();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _cancelar(Devolucion devolucion) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Cancelar solicitud'),
        content: const Text('¿Quieres cancelar esta solicitud de devolución?'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Volver')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('Cancelar solicitud')),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    try {
      await DevolucionService.cancelar(devolucion.id);
      await _cargar();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: AppColors.danger),
      );
    }
  }

  void _verDetalle(Devolucion devolucion) {
    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
        child: ListView(
          shrinkWrap: true,
          children: [
            Text(devolucion.codigo, style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800)),
            const SizedBox(height: 8),
            _EstadoDevolucion(estado: devolucion.estado),
            const SizedBox(height: 12),
            Text('Compra ${devolucion.ventaCodigo}'),
            Text('Motivo: ${devolucion.motivo}'),
            Text('Solicitado: ${_monto(devolucion.montoSolicitado)}'),
            if (devolucion.montoAprobado > 0) Text('Importe aprobado: ${_monto(devolucion.montoAprobado)}'),
            const Divider(height: 24),
            const Text('Artículos', style: TextStyle(fontWeight: FontWeight.w800)),
            ...devolucion.detalles.map((item) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text('${item.producto} · ${item.talla} / ${item.color}'),
                  subtitle: Text('Solicitados: ${item.cantidadSolicitada} · Aceptados: ${item.cantidadAceptada} · Rechazados: ${item.cantidadRechazada}'),
                  trailing: item.montoAprobado > 0 ? Text(_monto(item.montoAprobado)) : null,
                )),
            if (devolucion.estado == 'REEMBOLSADA')
              Text('Reembolso confirmado: ${devolucion.metodoReembolso ?? ''} ${devolucion.referenciaReembolso ?? ''}'),
            if (devolucion.estado == 'SOLICITADA') ...[
              const SizedBox(height: 8),
              OutlinedButton.icon(
                onPressed: () {
                  Navigator.pop(context);
                  _cancelar(devolucion);
                },
                icon: const Icon(Icons.close),
                label: const Text('Cancelar solicitud'),
              ),
            ],
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis devoluciones')),
      body: _cargando
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _cargar,
              child: _error != null
                  ? ListView(
                      padding: const EdgeInsets.all(24),
                      children: [
                        const SizedBox(height: 70),
                        const Icon(Icons.error_outline, size: 48, color: AppColors.danger),
                        const SizedBox(height: 12),
                        const Text('No se pudieron cargar las devoluciones.', textAlign: TextAlign.center),
                        Text(_error!, textAlign: TextAlign.center),
                        TextButton(onPressed: _cargar, child: const Text('Reintentar')),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.all(16),
                      children: [
                        const Text('Compras elegibles', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        if (_ventas.isEmpty)
                          const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('No tienes compras elegibles dentro del plazo de devolución.'))),
                        ..._ventas.map((venta) => Card(
                              child: Padding(
                                padding: const EdgeInsets.all(14),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text('${venta.codigo} · ${_monto(venta.total)}', style: const TextStyle(fontWeight: FontWeight.w900)),
                                    Text('${venta.sucursal} · ${_fecha(venta.fecha)}', style: const TextStyle(color: AppColors.textSecondary)),
                                    const SizedBox(height: 8),
                                    ...venta.detalles.map((item) => Padding(
                                          padding: const EdgeInsets.symmetric(vertical: 3),
                                          child: Text('${item.producto} · ${item.talla} / ${item.color} · Disponibles: ${item.cantidadDisponible}'),
                                        )),
                                    const SizedBox(height: 8),
                                    SizedBox(
                                      width: double.infinity,
                                      child: FilledButton.icon(
                                        onPressed: _guardando ? null : () => _solicitar(venta),
                                        icon: const Icon(Icons.assignment_return_outlined),
                                        label: const Text('Solicitar devolución'),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            )),
                        const SizedBox(height: 20),
                        const Text('Seguimiento', style: TextStyle(fontSize: 20, fontWeight: FontWeight.w900)),
                        const SizedBox(height: 8),
                        if (_devoluciones.isEmpty)
                          const Card(child: Padding(padding: EdgeInsets.all(16), child: Text('Aún no tienes solicitudes de devolución.'))),
                        ..._devoluciones.map((devolucion) => Card(
                              child: ListTile(
                                onTap: () => _verDetalle(devolucion),
                                title: Text('${devolucion.codigo} · ${devolucion.ventaCodigo}', style: const TextStyle(fontWeight: FontWeight.w800)),
                                subtitle: Padding(
                                  padding: const EdgeInsets.only(top: 8),
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      _EstadoDevolucion(estado: devolucion.estado),
                                      const SizedBox(height: 6),
                                      Text('Solicitado ${_monto(devolucion.montoSolicitado)}${devolucion.montoAprobado > 0 ? ' · Aprobado ${_monto(devolucion.montoAprobado)}' : ''}'),
                                    ],
                                  ),
                                ),
                                trailing: const Icon(Icons.chevron_right),
                              ),
                            )),
                        const SizedBox(height: 12),
                        const Text('El reembolso y la reposición de stock se confirman después de que la tienda reciba e inspeccione los artículos. El delivery no está incluido.', style: TextStyle(color: AppColors.textSecondary)),
                      ],
                    ),
            ),
    );
  }
}

class _SolicitudDevolucionData {
  final String motivo;
  final String observacion;
  final List<Map<String, int>> items;
  const _SolicitudDevolucionData(this.motivo, this.observacion, this.items);
}

class _SolicitudDevolucionSheet extends StatefulWidget {
  final VentaDevolucionElegible venta;
  const _SolicitudDevolucionSheet({required this.venta});

  @override
  State<_SolicitudDevolucionSheet> createState() => _SolicitudDevolucionSheetState();
}

class _SolicitudDevolucionSheetState extends State<_SolicitudDevolucionSheet> {
  final _motivo = TextEditingController();
  final _observacion = TextEditingController();
  late final Map<int, int> _cantidades = {
    for (final item in widget.venta.detalles) item.ventaDetalleId: 0,
  };

  @override
  void dispose() {
    _motivo.dispose();
    _observacion.dispose();
    super.dispose();
  }

  void _enviar() {
    if (_motivo.text.trim().length < 5) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Escribe un motivo de al menos 5 caracteres.')));
      return;
    }
    final items = _cantidades.entries
        .where((entry) => entry.value > 0)
        .map((entry) => {'venta_detalle_id': entry.key, 'cantidad': entry.value})
        .toList();
    if (items.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Selecciona al menos una unidad.')));
      return;
    }
    Navigator.pop(context, _SolicitudDevolucionData(_motivo.text.trim(), _observacion.text.trim(), items));
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.sizeOf(context).height * .86,
      decoration: const BoxDecoration(color: Colors.white, borderRadius: BorderRadius.vertical(top: Radius.circular(22))),
      child: SafeArea(
        child: ListView(
          padding: EdgeInsets.fromLTRB(20, 18, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
          children: [
            Row(mainAxisAlignment: MainAxisAlignment.spaceBetween, children: [
              Expanded(child: Text('Devolución ${widget.venta.codigo}', style: const TextStyle(fontSize: 20, fontWeight: FontWeight.w900))),
              IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
            ]),
            const Text('Selecciona el artículo y la cantidad que quieres devolver.'),
            const SizedBox(height: 12),
            ...widget.venta.detalles.map((item) => Card(
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Row(
                      children: [
                        Expanded(child: Text('${item.producto}\n${item.talla} / ${item.color}\n${item.cantidadDisponible} disponibles')),
                        IconButton(
                          onPressed: _cantidades[item.ventaDetalleId]! > 0
                              ? () => setState(() => _cantidades[item.ventaDetalleId] = _cantidades[item.ventaDetalleId]! - 1)
                              : null,
                          icon: const Icon(Icons.remove_circle_outline),
                        ),
                        Text('${_cantidades[item.ventaDetalleId]}', style: const TextStyle(fontWeight: FontWeight.w900)),
                        IconButton(
                          onPressed: _cantidades[item.ventaDetalleId]! < item.cantidadDisponible
                              ? () => setState(() => _cantidades[item.ventaDetalleId] = _cantidades[item.ventaDetalleId]! + 1)
                              : null,
                          icon: const Icon(Icons.add_circle_outline),
                        ),
                      ],
                    ),
                  ),
                )),
            const SizedBox(height: 8),
            TextField(controller: _motivo, minLines: 1, maxLines: 3, decoration: const InputDecoration(labelText: 'Motivo', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            TextField(controller: _observacion, minLines: 2, maxLines: 4, decoration: const InputDecoration(labelText: 'Observación (opcional)', border: OutlineInputBorder())),
            const SizedBox(height: 12),
            const Text('La tienda revisará los artículos. El costo de delivery no se devuelve.', style: TextStyle(color: AppColors.textSecondary)),
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: FilledButton(onPressed: _enviar, child: const Text('Enviar solicitud'))),
          ],
        ),
      ),
    );
  }
}

class _EstadoDevolucion extends StatelessWidget {
  final String estado;
  const _EstadoDevolucion({required this.estado});

  @override
  Widget build(BuildContext context) {
    final color = switch (estado) {
      'REEMBOLSADA' => const Color(0xFF3F6A34),
      'RECHAZADA' || 'ERROR_REEMBOLSO' => AppColors.danger,
      'APROBADA' => const Color(0xFF315E97),
      'REEMBOLSO_PENDIENTE' => const Color(0xFF6856A0),
      'CANCELADA' => AppColors.textSecondary,
      _ => const Color(0xFF8B641C),
    };
    return DecoratedBox(
      decoration: BoxDecoration(color: color.withValues(alpha: .12), borderRadius: BorderRadius.circular(30)),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        child: Text(estado.replaceAll('_', ' '), style: TextStyle(color: color, fontWeight: FontWeight.w800, fontSize: 12)),
      ),
    );
  }
}

String _monto(double monto) => 'Bs ${monto.toStringAsFixed(2)}';
String _fecha(String value) {
  final parsed = DateTime.tryParse(value)?.toLocal();
  if (parsed == null) return value;
  return '${parsed.day.toString().padLeft(2, '0')}/${parsed.month.toString().padLeft(2, '0')}/${parsed.year}';
}
