import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_tr/core/constants/api_constants.dart';
import 'package:mobile_tr/core/network/api_client.dart';
import 'package:mobile_tr/core/session/clave_pago.dart';
import 'package:mobile_tr/screens/carrito/pago_stripe_screen.dart';
import 'package:mobile_tr/screens/notificaciones/notificaciones_screen.dart';
import 'package:mobile_tr/services/pago_service.dart';

import 'cuenta_test.dart'
    show sesion, empresaA, empresaB, usuario, jwt, jsonRespuesta;

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
    'reintento de checkout reutiliza UUID y cambio de empresa lo separa',
    () async {
      final claves = <String>[];
      ApiClient.client = MockClient((r) async {
        claves.add((jsonDecode(r.body) as Map)['clave_operacion'] as String);
        throw Exception('Respuesta perdida');
      });
      for (var n = 0; n < 2; n++) {
        await expectLater(
          PagoService.crearCheckoutQr(sucursalId: 1, totalEsperado: 50),
          throwsA(isA<Exception>()),
        );
      }
      expect(claves[0], claves[1]);
      await sesion.seleccionar(empresaB);
      await sesion.guardar(jwt(empresa: 2), usuario(2));
      await expectLater(
        PagoService.crearCheckoutQr(sucursalId: 1, totalEsperado: 50),
        throwsA(isA<Exception>()),
      );
      expect(claves[2], isNot(claves[0]));
    },
  );
  test('orden terminal renueva clave y pendiente conserva la misma', () async {
    final body = {'sucursal_id': 1};
    final a = await ClavePago.preparar(body, 'qr');
    await ClavePago.finalizar('qr', 'PENDIENTE');
    expect(
      (await ClavePago.preparar(body, 'qr'))['clave_operacion'],
      a['clave_operacion'],
    );
    await ClavePago.finalizar('qr', 'PAGADO');
    expect(
      (await ClavePago.preparar(body, 'qr'))['clave_operacion'],
      isNot(a['clave_operacion']),
    );
  });
  testWidgets('consultar retorno Stripe no aprueba automáticamente', (
    tester,
  ) async {
    final metodos = <String>[];
    ApiClient.client = MockClient((r) async {
      metodos.add(r.method);
      return jsonRespuesta({
        'orden_id': 1,
        'venta_id': 2,
        'estado': 'PENDIENTE',
        'proveedor': 'STRIPE',
        'modo_pago': 'PRUEBA',
        'confirmacion_prueba': true,
        'monto_total': 50,
      });
    });
    await tester.pumpWidget(
      const MaterialApp(home: PagoStripeScreen(checkoutUrl: '', ordenId: 1)),
    );
    await tester.pumpAndSettle();
    expect(find.text('Simular pago aprobado'), findsOneWidget);
    expect(metodos, ['GET']);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('bandeja permite reintentar, leer y explica Firebase pendiente', (
    tester,
  ) async {
    var fallo = true;
    var leida = false;
    ApiClient.client = MockClient((r) async {
      if (r.url.path.endsWith('/leer')) {
        leida = true;
        return jsonRespuesta({});
      }
      if (r.url.path.endsWith('/reembolsos')) {
        return jsonRespuesta([
          {
            'orden_id': 1,
            'estado': 'PENDIENTE',
            'monto': 50,
            'moneda': 'BOB',
            'motivo': 'Sin stock',
          },
        ]);
      }
      if (fallo) return jsonRespuesta({'detail': 'Temporal'}, 503);
      expect(r.url.path, endsWith('/notificaciones/bandeja'));
      return jsonRespuesta({
        'avisos': [
          {
            'id': 1,
            'titulo': 'Pago recibido',
            'mensaje': 'Consulta tu orden',
            'leida': leida,
            'orden_id': 1,
            'categoria': 'PAGO',
            'creado_en': '2026-11-07T12:00:00Z',
          },
        ],
        'total': 1,
        'no_leidas': leida ? 0 : 1,
        'pagina': 1,
        'tamano': 20,
      });
    });
    await tester.pumpWidget(const MaterialApp(home: NotificacionesScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Reintentar'), findsOneWidget);
    fallo = false;
    await tester.tap(find.text('Reintentar'));
    await tester.pumpAndSettle();
    expect(find.text('Pago recibido'), findsOneWidget);
    await tester.tap(find.text('Marcar como leída'));
    await tester.pumpAndSettle();
    expect(leida, true);
    await tester.tap(find.text('Activar avisos push'));
    await tester.pumpAndSettle();
    expect(find.textContaining('La bandeja está disponible'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
