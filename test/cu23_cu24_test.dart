import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_tr/core/constants/api_constants.dart';
import 'package:mobile_tr/core/network/api_client.dart';
import 'package:mobile_tr/core/session/contexto_sesion.dart';
import 'package:mobile_tr/models/empresa_models.dart';
import 'package:mobile_tr/models/asistente_models.dart';
import 'package:mobile_tr/providers/auth_provider.dart';
import 'package:mobile_tr/screens/asistente/asistente_screen.dart';
import 'package:mobile_tr/screens/asistente/datos_chat.dart';
import 'package:mobile_tr/screens/catalogo/preferencias_recomendaciones_sheet.dart';

Map<String, dynamic> respuesta() => {
  'respuesta': 'Disponibilidad actual',
  'tipo': 'catalogo',
  'productos': [],
  'contexto': {
    'producto_id': 7,
    'talla_patrones': ['m'],
    'empresa_id': 1,
  },
  'fuentes': ['Catálogo'],
  'datos': [],
};
http.Response json(Object datos, [int estado = 200]) => http.Response(
  jsonEncode(datos),
  estado,
  headers: {'content-type': 'application/json'},
);
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ApiConstants.customHost = 'http://127.0.0.1:58127';
    await ContextoSesion.instance.seleccionar(
      const EmpresaPublica(
        id: 1,
        codigo: 'prueba',
        nombre: 'Prueba',
        estado: 'ACTIVA',
      ),
    );
  });
  tearDown(() async {
    await ContextoSesion.instance.seleccionar(null);
    ApiClient.client.close();
  });
  test('contexto completo y precio final exacto, nulo y cero', () {
    final c = AsistenteContexto.fromJson({
      'producto_id': 7,
      'variante_id': 8,
      'sucursal_id': 2,
      'empresa_id': 1,
      'terminos': ['polera'],
      'color_patrones': ['azul'],
      'talla_patrones': ['m'],
      'precio_max': 50,
    });
    expect(c.toJson()['color_patrones'], ['azul']);
    expect(c.toJson()['variante_id'], 8);
    expect(
      AsistenteProductoResponse.fromJson({
        'producto_id': 7,
        'precio_final': 0,
        'precio_vigente': 50,
      }).precioMostrado,
      'BOB 0.0',
    );
    expect(
      AsistenteProductoResponse.fromJson({
        'producto_id': 7,
        'precio_final_exacto': '40.00',
        'precio_vigente': 50,
      }).precioMostrado,
      'BOB 40.00',
    );
    expect(
      AsistenteProductoResponse.fromJson({'producto_id': 7}).precioMostrado,
      'Precio no disponible',
    );
    expect(destinoChat('https://evil.test'), null);
    expect(destinoChat('/saas/planes'), null);
    expect(
      operacionChat({'recurso_tipo': 'VENTA', 'id': 5})?.recursoTipo,
      'VENTA',
    );
    expect(operacionChat({'recurso_tipo': 'OTRO', 'id': 5}), null);
  });
  testWidgets(
    'chat reutiliza contexto y borra conversación al cambiar empresa',
    (t) async {
      final cuerpos = <Map<String, dynamic>>[];
      ApiClient.client = MockClient((r) async {
        cuerpos.add(jsonDecode(r.body) as Map<String, dynamic>);
        return json(respuesta());
      });
      final auth = AuthProvider();
      await t.pumpWidget(
        ChangeNotifierProvider.value(
          value: auth,
          child: const MaterialApp(
            home: AsistenteScreen(
              contextoInicial: AsistenteContexto(productoId: 7),
            ),
          ),
        ),
      );
      await t.enterText(find.byType(TextField), 'Prenda en M');
      await t.testTextInput.receiveAction(TextInputAction.send);
      await t.pumpAndSettle();
      await t.enterText(find.byType(TextField), '¿y en negro?');
      await t.testTextInput.receiveAction(TextInputAction.send);
      await t.pumpAndSettle();
      expect((cuerpos.last['contexto'] as Map)['talla_patrones'], ['m']);
      await t.runAsync(
        () => ContextoSesion.instance.seleccionar(
          const EmpresaPublica(
            id: 2,
            codigo: 'otra',
            nombre: 'Otra',
            estado: 'ACTIVA',
          ),
        ),
      );
      await t.pumpAndSettle();
      expect(find.text('Disponibilidad actual'), findsNothing);
      expect(find.text('Sin selección'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      auth.dispose();
    },
  );
  testWidgets(
    'preferencias conserva formulario ante fallo y permite desactivar personalización',
    (t) async {
      Map<String, dynamic>? guardado;
      ApiClient.client = MockClient((r) async {
        if (r.method == 'GET') {
          return json({'categorias': [], 'usar_historial': true});
        }
        guardado = jsonDecode(r.body) as Map<String, dynamic>;
        return json({'detail': 'Sin conexión con el servidor'}, 503);
      });
      await t.pumpWidget(
        const MaterialApp(
          home: Scaffold(
            body: PreferenciasRecomendacionesSheet(categorias: []),
          ),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.byType(SwitchListTile));
      await t.pump();
      await t.tap(find.text('Guardar preferencias'));
      await t.pumpAndSettle();
      expect(guardado?['usar_historial'], false);
      expect(find.text('Sin conexión con el servidor'), findsOneWidget);
      expect(
        t.widget<SwitchListTile>(find.byType(SwitchListTile)).value,
        false,
      );
    },
  );
  testWidgets('respuesta de chat en vuelo no aparece en otra sesión', (
    t,
  ) async {
    final pendiente = Completer<http.Response>();
    ApiClient.client = MockClient((_) => pendiente.future);
    final auth = AuthProvider();
    await t.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: const MaterialApp(home: AsistenteScreen()),
      ),
    );
    await t.enterText(find.byType(TextField), 'Mis reservas');
    await t.testTextInput.receiveAction(TextInputAction.send);
    await t.pump();
    await t.runAsync(() => ContextoSesion.instance.seleccionar(null));
    pendiente.complete(json(respuesta()));
    await t.pumpAndSettle();
    expect(find.text('Disponibilidad actual'), findsNothing);
    await t.pumpWidget(const SizedBox());
    auth.dispose();
  });
}
