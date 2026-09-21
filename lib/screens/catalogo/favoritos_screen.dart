import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/favoritos_provider.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/product_card.dart';
import '../auth/login_screen.dart';
import 'producto_detalle_screen.dart';

class FavoritosScreen extends StatefulWidget {
  const FavoritosScreen({super.key});

  @override
  State<FavoritosScreen> createState() => _FavoritosScreenState();
}

class _FavoritosScreenState extends State<FavoritosScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final auth = context.read<AuthProvider>();
      if (auth.estaAutenticado) {
        context.read<FavoritosProvider>().cargarFavoritos();
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final favProvider = context.watch<FavoritosProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mis Favoritos'),
      ),
      body: !auth.estaAutenticado
          ? Center(
              child: Padding(
                padding: const EdgeInsets.all(32),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    const Icon(Icons.favorite_border, size: 72, color: AppColors.border),
                    const SizedBox(height: 16),
                    const Text(
                      'Inicia sesión para ver tus favoritos',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        color: AppColors.textPrimary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Guarda las prendas que más te gusten y accede a ellas fácilmente desde cualquier dispositivo.',
                      textAlign: TextAlign.center,
                      style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
                    ),
                    const SizedBox(height: 24),
                    ElevatedButton(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
                        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                      ),
                      onPressed: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const LoginScreen()),
                        );
                      },
                      child: const Text('Iniciar Sesión'),
                    ),
                  ],
                ),
              ),
            )
          : favProvider.cargando && favProvider.favoritos.isEmpty
              ? const Center(child: CircularProgressIndicator())
              : favProvider.favoritos.isEmpty
                  ? EmptyState(
                      icon: Icons.favorite_border,
                      title: 'Aún no tienes favoritos',
                      subtitle: 'Explora nuestro catálogo y presiona el corazón en las prendas que te encanten.',
                      actionText: 'Explorar catálogo',
                      onAction: () => Navigator.of(context).pop(),
                    )
                  : RefreshIndicator(
                      onRefresh: () => favProvider.cargarFavoritos(),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: GridView.builder(
                          itemCount: favProvider.favoritos.length,
                          gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            crossAxisSpacing: 16,
                            mainAxisSpacing: 16,
                            childAspectRatio: 0.58,
                          ),
                          itemBuilder: (context, index) {
                            final item = favProvider.favoritos[index];
                            return ProductCard(
                              prenda: item,
                              onTap: () {
                                Navigator.of(context).push(
                                  MaterialPageRoute(
                                    builder: (_) => ProductoDetalleScreen(productoId: item.productoId),
                                  ),
                                );
                              },
                            );
                          },
                        ),
                      ),
                    ),
    );
  }
}
