import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/constants/app_colors.dart';
import '../../models/catalogo_models.dart';
import '../../models/recomendacion_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/carrito_provider.dart';
import '../../providers/catalogo_provider.dart';
import '../../providers/favoritos_provider.dart';
import '../../services/admin_catalogo_service.dart';
import '../../services/recomendacion_service.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/product_card.dart';
import '../../widgets/stock_badge.dart';
import '../admin_catalogo/admin_producto_form_screen.dart';
import '../auth/login_screen.dart';
import '../vestidor/vestidor_screen.dart';

class ProductoDetalleScreen extends StatefulWidget {
  final int productoId;

  const ProductoDetalleScreen({super.key, required this.productoId});

  @override
  State<ProductoDetalleScreen> createState() => _ProductoDetalleScreenState();
}

class _ProductoDetalleScreenState extends State<ProductoDetalleScreen> {
  CatalogoVariante? _varianteSeleccionada;
  int _cantidad = 1;
  List<RecomendacionPrendaItem> _recomendaciones = [];
  bool _cargandoRecomendaciones = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<CatalogoProvider>().cargarPrendaDetalle(widget.productoId);
      _cargarRecomendaciones();
    });
  }

  Future<void> _cargarRecomendaciones() async {
    setState(() => _cargandoRecomendaciones = true);
    try {
      final items = await RecomendacionService.obtenerPorProducto(
        widget.productoId,
      );
      if (mounted) setState(() => _recomendaciones = items);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _cargandoRecomendaciones = false);
    }
  }

  void _abrirDisponibilidadPorSucursal(CatalogoPrendaDetalle detalle) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) {
        final disp = detalle.disponibilidad;
        return Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text(
                    'Disponibilidad por Sucursal',
                    style: TextStyle(
                      fontFamily: 'Playfair Display',
                      fontSize: 20,
                      fontWeight: FontWeight.w700,
                      color: AppColors.primary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close),
                    onPressed: () => Navigator.of(ctx).pop(),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              const Text(
                'El stock real se calcula descontando las reservas activas.',
                style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 16),
              if (disp.isEmpty)
                const Padding(
                  padding: EdgeInsets.symmetric(vertical: 24),
                  child: Center(
                    child: Text(
                      'No hay información de sucursales disponible para esta prenda.',
                      style: TextStyle(color: AppColors.textSecondary),
                    ),
                  ),
                )
              else
                ...disp.map((item) {
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(14),
                    decoration: BoxDecoration(
                      color: AppColors.background,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.border),
                    ),
                    child: Row(
                      children: [
                        const Icon(
                          Icons.storefront_outlined,
                          color: AppColors.primary,
                          size: 24,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                item.sucursal,
                                style: const TextStyle(
                                  fontWeight: FontWeight.w600,
                                  fontSize: 14,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                item.ciudad,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                              if (item.talla != null || item.color != null)
                                Text(
                                  'Talla: ${item.talla ?? '-'} | Color: ${item.color ?? '-'}',
                                  style: const TextStyle(
                                    fontSize: 11,
                                    color: AppColors.textSecondary,
                                  ),
                                ),
                            ],
                          ),
                        ),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Text(
                              '${item.stockReal} unid.',
                              style: TextStyle(
                                fontWeight: FontWeight.bold,
                                fontSize: 15,
                                color: item.stockReal > 0
                                    ? AppColors.success
                                    : AppColors.danger,
                              ),
                            ),
                            Text(
                              '(${item.stockReservado} reservadas)',
                              style: const TextStyle(
                                fontSize: 10,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                }),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  Future<void> _agregarAlCarrito(CatalogoPrendaDetalle detalle) async {
    final auth = context.read<AuthProvider>();
    if (!auth.estaAutenticado) {
      final quiereIniciar = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Iniciar Sesión Requerido'),
          content: const Text(
            'Para agregar prendas a tu carrito o reservarlas, necesitas tener una sesión iniciada.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(ctx).pop(false),
              child: const Text('Cancelar'),
            ),
            ElevatedButton(
              onPressed: () => Navigator.of(ctx).pop(true),
              child: const Text('Iniciar Sesión'),
            ),
          ],
        ),
      );

      if (quiereIniciar == true && mounted) {
        Navigator.of(context)
            .push(MaterialPageRoute(builder: (_) => const LoginScreen()));
      }
      return;
    }

    final variante =
        _varianteSeleccionada ??
        (detalle.variantes.isNotEmpty ? detalle.variantes.first : null);
    if (variante == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Esta prenda no tiene variantes disponibles.'),
        ),
      );
      return;
    }

    final carrito = context.read<CarritoProvider>();
    final ok = await carrito.agregarItem(
      varianteId: variante.id,
      cantidad: _cantidad,
    );

    if (ok && mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('¡${detalle.nombre} agregado al carrito!'),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 2),
          action: SnackBarAction(
            label: 'Ver Carrito',
            textColor: Colors.white,
            onPressed: () {
              ScaffoldMessenger.of(context).hideCurrentSnackBar();
              Navigator.of(context).pop(); // Vuelve para ir al carrito
            },
          ),
        ),
      );
    } else if (mounted && carrito.error != null) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(carrito.error!),
          backgroundColor: AppColors.danger,
          duration: const Duration(seconds: 2),
        ),
      );
    }
  }

  Widget _buildImage(String? img) {
    if (img != null && img.isNotEmpty) {
      if (img.startsWith('data:image')) {
        try {
          final base64String = img.split(',').last;
          final bytes = base64Decode(base64String);
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            height: 320,
            width: double.infinity,
          );
        } catch (_) {}
      } else if (img.startsWith('http')) {
        return Image.network(
          img,
          fit: BoxFit.cover,
          height: 320,
          width: double.infinity,
        );
      }
    }
    return Container(
      height: 260,
      color: AppColors.background,
      child: const Center(
        child: Icon(
          Icons.checkroom_outlined,
          size: 64,
          color: AppColors.border,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final catalogo = context.watch<CatalogoProvider>();
    final detalle = catalogo.detalleSeleccionado;
    final currencyFormat = NumberFormat.currency(
      locale: 'es_BO',
      symbol: 'Bs. ',
    );

    if (catalogo.cargandoDetalle || detalle == null) {
      return Scaffold(
        appBar: AppBar(),
        body: const Center(child: CircularProgressIndicator()),
      );
    }

    // Si aún no se seleccionó variante, se usa la primera por defecto
    final varianteActual =
        _varianteSeleccionada ??
        (detalle.variantes.isNotEmpty ? detalle.variantes.first : null);
    final precio = varianteActual?.precioFinal ?? detalle.precioFinal;
    final tienePromocion =
        varianteActual?.tienePromocion ?? detalle.tienePromocion;
    final precioVigente =
        varianteActual?.precioVigente ?? detalle.precioVigente;

    return Scaffold(
      appBar: AppBar(
        title: Text(detalle.nombre),
        actions: [
          Consumer2<AuthProvider, FavoritosProvider>(
            builder: (context, auth, favProvider, _) {
              final esFav = favProvider.esFavorito(widget.productoId);
              return IconButton(
                icon: Icon(
                  esFav ? Icons.favorite : Icons.favorite_border,
                  color: esFav ? Colors.red : null,
                ),
                tooltip: esFav ? 'Quitar de Favoritos' : 'Añadir a Favoritos',
                onPressed: () async {
                  if (!auth.estaAutenticado) {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                    return;
                  }
                  final ok = await favProvider.toggleFavorito(
                    widget.productoId,
                  );
                  if (ok) {
                    await _cargarRecomendaciones();
                  }
                  if (!context.mounted) return;
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(
                        esFav
                            ? 'Eliminado de tus favoritos'
                            : '¡Añadido a tus favoritos!',
                      ),
                      duration: const Duration(seconds: 2),
                      backgroundColor: esFav
                          ? AppColors.textSecondary
                          : AppColors.success,
                    ),
                  );
                },
              );
            },
          ),
          IconButton(
            icon: const Icon(Icons.location_on_outlined),
            tooltip: 'Disponibilidad por Sucursal',
            onPressed: () => _abrirDisponibilidadPorSucursal(detalle),
          ),
          if (context.watch<AuthProvider>().esAdminOEncargado)
            IconButton(
              icon: const Icon(Icons.edit_outlined),
              tooltip: 'Editar en Catálogo Admin',
              onPressed: () async {
                try {
                  final prod = await AdminCatalogoService.obtenerProducto(
                    widget.productoId,
                  );
                  if (context.mounted) {
                    final res = await Navigator.of(context).push<bool>(
                      MaterialPageRoute(
                        builder: (_) => AdminProductoFormScreen(producto: prod),
                      ),
                    );
                    if (res == true && context.mounted) {
                      context.read<CatalogoProvider>().cargarPrendaDetalle(
                        widget.productoId,
                      );
                    }
                  }
                } catch (e) {
                  if (context.mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      SnackBar(content: Text('Error al abrir editor: $e')),
                    );
                  }
                }
              },
            ),
        ],
      ),
      body: SafeArea(
        child: Column(
          children: [
            Expanded(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Imagen principal
                    _buildImage(detalle.imagenPrincipal),

                    Padding(
                      padding: const EdgeInsets.all(20),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          // Categoría y Marca
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              Text(
                                '${detalle.categoria.toUpperCase()} ${detalle.marca != null ? "• ${detalle.marca!.toUpperCase()}" : ""}',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.w700,
                                  color: AppColors.accent,
                                  letterSpacing: 0.5,
                                ),
                              ),
                              StockBadge.fromStock(detalle.stockTotal),
                            ],
                          ),
                          const SizedBox(height: 8),

                          // Nombre de la prenda
                          Text(
                            detalle.nombre,
                            style: const TextStyle(
                              fontFamily: 'Playfair Display',
                              fontSize: 24,
                              fontWeight: FontWeight.w700,
                              color: AppColors.textPrimary,
                            ),
                          ),
                          const SizedBox(height: 8),

                          // Precio
                          Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              if (tienePromocion)
                                Container(
                                  margin: const EdgeInsets.only(bottom: 8),
                                  padding: const EdgeInsets.symmetric(
                                    horizontal: 10,
                                    vertical: 5,
                                  ),
                                  decoration: BoxDecoration(
                                    color: AppColors.danger,
                                    borderRadius: BorderRadius.circular(999),
                                  ),
                                  child: const Text(
                                    'OFERTA',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontSize: 11,
                                      fontWeight: FontWeight.w800,
                                      letterSpacing: 0.7,
                                    ),
                                  ),
                                ),
                              if (tienePromocion && precioVigente != null) ...[
                                Text(
                                  currencyFormat.format(precioVigente),
                                  style: const TextStyle(
                                    fontSize: 14,
                                    decoration: TextDecoration.lineThrough,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w600,
                                  ),
                                ),
                                const SizedBox(height: 2),
                              ],
                              Text(
                                currencyFormat.format(precio),
                                style: TextStyle(
                                  fontSize: 24,
                                  fontWeight: FontWeight.w900,
                                  color: tienePromocion
                                      ? AppColors.danger
                                      : AppColors.primary,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 16),

                          // Selector de Variantes (Talla y Color)
                          if (detalle.variantes.isNotEmpty) ...[
                            const Text(
                              'SELECCIONAR VARIANTE (TALLA / COLOR)',
                              style: TextStyle(
                                fontSize: 12,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.8,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 12),
                            Wrap(
                              spacing: 8,
                              runSpacing: 8,
                              children: detalle.variantes.map((variante) {
                                final isSelected =
                                    varianteActual?.id == variante.id;
                                final label =
                                    '${variante.talla ?? ""} - ${variante.color ?? ""}'
                                        .trim();
                                return ChoiceChip(
                                  label: Text(
                                    label.isNotEmpty
                                        ? label
                                        : 'Variante ${variante.sku}',
                                  ),
                                  selected: isSelected,
                                  selectedColor: AppColors.primary,
                                  labelStyle: TextStyle(
                                    color: isSelected
                                        ? Colors.white
                                        : AppColors.textPrimary,
                                    fontWeight: isSelected
                                        ? FontWeight.bold
                                        : FontWeight.normal,
                                    fontSize: 12,
                                  ),
                                  onSelected: (selected) {
                                    if (selected) {
                                      setState(() {
                                        _varianteSeleccionada = variante;
                                      });
                                    }
                                  },
                                );
                              }).toList(),
                            ),
                            const SizedBox(height: 20),
                          ],

                          // Botón Vestidor Virtual AR (CU24)
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(12),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0F172A)
                                      .withValues(alpha: 0.25),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(12),
                                onTap: () {
                                  Navigator.of(context).push(
                                    MaterialPageRoute(
                                      builder: (_) => VestidorScreen(
                                        productoId: widget.productoId,
                                        varianteInicialId: varianteActual?.id,
                                      ),
                                    ),
                                  );
                                },
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: 14,
                                    horizontal: 16,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.view_in_ar_rounded,
                                        color: Color(0xFF00E5FF),
                                        size: 22,
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        'Probar en Vestidor Virtual (AR)',
                                        style: TextStyle(
                                          color: Colors.white,
                                          fontWeight: FontWeight.w700,
                                          fontSize: 14,
                                          letterSpacing: 0.3,
                                        ),
                                      ),
                                    ],
                                  ),
                                ),
                              ),
                            ),
                          ),

                          // Botón para consultar disponibilidad por sucursal
                          OutlinedButton.icon(
                            icon: const Icon(
                              Icons.store_mall_directory_outlined,
                              size: 18,
                            ),
                            label: const Text(
                              'Consultar disponibilidad por sucursal',
                            ),
                            style: OutlinedButton.styleFrom(
                              minimumSize: const Size(double.infinity, 44),
                            ),
                            onPressed: () =>
                                _abrirDisponibilidadPorSucursal(detalle),
                          ),

                          const SizedBox(height: 20),
                          const Divider(),
                          const SizedBox(height: 16),

                          // Selector de Cantidad
                          Row(
                            mainAxisAlignment: MainAxisAlignment.spaceBetween,
                            children: [
                              const Text(
                                'Cantidad a reservar:',
                                style: TextStyle(
                                  fontSize: 14,
                                  fontWeight: FontWeight.w600,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Container(
                                decoration: BoxDecoration(
                                  color: AppColors.background,
                                  borderRadius: BorderRadius.circular(8),
                                  border: Border.all(color: AppColors.border),
                                ),
                                child: Row(
                                  children: [
                                    IconButton(
                                      icon: const Icon(Icons.remove, size: 18),
                                      onPressed: _cantidad > 1
                                          ? () => setState(() => _cantidad--)
                                          : null,
                                    ),
                                    Text(
                                      '$_cantidad',
                                      style: const TextStyle(
                                        fontSize: 16,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                    IconButton(
                                      icon: const Icon(Icons.add, size: 18),
                                      onPressed: () =>
                                          setState(() => _cantidad++),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 24),

                          // Descripción y Detalles
                          if (detalle.descripcion != null &&
                              detalle.descripcion!.isNotEmpty) ...[
                            const Text(
                              'Descripción',
                              style: TextStyle(
                                fontSize: 16,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 6),
                            Text(
                              detalle.descripcion!,
                              style: const TextStyle(
                                fontSize: 14,
                                color: AppColors.textSecondary,
                                height: 1.4,
                              ),
                            ),
                            const SizedBox(height: 20),
                          ],
                        ],
                      ),
                    ),
                    // Recomendaciones IA: Te podría gustar
                    if (_cargandoRecomendaciones)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 24),
                        child: Center(
                          child: CircularProgressIndicator(strokeWidth: 2),
                        ),
                      )
                    else if (_recomendaciones.isNotEmpty) ...[
                      const Divider(),
                      const SizedBox(height: 12),
                      const Padding(
                        padding: EdgeInsets.symmetric(horizontal: 20),
                        child: Row(
                          children: [
                            Icon(
                              Icons.auto_awesome,
                              size: 20,
                              color: AppColors.primary,
                            ),
                            SizedBox(width: 8),
                            Text(
                              'Te podría gustar',
                              style: TextStyle(
                                fontFamily: 'Playfair Display',
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.primary,
                              ),
                            ),
                          ],
                        ),
                      ),
                      const SizedBox(height: 12),
                      SizedBox(
                        height: 250,
                        child: ListView.separated(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 20),
                          itemCount: _recomendaciones.length,
                          separatorBuilder: (_, index) =>
                              const SizedBox(width: 14),
                          itemBuilder: (context, index) {
                            final rec = _recomendaciones[index];
                            return SizedBox(
                              width: 155,
                              child: ProductCard(
                                prenda: rec.prenda,
                                recommendationReason: rec.motivo,
                                onFavoriteChanged: _cargarRecomendaciones,
                                onTap: () {
                                  Navigator.of(context).pushReplacement(
                                    MaterialPageRoute(
                                      builder: (_) => ProductoDetalleScreen(
                                        productoId: rec.prenda.productoId,
                                      ),
                                    ),
                                  );
                                },
                              ),
                            );
                          },
                        ),
                      ),
                      const SizedBox(height: 20),
                    ],
                  ],
                ),
              ),
            ),

            // Barra Inferior Fija para Agregar al Carrito
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.05),
                    offset: const Offset(0, -2),
                    blurRadius: 10,
                  ),
                ],
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        const Text(
                          'Total estimado',
                          style: TextStyle(
                            fontSize: 11,
                            color: AppColors.textSecondary,
                          ),
                        ),
                        Text(
                          currencyFormat.format(precio * _cantidad),
                          style: const TextStyle(
                            fontSize: 18,
                            fontWeight: FontWeight.bold,
                            color: AppColors.primary,
                          ),
                        ),
                      ],
                    ),
                  ),
                  Expanded(
                    flex: 2,
                    child: CustomButton(
                      text: 'Agregar al Carrito',
                      icon: Icons.shopping_bag_outlined,
                      onPressed: () => _agregarAlCarrito(detalle),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
