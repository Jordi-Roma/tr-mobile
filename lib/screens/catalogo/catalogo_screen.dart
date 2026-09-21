import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/recomendacion_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/catalogo_provider.dart';
import '../../providers/favoritos_provider.dart';
import '../../services/recomendacion_service.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/product_card.dart';
import '../auth/login_screen.dart';
import 'favoritos_screen.dart';
import 'producto_detalle_screen.dart';

class CatalogoScreen extends StatefulWidget {
  const CatalogoScreen({super.key});

  @override
  State<CatalogoScreen> createState() => _CatalogoScreenState();
}

class _CatalogoScreenState extends State<CatalogoScreen> {
  final _searchCtrl = TextEditingController();
  bool _modoParaTi = false;
  List<RecomendacionPrendaItem> _recomendacionesParaTi = [];
  bool _cargandoParaTi = false;
  String? _errorParaTi;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final catalogo = context.read<CatalogoProvider>();
      catalogo.cargarPrendas();
      catalogo.cargarFiltros();
    });
  }

  Future<void> _cargarRecomendacionesParaTi() async {
    final auth = context.read<AuthProvider>();
    if (!auth.estaAutenticado) {
      final logueado = await Navigator.of(context)
          .push<bool>(MaterialPageRoute(builder: (_) => const LoginScreen()));
      if (logueado != true || !mounted) return;
    }

    setState(() {
      _modoParaTi = true;
      _cargandoParaTi = true;
      _errorParaTi = null;
    });

    try {
      final items = await RecomendacionService.obtenerParaMi();
      if (mounted) setState(() => _recomendacionesParaTi = items);
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorParaTi = 'No se pudieron cargar recomendaciones: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _cargandoParaTi = false);
    }
  }

  @override
  void dispose() {
    _searchCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final catalogo = context.watch<CatalogoProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'StyleAR',
          style: TextStyle(
            fontFamily: 'Playfair Display',
            fontSize: 24,
            fontWeight: FontWeight.w800,
            letterSpacing: -0.5,
          ),
        ),
        actions: [
          Consumer<FavoritosProvider>(
            builder: (context, fav, _) {
              return Stack(
                alignment: Alignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.favorite_border),
                    tooltip: 'Mis Favoritos',
                    onPressed: () {
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => const FavoritosScreen(),
                        ),
                      );
                    },
                  ),
                  if (fav.cantidad > 0)
                    Positioned(
                      top: 8,
                      right: 8,
                      child: Container(
                        padding: const EdgeInsets.all(4),
                        decoration: const BoxDecoration(
                          color: Colors.red,
                          shape: BoxShape.circle,
                        ),
                        constraints: const BoxConstraints(
                          minWidth: 16,
                          minHeight: 16,
                        ),
                        child: Text(
                          '${fav.cantidad}',
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
      body: SafeArea(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Barra de Búsqueda
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: TextField(
                controller: _searchCtrl,
                decoration: InputDecoration(
                  hintText: 'Buscar poleras, camisas, oversize...',
                  prefixIcon: const Icon(
                    Icons.search,
                    size: 20,
                    color: AppColors.textSecondary,
                  ),
                  suffixIcon: _searchCtrl.text.isNotEmpty
                      ? IconButton(
                          icon: const Icon(Icons.clear, size: 18),
                          onPressed: () {
                            _searchCtrl.clear();
                            catalogo.buscar('');
                          },
                        )
                      : null,
                  filled: true,
                  fillColor: AppColors.surface,
                  contentPadding: const EdgeInsets.symmetric(
                    vertical: 0,
                    horizontal: 16,
                  ),
                ),
                onSubmitted: (val) {
                  setState(() => _modoParaTi = false);
                  catalogo.buscar(val);
                },
                textInputAction: TextInputAction.search,
              ),
            ),

            // 1. Selector Horizontal de Categorías
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  // Opción Recomendaciones IA "Para Ti"
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: _modoParaTi
                          ? const Icon(
                              Icons.auto_awesome,
                              size: 16,
                              color: Colors.white,
                            )
                          : const Icon(
                              Icons.auto_awesome,
                              size: 16,
                              color: Color(0xFFD97706),
                            ),
                      label: const Text('Para Ti ✨'),
                      selected: _modoParaTi,
                      onSelected: (_) {
                        if (!_modoParaTi) {
                          _cargarRecomendacionesParaTi();
                        } else {
                          setState(() => _modoParaTi = false);
                        }
                      },
                      selectedColor: const Color(0xFFD97706),
                      backgroundColor: const Color(0xFFFEF3C7),
                      labelStyle: TextStyle(
                        color: _modoParaTi
                            ? Colors.white
                            : const Color(0xFF92400E),
                        fontWeight: FontWeight.w700,
                        fontSize: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color: _modoParaTi
                              ? const Color(0xFFD97706)
                              : const Color(0xFFFDE68A),
                        ),
                      ),
                    ),
                  ),

                  // Opción por defecto: "Todas las prendas"
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      avatar: !_modoParaTi && catalogo.filtroCategoriaId == null
                          ? const Icon(
                              Icons.check,
                              size: 16,
                              color: Colors.white,
                            )
                          : const Icon(
                              Icons.checkroom_outlined,
                              size: 16,
                              color: AppColors.textSecondary,
                            ),
                      label: const Text('Todas las prendas'),
                      selected:
                          !_modoParaTi && catalogo.filtroCategoriaId == null,
                      onSelected: (_) {
                        setState(() => _modoParaTi = false);
                        catalogo.filtrarPorCategoria(null);
                      },
                      selectedColor: AppColors.primary,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color:
                            !_modoParaTi && catalogo.filtroCategoriaId == null
                            ? Colors.white
                            : AppColors.textPrimary,
                        fontWeight:
                            !_modoParaTi && catalogo.filtroCategoriaId == null
                            ? FontWeight.w600
                            : FontWeight.w500,
                        fontSize: 13,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20),
                        side: BorderSide(
                          color:
                              !_modoParaTi && catalogo.filtroCategoriaId == null
                              ? AppColors.primary
                              : AppColors.border,
                        ),
                      ),
                    ),
                  ),

                  // Categorías dinámicas cargadas del backend
                  ...catalogo.categorias.map((cat) {
                    final selected = catalogo.filtroCategoriaId == cat.id;
                    final nombreFormateado = cat.nombre.isNotEmpty
                        ? '${cat.nombre[0].toUpperCase()}${cat.nombre.substring(1)}'
                        : cat.nombre;

                    return Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        avatar: selected
                            ? const Icon(
                                Icons.check,
                                size: 16,
                                color: Colors.white,
                              )
                            : null,
                        label: Text(nombreFormateado),
                        selected: selected,
                        onSelected: (_) {
                          setState(() => _modoParaTi = false);
                          catalogo.filtrarPorCategoria(
                            selected ? null : cat.id,
                          );
                        },
                        selectedColor: AppColors.primary,
                        backgroundColor: Colors.white,
                        labelStyle: TextStyle(
                          color: selected
                              ? Colors.white
                              : AppColors.textPrimary,
                          fontWeight: selected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          fontSize: 13,
                        ),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(20),
                          side: BorderSide(
                            color: selected
                                ? AppColors.primary
                                : AppColors.border,
                          ),
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),

            // 2. Filtros Secundarios: Sucursales y Stock
            SingleChildScrollView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
              child: Row(
                children: [
                  if (catalogo.sucursales.isNotEmpty) ...[
                    FilterChip(
                      label: const Text('Todas las sucursales'),
                      selected: catalogo.filtroSucursalId == null,
                      onSelected: (_) => catalogo.filtrarPorSucursal(null),
                      selectedColor: AppColors.accentSoft,
                      backgroundColor: Colors.white,
                      labelStyle: TextStyle(
                        color: catalogo.filtroSucursalId == null
                            ? AppColors.accent
                            : AppColors.textSecondary,
                        fontSize: 12,
                        fontWeight: catalogo.filtroSucursalId == null
                            ? FontWeight.w600
                            : FontWeight.normal,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(
                          color: catalogo.filtroSucursalId == null
                              ? AppColors.accent
                              : AppColors.border,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    ...catalogo.sucursales.map((sucursal) {
                      final selected = catalogo.filtroSucursalId == sucursal.id;
                      return Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          avatar: selected
                              ? const Icon(
                                  Icons.store,
                                  size: 14,
                                  color: AppColors.accent,
                                )
                              : null,
                          label: Text(sucursal.nombre),
                          selected: selected,
                          onSelected: (_) => catalogo.filtrarPorSucursal(
                            selected ? null : sucursal.id,
                          ),
                          selectedColor: AppColors.accentSoft,
                          backgroundColor: Colors.white,
                          labelStyle: TextStyle(
                            color: selected
                                ? AppColors.accent
                                : AppColors.textSecondary,
                            fontSize: 12,
                            fontWeight: selected
                                ? FontWeight.w600
                                : FontWeight.normal,
                          ),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(16),
                            side: BorderSide(
                              color: selected
                                  ? AppColors.accent
                                  : AppColors.border,
                            ),
                          ),
                        ),
                      );
                    }),
                  ],
                  FilterChip(
                    avatar: catalogo.filtroSoloDisponibles
                        ? const Icon(Icons.check, size: 14, color: Colors.white)
                        : null,
                    label: const Text('Solo con stock'),
                    selected: catalogo.filtroSoloDisponibles,
                    onSelected: (_) => catalogo.alternarSoloDisponibles(),
                    selectedColor: AppColors.accent,
                    backgroundColor: Colors.white,
                    labelStyle: TextStyle(
                      color: catalogo.filtroSoloDisponibles
                          ? Colors.white
                          : AppColors.textSecondary,
                      fontSize: 12,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16),
                      side: BorderSide(
                        color: catalogo.filtroSoloDisponibles
                            ? AppColors.accent
                            : AppColors.border,
                      ),
                    ),
                  ),
                  if (catalogo.filtroCategoriaId != null ||
                      catalogo.filtroSucursalId != null ||
                      catalogo.filtroSoloDisponibles ||
                      catalogo.filtroBusqueda.isNotEmpty) ...[
                    const SizedBox(width: 8),
                    ActionChip(
                      avatar: const Icon(
                        Icons.close,
                        size: 14,
                        color: AppColors.danger,
                      ),
                      label: const Text('Limpiar filtros'),
                      onPressed: () {
                        _searchCtrl.clear();
                        catalogo.limpiarFiltros();
                      },
                      backgroundColor: Colors.red.shade50,
                      labelStyle: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 12,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16),
                        side: BorderSide(color: Colors.red.shade200),
                      ),
                    ),
                  ],
                ],
              ),
            ),

            const SizedBox(height: 6),

            // Contenido: Lista o Estados
            Expanded(
              child: RefreshIndicator(
                onRefresh: () async {
                  if (_modoParaTi) {
                    await _cargarRecomendacionesParaTi();
                  } else {
                    await catalogo.cargarPrendas();
                  }
                },
                child: _modoParaTi ? _buildParaTiGrid() : _buildGrid(catalogo),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildParaTiGrid() {
    if (_cargandoParaTi && _recomendacionesParaTi.isEmpty) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: Color(0xFFD97706)),
            SizedBox(height: 16),
            Text(
              'Generando recomendaciones con IA...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_recomendacionesParaTi.isEmpty) {
      return EmptyState(
        icon: _errorParaTi == null
            ? Icons.auto_awesome
            : Icons.wifi_off_outlined,
        title: _errorParaTi == null
            ? 'Aún no tenemos recomendaciones personalizadas'
            : 'No se pudieron cargar tus recomendaciones',
        subtitle: _errorParaTi ?? 'Explora prendas, agrégalas a favoritos o realiza una compra para que nuestra IA conozca tu estilo.',
        actionText: _errorParaTi == null
            ? 'Ver catálogo completo'
            : 'Reintentar',
        onAction: _errorParaTi == null
            ? () {
                setState(() => _modoParaTi = false);
              }
            : _cargarRecomendacionesParaTi,
      );
    }

    return Column(
      children: [
        Container(
          margin: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
          decoration: BoxDecoration(
            color: const Color(0xFFFEF3C7),
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFFDE68A)),
          ),
          child: const Row(
            children: [
              Icon(Icons.auto_awesome, color: Color(0xFFD97706), size: 18),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'Sugerencias inteligentes basadas en tu perfil y prendas favoritas.',
                  style: TextStyle(
                    fontSize: 12,
                    color: Color(0xFF92400E),
                    fontWeight: FontWeight.w500,
                  ),
                ),
              ),
            ],
          ),
        ),
        Expanded(
          child: GridView.builder(
            padding: const EdgeInsets.all(16),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 2,
              childAspectRatio: 0.65,
              crossAxisSpacing: 14,
              mainAxisSpacing: 14,
            ),
            itemCount: _recomendacionesParaTi.length,
            itemBuilder: (context, index) {
              final rec = _recomendacionesParaTi[index];
              return ProductCard(
                prenda: rec.prenda,
                recommendationReason: rec.motivo,
                onFavoriteChanged: _modoParaTi
                    ? _cargarRecomendacionesParaTi
                    : null,
                onTap: () {
                  Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => ProductoDetalleScreen(
                        productoId: rec.prenda.productoId,
                      ),
                    ),
                  );
                },
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildGrid(CatalogoProvider catalogo) {
    if (catalogo.cargando && catalogo.prendas.isEmpty) {
      return const Center(child: CircularProgressIndicator());
    }

    if (catalogo.error != null && catalogo.prendas.isEmpty) {
      return EmptyState(
        icon: Icons.wifi_off_outlined,
        title: 'Error al conectar con la tienda',
        subtitle: catalogo.error,
        actionText: 'Reintentar',
        onAction: () => catalogo.cargarPrendas(),
      );
    }

    if (catalogo.prendas.isEmpty) {
      return EmptyState(
        icon: Icons.search_off_outlined,
        title: 'No se encontraron prendas',
        subtitle: 'Intenta modificar tus filtros o términos de búsqueda.',
        actionText: 'Limpiar Filtros',
        onAction: () {
          _searchCtrl.clear();
          catalogo.limpiarFiltros();
        },
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        childAspectRatio: 0.65,
        crossAxisSpacing: 14,
        mainAxisSpacing: 14,
      ),
      itemCount: catalogo.prendas.length,
      itemBuilder: (context, index) {
        final prenda = catalogo.prendas[index];
        return ProductCard(
          prenda: prenda,
          onTap: () {
            Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    ProductoDetalleScreen(productoId: prenda.productoId),
              ),
            );
          },
        );
      },
    );
  }
}
