import 'package:provider/provider.dart';
import 'package:mobile_tr/providers/auth_provider.dart';
import 'package:mobile_tr/screens/delivery/historial_delivery_screen.dart';

import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_tr/core/constants/api_constants.dart';
import 'package:mobile_tr/core/network/api_client.dart';
import 'package:mobile_tr/models/delivery_models.dart';
import 'package:mobile_tr/services/delivery_service.dart';
import 'package:mobile_tr/screens/delivery/detalle_delivery_screen.dart';

import 'cuenta_test.dart' show sesion, empresaA, usuario, jwt, jsonRespuesta;

Map<String, dynamic> detalle({String estado = 'EN_CAMINO', int version = 3}) =>
    {
      'id': 7,
      'venta_id': 8,
      'sucursal_id': 2,
      'direccion_entrega': 'Avenida prueba 123',
      'distancia_km': '4.50',
      'tiempo_estimado_min': 12,
      'costo_delivery': '12.00',
      'total_venta': '62.00',
      'estado': estado,
      'fecha_creacion': '2026-10-31T12:00:00Z',
      'latitud_entrega': -17.77,
      'longitud_entrega': -63.17,
      'version': version,
      'pago_confirmado': true,
      'puede_gestionar': true,
      'incidencia_abierta': false,
      'transiciones': estado == 'ENTREGADO' ? <String>[] : ['ENTREGADO'],
      'ruta': <List<double>>[],
      'historial': [
        {
          'tipo': 'ESTADO',
          'estado_nuevo': estado,
          'fecha': '2026-10-31T12:00:00Z',
          'observacion': 'Registro de prueba',
          'version': version,
        },
      ],
    };
void main() {
  testWidgets('historial retira direcciones al cambiar la sesión', (
    tester,
  ) async {
    final auth = AuthProvider();
    ApiClient.client = MockClient((r) async => jsonRespuesta([detalle()]));
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: const MaterialApp(home: HistorialDeliveryScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.textContaining('Avenida prueba 123'), findsOneWidget);
    await tester.runAsync(() => sesion.seleccionar(null));
    await tester.pumpAndSettle();
    expect(find.textContaining('Avenida prueba 123'), findsNothing);
    await tester.pumpWidget(const SizedBox());
    auth.dispose();
  });
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
  test('cotización y checkout conservan ID aceptado y ruta', () async {
    ApiClient.client = MockClient(
      (r) async => jsonRespuesta({
        'cotizacion_id': '11111111-1111-4111-8111-111111111111',
        'vence_en': '2026-10-31T23:00:00Z',
        'sucursal_id': 2,
        'distancia_km': '4.50',
        'tiempo_estimado_min': 12,
        'costo_delivery': '12.00',
        'disponible': true,
        'ruta': [
          [-63.18, -17.78],
          [-63.17, -17.77],
        ],
      }),
    );
    final q = await DeliveryService.cotizar(
      const DeliveryCheckoutRequest(
        sucursalId: 2,
        direccionEntrega: 'Avenida prueba 123',
        latitudEntrega: -17.77,
        longitudEntrega: -63.17,
      ),
    );
    expect(q.cotizacionId, isNotNull);
    expect(q.ruta.length, 2);
    final body = DeliveryCheckoutRequest(
      sucursalId: 2,
      direccionEntrega: 'Avenida prueba 123',
      latitudEntrega: -17.77,
      longitudEntrega: -63.17,
      cotizacionId: q.cotizacionId,
      direccionId: 5,
    ).toJson();
    expect(body['cotizacion_id'], q.cotizacionId);
    expect(body['direccion_id'], 5);
  });
  test(
    'incidencia envía versión y mantiene estado separado del pago',
    () async {
      Map<String, dynamic>? body;
      ApiClient.client = MockClient((r) async {
        body = jsonDecode(r.body) as Map<String, dynamic>;
        return jsonRespuesta({
          'delivery': {...detalle(), 'incidencia_abierta': true, 'version': 4},
        });
      });
      final d = await DeliveryService.incidencia(
        7,
        3,
        'No se logra contactar',
        false,
      );
      expect(body?['version'], 3);
      expect(body?['resolver'], false);
      expect(d.incidenciaAbierta, true);
      expect(d.pagoConfirmado, true);
    },
  );
  testWidgets('entrega física requiere confirmación y envía versión', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(800, 1500);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
    Map<String, dynamic>? body;
    ApiClient.client = MockClient((r) async {
      if (r.method == 'PATCH') {
        body = jsonDecode(r.body) as Map<String, dynamic>;
        return jsonRespuesta({
          'delivery': detalle(estado: 'ENTREGADO', version: 4),
        });
      }
      return jsonRespuesta(detalle());
    });
    await tester.pumpWidget(
      const MaterialApp(
        home: DetalleDeliveryScreen(deliveryId: 7, esStaff: true),
      ),
    );
    await tester.pumpAndSettle();
    await tester.tap(find.byType(DropdownButtonFormField<String>));
    await tester.pumpAndSettle();
    await tester.tap(find.text('ENTREGADO').last);
    await tester.pumpAndSettle();
    final guardar = find.widgetWithText(ElevatedButton, 'Guardar estado');
    expect(tester.widget<ElevatedButton>(guardar).onPressed, isNull);
    await tester.tap(find.text('Confirmo que la entrega física se realizó'));
    await tester.pumpAndSettle();
    expect(tester.widget<ElevatedButton>(guardar).onPressed, isNotNull);
    await tester.tap(guardar);
    await tester.pumpAndSettle();
    expect(body?['version'], 3);
    expect(body?['recepcion_confirmada'], true);
    expect(find.text('Entrega #7 · ENTREGADO'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
  testWidgets('cliente consulta y retira datos ante fallo al actualizar', (
    tester,
  ) async {
    var fallo = false;
    ApiClient.client = MockClient(
      (r) async => fallo
          ? jsonRespuesta({'detail': 'No encontrada'}, 404)
          : jsonRespuesta({...detalle(), 'puede_gestionar': false}),
    );
    await tester.pumpWidget(
      const MaterialApp(
        home: DetalleDeliveryScreen(deliveryId: 7, esStaff: false),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Avenida prueba 123'), findsOneWidget);
    expect(find.text('Guardar estado'), findsNothing);
    fallo = true;
    await tester.tap(find.byTooltip('Actualizar seguimiento'));
    await tester.pumpAndSettle();
    expect(find.text('Avenida prueba 123'), findsNothing);
    expect(find.text('Reintentar'), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });
}
