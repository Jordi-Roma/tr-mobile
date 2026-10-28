import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:mobile_tr/core/constants/api_constants.dart';
import 'package:mobile_tr/core/network/api_client.dart';
import 'package:mobile_tr/core/reintento_comercial.dart';
import 'package:mobile_tr/core/session/contexto_sesion.dart';
import 'package:mobile_tr/models/reserva_models.dart';
import 'package:mobile_tr/models/auth_models.dart';
import 'package:mobile_tr/providers/auth_provider.dart';
import 'package:mobile_tr/providers/carrito_provider.dart';
import 'package:mobile_tr/providers/favoritos_provider.dart';
import 'package:mobile_tr/providers/catalogo_provider.dart';
import 'package:mobile_tr/providers/reserva_provider.dart';
import 'package:mobile_tr/screens/catalogo/filtros_catalogo_sheet.dart';
import 'package:mobile_tr/screens/home/main_navigation_screen.dart';
import 'package:mobile_tr/screens/reservas/reservas_admin_screen.dart';

import 'cuenta_test.dart'
    show empresaA, jwt, usuario, jsonRespuesta, perfilJson;

Map<String, dynamic> reserva() => {
  'id': 1,
  'codigo': 'RES-1',
  'cliente_id': 1,
  'sucursal_id': 2,
  'sucursal': 'Centro',
  'ciudad': 'Santa Cruz',
  'estado': 'PENDIENTE',
  'es_gratuita': true,
  'total': '50.00',
  'monto_reserva': '0.00',
  'monto_aplicado': '0.00',
  'anticipo_pagado': false,
  'fecha_reserva': '2026-10-27T12:00:00-04:00',
  'fecha_expiracion': '2026-11-03T12:00:00-04:00',
  'detalles': [],
};

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ApiConstants.customHost = 'http://127.0.0.1:58127';
    await ContextoSesion.instance.seleccionar(empresaA);
  });
  tearDown(() async {
    ApiClient.client.close();
    await ContextoSesion.instance.seleccionar(null);
  });

  test('reserva gratuita conserva vencimiento y no inventa anticipo', () {
    final r = ReservaResponse.fromJson(reserva());
    expect(r.esGratuita, true);
    expect(r.montoReserva, 0);
    expect(r.anticipoPagado, false);
    expect(
      DateTime.parse(r.fechaExpiracion!)
          .difference(DateTime.parse(r.fechaReserva)),
      const Duration(days: 7),
    );
    expect(
      ReservaResponse.fromJson({
        ...reserva(),
        'es_gratuita': false,
        'monto_reserva': '20.00',
      }).montoReserva,
      20,
    );
  });

  test('reintento incierto reutiliza clave y nueva operación obtiene otra', () {
    final r = ReintentoComercial();
    final primera = r.clavePara({'cantidad': 1});
    expect(
      primera,
      matches(
        RegExp(
          r'^[a-f0-9]{8}-[a-f0-9]{4}-4[a-f0-9]{3}-[89ab][a-f0-9]{3}-[a-f0-9]{12}$',
        ),
      ),
    );
    expect(r.clavePara({'cantidad': 1}), primera);
    expect(r.clavePara({'cantidad': 2}), isNot(primera));
    r.completar();
    expect(r.clavePara({'cantidad': 1}), isNot(primera));
  });

  test(
    'reserva reintenta con misma clave y empresa después de perder respuesta',
    () async {
      await ContextoSesion.instance.guardar(jwt(), usuario());
      final cuerpos = <Map<String, dynamic>>[];
      ApiClient.client = MockClient((request) async {
        expect(request.headers['X-Empresa-Codigo'], 'tienda-a');
        cuerpos.add(jsonDecode(request.body) as Map<String, dynamic>);
        if (cuerpos.length == 1) throw TimeoutException('Respuesta perdida');
        return jsonRespuesta(reserva());
      });
      final p = ReservaProvider();
      expect(
        await p.crearReservaDesdeCarrito(
          sucursalId: 2,
          fechaCita: '2026-10-28',
        ),
        null,
      );
      expect(
        (await p.crearReservaDesdeCarrito(
          sucursalId: 2,
          fechaCita: '2026-10-28',
        ))?.esGratuita,
        true,
      );
      expect(cuerpos[0]['clave_operacion'], cuerpos[1]['clave_operacion']);
      expect(cuerpos[0].containsKey('empresa_id'), false);
      p.dispose();
    },
  );

  test(
    'catálogo envía filtros y permite consultar páginas posteriores',
    () async {
      final peticiones = <Uri>[];
      ApiClient.client = MockClient((request) async {
        peticiones.add(request.url);
        return jsonRespuesta({'items': [], 'total': 60, 'pagina': 1});
      });
      final p = CatalogoProvider();
      await p.cargarPrendas();
      expect(p.paginas, 3);
      p.aplicarFiltrosAvanzados(
        talla: 3,
        color: 4,
        temporada: 5,
        coleccion: 6,
        minimo: 10,
        maximo: 50,
        ordenElegido: 'precio-asc',
      );
      await pumpEventQueue();
      expect(peticiones.last.queryParameters, containsPair('talla_id', '3'));
      expect(
        peticiones.last.queryParameters,
        containsPair('precio_max', '50.0'),
      );
      expect(
        peticiones.last.queryParameters,
        containsPair('orden', 'precio-asc'),
      );
      p.irPagina(2);
      await pumpEventQueue();
      expect(peticiones.last.queryParameters['pagina'], '2');
      expect(p.pagina, 2);
      p.limpiarFiltros();
      await pumpEventQueue();
      expect(peticiones.last.queryParameters.containsKey('talla_id'), false);
      expect(p.pagina, 1);
      p.dispose();
    },
  );

  test('catálogo descarta una búsqueda anterior que responde tarde', () async {
    final anterior = Completer<http.Response>();
    var llamadas = 0;
    ApiClient.client = MockClient((request) {
      if (++llamadas == 1) return anterior.future;
      return Future.value(jsonRespuesta({'items': [], 'total': 2}));
    });
    final p = CatalogoProvider();
    final primera = p.cargarPrendas();
    await pumpEventQueue();
    await p.cargarPrendas();
    anterior.complete(jsonRespuesta({'items': [], 'total': 99}));
    await primera;
    expect(p.total, 2);
    p.dispose();
  });

  testWidgets(
    'cajero accede a reservas sin carrito ni pantallas CU14/CU15 móviles',
    (tester) async {
      await tester.runAsync(() async {
        final perfil = {
          ...perfilJson(),
          'roles': ['CAJERO'],
        };
        await ContextoSesion.instance.guardar(
          jwt(),
          UsuarioAutenticado.fromJson(perfil),
        );
        ApiClient.client = MockClient((request) async {
          if (request.url.path.endsWith('/perfil')) {
            return jsonRespuesta(perfil);
          }
          if (request.url.path.endsWith('/catalogo/prendas')) {
            return jsonRespuesta({'items': [], 'total': 0});
          }
          if (request.url.path.endsWith('/catalogo/filtros')) {
            return jsonRespuesta({
              'categorias': [],
              'tallas': [],
              'colores': [],
              'temporadas': [],
              'colecciones': [],
              'sucursales': [],
            });
          }
          return jsonRespuesta([]);
        });
        final auth = AuthProvider();
        await tester.pumpWidget(
          MultiProvider(
            providers: [
              ChangeNotifierProvider.value(value: auth),
              ChangeNotifierProvider(create: (_) => CarritoProvider()),
              ChangeNotifierProvider(create: (_) => CatalogoProvider()),
              ChangeNotifierProvider(create: (_) => ReservaProvider()),
              ChangeNotifierProvider(create: (_) => FavoritosProvider()),
            ],
            child: const MaterialApp(home: MainNavigationScreen()),
          ),
        );
        await tester.pumpAndSettle();
        expect(find.text('Carrito'), findsNothing);
        expect(find.text('Inventario'), findsNothing);
        expect(find.text('Reportes'), findsNothing);
        await tester.tap(find.text('Reservas'));
        await tester.pumpAndSettle();
        expect(find.byType(ReservasAdminScreen), findsOneWidget);
        await tester.pumpWidget(const SizedBox());
        auth.dispose();
      });
    },
  );

  testWidgets('filtros muestran error cuando máximo es menor al mínimo', (
    tester,
  ) async {
    final p = CatalogoProvider();
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(body: FiltrosCatalogoSheet(catalogo: p)),
      ),
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Precio mínimo (Bs)'),
      '50',
    );
    await tester.enterText(
      find.widgetWithText(TextFormField, 'Precio máximo (Bs)'),
      '10',
    );
    await tester.ensureVisible(find.text('Aplicar filtros'));
    await tester.tap(find.text('Aplicar filtros'));
    await tester.pump();
    expect(find.text('Debe ser mayor o igual al mínimo'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
    p.dispose();
  });
}
