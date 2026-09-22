import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/proveedor_panel_models.dart';
import '../../services/proveedor_panel_service.dart';

class ProveedorPanelScreen extends StatefulWidget {
  const ProveedorPanelScreen({super.key});

  @override
  State<ProveedorPanelScreen> createState() => _ProveedorPanelScreenState();
}

class _ProveedorPanelScreenState extends State<ProveedorPanelScreen> {
  ProveedorPerfil? _perfil;
  List<ProveedorProducto> _productos = [];
  List<ProveedorStock> _stock = [];
  List<ProveedorEntrega> _entregas = [];
  bool _cargando = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  Future<void> _cargarDatos() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final res = await Future.wait([
        ProveedorPanelService.obtenerPerfil(),
        ProveedorPanelService.listarProductos(),
        ProveedorPanelService.listarStock(),
        ProveedorPanelService.listarEntregas(),
      ]);

      if (!mounted) return;
      setState(() {
        _perfil = res[0] as ProveedorPerfil;
        _productos = res[1] as List<ProveedorProducto>;
        _stock = res[2] as List<ProveedorStock>;
        _entregas = res[3] as List<ProveedorEntrega>;
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
    return DefaultTabController(
      length: 4,
      child: Scaffold(
        appBar: AppBar(
          title: const Text('Panel proveedor'),
          bottom: const TabBar(
            isScrollable: true,
            tabs: [
              Tab(text: 'Perfil'),
              Tab(text: 'Productos'),
              Tab(text: 'Stock'),
              Tab(text: 'Entregas'),
            ],
          ),
        ),
        body: RefreshIndicator(
          onRefresh: _cargarDatos,
          child: _buildBody(),
        ),
      ),
    );
  }

  Widget _buildBody() {
    if (_cargando) {
      return const Center(child: CircularProgressIndicator());
    }

    if (_error != null) {
      return ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Icon(Icons.warning_amber_rounded, size: 48, color: AppColors.danger),
          const SizedBox(height: 12),
          const Text(
            'No se pudo cargar el panel de proveedor.',
            textAlign: TextAlign.center,
            style: TextStyle(fontSize: 16, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          Text(
            _error!,
            textAlign: TextAlign.center,
            style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 16),
          ElevatedButton.icon(
            onPressed: _cargarDatos,
            icon: const Icon(Icons.refresh),
            label: const Text('Reintentar'),
          ),
        ],
      );
    }

    return TabBarView(
      children: [
        _PerfilTab(perfil: _perfil),
        _ProductosTab(productos: _productos),
        _StockTab(stock: _stock),
        _EntregasTab(entregas: _entregas),
      ],
    );
  }
}

class _PerfilTab extends StatelessWidget {
  final ProveedorPerfil? perfil;

  const _PerfilTab({required this.perfil});

  @override
  Widget build(BuildContext context) {
    final p = perfil;
    if (p == null) {
      return const _EmptyState(message: 'No hay proveedor vinculado a este usuario.');
    }

    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Card(
          child: Padding(
            padding: const EdgeInsets.all(18),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Mi proveedor',
                  style: TextStyle(
                    fontSize: 12,
                    letterSpacing: 0.8,
                    fontWeight: FontWeight.w700,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  p.nombre,
                  style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 26,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 14),
                _InfoRow(icon: Icons.badge_outlined, label: 'NIT', value: p.nit),
                _InfoRow(icon: Icons.phone_outlined, label: 'Teléfono', value: p.telefono),
                _InfoRow(icon: Icons.email_outlined, label: 'Correo', value: p.correo),
                _InfoRow(icon: Icons.location_on_outlined, label: 'Dirección', value: p.direccion),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _ProductosTab extends StatelessWidget {
  final List<ProveedorProducto> productos;

  const _ProductosTab({required this.productos});

  @override
  Widget build(BuildContext context) {
    if (productos.isEmpty) {
      return const _EmptyState(message: 'No tienes productos vinculados todavía.');
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: productos.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final p = productos[index];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.accentSoft,
              child: Icon(Icons.checkroom_outlined, color: AppColors.accent),
            ),
            title: Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text('${p.categoria} · ${p.marca}\n${p.variantes} variantes'),
            isThreeLine: true,
            trailing: Chip(
              label: Text(p.activo ? 'Activo' : 'Inactivo'),
              visualDensity: VisualDensity.compact,
            ),
          ),
        );
      },
    );
  }
}

class _StockTab extends StatelessWidget {
  final List<ProveedorStock> stock;

