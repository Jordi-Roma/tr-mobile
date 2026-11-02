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
}
