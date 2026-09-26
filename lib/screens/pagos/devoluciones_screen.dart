import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/devolucion_models.dart';
import '../../providers/auth_provider.dart';
import '../../services/devolucion_service.dart';

class DevolucionesScreen extends StatefulWidget {
  const DevolucionesScreen({super.key});

  @override
  State<DevolucionesScreen> createState() => _DevolucionesScreenState();
}

class _DevolucionesScreenState extends State<DevolucionesScreen> with SingleTickerProviderStateMixin {
  TabController? _tabController;
  bool _cargando = true;
  bool _guardando = false;
  String? _error;

  // Datos Cliente
  List<VentaDevolucionElegible> _ventasCliente = [];
  List<Devolucion> _devolucionesCliente = [];

  // Datos Gestión (Admin / Encargado / Cajero)
  List<Devolucion> _devolucionesGestion = [];
  String _filtroEstadoGestion = 'TODOS';

  final List<String> _estadosFiltro = [
    'TODOS',
    'SOLICITADA',
    'EN_REVISION',
    'APROBADA',
    'RECHAZADA',
    'REEMBOLSO_PENDIENTE',
    'REEMBOLSADA',
    'CANCELADA',
  ];

  @override
  void initState() {
    super.initState();
    final auth = Provider.of<AuthProvider>(context, listen: false);
    if (auth.esPersonalDevoluciones) {
      _tabController = TabController(length: 2, vsync: this);
    }
    _cargar();
  }

  @override
  void dispose() {
    _tabController?.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    final auth = Provider.of<AuthProvider>(context, listen: false);

    try {
      if (auth.esPersonalDevoluciones) {
        final estadoQuery = _filtroEstadoGestion == 'TODOS' ? null : _filtroEstadoGestion;
        final resultados = await Future.wait([
          DevolucionService.listarGestion(estado: estadoQuery),
          DevolucionService.listarPropias().catchError((_) => <Devolucion>[]),
          DevolucionService.listarVentasElegibles().catchError((_) => <VentaDevolucionElegible>[]),
        ]);
        if (!mounted) return;
        setState(() {
          _devolucionesGestion = resultados[0] as List<Devolucion>;
          _devolucionesCliente = resultados[1] as List<Devolucion>;
          _ventasCliente = resultados[2] as List<VentaDevolucionElegible>;
          _cargando = false;
        });
      } else {
        final resultados = await Future.wait([
          DevolucionService.listarVentasElegibles(),
          DevolucionService.listarPropias(),
        ]);
        if (!mounted) return;
        setState(() {
          _ventasCliente = resultados[0] as List<VentaDevolucionElegible>;
          _devolucionesCliente = resultados[1] as List<Devolucion>;
          _cargando = false;
        });
      }
    } catch (error) {
      if (!mounted) return;
      setState(() {
        _error = error.toString();
        _cargando = false;
      });
    }
  }

