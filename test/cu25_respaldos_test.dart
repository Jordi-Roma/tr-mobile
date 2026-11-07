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
import 'package:mobile_tr/core/network/api_exceptions.dart';
import 'package:mobile_tr/core/session/contexto_sesion.dart';
import 'package:mobile_tr/models/auth_models.dart';
import 'package:mobile_tr/models/empresa_models.dart';
import 'package:mobile_tr/models/respaldo_models.dart';
import 'package:mobile_tr/providers/auth_provider.dart';
import 'package:mobile_tr/providers/plan_provider.dart';
import 'package:mobile_tr/screens/respaldos/respaldos_screen.dart';
import 'package:mobile_tr/services/respaldos_service.dart';

const id = '12345678-1234-1234-1234-123456789abc';
Map<String, dynamic> copia() => {
  'id': id,
  'tipo': 'EMPRESA',
  'origen': 'AUTOMATICO',
  'empresa_id': 1,
  'fecha': '2026-11-06T12:00:00Z',
  'vence_en': '2026-12-06T12:00:00Z',
  'bytes': 2048,
  'estado': 'DISPONIBLE',
};
Map<String, dynamic> previa() => {
  'id': id,
  'tipo': 'EMPRESA',
  'empresa_id': 1,
  'archivos': 0,
  'confirmacion': 'RESTAURAR $id',
  'destino': 'Empresa suspendida',
  'conteos': {'usuario': 1},
  'conteos_actuales': {'usuario': 2},
};
Map<String, dynamic> config() => {
  'politica': {
    'manuales_semana': 1,
    'retencion_dias': 7,
    'frecuencia_dias': 7,
    'horario_editable': false,
    'manuales_habilitados': false,
  },
  'programacion': {
    'activa': true,
    'fecha_inicio': '2026-11-06',
    'hora_local': '19:30:00',
    'zona_horaria': 'UTC',
    'ultimo_respaldo': null,
  },
};
Map<String, dynamic> caps({bool manual = false}) => {
  'empresa_id': 1,
  'plan': {},
  'suscripcion': {},
  'operaciones_habilitadas': true,
  'limites': {'retencion_respaldos_dias': 7, 'frecuencia_respaldo_dias': 7},
  'uso': {},
  'catalogo': {},
  'funciones': {
    'respaldos_manuales': {
      'incluida': manual,
      'habilitada': manual,
      'motivo': manual ? null : 'FUNCION_NO_INCLUIDA',
    },
    'respaldos_automaticos': {
      'incluida': true,
      'habilitada': true,
      'motivo': null,
    },
    'horario_respaldo_configurable': {
      'incluida': false,
      'habilitada': false,
      'motivo': 'FUNCION_NO_INCLUIDA',
    },
  },
  'cupos': {
    'respaldos_manuales_semana': {
      'limite': 1,
      'uso': 0,
      'disponibles': 1,
      'agotado': false,
      'motivo': null,
    },
  },
};
http.Response respuesta(Object j, [int estado = 200]) => http.Response(
  jsonEncode(j),
  estado,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
Future<void> iniciar({bool saas = false}) async {
  final c = ContextoSesion.instance;
  if (saas) {
    await c.abrirPlataforma();
  } else {
    await c.seleccionar(
      EmpresaPublica(
        id: 1,
        codigo: 'stylear',
        nombre: 'StyleAR',
        estado: 'ACTIVA',
      ),
    );
  }
  final u = UsuarioAutenticado(
    id: 77,
    nombre: 'Admin',
    apellido: 'Prueba',
    username: 'admin',
    correo: 'admin@example.invalid',
    roles: [saas ? 'ADMIN_SAAS' : 'ADMINISTRADOR'],
    empresaId: saas ? null : 1,
    empresaCodigo: saas ? null : 'stylear',
  );
  final token =
      'h.${base64Url.encode(utf8.encode(jsonEncode({'sub': '77', 'sid': '1', 'empresa_id': u.empresaId, 'empresa_codigo': u.empresaCodigo, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600}))).replaceAll('=', '')}.s';
  await c.guardar(token, u);
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    ApiConstants.customHost = 'http://127.0.0.1:58127';
  });
  tearDown(() async {
    await ContextoSesion.instance.seleccionar(null);
    ApiClient.client.close();
  });
  test('normaliza HH:MM:SS y envía horario fijo sin modificar frecuencia', () {
    final c = ConfiguracionRespaldos.fromJson(config());
    expect(c.hora, '19:30');
    final datos = c.datos(
      activar: true,
      inicio: '2026-11-06',
      hora: c.hora,
      zona: c.zona,
      editable: false,
    );
    expect(datos['hora_local'], '02:00');
    expect(datos['zona_horaria'], 'America/La_Paz');
    expect(datos.containsKey('frecuencia_dias'), false);
    expect(Respaldo.fromJson(copia()).origenNombre, 'Automático');
  });
  test('empresa no envía selector ni usa las rutas SaaS', () async {
    await iniciar();
    final rutas = <String>[];
    ApiClient.client = MockClient((r) async {
      rutas.add(r.url.path);
      expect(r.headers['X-Empresa-Codigo'], 'stylear');
      expect(r.url.path.contains('/saas/'), false);
      if (r.method == 'GET') return respuesta([copia()]);
      if (r.url.path.endsWith('/restaurar')) {
        expect(jsonDecode(r.body), {'confirmacion': 'RESTAURAR $id'});
        return respuesta({'estado': 'RESTAURADO'});
      }
      expect(jsonDecode(r.body), isEmpty);
      return respuesta(copia(), 201);
    });
    const api = RespaldosService(plataforma: false);
    await api.listar();
    await api.crear();
    await api.restaurar(id, 'RESTAURAR $id');
    expect(rutas.length, 3);
    await expectLater(api.crear(empresaId: 2), throwsA(isA<ApiException>()));
    expect(rutas.length, 3);
  });
  test(
    'SaaS conserva alcance global explícito sin header de empresa',
    () async {
      await iniciar(saas: true);
      ApiClient.client = MockClient((r) async {
        expect(r.url.path, '/api/v1/saas/respaldos');
        expect(r.headers.containsKey('X-Empresa-Codigo'), false);
        expect(jsonDecode(r.body), {'empresa_id': null});
        return respuesta(copia(), 201);
      });
      await const RespaldosService(plataforma: true).crear();
    },
  );
  testWidgets('revisión exige suspensión, frase exacta y botón explícito', (
    tester,
  ) async {
    await tester.runAsync(iniciar);
    Future<void> abrir(bool suspendida) async {
      await tester.pumpWidget(
        MaterialApp(
          home: RevisionRespaldoScreen(
            previa: PreviaRespaldo.fromJson(previa()),
            suspendida: suspendida,
            plataforma: false,
          ),
        ),
      );
      await tester.pumpAndSettle();
    }

    await abrir(false);
    await tester.enterText(find.byType(TextField), 'RESTAURAR $id');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      null,
    );
    await tester.pumpWidget(const SizedBox.shrink());
    await abrir(true);
    await tester.enterText(find.byType(TextField), 'incorrecta');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      null,
    );
    await tester.enterText(find.byType(TextField), 'RESTAURAR $id');
    await tester.pump();
    expect(
      tester.widget<FilledButton>(find.byType(FilledButton)).onPressed,
      isNotNull,
    );
    await tester.testTextInput.receiveAction(TextInputAction.done);
    await tester.pump();
    expect(find.text('Restaurar copia revisada'), findsOneWidget);
    await tester.pumpWidget(const SizedBox.shrink());
  });
  testWidgets(
    'sin creación manual mantiene listado y revisión; programa con hora fija',
    (tester) async {
      await tester.runAsync(iniciar);
      Map<String, dynamic>? guardado;
      ApiClient.client = MockClient((r) async {
        if (r.url.path.endsWith('/capacidades')) return respuesta(caps());
        if (r.url.path.endsWith('/mi-empresa/plan')) {
          return respuesta({'empresa_estado': 'SUSPENDIDA'});
        }
        if (r.url.path.endsWith('/programacion')) {
          if (r.method == 'PUT') {
            guardado = jsonDecode(r.body) as Map<String, dynamic>;
            return respuesta(config()['programacion']);
          }
          return respuesta(config());
        }
        expect(r.url.path, '/api/v1/respaldos');
        return respuesta([copia()]);
      });
      final auth = AuthProvider(), plan = PlanProvider();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: plan),
          ],
          child: const MaterialApp(home: RespaldosScreen()),
        ),
      );
      await tester.pumpAndSettle();
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Crear copia cifrada'),
            )
            .onPressed,
        null,
      );
      expect(find.text('Revisar restauración'), findsOneWidget);
      expect(find.text('Automático · DISPONIBLE'), findsOneWidget);
      final guardar = find.widgetWithText(FilledButton, 'Guardar programación');
      await tester.scrollUntilVisible(
        guardar,
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.ensureVisible(guardar);
      await tester.pumpAndSettle();
      await tester.tap(guardar);
      await tester.pumpAndSettle();
      expect(guardado?['hora_local'], '02:00');
      expect(guardado?['zona_horaria'], 'America/La_Paz');
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
      plan.dispose();
    },
  );
  testWidgets(
    'timeout de copia no reintenta ni habilita repetir sin actualizar',
    (tester) async {
      await tester.runAsync(iniciar);
      int creaciones = 0;
      ApiClient.client = MockClient((r) async {
        if (r.url.path.endsWith('/capacidades')) {
          return respuesta(caps(manual: true));
        }
        if (r.url.path.endsWith('/mi-empresa/plan')) {
          return respuesta({'empresa_estado': 'ACTIVA'});
        }
        if (r.url.path.endsWith('/programacion')) return respuesta(config());
        if (r.method == 'POST') {
          creaciones++;
          throw TimeoutException('Simulado');
        }
        return respuesta([]);
      });
      final auth = AuthProvider(), plan = PlanProvider();
      await tester.pumpWidget(
        MultiProvider(
          providers: [
            ChangeNotifierProvider.value(value: auth),
            ChangeNotifierProvider.value(value: plan),
          ],
          child: const MaterialApp(home: RespaldosScreen()),
        ),
      );
      await tester.pumpAndSettle();
      final crear = find.widgetWithText(FilledButton, 'Crear copia cifrada');
      await tester.tap(crear);
      await tester.pumpAndSettle();
      expect(creaciones, 1);
      expect(tester.widget<FilledButton>(crear).onPressed, null);
      expect(
        find.textContaining('No se pudo confirmar el resultado'),
        findsOneWidget,
      );
      await tester.tap(find.byTooltip('Actualizar respaldos'));
      await tester.pumpAndSettle();
      expect(creaciones, 1);
      expect(tester.widget<FilledButton>(crear).onPressed, isNotNull);
      await tester.pumpWidget(const SizedBox.shrink());
      auth.dispose();
      plan.dispose();
    },
  );
}
