import 'package:firebase_core/firebase_core.dart';

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_tr/core/constants/api_constants.dart';
import 'package:mobile_tr/core/network/api_client.dart';
import 'package:mobile_tr/core/session/contexto_sesion.dart';
import 'package:mobile_tr/models/auth_models.dart';
import 'package:mobile_tr/models/empresa_models.dart';
import 'package:mobile_tr/services/notificaciones_service.dart';
import 'package:mobile_tr/services/firebase_push_service.dart';
import 'package:mobile_tr/screens/notificaciones/notificaciones_screen.dart';
import 'package:mobile_tr/screens/notificaciones/preferencias_notificaciones_sheet.dart';
import 'package:mobile_tr/screens/notificaciones/destinos_notificaciones.dart';
import 'package:mobile_tr/screens/pagos/detalle_pago_screen.dart';

http.Response respuesta(Object o, [int estado = 200]) => http.Response(
  jsonEncode(o),
  estado,
  headers: {'content-type': 'application/json'},
);
Map<String, dynamic> bandeja({int noLeidas = 27}) => {
  'avisos': [
    {
      'id': 1,
      'titulo': 'Aviso propio',
      'mensaje': 'Estado registrado',
      'categoria': 'RESERVA',
      'creado_en': '2026-11-07T12:00:00Z',
      'leida': false,
    },
  ],
  'total': 45,
  'no_leidas': noLeidas,
  'pagina': 1,
  'tamano': 20,
};
Future<void> sesion() async {
  final c = ContextoSesion.instance;
  await c.seleccionar(
    const EmpresaPublica(
      id: 1,
      codigo: 'prueba',
      nombre: 'Prueba',
      estado: 'ACTIVA',
    ),
  );
  final u = UsuarioAutenticado(
    id: 77,
    nombre: 'Cliente',
    apellido: 'Prueba',
    username: 'cliente',
    correo: 'cliente@example.invalid',
    roles: ['CLIENTE'],
    empresaId: 1,
    empresaCodigo: 'prueba',
  );
  final token =
      'h.${base64Url.encode(utf8.encode(jsonEncode({'sub': '77', 'sid': '1', 'empresa_id': 1, 'empresa_codigo': 'prueba', 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600}))).replaceAll('=', '')}.s';
  await c.guardar(token, u);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ApiConstants.customHost = 'http://127.0.0.1:58127';
    await sesion();
  });
  tearDown(() async {
    await ContextoSesion.instance.seleccionar(null);
    ApiClient.client.close();
    FirebasePush.pendiente.value = null;
  });
  test('destinos tipados y referencia mínima: venta nunca abre una orden con ID coincidente', () {
    final venta = DestinoNotificacion({
      'disponible': true,
      'accion': 'VER_DETALLE',
      'recurso_tipo': 'VENTA',
      'recurso_id': 5,
    });
    expect(pantallaNotificacion(venta), null);
    final pago = DestinoNotificacion({
      'disponible': true,
      'accion': 'VER_DETALLE',
      'recurso_tipo': 'ORDEN_PAGO',
      'recurso_id': 5,
    });
    final pantalla = pantallaNotificacion(pago) as DetallePagoScreen;
    expect(pantalla.ordenId, 5);
    expect(pantalla.esAdmin, false);
    expect(
      ReferenciaPush.desde({'notificacion_id': '-1', 'empresa_id': '1'}),
      null,
    );
    expect(
      ReferenciaPush.desde({
        'notificacion_id': '5',
        'empresa_id': '1',
        'token': 'descartado',
      })!.toJson(),
      {'notificacion_id': 5, 'empresa_id': 1},
    );
  });
  test('desvincular usa UUID persistente antes de cerrar sesión', () async {
    const id = '12345678-1234-1234-1234-123456789abc';
    SharedPreferences.setMockInitialValues({'stylear_push_instalacion': id});
    int bajas = 0;
    ApiClient.client = MockClient((r) async {
      expect(r.method, 'DELETE');
      expect(r.url.path, endsWith('/dispositivos/$id'));
      expect(r.headers['Authorization'], startsWith('Bearer '));
      bajas++;
      return respuesta({});
    });
    await FirebasePush.desvincular();
    expect(bajas, 1);
    expect(
      (await SharedPreferences.getInstance()).getString(
        'stylear_push_instalacion',
      ),
      id,
    );
  });
  testWidgets(
    'contador global, marcado de todas y reembolsos existentes se conservan',
    (t) async {
      bool todas = false;
      ApiClient.client = MockClient((r) async {
        if (r.url.path.endsWith('/leer-todas')) {
          todas = true;
          return respuesta({'actualizadas': 27});
        }
        if (r.url.path.endsWith('/reembolsos')) {
          return respuesta([
            {
              'orden_id': 2,
              'estado': 'PENDIENTE',
              'monto': '10.00',
              'moneda': 'BOB',
              'motivo': 'Ensayo',
            },
          ]);
        }
        return respuesta(bandeja(noLeidas: todas ? 0 : 27));
      });
      await t.pumpWidget(const MaterialApp(home: NotificacionesScreen()));
      await t.pumpAndSettle();
      expect(
        find.text('27 sin leer en toda tu bandeja · 45 resultados del filtro'),
        findsOneWidget,
      );
      expect(
        find.text('Mis reembolsos de compras no completadas'),
        findsOneWidget,
      );
      await t.tap(find.text('Marcar todas como leídas'));
      await t.pumpAndSettle();
      expect(todas, true);
      expect(
        find.text('0 sin leer en toda tu bandeja · 45 resultados del filtro'),
        findsOneWidget,
      );
    },
  );
  testWidgets('preferencia fallida conserva selección y envía solo cambios', (
    t,
  ) async {
    Map<String, dynamic>? enviado;
    ApiClient.client = MockClient((r) async {
      if (r.method == 'GET') {
        return respuesta({
          'categorias': {for (final c in categoriasNotificacion) c: true},
        });
      }
      enviado = jsonDecode(r.body) as Map<String, dynamic>;
      return respuesta({'detail': 'No se pudo guardar'}, 503);
    });
    await t.pumpWidget(
      const MaterialApp(
        home: Scaffold(body: PreferenciasNotificacionesSheet()),
      ),
    );
    await t.pumpAndSettle();
    await t.tap(find.widgetWithText(SwitchListTile, 'COMPRA'));
    await t.pump();
    await t.ensureVisible(find.text('Guardar preferencias'));
    await t.tap(find.text('Guardar preferencias'));
    await t.pumpAndSettle();
    expect(enviado, {
      'categorias': {'COMPRA': false},
    });
    expect(find.text('No se pudo guardar'), findsOneWidget);
    expect(
      t
          .widget<SwitchListTile>(find.widgetWithText(SwitchListTile, 'COMPRA'))
          .value,
      false,
    );
  });
  testWidgets(
    'respuesta pendiente no muestra avisos ni reembolsos de otra cuenta',
    (t) async {
      final pendiente = Completer<http.Response>();
      ApiClient.client = MockClient((_) => pendiente.future);
      await t.pumpWidget(const MaterialApp(home: NotificacionesScreen()));
      await t.pump();
      await t.runAsync(() => ContextoSesion.instance.seleccionar(null));
      pendiente.complete(respuesta(bandeja()));
      await t.pumpAndSettle();
      expect(find.text('Aviso propio'), findsNothing);
      expect(
        find.textContaining('0 sin leer en toda tu bandeja'),
        findsOneWidget,
      );
    },
  );
  test('fallo de registro FCM se explica sin mostrar excepción técnica', () {
    final e = FirebaseException(
      plugin: 'firebase_messaging',
      code: 'unknown',
      message: 'java.io.IOException: FCM Registration failed!',
    );
    final texto = FirebasePush.explicarError(e);
    expect(texto, contains('Google no pudo registrar'));
    expect(texto, contains('La bandeja sigue disponible'));
    expect(texto, isNot(contains('java.io')));
    expect(texto, isNot(contains('firebase_messaging/unknown')));
  });
  test('canal nativo se usa solo por acciones explícitas de Android', () async {
    final llamadas = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(FirebasePush.puente, (c) async {
          llamadas.add(c.method);
          return null;
        });
    await FirebasePush.ajustes();
    expect(llamadas, ['ajustes']);
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(FirebasePush.puente, null);
  });
}