  const _StockTab({required this.stock});

  @override
  Widget build(BuildContext context) {
    if (stock.isEmpty) {
      return const _EmptyState(message: 'No hay stock registrado para tus productos.');
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: stock.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = stock[index];
        return Card(
          child: Padding(
            padding: const EdgeInsets.all(14),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(item.producto, style: const TextStyle(fontWeight: FontWeight.w800)),
                const SizedBox(height: 4),
                Text(
                  '${item.sku} · ${item.talla}/${item.color} · ${item.sucursal}',
                  style: const TextStyle(fontSize: 12, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 12),
                Row(
                  children: [
                    _Metric(label: 'Disponible', value: item.stockDisponible),
                    _Metric(label: 'Reservado', value: item.stockReservado),
                    _Metric(label: 'Real', value: item.stockReal),
                  ],
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _EntregasTab extends StatelessWidget {
  final List<ProveedorEntrega> entregas;

  const _EntregasTab({required this.entregas});

  @override
  Widget build(BuildContext context) {
    if (entregas.isEmpty) {
      return const _EmptyState(message: 'No hay entregas registradas todavía.');
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: entregas.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = entregas[index];
        return Card(
          child: ListTile(
            leading: const CircleAvatar(
              backgroundColor: AppColors.accentSoft,
              child: Icon(Icons.inventory_2_outlined, color: AppColors.accent),
            ),
            title: Text(item.producto, style: const TextStyle(fontWeight: FontWeight.w700)),
            subtitle: Text(
              '${item.sku} · ${item.sucursal}\n${_formatDate(item.fecha)}'
              '${item.motivo != null && item.motivo!.isNotEmpty ? ' · ${item.motivo}' : ''}',
            ),
            isThreeLine: true,
            trailing: Text(
              '+${item.cantidad}',
              style: const TextStyle(fontWeight: FontWeight.w800, color: AppColors.success),
            ),
          ),
        );
      },
    );
  }

  String _formatDate(DateTime fecha) {
    return '${fecha.day.toString().padLeft(2, '0')}/'
        '${fecha.month.toString().padLeft(2, '0')}/'
        '${fecha.year}';
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String? value;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    final text = value == null || value!.trim().isEmpty ? 'No registrado' : value!;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 7),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 19, color: AppColors.textSecondary),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(fontSize: 11, color: AppColors.textSecondary)),
                Text(text, style: const TextStyle(fontWeight: FontWeight.w600)),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String label;
  final int value;

  const _Metric({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        margin: const EdgeInsets.only(right: 8),
        padding: const EdgeInsets.symmetric(vertical: 10),
        decoration: BoxDecoration(
          color: AppColors.background,
          borderRadius: BorderRadius.circular(10),
        ),
        child: Column(
          children: [
            Text(
              value.toString(),
              style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
            ),
            Text(
              label,
              style: const TextStyle(fontSize: 10, color: AppColors.textSecondary),
            ),
          ],
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final String message;

  const _EmptyState({required this.message});

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(28),
      children: [
        const SizedBox(height: 80),
        const Icon(Icons.inbox_outlined, size: 56, color: AppColors.textSecondary),
        const SizedBox(height: 12),
        Text(
          message,
          textAlign: TextAlign.center,
          style: const TextStyle(fontSize: 14, color: AppColors.textSecondary),
        ),
      ],
    );
  }
}
