import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:intl/date_symbol_data_local.dart';
import 'package:provider/provider.dart';

import 'core/theme/app_theme.dart';
import 'providers/auth_provider.dart';
import 'providers/carrito_provider.dart';
import 'providers/catalogo_provider.dart';
import 'providers/favoritos_provider.dart';
import 'providers/reserva_provider.dart';
import 'screens/home/main_navigation_screen.dart';
import 'screens/auth/empresa_screen.dart';
import 'screens/auth/login_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  runApp(const StyleARApp());
}

class StyleARApp extends StatelessWidget {
  const StyleARApp({super.key});

  @override
  Widget build(BuildContext context) {
    return ChangeNotifierProvider(
      create: (_) => AuthProvider()..inicializar(),
      child: Consumer<AuthProvider>(
        builder: (context, auth, _) {
          return MultiProvider(
            key: ValueKey(auth.generacion),
            providers: [
              ChangeNotifierProvider(create: (_) => CatalogoProvider()),
              ChangeNotifierProvider(create: (_) => CarritoProvider()),
              ChangeNotifierProvider(create: (_) => ReservaProvider()),
              ChangeNotifierProvider(create: (_) => FavoritosProvider()),
            ],
            child: MaterialApp(
              key: ValueKey(auth.generacion),
              title: 'StyleAR',
              debugShowCheckedModeBanner: false,
              theme: AppTheme.lightTheme,
              localizationsDelegates: const [
                GlobalMaterialLocalizations.delegate,
                GlobalWidgetsLocalizations.delegate,
                GlobalCupertinoLocalizations.delegate,
              ],
              supportedLocales: const [
                Locale('es', 'BO'),
                Locale('es', ''),
                Locale('en', ''),
              ],
              locale: const Locale('es'),
              home: !auth.inicializado
                  ? const Scaffold(
                      body: Center(child: CircularProgressIndicator()),
                    )
                  : auth.empresa == null
                  ? const EmpresaScreen()
                  : auth.requiereLogin
                  ? const LoginScreen()
                  : const _TiendaSesion(),
            ),
          );
        },
      ),
    );
  }
}

class _TiendaSesion extends StatefulWidget {
  const _TiendaSesion();
  @override
  State<_TiendaSesion> createState() => _TiendaSesionState();
}

class _TiendaSesionState extends State<_TiendaSesion> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      if (context.read<AuthProvider>().esCliente) {
        context.read<CarritoProvider>().cargarCarrito();
        context.read<FavoritosProvider>().cargarFavoritos();
      }
    });
  }

  Future<void> _cambiar() async {
    final auth = context.read<AuthProvider>();
    if (auth.estaAutenticado) {
      final confirma = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          title: const Text('Cambiar de empresa'),
          content: const Text(
            'Se cerrará esta sesión y se limpiarán sus datos de este dispositivo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: const Text('Conservar mi sesión'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(ctx, true),
              child: const Text('Cerrar sesión y cambiar'),
            ),
          ],
        ),
      );
      if (confirma != true) return;
    }
    await auth.cambiarEmpresa();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Column(
      children: [
        Material(
          color: Theme.of(context).colorScheme.surface,
          child: SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      auth.empresa?.nombre ?? '',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                  TextButton(
                    onPressed: auth.cargando ? null : _cambiar,
                    child: const Text('Cambiar empresa'),
                  ),
                ],
              ),
            ),
          ),
        ),
        const Expanded(child: MainNavigationScreen()),
      ],
    );
  }
}