  // ── ACCIONES CLIENTE ──────────────────────────────────────────

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
        const SnackBar(content: Text('Solicitud de devolución enviada con éxito.'), backgroundColor: Colors.green),
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
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
            child: const Text('Cancelar solicitud'),
          ),
        ],
      ),
    );
    if (confirmar != true || !mounted) return;
    try {
      await DevolucionService.cancelar(devolucion.id);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Solicitud cancelada.'), backgroundColor: Colors.grey),
      );
      await _cargar();
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.toString()), backgroundColor: AppColors.danger),
      );
    }
  }

  // ── ACCIONES STAFF (ADMIN / ENCARGADO / CAJERO) ─────────────

  Future<void> _revisarDevolucion(Devolucion devolucion, bool aprobar) async {
    String observacion = '';
    if (!aprobar) {
      final motivoCtrl = TextEditingController();
      final confirmado = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Rechazar Solicitud'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text('Indica el motivo por el cual se rechaza esta devolución:'),
              const SizedBox(height: 12),
              TextField(
                controller: motivoCtrl,
                maxLines: 3,
                decoration: const InputDecoration(
                  labelText: 'Motivo de rechazo *',
                  border: OutlineInputBorder(),
                  hintText: 'Ej: No cumple política de cambio, etiqueta retirada...',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Volver')),
            FilledButton(
              onPressed: () {
                if (motivoCtrl.text.trim().isEmpty) return;
                Navigator.pop(ctx, true);
              },
              style: FilledButton.styleFrom(backgroundColor: AppColors.danger),
              child: const Text('Rechazar'),
            ),
          ],
        ),
      );
      if (confirmado != true || !mounted) return;
      observacion = motivoCtrl.text.trim();
    } else {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Aprobar Devolución'),
          content: Text('¿Deseas aprobar la solicitud ${devolucion.codigo}?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Volver')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
              child: const Text('Aprobar'),
            ),
          ],
        ),
      );
      if (confirmar != true || !mounted) return;
    }

    setState(() => _guardando = true);
    try {
      await DevolucionService.revisar(
        id: devolucion.id,
        aprobar: aprobar,
        observacion: observacion.isNotEmpty ? observacion : null,
      );
      if (!mounted) return;
      Navigator.of(context).pop(); // cerrar bottomsheet si está abierto
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(aprobar ? 'Devolución aprobada exitosamente.' : 'Devolución rechazada.'),
          backgroundColor: aprobar ? Colors.green.shade700 : AppColors.danger,
        ),
      );
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e'), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _registrarRecepcion(Devolucion devolucion) async {
    final Map<int, int> cantidades = {
      for (final d in devolucion.detalles) d.id: d.cantidadSolicitada,
    };

    final confirmado = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (ctx) => StatefulBuilder(
        builder: (context, setModalState) {
          return Padding(
            padding: EdgeInsets.fromLTRB(20, 24, 20, MediaQuery.viewInsetsOf(context).bottom + 24),
            child: ListView(
              shrinkWrap: true,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(
                        'Recepción de Artículos · ${devolucion.codigo}',
                        style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
                      ),
                    ),
                    IconButton(onPressed: () => Navigator.pop(ctx, false), icon: const Icon(Icons.close)),
                  ],
                ),
                const Text(
                  'Inspecciona las prendas e ingresa la cantidad exacta aceptada para reponer automáticamente al inventario.',
                  style: TextStyle(fontSize: 12, color: Colors.grey),
                ),
                const SizedBox(height: 14),
                ...devolucion.detalles.map((detalle) {
                  final cant = cantidades[detalle.id] ?? detalle.cantidadSolicitada;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text('${detalle.producto} · ${detalle.talla} / ${detalle.color}', style: const TextStyle(fontWeight: FontWeight.w600)),
                                Text('Solicitadas: ${detalle.cantidadSolicitada} un.', style: const TextStyle(fontSize: 12, color: Colors.grey)),
                              ],
                            ),
                          ),
                          IconButton(
                            onPressed: cant > 0
                                ? () => setModalState(() => cantidades[detalle.id] = cant - 1)
                                : null,
                            icon: const Icon(Icons.remove_circle_outline),
                          ),
                          Text('$cant', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
                          IconButton(
                            onPressed: cant < detalle.cantidadSolicitada
                                ? () => setModalState(() => cantidades[detalle.id] = cant + 1)
                                : null,
                            icon: const Icon(Icons.add_circle_outline),
                          ),
                        ],
                      ),
                    ),
                  );
                }),
                const SizedBox(height: 16),
                FilledButton.icon(
                  onPressed: () => Navigator.pop(ctx, true),
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Confirmar Recepción y Reponer Stock'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary, padding: const EdgeInsets.symmetric(vertical: 14)),
                ),
              ],
            ),
          );
        },
      ),
    );

    if (confirmado != true || !mounted) return;

    setState(() => _guardando = true);
    try {
      final items = cantidades.entries.map((e) => {
        'detalle_id': e.key,
        'cantidad_aceptada': e.value,
      }).toList();

      await DevolucionService.recepcionar(id: devolucion.id, items: items);
      if (!mounted) return;
      Navigator.of(context).pop(); // cerrar bottomsheet si está abierto
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Recepción registrada e inventario actualizado.'), backgroundColor: Colors.green),
      );
      await _cargar();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error en recepción: $e'), backgroundColor: AppColors.danger),
      );
    } finally {
      if (mounted) setState(() => _guardando = false);
    }
  }

  Future<void> _procesarReembolso(Devolucion devolucion) async {
    final esStripe = devolucion.proveedorPagoOriginal?.toUpperCase() == 'STRIPE';

    if (esStripe) {
      final confirmar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Reembolso Stripe'),
          content: Text('¿Deseas procesar el reembolso automático de ${_monto(devolucion.montoAprobado)} a la tarjeta del cliente a través de Stripe?'),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Volver')),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              style: FilledButton.styleFrom(backgroundColor: Colors.indigo),
              child: const Text('Procesar Reembolso'),
            ),
          ],
        ),
      );
      if (confirmar != true || !mounted) return;

      setState(() => _guardando = true);
      try {
        await DevolucionService.reembolsarStripe(devolucion.id);
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reembolso Stripe procesado correctamente.'), backgroundColor: Colors.green),
        );
        await _cargar();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al procesar reembolso: $e'), backgroundColor: AppColors.danger),
        );
      } finally {
        if (mounted) setState(() => _guardando = false);
      }
    } else {
      // Reembolso Manual (Efectivo / QR / Transferencia)
      String metodo = 'EFECTIVO';
      final refCtrl = TextEditingController();
      final obsCtrl = TextEditingController();

      final confirmado = await showDialog<bool>(
        context: context,
        builder: (ctx) => StatefulBuilder(
          builder: (context, setDialogState) {
            return AlertDialog(
              title: const Text('Registrar Reembolso Manual'),
              content: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text('Monto a reembolsar: ${_monto(devolucion.montoAprobado)}', style: const TextStyle(fontWeight: FontWeight.bold)),
                    const SizedBox(height: 14),
                    DropdownButtonFormField<String>(
                      initialValue: metodo,
                      decoration: const InputDecoration(labelText: 'Método de Reembolso', border: OutlineInputBorder()),
                      items: const [
                        DropdownMenuItem(value: 'EFECTIVO', child: Text('Efectivo en Tienda')),
                        DropdownMenuItem(value: 'QR', child: Text('Transferencia / QR')),
                        DropdownMenuItem(value: 'OTRO', child: Text('Otro Método')),
                      ],
                      onChanged: (v) {
                        if (v != null) setDialogState(() => metodo = v);
                      },
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: refCtrl,
                      decoration: const InputDecoration(
                        labelText: 'Nº Comprobante / Referencia *',
                        border: OutlineInputBorder(),
                        hintText: 'Ej: REF-98342 o RECIBO-012',
                      ),
                    ),
                    const SizedBox(height: 12),
                    TextField(
                      controller: obsCtrl,
                      maxLines: 2,
                      decoration: const InputDecoration(labelText: 'Nota (opcional)', border: OutlineInputBorder()),
                    ),
                  ],
                ),
              ),
              actions: [
                TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Volver')),
                FilledButton(
                  onPressed: () {
                    if (refCtrl.text.trim().length < 3) return;
                    Navigator.pop(ctx, true);
                  },
                  child: const Text('Confirmar Reembolso'),
                ),
              ],
            );
          },
        ),
      );

      if (confirmado != true || !mounted) return;

      setState(() => _guardando = true);
      try {
        await DevolucionService.reembolsarManual(
          id: devolucion.id,
          metodo: metodo,
          referencia: refCtrl.text.trim(),
          observacion: obsCtrl.text.trim().isNotEmpty ? obsCtrl.text.trim() : null,
        );
        if (!mounted) return;
        Navigator.of(context).pop();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Reembolso manual registrado con éxito.'), backgroundColor: Colors.green),
        );
        await _cargar();
      } catch (e) {
        if (!mounted) return;
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error al registrar reembolso: $e'), backgroundColor: AppColors.danger),
        );
      } finally {
        if (mounted) setState(() => _guardando = false);
      }
    }
  }

  // ── DETALLE MODAL BOTTOM SHEET ─────────────────────────────

  void _verDetalle(Devolucion devolucion, {required bool esGestion}) {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    showModalBottomSheet<void>(
      context: context,
      useSafeArea: true,
      isScrollControlled: true,
      builder: (context) => Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
        child: ListView(
          shrinkWrap: true,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Expanded(
                  child: Text(
                    devolucion.codigo,
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
                  ),
                ),
                IconButton(onPressed: () => Navigator.pop(context), icon: const Icon(Icons.close)),
              ],
            ),
            const SizedBox(height: 6),
            _EstadoDevolucion(estado: devolucion.estado),
            const SizedBox(height: 12),

            if (devolucion.clienteNombre != null && devolucion.clienteNombre!.isNotEmpty) ...[
              Text('Cliente: ${devolucion.clienteNombre} (${devolucion.clienteCorreo ?? ''})', style: const TextStyle(fontWeight: FontWeight.w600)),
            ],
            Text('Compra: ${devolucion.ventaCodigo}'),
            if (devolucion.sucursal.isNotEmpty) Text('Sucursal: ${devolucion.sucursal}'),
            Text('Fecha Solicitud: ${_fecha(devolucion.fechaSolicitud)}'),
            Text('Motivo: ${devolucion.motivo}'),
            if (devolucion.observacion != null && devolucion.observacion!.isNotEmpty)
              Text('Observación: ${devolucion.observacion}', style: const TextStyle(fontStyle: FontStyle.italic)),
            const SizedBox(height: 8),
            Text('Solicitado: ${_monto(devolucion.montoSolicitado)}', style: const TextStyle(fontWeight: FontWeight.w600)),
            if (devolucion.montoAprobado > 0)
              Text('Importe aprobado: ${_monto(devolucion.montoAprobado)}', style: const TextStyle(fontWeight: FontWeight.bold, color: Colors.green)),

            const Divider(height: 24),
            const Text('Artículos Solicitados', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
            const SizedBox(height: 6),
            ...devolucion.detalles.map((item) => Card(
                  margin: const EdgeInsets.only(bottom: 6),
                  child: ListTile(
                    contentPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                    title: Text('${item.producto} · ${item.talla} / ${item.color}', style: const TextStyle(fontWeight: FontWeight.w600, fontSize: 13)),
                    subtitle: Text('Solicitados: ${item.cantidadSolicitada} · Aceptados: ${item.cantidadAceptada} · Rechazados: ${item.cantidadRechazada}', style: const TextStyle(fontSize: 11)),
                    trailing: item.montoAprobado > 0 ? Text(_monto(item.montoAprobado), style: const TextStyle(fontWeight: FontWeight.bold)) : null,
                  ),
                )),

            if (devolucion.estado == 'REEMBOLSADA') ...[
              const SizedBox(height: 10),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(8)),
                child: Text('Reembolso completado vía ${devolucion.metodoReembolso ?? 'N/A'} (Ref: ${devolucion.referenciaReembolso ?? 'N/A'})', style: TextStyle(color: Colors.green.shade900, fontWeight: FontWeight.w600)),
              ),
            ],

            const SizedBox(height: 16),

            // BOTONES DE ACCIÓN PARA PERSONAL DE TIENDA
            if (esGestion) ...[
              // 1. REVISIÓN (Aprobar / Rechazar)
              if (auth.esAdminOEncargado && (devolucion.estado == 'SOLICITADA' || devolucion.estado == 'EN_REVISION')) ...[
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: _guardando ? null : () => _revisarDevolucion(devolucion, false),
                        icon: const Icon(Icons.cancel_outlined, color: AppColors.danger),
                        label: const Text('Rechazar', style: TextStyle(color: AppColors.danger)),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: FilledButton.icon(
                        onPressed: _guardando ? null : () => _revisarDevolucion(devolucion, true),
                        icon: const Icon(Icons.check_circle_outline),
                        label: const Text('Aprobar'),
                        style: FilledButton.styleFrom(backgroundColor: Colors.green.shade700),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 10),
              ],

              // 2. RECEPCIÓN E INSPECCIÓN DE ARTÍCULOS
              if (auth.esPersonalDevoluciones && devolucion.estado == 'APROBADA') ...[
                FilledButton.icon(
                  onPressed: _guardando ? null : () => _registrarRecepcion(devolucion),
                  icon: const Icon(Icons.inventory_2_outlined),
                  label: const Text('Registrar Recepción e Inspección'),
                  style: FilledButton.styleFrom(backgroundColor: AppColors.primary),
                ),
                const SizedBox(height: 10),
              ],

              // 3. REEMBOLSO
              if (auth.esAdminOEncargado && (devolucion.estado == 'REEMBOLSO_PENDIENTE' || (devolucion.estado == 'APROBADA' && devolucion.montoAprobado > 0))) ...[
                FilledButton.icon(
                  onPressed: _guardando ? null : () => _procesarReembolso(devolucion),
                  icon: const Icon(Icons.paid_outlined),
                  label: Text('Procesar Reembolso (${_monto(devolucion.montoAprobado)})'),
                  style: FilledButton.styleFrom(backgroundColor: Colors.indigo.shade700),
                ),
                const SizedBox(height: 10),
              ],
            ] else ...[
              // BOTÓN CLIENTE: Cancelar si está SOLICITADA
              if (devolucion.estado == 'SOLICITADA') ...[
                OutlinedButton.icon(
                  onPressed: () {
                    Navigator.pop(context);
                    _cancelar(devolucion);
                  },
                  icon: const Icon(Icons.close, color: AppColors.danger),
                  label: const Text('Cancelar solicitud', style: TextStyle(color: AppColors.danger)),
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }

  // ── BUILD VISTAS ──────────────────────────────────────────

  Widget _buildGestionTab() {
    return Column(
      children: [
        // Selector de filtro de estado
        Container(
          height: 48,
          margin: const EdgeInsets.symmetric(vertical: 8),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            scrollDirection: Axis.horizontal,
            itemCount: _estadosFiltro.length,
            separatorBuilder: (_, index) => const SizedBox(width: 8),
            itemBuilder: (ctx, i) {
              final est = _estadosFiltro[i];
              final isSel = _filtroEstadoGestion == est;
              return ChoiceChip(
                label: Text(est.replaceAll('_', ' '), style: TextStyle(fontSize: 11, fontWeight: isSel ? FontWeight.bold : FontWeight.normal)),
                selected: isSel,
                onSelected: (selected) {
                  if (selected) {
                    setState(() => _filtroEstadoGestion = est);
                    _cargar();
                  }
                },
              );
            },
          ),
        ),

        // Lista de devoluciones de la tienda
        Expanded(
          child: _devolucionesGestion.isEmpty
              ? const Center(child: Text('No hay solicitudes de devolución con este filtro.'))
              : ListView.separated(
                  padding: const EdgeInsets.all(16),
                  itemCount: _devolucionesGestion.length,
                  separatorBuilder: (_, index) => const SizedBox(height: 10),
                  itemBuilder: (ctx, i) {
                    final d = _devolucionesGestion[i];
                    return Card(
                      elevation: 1,
                      child: ListTile(
                        onTap: () => _verDetalle(d, esGestion: true),
                        title: Row(
                          children: [
                            Text(d.codigo, style: const TextStyle(fontWeight: FontWeight.bold)),
                            const SizedBox(width: 8),
                            _EstadoDevolucion(estado: d.estado),
                          ],
                        ),
                        subtitle: Padding(
                          padding: const EdgeInsets.only(top: 6),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (d.clienteNombre != null && d.clienteNombre!.isNotEmpty)
                                Text('Cliente: ${d.clienteNombre}', style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w600)),
                              Text('Compra: ${d.ventaCodigo} · Solicitado: ${_monto(d.montoSolicitado)}', style: const TextStyle(fontSize: 12)),
                              Text('Fecha: ${_fecha(d.fechaSolicitud)}', style: const TextStyle(fontSize: 11, color: Colors.grey)),
                            ],
                          ),
                        ),
                        trailing: const Icon(Icons.chevron_right),
                      ),
                    );
                  },
                ),
        ),
      ],
    );
  }

  Widget _buildClienteTab() {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text('Compras elegibles', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        if (_ventasCliente.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('No tienes compras elegibles dentro del plazo de devolución.'),
            ),
          )
        else
          ..._ventasCliente.map((venta) => Card(
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
        const Text('Mis Solicitudes', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w900)),
        const SizedBox(height: 8),
        if (_devolucionesCliente.isEmpty)
          const Card(
            child: Padding(
              padding: EdgeInsets.all(16),
              child: Text('Aún no tienes solicitudes de devolución.'),
            ),
          )
        else
          ..._devolucionesCliente.map((devolucion) => Card(
                child: ListTile(
                  onTap: () => _verDetalle(devolucion, esGestion: false),
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
        const Text(
          'El reembolso y la reposición de stock se confirman después de que la tienda reciba e inspeccione los artículos. El costo de delivery no se devuelve.',
          style: TextStyle(color: AppColors.textSecondary, fontSize: 12),
        ),
      ],
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final esPersonal = auth.esPersonalDevoluciones;

    return Scaffold(
      appBar: AppBar(
        title: Text(esPersonal ? 'Gestión de Devoluciones' : 'Mis Devoluciones'),
        bottom: esPersonal && _tabController != null
            ? TabBar(
                controller: _tabController,
                tabs: const [
                  Tab(icon: Icon(Icons.storefront_outlined), text: 'Gestión Tienda'),
                  Tab(icon: Icon(Icons.person_outline), text: 'Mis Solicitudes'),
                ],
              )
            : null,
      ),
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
                        Text(_error!, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.danger)),
                        const SizedBox(height: 12),
                        ElevatedButton(onPressed: _cargar, child: const Text('Reintentar')),
                      ],
                    )
                  : esPersonal && _tabController != null
                      ? TabBarView(
                          controller: _tabController,
                          children: [
                            _buildGestionTab(),
                            _buildClienteTab(),
                          ],
                        )
                      : _buildClienteTab(),
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
            TextField(
              controller: _observacion,
              minLines: 2,
              maxLines: 4,
              decoration: const InputDecoration(
                labelText: 'Observación / Cuenta para devolución (opcional)',
                hintText: 'Si pagaste con QR, indica tu banco, cuenta o celular para la transferencia',
                border: OutlineInputBorder(),
              ),
            ),
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
