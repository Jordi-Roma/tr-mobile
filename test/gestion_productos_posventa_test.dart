import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_tr/core/constants/api_constants.dart';
import 'package:mobile_tr/core/network/api_client.dart';
import 'package:mobile_tr/providers/auth_provider.dart';
import 'package:mobile_tr/screens/pagos/posventa_screen.dart';
import 'package:mobile_tr/screens/pagos/configuracion_comercial_screen.dart';
import 'package:mobile_tr/screens/admin_catalogo/catalogo_referencias_screen.dart';

import 'cuenta_test.dart' show sesion, empresaA, usuario, jwt, jsonRespuesta;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ApiConstants.customHost = 'http://127.0.0.1:58127';
    await sesion.seleccionar(empresaA);
    await sesion.guardar(jwt(), usuario());
  });
  tearDown(() async {
    ApiClient.client.close();
    await sesion.seleccionar(null);
  });
  testWidgets(
    'posventa muestra accesos de cliente sin consultar solicitudes ni permitir políticas',
    (t) async {
      var peticiones = 0;
      ApiClient.client = MockClient((r) async {
        peticiones++;
        return jsonRespuesta({});
      });
      final auth = AuthProvider();
      await t.pumpWidget(
        ChangeNotifierProvider.value(
          value: auth,
          child: const MaterialApp(home: PosventaScreen()),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Devoluciones'), findsOneWidget);
      expect(find.text('Cambios'), findsOneWidget);
      expect(find.text('Políticas posventa'), findsNothing);
      expect(peticiones, 0);
      await t.pumpWidget(const SizedBox());
      auth.dispose();
    },
  );
  testWidgets(
    'conflicto de política conserva condiciones y envía revisión, plazos y aceptación habilitada',
    (t) async {
      Map<String, dynamic>? enviado;
      ApiClient.client = MockClient((r) async {
        if (r.method == 'PUT') {
          enviado = jsonDecode(r.body) as Map<String, dynamic>;
          return jsonRespuesta({
            'detail': 'La configuración cambió. Recarga.',
          }, 409);
        }
        return jsonRespuesta({
          'version': 4,
          'cambios_habilitados': true,
          'devoluciones_habilitadas': true,
          'plazo_cambios': 15,
          'plazo_devoluciones': 10,
          'condiciones_cambios': 'Prenda con etiquetas',
          'condiciones_devoluciones': 'Revisión en sucursal',
        });
      });
      await t.pumpWidget(
        const MaterialApp(home: ConfiguracionComercialScreen(politicas: true)),
      );
      await t.pumpAndSettle();
      final condiciones = find.widgetWithText(
        TextField,
        'Condiciones de cambios',
      );
      await t.enterText(condiciones, 'Conservar etiqueta y recibo original');
      await t.ensureVisible(find.text('Guardar configuración'));
      await t.tap(find.text('Guardar configuración'));
      await t.pumpAndSettle();
      expect(enviado?['version'], 4);
      expect(enviado?['plazo_cambios'], 15);
      expect(enviado?['devoluciones_habilitadas'], true);
      expect(
        t.widget<TextField>(condiciones).controller!.text,
        'Conservar etiqueta y recibo original',
      );
      expect(find.textContaining('La configuración cambió'), findsOneWidget);
    },
  );
  testWidgets(
    'editar promoción conserva productos, sucursales, fechas e importe',
    (t) async {
      Map<String, dynamic>? enviado;
      final promo = {
        'id': 7,
        'nombre': 'Promoción vigente',
        'activo': true,
        'descripcion': 'Condiciones',
        'tipo_descuento': 'PORCENTAJE',
        'valor': '15.00',
        'fecha_inicio': '2026-11-01',
        'fecha_fin': '2026-12-01',
        'productos': [
          {'id': 1, 'nombre': 'Camisa'},
        ],
        'sucursales': [
          {'id': 2, 'nombre': 'Centro'},
        ],
      };
      ApiClient.client = MockClient((r) async {
        if (r.method == 'PUT') {
          enviado = jsonDecode(r.body) as Map<String, dynamic>;
          return jsonRespuesta({...promo, ...enviado!});
        }
        if (r.url.path.endsWith('/productos')) {
          return jsonRespuesta([
            {'id': 1, 'nombre': 'Camisa', 'activo': true},
          ]);
        }
        if (r.url.path.endsWith('/sucursales')) {
          return jsonRespuesta([
            {'id': 2, 'nombre': 'Centro', 'activo': true},
          ]);
        }
        return jsonRespuesta([promo]);
      });
      await t.pumpWidget(
        const MaterialApp(
          home: CatalogoReferenciasScreen(
            recurso: 'promociones',
            titulo: 'Promociones',
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byTooltip('Editar Promoción vigente'));
      await t.pumpAndSettle();
      await t.enterText(
        find.widgetWithText(TextFormField, 'Nombre'),
        'Promoción revisada',
      );
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('Guardar'),
        250,
        scrollable: find
            .byWidgetPredicate(
              (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
            )
            .last,
      );
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Guardar'));
      await t.pumpAndSettle();
      await t.tap(find.text('Guardar'));
      await t.pumpAndSettle();
      expect(enviado?['producto_ids'], [1]);
      expect(enviado?['sucursal_ids'], [2]);
      expect(enviado?['valor'], '15.00');
      expect(enviado?['fecha_fin'], '2026-12-01');
      expect(enviado?['nombre'], 'Promoción revisada');
      expect(t.takeException(), isNull);
    },
  );
}
