import 'package:flutter/material.dart';
import '../../core/constants/app_colors.dart';
import '../../models/admin_catalogo_models.dart';
import '../../services/admin_catalogo_service.dart';
import 'admin_producto_form_screen.dart';
import 'admin_variante_form_screen.dart';
import 'admin_catalogo_dialogs.dart';

class AdminCatalogoHubScreen extends StatefulWidget {
  const AdminCatalogoHubScreen({super.key});

  @override
  State<AdminCatalogoHubScreen> createState() => _AdminCatalogoHubScreenState();
}

class _AdminCatalogoHubScreenState extends State<AdminCatalogoHubScreen> with SingleTickerProviderStateMixin {
  late TabController _tabController;

  List<AdminProductoItem> _productos = [];
  List<AdminCategoria> _categorias = [];
  List<AdminTalla> _tallas = [];
  List<AdminColor> _colores = [];
  List<AdminVarianteItem> _variantes = [];

  bool _cargando = false;
  String? _error;
  String _busqueda = '';
  String _filtroEstado = 'todos'; // 'todos', 'activos', 'inactivos'

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 5, vsync: this);
    _cargarTodo();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _cargarTodo() async {
    setState(() {
      _cargando = true;
      _error = null;
    });

    try {
      final prods = await AdminCatalogoService.listarProductos();
      final cats = await AdminCatalogoService.listarCategorias();
      final tallas = await AdminCatalogoService.listarTallas();
      final cols = await AdminCatalogoService.listarColores();
      final vars = await AdminCatalogoService.listarVariantes();

      if (mounted) {
        setState(() {
          _productos = prods;
          _categorias = cats;
          _tallas = tallas;
          _colores = cols;
          _variantes = vars;
          _cargando = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = e.toString();
          _cargando = false;
        });
      }
    }
  }

  void _onFabPressed() async {
    final currentTab = _tabController.index;
    bool? cambio;

    switch (currentTab) {
      case 0: // Productos
        cambio = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const AdminProductoFormScreen()),
        );
        break;
      case 1: // Categorias
        cambio = await AdminCategoriaDialog.show(context, categoriasPadre: _categorias);
        break;
      case 2: // Tallas
        cambio = await AdminTallaDialog.show(context);
        break;
      case 3: // Colores
        cambio = await AdminColorDialog.show(context);
        break;
      case 4: // Variantes
        cambio = await Navigator.of(context).push<bool>(
          MaterialPageRoute(builder: (_) => const AdminVarianteFormScreen()),
        );
        break;
    }

    if (cambio == true) {
      _cargarTodo();
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: const Text(
          'Administración de Catálogo',
          style: TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ),
        backgroundColor: Colors.white,
        foregroundColor: AppColors.primary,
        elevation: 1,
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          labelColor: AppColors.primary,
          unselectedLabelColor: Colors.grey.shade600,
          indicatorColor: AppColors.primary,
          indicatorWeight: 3,
          tabs: const [
            Tab(icon: Icon(Icons.checkroom), text: 'Prendas'),
            Tab(icon: Icon(Icons.category), text: 'Categorías'),
            Tab(icon: Icon(Icons.straighten), text: 'Tallas & RA'),
            Tab(icon: Icon(Icons.palette), text: 'Colores'),
            Tab(icon: Icon(Icons.alt_route), text: 'Variantes'),
          ],
        ),
      ),
      body: Column(
        children: [
          // Toolbar de búsqueda y filtros
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
            color: Colors.white,
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    decoration: InputDecoration(
                      hintText: 'Buscar en catálogo...',
                      prefixIcon: const Icon(Icons.search, size: 20),
                      isDense: true,
                      contentPadding: const EdgeInsets.symmetric(vertical: 10, horizontal: 12),
                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(8)),
                    ),
                    onChanged: (v) => setState(() => _busqueda = v.trim().toLowerCase()),
                  ),
                ),
                const SizedBox(width: 10),
                DropdownButton<String>(
                  value: _filtroEstado,
                  underline: const SizedBox(),
                  items: const [
                    DropdownMenuItem(value: 'todos', child: Text('Todos')),
                    DropdownMenuItem(value: 'activos', child: Text('Activos')),
                    DropdownMenuItem(value: 'inactivos', child: Text('Inactivos')),
                  ],
                  onChanged: (v) {
                    if (v != null) setState(() => _filtroEstado = v);
                  },
                ),
                IconButton(
                  icon: const Icon(Icons.refresh, color: AppColors.primary),
                  onPressed: _cargarTodo,
                  tooltip: 'Refrescar datos',
                ),
              ],
            ),
          ),

          if (_error != null)
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              color: Colors.red.shade100,
              child: Text(_error!, style: TextStyle(color: Colors.red.shade900, fontSize: 12)),
            ),

          Expanded(
            child: _cargando
                ? const Center(child: CircularProgressIndicator())
                : TabBarView(
                    controller: _tabController,
                    children: [
                      _buildProductosTab(),
                      _buildCategoriasTab(),
                      _buildTallasTab(),
                      _buildColoresTab(),
                      _buildVariantesTab(),
                    ],
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _onFabPressed,
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Nuevo'),
      ),
    );
  }

  // ── TAB PRODUCTOS ─────────────────────────────────────────

  Widget _buildProductosTab() {
    final filtrados = _productos.where((p) {
      final matchBusqueda = _busqueda.isEmpty ||
          p.nombre.toLowerCase().contains(_busqueda) ||
          p.categoriaNombre.toLowerCase().contains(_busqueda) ||
          (p.marcaNombre?.toLowerCase().contains(_busqueda) ?? false);

      final matchEstado = _filtroEstado == 'todos' ||
          (_filtroEstado == 'activos' && p.activo) ||
          (_filtroEstado == 'inactivos' && !p.activo);

      return matchBusqueda && matchEstado;
    }).toList();

    if (filtrados.isEmpty) {
      return const Center(child: Text('No hay prendas con los filtros actuales.'));
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: filtrados.length,
      itemBuilder: (ctx, i) {
        final p = filtrados[i];
        final corteLabel = kTiposCorte.where((c) => c.key == p.tipoCorte).firstOrNull?.label ?? p.tipoCorte;

        return Card(
          margin: const EdgeInsets.only(bottom: 12),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: ClipRRect(
              borderRadius: BorderRadius.circular(8),
              child: p.imagenPrincipal.isNotEmpty
                  ? Image.network(p.imagenPrincipal, width: 56, height: 56, fit: BoxFit.cover, errorBuilder: (context, error, stackTrace) => const Icon(Icons.checkroom, size: 40))
                  : Container(width: 56, height: 56, color: Colors.grey.shade200, child: const Icon(Icons.checkroom, color: Colors.grey)),
            ),
            title: Text(p.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('${p.categoriaNombre} • ${p.marcaNombre ?? 'Sin marca'}', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: AppColors.primary.withValues(alpha: 0.1), borderRadius: BorderRadius.circular(4)),
                      child: Text(corteLabel, style: const TextStyle(fontSize: 11, color: AppColors.primary, fontWeight: FontWeight.w600)),
                    ),
                    if (p.anchoBaseCm != null && p.largoBaseCm != null)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                        decoration: BoxDecoration(color: Colors.blue.shade50, borderRadius: BorderRadius.circular(4)),
                        child: Text('RA: ${p.anchoBaseCm?.toStringAsFixed(0)}x${p.largoBaseCm?.toStringAsFixed(0)}cm', style: TextStyle(fontSize: 11, color: Colors.blue.shade800)),
                      ),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: AppColors.primary),
                  tooltip: 'Editar',
                  onPressed: () async {
                    final res = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(builder: (_) => AdminProductoFormScreen(producto: p)),
                    );
                    if (res == true) _cargarTodo();
                  },
                ),
                IconButton(
                  icon: Icon(p.activo ? Icons.toggle_on : Icons.toggle_off, color: p.activo ? Colors.green : Colors.grey, size: 30),
                  tooltip: p.activo ? 'Desactivar' : 'Activar',
                  onPressed: () async {
                    await AdminCatalogoService.toggleEstadoProducto(p.id, p.activo);
                    _cargarTodo();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── TAB CATEGORÍAS ────────────────────────────────────────

  Widget _buildCategoriasTab() {
    final filtrados = _categorias.where((c) {
      final matchBusqueda = _busqueda.isEmpty || c.nombre.toLowerCase().contains(_busqueda);
      final matchEstado = _filtroEstado == 'todos' || (_filtroEstado == 'activos' && c.activo) || (_filtroEstado == 'inactivos' && !c.activo);
      return matchBusqueda && matchEstado;
    }).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: filtrados.length,
      itemBuilder: (ctx, i) {
        final c = filtrados[i];
        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: const Icon(Icons.label, color: AppColors.primary),
            title: Text(c.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(c.categoriaPadreNombre != null ? 'Subcategoría de: ${c.categoriaPadreNombre}' : (c.descripcion ?? 'Categoría principal')),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: AppColors.primary),
                  onPressed: () async {
                    final res = await AdminCategoriaDialog.show(context, categoria: c, categoriasPadre: _categorias);
                    if (res == true) _cargarTodo();
                  },
                ),
                IconButton(
                  icon: Icon(c.activo ? Icons.toggle_on : Icons.toggle_off, color: c.activo ? Colors.green : Colors.grey, size: 30),
                  onPressed: () async {
                    await AdminCatalogoService.toggleEstadoCategoria(c.id, c.activo);
                    _cargarTodo();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── TAB TALLAS ────────────────────────────────────────────

  Widget _buildTallasTab() {
    final filtrados = _tallas.where((t) {
      final matchBusqueda = _busqueda.isEmpty || t.nombre.toLowerCase().contains(_busqueda);
      final matchEstado = _filtroEstado == 'todos' || (_filtroEstado == 'activos' && t.activo) || (_filtroEstado == 'inactivos' && !t.activo);
      return matchBusqueda && matchEstado;
    }).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: filtrados.length,
      itemBuilder: (ctx, i) {
        final t = filtrados[i];
        final tieneMedidas = t.anchoCm != null || t.largoCm != null;

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: CircleAvatar(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              child: Text(t.nombre, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 13)),
            ),
            title: Row(
              children: [
                Text('Talla ${t.nombre}', style: const TextStyle(fontWeight: FontWeight.bold)),
                const SizedBox(width: 8),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(
                    color: t.tipoPrenda == 'INFERIOR'
                        ? Colors.orange.shade50
                        : (t.tipoPrenda == 'VESTIDO' ? Colors.purple.shade50 : Colors.blue.shade50),
                    borderRadius: BorderRadius.circular(4),
                    border: Border.all(
                      color: t.tipoPrenda == 'INFERIOR'
                          ? Colors.orange.shade200
                          : (t.tipoPrenda == 'VESTIDO' ? Colors.purple.shade200 : Colors.blue.shade200),
                    ),
                  ),
                  child: Text(
                    t.tipoPrenda == 'INFERIOR'
                        ? 'Inferior / Pantalón'
                        : (t.tipoPrenda == 'VESTIDO' ? 'Vestido' : 'Superior'),
                    style: TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.bold,
                      color: t.tipoPrenda == 'INFERIOR'
                          ? Colors.orange.shade900
                          : (t.tipoPrenda == 'VESTIDO' ? Colors.purple.shade900 : Colors.blue.shade900),
                    ),
                  ),
                ),
              ],
            ),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (t.descripcion != null && t.descripcion!.isNotEmpty) Text(t.descripcion!, style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 2),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                  decoration: BoxDecoration(color: Colors.amber.shade50, borderRadius: BorderRadius.circular(4), border: Border.all(color: Colors.amber.shade200)),
                  child: Text(
                    tieneMedidas
                        ? (t.tipoPrenda == 'INFERIOR'
                            ? 'Cintura: ${t.anchoCm?.toStringAsFixed(1)} cm | Pierna: ${t.largoCm?.toStringAsFixed(1)} cm'
                            : (t.tipoPrenda == 'VESTIDO'
                                ? 'Busto: ${t.anchoCm?.toStringAsFixed(1)} cm | Vestido: ${t.largoCm?.toStringAsFixed(1)} cm'
                                : 'Pecho: ${t.anchoCm?.toStringAsFixed(1)} cm | Torso: ${t.largoCm?.toStringAsFixed(1)} cm'))
                        : 'Sin medidas base cargadas',
                    style: TextStyle(fontSize: 11, fontWeight: FontWeight.w600, color: Colors.amber.shade900),
                  ),
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: AppColors.primary),
                  onPressed: () async {
                    final res = await AdminTallaDialog.show(context, talla: t);
                    if (res == true) _cargarTodo();
                  },
                ),
                IconButton(
                  icon: Icon(t.activo ? Icons.toggle_on : Icons.toggle_off, color: t.activo ? Colors.green : Colors.grey, size: 30),
                  onPressed: () async {
                    await AdminCatalogoService.toggleEstadoTalla(t.id, t.activo);
                    _cargarTodo();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── TAB COLORES ───────────────────────────────────────────

  Widget _buildColoresTab() {
    final filtrados = _colores.where((c) {
      final matchBusqueda = _busqueda.isEmpty || c.nombre.toLowerCase().contains(_busqueda);
      final matchEstado = _filtroEstado == 'todos' || (_filtroEstado == 'activos' && c.activo) || (_filtroEstado == 'inactivos' && !c.activo);
      return matchBusqueda && matchEstado;
    }).toList();

    Color parseHex(String? hex) {
      if (hex == null || hex.isEmpty) return Colors.grey;
      try {
        final clean = hex.replaceAll('#', '');
        return Color(int.parse('0xFF$clean'));
      } catch (_) {
        return Colors.grey;
      }
    }

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: filtrados.length,
      itemBuilder: (ctx, i) {
        final c = filtrados[i];
        final col = parseHex(c.codigoHex);

        return Card(
          margin: const EdgeInsets.only(bottom: 8),
          child: ListTile(
            leading: Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: col,
                shape: BoxShape.circle,
                border: Border.all(color: Colors.grey.shade400),
              ),
            ),
            title: Text(c.nombre, style: const TextStyle(fontWeight: FontWeight.bold)),
            subtitle: Text(c.codigoHex ?? 'Sin código hexadecimal'),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: AppColors.primary),
                  onPressed: () async {
                    final res = await AdminColorDialog.show(context, color: c);
                    if (res == true) _cargarTodo();
                  },
                ),
                IconButton(
                  icon: Icon(c.activo ? Icons.toggle_on : Icons.toggle_off, color: c.activo ? Colors.green : Colors.grey, size: 30),
                  onPressed: () async {
                    await AdminCatalogoService.toggleEstadoColor(c.id, c.activo);
                    _cargarTodo();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }

  // ── TAB VARIANTES ─────────────────────────────────────────

  Widget _buildVariantesTab() {
    final filtrados = _variantes.where((v) {
      final matchBusqueda = _busqueda.isEmpty ||
          v.sku.toLowerCase().contains(_busqueda) ||
          v.productoNombre.toLowerCase().contains(_busqueda) ||
          (v.tallaNombre?.toLowerCase().contains(_busqueda) ?? false) ||
          (v.colorNombre?.toLowerCase().contains(_busqueda) ?? false);

      final matchEstado = _filtroEstado == 'todos' ||
          (_filtroEstado == 'activos' && v.activo) ||
          (_filtroEstado == 'inactivos' && !v.activo);

      return matchBusqueda && matchEstado;
    }).toList();

    return ListView.builder(
      padding: const EdgeInsets.all(14),
      itemCount: filtrados.length,
      itemBuilder: (ctx, i) {
        final v = filtrados[i];
        final tieneMedidas = v.anchoCm != null || v.largoCm != null;

        return Card(
          margin: const EdgeInsets.only(bottom: 10),
          child: ListTile(
            contentPadding: const EdgeInsets.all(12),
            leading: const Icon(Icons.alt_route, color: AppColors.primary, size: 30),
            title: Text('${v.productoNombre} (${v.sku})', style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
            subtitle: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const SizedBox(height: 4),
                Text('Talla: ${v.tallaNombre ?? 'N/A'} • Color: ${v.colorNombre ?? 'N/A'}', style: const TextStyle(fontSize: 12)),
                const SizedBox(height: 4),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.green.shade50, borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        v.precioActual != null ? 'Bs. ${v.precioActual!.toStringAsFixed(2)}' : 'Sin precio',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.green.shade800),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Container(
                      padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                      decoration: BoxDecoration(color: Colors.purple.shade50, borderRadius: BorderRadius.circular(4)),
                      child: Text(
                        tieneMedidas ? 'RA: ${v.anchoCm?.toStringAsFixed(0)}x${v.largoCm?.toStringAsFixed(0)}cm' : 'Talla estándar',
                        style: TextStyle(fontSize: 11, fontWeight: FontWeight.bold, color: Colors.purple.shade800),
                      ),
                    ),
                  ],
                ),
              ],
            ),
            trailing: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                IconButton(
                  icon: const Icon(Icons.edit, color: AppColors.primary),
                  onPressed: () async {
                    final res = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(builder: (_) => AdminVarianteFormScreen(variante: v)),
                    );
                    if (res == true) _cargarTodo();
                  },
                ),
                IconButton(
                  icon: Icon(v.activo ? Icons.toggle_on : Icons.toggle_off, color: v.activo ? Colors.green : Colors.grey, size: 30),
                  onPressed: () async {
                    await AdminCatalogoService.toggleEstadoVariante(v.id, v.activo);
                    _cargarTodo();
                  },
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}
