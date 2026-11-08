import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_tr/core/constants/api_constants.dart';
import 'package:mobile_tr/core/network/api_client.dart';
import 'package:mobile_tr/services/cambio_service.dart';
import 'package:mobile_tr/providers/auth_provider.dart';
import 'package:mobile_tr/screens/pagos/cambios_screen.dart';
import 'package:mobile_tr/screens/pagos/solicitud_cambio_dialog.dart';

import 'cuenta_test.dart' show sesion, empresaA, usuario, jwt, jsonRespuesta;

Map<String, dynamic> cambio() => {
  'id': 9,
  'version': 4,
  'cantidad': 1,
  'estado': 'ESPERA_PAGO',
  'diferencia': '20.00',
  'credito': '50.00',
  'original': {
    'id': 9,
    'venta_codigo': 'WEB-CU19',
    'estado': 'REEMBOLSO_PENDIENTE',
    'motivo': 'Otra talla',
    'detalles': [],
  },
};
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
    'solicitud inicial permite elegir talla y color y muestra la diferencia estimada',
    (t) async {
      ApiClient.client = MockClient((r) async {
        expect(r.url.path, endsWith('/opciones-solicitud'));
        expect(r.url.queryParameters['cantidad'], '1');
        return jsonRespuesta({
          'credito_estimado': '50.00',
          'opciones': [
            {
              'id': 11,
              'producto_id': 4,
              'producto': 'Camisa',
              'talla': 'S',
              'color': 'Negro',
              'precio': '50.00',
              'disponible': 2,
            },
            {
              'id': 12,
              'producto_id': 4,
              'producto': 'Camisa',
              'talla': 'M',
              'color': 'Azul',
              'precio': '60.00',
              'disponible': 2,
            },
            {
              'id': 13,
              'producto_id': 4,
              'producto': 'Camisa',
              'talla': 'M',
              'color': 'Negro',
              'precio': '70.00',
              'disponible': 2,
            },
          ],
        });
      });
      SolicitudCambioElegida? resultado;
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: Builder(
              builder: (context) => TextButton(
                onPressed: () async {
                  resultado = await showDialog<SolicitudCambioElegida>(
                    context: context,
                    builder: (_) => const SolicitudCambioDialog(
                      venta: 1,
                      linea: 2,
                      maximo: 1,
                    ),
                  );
                },
                child: const Text('Abrir solicitud'),
              ),
            ),
          ),
        ),
      );
      await t.tap(find.text('Abrir solicitud'));
      await t.pumpAndSettle();
      final selectores = find.byType(DropdownButtonFormField<String>);
      await t.tap(selectores.at(0));
      await t.pumpAndSettle();
      await t.tap(find.text('Camisa').last);
      await t.pumpAndSettle();
      await t.tap(selectores.at(1));
      await t.pumpAndSettle();
      await t.tap(find.text('M').last);
      await t.pumpAndSettle();
      await t.tap(selectores.at(2));
      await t.pumpAndSettle();
      await t.tap(find.text('Negro').last);
      await t.pumpAndSettle();
      expect(find.text('Pago estimado: Bs 20.00'), findsOneWidget);
      await t.enterText(
        find.widgetWithText(TextField, 'Motivo del cambio'),
        'Necesito talla M',
      );
      await t.tap(find.text('Enviar solicitud'));
      await t.pumpAndSettle();
      expect(resultado?.variante, 13);
      expect(resultado?.cantidad, 1);
      expect(t.takeException(), isNull);
    },
  );
  test(
    'reintento incierto de cambio conserva la clave y el detalle original',
    () async {
      final claves = <String>[];
      ApiClient.client = MockClient((r) async {
        final b = jsonDecode(r.body) as Map<String, dynamic>;
        claves.add(b['clave_operacion'] as String);
        expect(b['venta_detalle_id'], 8);
        return claves.length == 1
            ? jsonRespuesta({'detail': 'Respuesta temporal no disponible'}, 503)
            : jsonRespuesta(cambio());
      });
      await expectLater(
        CambioService.solicitar(2, 8, 1, 'Otra talla'),
        throwsException,
      );
      await CambioService.solicitar(2, 8, 1, 'Otra talla');
      expect(claves[0], claves[1]);
    },
  );
  test('aceptar conserva versión y excedente negativo exacto', () async {
    ApiClient.client = MockClient((r) async {
      expect(r.url.path, '/api/v1/posventa/cambios/9/aceptar');
      expect(jsonDecode(r.body), {'version': 4, 'diferencia': '-20.50'});
      return jsonRespuesta({
        ...cambio(),
        'estado': 'ESPERA_REINTEGRO',
        'diferencia': '-20.50',
      });
    });
    final c = await CambioService.accion(9, 'aceptar', {
      'version': 4,
      'diferencia': '-20.50',
    });
    expect(c.estado, 'ESPERA_REINTEGRO');
    expect(c.diferencia, -20.5);
    expect(c.comprobante, isNull);
  });
  test(
    'un pago conectado no puede marcarse pagado desde el simulador',
    () async {
      var llamadas = 0;
      ApiClient.client = MockClient((r) async {
        llamadas++;
        return jsonRespuesta({});
      });
      await expectLater(
        CambioService.simular({
          'id': 2,
          'proveedor': 'STRIPE',
          'simulable': false,
        }),
        throwsStateError,
      );
      expect(llamadas, 0);
    },
  );
  testWidgets(
    'pago pendiente no ofrece entrega y cambiar sesión retira la compra',
    (tester) async {
      final auth = AuthProvider();
      ApiClient.client = MockClient((r) async {
        if (r.url.path.endsWith('/politica')) {
          return jsonRespuesta({
            'cambios_habilitados': true,
            'plazo_cambios': 15,
            'condiciones_cambios': 'Inspección requerida',
          });
        }
        return jsonRespuesta(
          r.url.path.endsWith('/elegibles') ? <Object>[] : [cambio()],
        );
      });
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: auth,
          child: const MaterialApp(home: CambiosScreen()),
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cambio 9 · ESPERA_PAGO'));
      await tester.pumpAndSettle();
      expect(find.text('Pagar diferencia con QR'), findsOneWidget);
      expect(find.text('Completar cambio y emitir comprobante'), findsNothing);
      await tester.runAsync(() => sesion.seleccionar(null));
      await tester.pumpAndSettle();
      expect(find.textContaining('WEB-CU19'), findsNothing);
      await tester.pumpWidget(const SizedBox());
      auth.dispose();
    },
  );
  testWidgets(
    'cotizacion de reemplazo solicitado permite confirmar y pasar al pago sin elegir otra vez',
    (t) async {
      final auth = AuthProvider();
      var aceptada = false;
      final cotizado = {
        ...cambio(),
        'estado': 'COTIZADO',
        'reemplazo_id': 11,
        'reemplazo': {'producto': 'Camisa', 'talla': 'M', 'color': 'Azul'},
        'precio_reemplazo': '70.00',
      };
      ApiClient.client = MockClient((r) async {
        if (r.url.path.endsWith('/politica')) {
          return jsonRespuesta({
            'cambios_habilitados': true,
            'plazo_cambios': 15,
          });
        }
        if (r.url.path.endsWith('/elegibles')) return jsonRespuesta(<Object>[]);
        if (r.url.path.endsWith('/aceptar')) {
          expect(jsonDecode(r.body), {'version': 4, 'diferencia': '20.00'});
          aceptada = true;
          return jsonRespuesta({...cotizado, 'estado': 'ESPERA_PAGO'});
        }
        expect(r.url.path.contains('/opciones'), isFalse);
        return jsonRespuesta([
          {...cotizado, if (aceptada) 'estado': 'ESPERA_PAGO'},
        ]);
      });
      await t.pumpWidget(
        ChangeNotifierProvider.value(
          value: auth,
          child: const MaterialApp(home: CambiosScreen()),
        ),
      );
      await t.pumpAndSettle();
      await t.tap(find.text('Cambio 9 · COTIZADO'));
      await t.pumpAndSettle();
      expect(find.text('Consultar reemplazos disponibles'), findsNothing);
      final confirmar = find.text('Confirmar diferencia y continuar al pago');
      await t.ensureVisible(confirmar);
      await t.pumpAndSettle();
      await t.tap(confirmar);
      await t.pumpAndSettle();
      await t.tap(find.text('Aceptar'));
      await t.pumpAndSettle();
      expect(aceptada, isTrue);
      expect(find.text('Pagar diferencia con QR'), findsOneWidget);
      await t.pumpWidget(const SizedBox());
      auth.dispose();
    },
  );
}
