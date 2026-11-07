import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_tr/core/constants/api_constants.dart';
import 'package:mobile_tr/core/network/api_client.dart';
import 'package:mobile_tr/core/network/api_exceptions.dart';
import 'package:mobile_tr/core/session/contexto_sesion.dart';
import 'package:mobile_tr/core/storage/session_storage.dart';
import 'package:mobile_tr/models/auth_models.dart';
import 'package:mobile_tr/models/capacidades_plan.dart';
import 'package:mobile_tr/providers/auth_provider.dart';
import 'package:mobile_tr/screens/saas/plataforma_screen.dart';

UsuarioAutenticado saas({int? empresa}) => UsuarioAutenticado(
  id: 77,
  nombre: 'Admin',
  apellido: 'Prueba',
  username: 'saas',
  correo: 'saas@example.invalid',
  roles: ['ADMIN_SAAS'],
  empresaId: empresa,
  empresaCodigo: empresa == null ? null : 'stylear',
);
String token({int? empresa, int? exp}) =>
    'h.${base64Url.encode(utf8.encode(jsonEncode({'sub': '77', 'sid': '1', 'empresa_id': empresa, 'empresa_codigo': null, 'exp': exp ?? DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600}))).replaceAll('=', '')}.s';
http.Response respuesta(Object v) => http.Response(
  jsonEncode(v),
  200,
  headers: {'content-type': 'application/json'},
);

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  final c = ContextoSesion.instance;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ApiConstants.customHost = 'http://127.0.0.1:58127';
    await c.seleccionar(null);
  });
  tearDown(() async {
    await c.seleccionar(null);
    ApiClient.client.close();
  });
  testWidgets('entrada SaaS muestra empresas y planes sin catálogo comercial', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await c.abrirPlataforma();
      await c.guardar(token(), saas());
    });
    ApiClient.client = MockClient((r) async {
      expect(r.headers.containsKey('X-Empresa-Codigo'), false);
      if (r.url.path.endsWith('/saas/empresas')) {
        return respuesta([
          {'nombre': 'Tienda de prueba', 'estado': 'ACTIVA'},
        ]);
      }
      expect(r.url.path.endsWith('/saas/planes'), true);
      return respuesta([
        {'nombre': 'Plan de prueba', 'activo': true},
      ]);
    });
    final auth = AuthProvider();
    await tester.pumpWidget(
      ChangeNotifierProvider.value(
        value: auth,
        child: const MaterialApp(home: PlataformaScreen()),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Tienda de prueba'), findsOneWidget);
    expect(find.text('Plan de prueba'), findsOneWidget);
    expect(find.text('Catálogo'), findsNothing);
    expect(find.byTooltip('Cerrar sesión'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
    auth.dispose();
  });
  test(
    'SaaS válido sin empresa; rechaza SaaS asociado a tienda y token vencido',
    () {
      expect(ContextoSesion.sesionValida(token(), saas()), true);
      expect(
        ContextoSesion.sesionValida(token(empresa: 1), saas(empresa: 1)),
        false,
      );
      expect(ContextoSesion.sesionValida(token(exp: 1), saas()), false);
    },
  );
  test('SaaS exige entrada de plataforma, no envía empresa y bloquea operaciones de tienda', () async {
    await expectLater(c.guardar(token(), saas()), throwsStateError);
    await c.abrirPlataforma();
    await c.guardar(token(), saas());
    final h = await ApiClient.headersPara(
      '${ApiConstants.baseUrl}/saas/planes',
    );
    expect(h['Authorization'], 'Bearer ${token()}');
    expect(h.containsKey('X-Empresa-Codigo'), false);
    await expectLater(
      ApiClient.headersPara('${ApiConstants.baseUrl}/reportes/dashboard'),
      throwsA(isA<ApiException>()),
    );
  });
  test('restaura sesión SaaS sin consultar directorio de empresa', () async {
    await SessionStorage.saveSession(token: token(), usuario: saas());
    ApiClient.client = MockClient((r) async {
      expect(r.url.path, '/api/v1/perfil');
      expect(r.headers.containsKey('X-Empresa-Codigo'), false);
      return respuesta(saas().toJson());
    });
    final auth = AuthProvider();
    try {
      await auth.inicializar();
      expect(auth.esAdminSaas, true);
      expect(auth.empresa, null);
    } finally {
      auth.dispose();
    }
  });
  test('respuesta SaaS tardía se descarta al salir de plataforma', () async {
    await c.abrirPlataforma();
    await c.guardar(token(), saas());
    final started = Completer<void>(), response = Completer<http.Response>();
    ApiClient.client = MockClient((_) {
      started.complete();
      return response.future;
    });
    final request = ApiClient.get('${ApiConstants.baseUrl}/saas/planes');
    final check = expectLater(request, throwsA(isA<ApiException>()));
    await started.future;
    await c.seleccionar(null);
    response.complete(respuesta([]));
    await check;
    expect(c.usuario, null);
    expect(c.modoPlataforma, false);
  });
  test('capacidad usa habilitada y distingue cero de ilimitado', () {
    final p = CapacidadesPlan.fromJson({
      'empresa_id': 1,
      'operaciones_habilitadas': false,
      'plan': {},
      'suscripcion': {},
      'catalogo': {},
      'limites': {},
      'uso': {},
      'funciones': {
        'reportes_pdf': {
          'incluida': true,
          'habilitada': false,
          'motivo': 'SUSCRIPCION_NO_VIGENTE',
        },
      },
      'cupos': {
        'usuarios': {'limite': 0, 'uso': 1, 'disponibles': 0, 'agotado': true},
        'empleados': {
          'limite': null,
          'uso': 1,
          'disponibles': null,
          'agotado': false,
        },
      },
    });
    expect(p.habilita('reportes_pdf'), false);
    expect(p.motivo('reportes_pdf'), 'La suscripción no está vigente.');
    expect(p.cupos['usuarios']!.disponibles, 0);
    expect(p.cupos['usuarios']!.agotado, true);
    expect(p.cupos['empleados']!.limite, null);
    expect(p.cupos['empleados']!.agotado, false);
  });
}
