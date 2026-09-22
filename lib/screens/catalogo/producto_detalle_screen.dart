import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:url_launcher/url_launcher.dart';

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
import '../vestidor/probador_ia_screen.dart';
import '../vestidor/services/vestidor_api_service.dart';
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

  Future<void> _lanzarMotor3DDirecto({
    required String targetUrl,
    required int productoId,
    int? varianteId,
  }) async {
    final auth = Provider.of<AuthProvider>(context, listen: false);

    // Registrar telemetría de la sesión (CU24) en PostgreSQL
    VestidorApiService.registrarSesion(
      clienteId: auth.usuario?.id,
      productoId: productoId,
      varianteId: varianteId,
      origen: 'CATALOGO_3D_DIRECTO',
    );

    // Modal de Calibración
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: const Color(0xFF0F172A),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        content: const Padding(
          padding: EdgeInsets.symmetric(vertical: 8),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              CircularProgressIndicator(color: Color(0xFF00E5FF)),
              SizedBox(height: 18),
              Text(
                'Iniciando Motor AR 3D StyleAR...',
                style: TextStyle(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                  fontSize: 16,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Calibrando sensor de tracking a 60 FPS\ny sincronizando telemetría con PostgreSQL (CU24)...',
                textAlign: TextAlign.center,
                style: TextStyle(color: Colors.white60, fontSize: 12),
              ),
            ],
          ),
        ),
      ),
    );

    await Future.delayed(const Duration(milliseconds: 1200));
    if (mounted) Navigator.pop(context);

    final cleanUrl = targetUrl.trim();
    final uri = Uri.parse(cleanUrl);

    bool launched = false;
    // Intento 1: External application (app nativa o navegador externo)
    try {
      launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    } catch (e) {
      debugPrint('Error en LaunchMode.externalApplication: $e');
    }

    // Intento 2: Platform default si no abrió
    if (!launched) {
      try {
        launched = await launchUrl(uri, mode: LaunchMode.platformDefault);
      } catch (e) {
        debugPrint('Error en LaunchMode.platformDefault: $e');
      }
    }

    // Intento 3: In-app browser como fallback
    if (!launched) {
      try {
        launched = await launchUrl(uri, mode: LaunchMode.inAppBrowserView);
      } catch (e) {
        debugPrint('Error en LaunchMode.inAppBrowserView: $e');
      }
    }

    if (!launched && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('No se pudo abrir el motor AR 3D. Verifica el navegador de tu dispositivo.'),
          backgroundColor: Colors.redAccent,
        ),
      );
    }
  }

  void _abrirModalOpcionesVestidor(CatalogoPrendaDetalle detalle, CatalogoVariante? varianteActual) {
    final bool tiene3D = detalle.modelo3dUrl != null && detalle.modelo3dUrl!.trim().isNotEmpty;

    showModalBottomSheet(
      context: context,
      backgroundColor: const Color(0xFF0F172A),
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
      ),
      builder: (ctx) {
        return SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Center(
                  child: Container(
                    width: 44,
                    height: 4,
                    decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                ),
                const SizedBox(height: 18),
                Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.all(10),
                      decoration: BoxDecoration(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(Icons.checkroom_rounded, color: Color(0xFF00E5FF), size: 24),
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          const Text(
                            'VESTIDOR VIRTUAL STYLE-AR',
                            style: TextStyle(
                              color: Colors.white,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 0.5,
                            ),
                          ),
                          Text(
                            detalle.nombre,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(color: Colors.white60, fontSize: 12),
                          ),
                        ],
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 20),

                // OPCIÓN 1: Simulador con IA (SIEMPRE DISPONIBLE PARA TODOS LOS PRODUCTOS)
                GestureDetector(
                  onTap: () {
                    Navigator.pop(ctx);
                    Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => ProbadorIaScreen(
                          productoInicialId: detalle.productoId,
                        ),
                      ),
                    );
                  },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      gradient: const LinearGradient(
                        colors: [Color(0xFF1E293B), Color(0xFF0F172A)],
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                      ),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: const Color(0xFF00E5FF).withValues(alpha: 0.6),
                        width: 1.5,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: const Color(0xFF00E5FF).withValues(alpha: 0.12),
                          blurRadius: 10,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: const Color(0xFF00E5FF).withValues(alpha: 0.2),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: const Icon(
                            Icons.auto_awesome,
                            color: Color(0xFF00E5FF),
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  const Text(
                                    'Simulador con IA',
                                    style: TextStyle(
                                      color: Colors.white,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: const Color(0xFF10B981).withValues(alpha: 0.2),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: const Text(
                                      '✨ Para Todo el Catálogo',
                                      style: TextStyle(
                                        color: Color(0xFF10B981),
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              const Text(
                                'Pruébate esta prenda subiendo tu foto. La IA ajusta la fisonomía y sombras usando la imagen del producto (no requiere 3D).',
                                style: TextStyle(
                                  color: Colors.white70,
                                  fontSize: 11,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 14),

                // OPCIÓN 2: Vestidor 3D en Vivo (EN GRIS SOLO SI NO TIENE MODELO 3D)
                GestureDetector(
                  onTap: tiene3D
                      ? () {
                          Navigator.pop(ctx);
                          _lanzarMotor3DDirecto(
                            targetUrl: detalle.modelo3dUrl!,
                            productoId: detalle.productoId,
                            varianteId: varianteActual?.id,
                          );
                        }
                      : () {
                          Navigator.pop(ctx);
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                'Esta prenda aún no cuenta con modelo 3D en vivo. Utiliza la opción "Simulador con IA" para probártela.',
                              ),
                              backgroundColor: Color(0xFF334155),
                              duration: Duration(seconds: 3),
                            ),
                          );
                        },
                  child: Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: tiene3D
                          ? const Color(0xFF1E293B).withValues(alpha: 0.6)
                          : const Color(0xFF1E293B).withValues(alpha: 0.25),
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                        color: tiene3D ? const Color(0xFF60A5FA).withValues(alpha: 0.5) : Colors.white10,
                        width: tiene3D ? 1.2 : 1,
                      ),
                    ),
                    child: Row(
                      children: [
                        Container(
                          width: 48,
                          height: 48,
                          decoration: BoxDecoration(
                            color: tiene3D
                                ? const Color(0xFF3B82F6).withValues(alpha: 0.2)
                                : Colors.white.withValues(alpha: 0.04),
                            borderRadius: BorderRadius.circular(14),
                          ),
                          child: Icon(
                            Icons.view_in_ar_rounded,
                            color: tiene3D ? const Color(0xFF60A5FA) : Colors.white24,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'Vestidor 3D en Vivo',
                                    style: TextStyle(
                                      color: tiene3D ? Colors.white : Colors.white38,
                                      fontWeight: FontWeight.bold,
                                      fontSize: 15,
                                    ),
                                  ),
                                  const Spacer(),
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                    decoration: BoxDecoration(
                                      color: tiene3D
                                          ? Colors.blueAccent.withValues(alpha: 0.2)
                                          : Colors.white.withValues(alpha: 0.05),
                                      borderRadius: BorderRadius.circular(8),
                                    ),
                                    child: Text(
                                      tiene3D ? 'Tracking 60 FPS' : 'No disponible en 3D',
                                      style: TextStyle(
                                        color: tiene3D ? const Color(0xFF60A5FA) : Colors.white38,
                                        fontSize: 10,
                                        fontWeight: FontWeight.bold,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
                              const SizedBox(height: 5),
                              Text(
                                tiene3D
                                    ? 'Tracking corporal completo a 60 FPS con física de tela volumétrica en tiempo real.'
                                    : 'Esta prenda aún no cuenta con modelo volumétrico 3D. Elige "Simulador con IA" para probártela.',
                                style: TextStyle(
                                  color: tiene3D ? Colors.white70 : Colors.white30,
                                  fontSize: 11,
                                  height: 1.3,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ),

                const SizedBox(height: 16),

                // Acceso al Estudio de Outfits Completo (VestidorScreen)
                Center(
                  child: TextButton.icon(
                    onPressed: () {
                      Navigator.pop(ctx);
                      Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => VestidorScreen(
                            productoId: detalle.productoId,
                            varianteInicialId: varianteActual?.id,
                          ),
                        ),
                      );
                    },
                    icon: const Icon(Icons.style_outlined, color: Colors.white60, size: 16),
                    label: const Text(
                      'Combinar en Estudio de Outfits Completo',
                      style: TextStyle(
                        color: Colors.white70,
                        fontSize: 12,
                        decoration: TextDecoration.underline,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
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

                          // Botón Probar en Vestidor Virtual (CU24) - Siempre activo para todo el catálogo
                          Container(
                            margin: const EdgeInsets.only(bottom: 12),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(14),
                              gradient: const LinearGradient(
                                colors: [Color(0xFF0F172A), Color(0xFF1E293B)],
                              ),
                              border: Border.all(
                                color: const Color(0xFF00E5FF).withValues(alpha: 0.35),
                              ),
                              boxShadow: [
                                BoxShadow(
                                  color: const Color(0xFF0F172A).withValues(alpha: 0.3),
                                  blurRadius: 8,
                                  offset: const Offset(0, 3),
                                ),
                              ],
                            ),
                            child: Material(
                              color: Colors.transparent,
                              child: InkWell(
                                borderRadius: BorderRadius.circular(14),
                                onTap: () => _abrirModalOpcionesVestidor(detalle, varianteActual),
                                child: const Padding(
                                  padding: EdgeInsets.symmetric(
                                    vertical: 14,
                                    horizontal: 16,
                                  ),
                                  child: Row(
                                    mainAxisAlignment: MainAxisAlignment.center,
                                    children: [
                                      Icon(
                                        Icons.checkroom_rounded,
                                        color: Color(0xFF00E5FF),
                                        size: 22,
                                      ),
                                      SizedBox(width: 10),
                                      Text(
                                        'Probar en Vestidor Virtual',
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
