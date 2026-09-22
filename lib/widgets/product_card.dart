import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../core/constants/app_colors.dart';
import '../models/catalogo_models.dart';
import '../providers/auth_provider.dart';
import '../providers/favoritos_provider.dart';
import '../screens/auth/login_screen.dart';
import 'stock_badge.dart';

class ProductCard extends StatelessWidget {
  final CatalogoPrendaItem prenda;
  final VoidCallback? onTap;
  final String? recommendationReason;
  final Future<void> Function()? onFavoriteChanged;

  const ProductCard({
    super.key,
    required this.prenda,
    this.onTap,
    this.recommendationReason,
    this.onFavoriteChanged,
  });

  Widget _buildImage() {
    if (prenda.imagenPrincipal != null && prenda.imagenPrincipal!.isNotEmpty) {
      final img = prenda.imagenPrincipal!;
      if (img.startsWith('data:image')) {
        try {
          final base64String = img.split(',').last;
          final bytes = base64Decode(base64String);
          return Image.memory(
            bytes,
            fit: BoxFit.cover,
            width: double.infinity,
            errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
          );
        } catch (_) {
          return _buildPlaceholder();
        }
      } else if (img.startsWith('http')) {
        return Image.network(
          img,
          fit: BoxFit.cover,
          width: double.infinity,
          errorBuilder: (context, error, stackTrace) => _buildPlaceholder(),
        );
      }
    }
    return _buildPlaceholder();
  }

  Widget _buildPlaceholder() {
    return Container(
      color: AppColors.background,
      width: double.infinity,
      child: const Center(
        child: Icon(
          Icons.checkroom_outlined,
          size: 40,
          color: AppColors.border,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final currencyFormat = NumberFormat.currency(
      locale: 'es_BO',
      symbol: 'Bs. ',
    );

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Card(
        clipBehavior: Clip.antiAlias,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Imagen con Badge de Stock
            Expanded(
              flex: 12,
              child: Stack(
                fit: StackFit.expand,
                children: [
                  _buildImage(),
                  Positioned(
                    top: 8,
                    right: 8,
                    child: StockBadge.fromStock(prenda.stockTotal),
                  ),
                  if (prenda.tienePromocion)
                    Positioned(
                      top: 8,
                      left: 8,
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.danger,
                          borderRadius: BorderRadius.circular(12),
                        ),
                        child: const Text(
                          'OFERTA',
                          style: TextStyle(
                            color: Colors.white,
                            fontSize: 10,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                    ),
                  Positioned(
                    bottom: 8,
                    right: 8,
                    child: Consumer2<AuthProvider, FavoritosProvider>(
                      builder: (context, auth, favProvider, _) {
                        final esFav = favProvider.esFavorito(prenda.productoId);
                        return Material(
                          color: Colors.white.withValues(alpha: 0.92),
                          shape: const CircleBorder(),
                          elevation: 2,
                          child: InkWell(
                            customBorder: const CircleBorder(),
                            onTap: () async {
                              if (!auth.estaAutenticado) {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => const LoginScreen(),
                                  ),
                                );
                                return;
                              }
                              final ok = await favProvider.toggleFavorito(
                                prenda.productoId,
                              );
                              if (ok) {
                                await onFavoriteChanged?.call();
                              }
                            },
                            child: Padding(
                              padding: const EdgeInsets.all(6),
                              child: Icon(
                                esFav ? Icons.favorite : Icons.favorite_border,
                                size: 18,
                                color: esFav
                                    ? Colors.red
                                    : AppColors.textSecondary,
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                ],
              ),
            ),
            // Información del Producto
            Padding(
              padding: const EdgeInsets.all(10),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    prenda.categoria.toUpperCase(),
                    style: const TextStyle(
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textSecondary,
                      letterSpacing: 0.5,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 2),
                  Text(
                    prenda.nombre,
                    style: const TextStyle(
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  const SizedBox(height: 4),
                  if (recommendationReason != null &&
                      recommendationReason!.isNotEmpty) ...[
                    Container(
                      margin: const EdgeInsets.only(bottom: 5),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 7,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: const Color(0xFFFEF3C7),
                        borderRadius: BorderRadius.circular(8),
                        border: Border.all(color: const Color(0xFFFDE68A)),
                      ),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.auto_awesome,
                            size: 12,
                            color: Color(0xFFD97706),
                          ),
                          const SizedBox(width: 4),
                          Expanded(
                            child: Text(
                              recommendationReason!,
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(
                                fontSize: 9.5,
                                color: Color(0xFF92400E),
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ],
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      if (prenda.tienePromocion &&
                          prenda.precioVigente != null) ...[
                        Text(
                          currencyFormat.format(prenda.precioVigente),
                          style: const TextStyle(
                            fontSize: 11,
                            decoration: TextDecoration.lineThrough,
                            color: AppColors.textSecondary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                        const SizedBox(height: 1),
                      ],
                      Text(
                        currencyFormat.format(prenda.precioFinal),
                        style: TextStyle(
                          fontSize: 14,
                          fontWeight: FontWeight.w800,
                          color: prenda.tienePromocion
                              ? AppColors.danger
                              : AppColors.primary,
                        ),
                      ),
                    ],
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
