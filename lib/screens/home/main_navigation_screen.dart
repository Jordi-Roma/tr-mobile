import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../providers/carrito_provider.dart';
import '../admin_catalogo/admin_catalogo_hub_screen.dart';
import '../asistente/asistente_screen.dart';
import '../carrito/carrito_screen.dart';
import '../catalogo/catalogo_screen.dart';
import '../perfil/perfil_screen.dart';
import '../reportes/reportes_admin_screen.dart';
import '../reservas/mis_reservas_screen.dart';
import '../reservas/reservas_admin_screen.dart';

class MainNavigationScreen extends StatefulWidget {
  const MainNavigationScreen({super.key});

  @override
  State<MainNavigationScreen> createState() => _MainNavigationScreenState();
}

class _MainNavigationScreenState extends State<MainNavigationScreen> {
  int _currentIndex = 0;

  void _irAIndex(int index) {
    ScaffoldMessenger.of(context).hideCurrentSnackBar();
    setState(() {
      _currentIndex = index;
    });
    final auth = context.read<AuthProvider>();
    if (index == 1 && !auth.esAdminOEncargado && auth.estaAutenticado) {
      context.read<CarritoProvider>().cargarCarrito();
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final carrito = context.watch<CarritoProvider>();
    final esAdminOEncargado = auth.esAdminOEncargado;

    // Páginas para el modo Empleado / Administrador
    final paginasAdmin = [
      const CatalogoScreen(),
      const AdminCatalogoHubScreen(),
      const ReservasAdminScreen(),
      const ReportesAdminScreen(),
      const PerfilScreen(),
    ];

    // Páginas para el modo Cliente / Tienda
    final paginasCliente = [
      const CatalogoScreen(),
      CarritoScreen(
        onIrAlCatalogo: () => _irAIndex(0),
        onIrAMisReservas: () => _irAIndex(2),
      ),
      MisReservasScreen(
        onIrAlCatalogo: () => _irAIndex(0),
      ),
      const PerfilScreen(),
    ];

    final paginas = esAdminOEncargado ? paginasAdmin : paginasCliente;
    final indexSeguro = _currentIndex < paginas.length ? _currentIndex : 0;

    return Scaffold(
      body: IndexedStack(
        index: indexSeguro,
        children: paginas,
      ),
      // FAB del asistente virtual IA — visible solo para clientes (no para admin/encargado)
      floatingActionButton: !esAdminOEncargado
          ? FloatingActionButton(
              heroTag: 'fab_asistente',
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              tooltip: 'Asistente Virtual',
              elevation: 4,
              onPressed: () {
                showModalBottomSheet<void>(
                  context: context,
                  isScrollControlled: true,
                  useSafeArea: true,
                  backgroundColor: Colors.transparent,
                  builder: (_) => const FractionallySizedBox(
                    heightFactor: 0.92,
                    child: ClipRRect(
                      borderRadius:
                          BorderRadius.vertical(top: Radius.circular(20)),
                      child: AsistenteScreen(),
                    ),
                  ),
                );
              },
              child: const Icon(Icons.auto_awesome, size: 26),
            )
          : null,
      bottomNavigationBar: NavigationBar(
        selectedIndex: indexSeguro,
        onDestinationSelected: (i) {
          ScaffoldMessenger.of(context).hideCurrentSnackBar();
          setState(() => _currentIndex = i);
          if (i == 1 && !esAdminOEncargado && auth.estaAutenticado) {
            context.read<CarritoProvider>().cargarCarrito();
          }
        },
        backgroundColor: Colors.white,
        indicatorColor: AppColors.primary.withValues(alpha: 0.12),
        elevation: 3,
        destinations: esAdminOEncargado
            ? const [
                NavigationDestination(
                  icon: Icon(Icons.checkroom_outlined),
                  selectedIcon: Icon(Icons.checkroom, color: AppColors.primary),
                  label: 'Catálogo',
                ),
                NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined),
                  selectedIcon: Icon(Icons.inventory_2, color: AppColors.primary),
                  label: 'Gestión',
                ),
                NavigationDestination(
                  icon: Icon(Icons.assignment_outlined),
                  selectedIcon: Icon(Icons.assignment, color: AppColors.primary),
                  label: 'Reservas',
                ),
                NavigationDestination(
                  icon: Icon(Icons.analytics_outlined),
                  selectedIcon: Icon(Icons.analytics, color: AppColors.primary),
                  label: 'Reportes',
                ),
                NavigationDestination(
                  icon: Icon(Icons.account_circle_outlined),
                  selectedIcon: Icon(Icons.account_circle, color: AppColors.primary),
                  label: 'Perfil',
                ),
              ]
            : [
                const NavigationDestination(
                  icon: Icon(Icons.checkroom_outlined),
                  selectedIcon: Icon(Icons.checkroom, color: AppColors.primary),
                  label: 'Catálogo',
                ),
                NavigationDestination(
                  icon: Badge(
                    isLabelVisible: carrito.cantidadTotal > 0,
                    label: Text('${carrito.cantidadTotal}'),
                    child: const Icon(Icons.shopping_bag_outlined),
                  ),
                  selectedIcon: Badge(
                    isLabelVisible: carrito.cantidadTotal > 0,
                    label: Text('${carrito.cantidadTotal}'),
                    child: const Icon(Icons.shopping_bag, color: AppColors.primary),
                  ),
                  label: 'Carrito',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.calendar_today_outlined),
                  selectedIcon: Icon(Icons.calendar_today, color: AppColors.primary),
                  label: 'Mis Reservas',
                ),
                const NavigationDestination(
                  icon: Icon(Icons.account_circle_outlined),
                  selectedIcon: Icon(Icons.account_circle, color: AppColors.primary),
                  label: 'Perfil',
                ),
              ],
      ),
    );
  }
}
