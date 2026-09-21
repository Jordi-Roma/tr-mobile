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

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await initializeDateFormatting('es', null);
  runApp(const StyleARApp());
}

class StyleARApp extends StatelessWidget {
  const StyleARApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider(
          create: (_) => AuthProvider()..inicializar(),
        ),
        ChangeNotifierProvider(
          create: (_) => CatalogoProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => CarritoProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => ReservaProvider(),
        ),
        ChangeNotifierProvider(
          create: (_) => FavoritosProvider(),
        ),
      ],
      child: Builder(
        builder: (context) {
          // Si el usuario ya está autenticado al arrancar la app, cargar su carrito y favoritos
          WidgetsBinding.instance.addPostFrameCallback((_) {
            final auth = context.read<AuthProvider>();
            if (auth.estaAutenticado && !auth.esAdminOEncargado) {
              context.read<CarritoProvider>().cargarCarrito();
              context.read<FavoritosProvider>().cargarFavoritos();
            }
          });

          return MaterialApp(
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
            home: const MainNavigationScreen(),
          );
        },
      ),
    );
  }
}
