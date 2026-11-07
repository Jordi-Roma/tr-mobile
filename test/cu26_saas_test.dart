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
import 'package:mobile_tr/models/saas_models.dart';
import 'package:mobile_tr/screens/saas/plan_editor_screen.dart';
import 'package:mobile_tr/screens/saas/empresa_saas_screen.dart';
import 'package:mobile_tr/screens/saas/saas_widgets.dart';
import 'package:mobile_tr/services/saas_service.dart';

Map<String, dynamic> planJson() => {
  'id': 1,
  'codigo': 'PRUEBA',
  'nombre': 'Plan de prueba',
  'descripcion': 'Original',
  'condiciones': 'Condiciones',
  'precio': '10.00',
  'moneda': 'BOB',
  'activo': true,
  'publico': false,
  'revision': 1,
  'limites': {'usuarios': 20, 'productos': 777, 'respaldos_manuales_semana': 5},
  'funciones': {
    'reportes_pdf': true,
    'reportes_interpretacion': true,
    'reportes_voz': false,
  },
};
Map<String, dynamic> catalogoJson() => {
  'funciones': [
    {
      'clave': 'reportes_pdf',
      'nombre': 'Exportar PDF',
      'descripcion': 'PDF',
      'dependencias': [],
      'requiere_alguna': [],
    },
    {
      'clave': 'reportes_interpretacion',
      'nombre': 'Interpretación',
      'descripcion': 'Texto',
      'dependencias': [],
      'requiere_alguna': [],
    },
    {
      'clave': 'reportes_voz',
      'nombre': 'Voz',
      'descripcion': 'Micrófono',
      'dependencias': ['reportes_interpretacion'],
      'requiere_alguna': [],
    },
  ],
  'limites': [
    {
      'clave': 'usuarios',
      'nombre': 'Usuarios',
      'unidad': 'cuentas',
      'minimo': 1,
    },
  ],
};
http.Response respuesta(Object j, [int status = 200]) => http.Response(
  jsonEncode(j),
  status,
  headers: {'content-type': 'application/json; charset=utf-8'},
);
Future<void> iniciar() async {
  final u = UsuarioAutenticado(
    id: 77,
    nombre: 'Admin',
    apellido: 'Prueba',
    username: 'saas',
    correo: 'saas@example.invalid',
    roles: ['ADMIN_SAAS'],
    empresaId: null,
    empresaCodigo: null,
  );
  final t =
      'h.${base64Url.encode(utf8.encode(jsonEncode({'sub': '77', 'sid': '1', 'empresa_id': null, 'empresa_codigo': null, 'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600}))).replaceAll('=', '')}.s';
  await ContextoSesion.instance.abrirPlataforma();
  await ContextoSesion.instance.guardar(t, u);
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
  test('dependencias provienen del catálogo y no del nombre del plan', () {
    final c = CatalogoSaas.fromJson(catalogoJson());
    expect(
      validarPoliticaSaas(c, {}, {
        'reportes_voz': true,
        'reportes_interpretacion': false,
      }),
      isNotNull,
    );
    expect(
      validarPoliticaSaas(c, {}, {
        'reportes_voz': true,
        'reportes_interpretacion': true,
      }),
      null,
    );
    expect(validarFechaSaas('2026-02-30'), isNotNull);
    expect(validarFechaSaas('2026-11-06'), null);
  });
  test(
    'edición parcial conserva condiciones y claves históricas no editadas',
    () {
      final p = PlanSaas.fromJson(planJson());
      final cambios = cambiosPlanSaas(p, {
        ...planJson(),
        'descripcion': 'Revisado',
        'limites': <String, int>{'usuarios': 20},
        'funciones': <String, bool>{
          'reportes_pdf': true,
          'reportes_interpretacion': true,
          'reportes_voz': false,
        },
      });
      expect(cambios, {'descripcion': 'Revisado'});
    },
  );
  test(
    'servicio SaaS confirma el mismo contenido y token sin enviar empresa',
    () async {
      await iniciar();
      final cambios = {
        'descripcion': 'Revisado',
        'limites': {'usuarios': 10},
      };
      ApiClient.client = MockClient((r) async {
        expect(r.headers.containsKey('X-Empresa-Codigo'), false);
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        expect(body['descripcion'], 'Revisado');
        expect(body['limites'], {'usuarios': 10});
        if (r.method == 'POST') {
          return respuesta({
            'token_previsualizacion': 'token',
            'propuesta': planJson(),
            'impacto': {'total_empresas': 0, 'empresas': []},
          });
        }
        expect(r.method, 'PUT');
        expect(body['token_previsualizacion'], 'token');
        return respuesta(planJson());
      });
      final p = await SaasService.previsualizar(1, cambios);
      await SaasService.editarPlan(1, cambios, p.token);
    },
  );
  testWidgets(
    'edición de plan exige preview, conserva formulario ante 409 y repite revisión',
    (tester) async {
      await tester.runAsync(iniciar);
      int previas = 0, guardados = 0;
      ApiClient.client = MockClient((r) async {
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        expect(
          (body['limites'] as Map?)?.containsKey('productos') ?? false,
          false,
        ); // El servidor conserva claves históricas omitidas.
        if (r.method == 'POST') {
          previas++;
          return respuesta({
            'token_previsualizacion': 'token-$previas',
            'propuesta': planJson(),
            'impacto': {
              'total_empresas': 1,
              'empresas': [
                {
                  'id': 5,
                  'nombre': 'Empresa afectada',
                  'excesos': {
                    'usuarios': {'uso': 25, 'limite': 20},
                  },
                  'reportes_a_pausar': [1, 2],
                  'restablecer_horario_respaldo': true,
                  'operaciones_bloqueadas_por_desactivar_plan': false,
                },
              ],
            },
          });
        }
        guardados++;
        expect(body['token_previsualizacion'], 'token-1');
        return respuesta({'detail': 'La previsualización cambió.'}, 409);
      });
      await tester.pumpWidget(
        MaterialApp(
          home: PlanEditorScreen(
            catalogo: CatalogoSaas.fromJson(catalogoJson()),
            plan: PlanSaas.fromJson(planJson()),
          ),
        ),
      );
      await tester.enterText(
        find.widgetWithText(TextFormField, 'Descripción'),
        'Edición pendiente',
      );
      final revisar = find.widgetWithText(FilledButton, 'Revisar impacto');
      await tester.scrollUntilVisible(
        revisar,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(revisar);
      await tester.pumpAndSettle();
      final confirmar = find.widgetWithText(
        FilledButton,
        'Confirmar cambios del plan',
      );
      await tester.scrollUntilVisible(
        confirmar,
        400,
        scrollable: find.byType(Scrollable).first,
      );
      expect(find.text('Empresa afectada'), findsOneWidget);
      await tester.tap(confirmar);
      await tester.pumpAndSettle();
      expect(guardados, 1);
      expect(
        find.textContaining('Revisa nuevamente el impacto'),
        findsOneWidget,
      );
      expect(find.text('Edición pendiente'), findsOneWidget);
      expect(find.text('Confirmar cambios del plan'), findsNothing);
      await tester.scrollUntilVisible(
        revisar,
        500,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(revisar);
      await tester.pumpAndSettle();
      expect(previas, 2);
      final volver = find.widgetWithText(OutlinedButton, 'Volver a editar');
      await tester.scrollUntilVisible(
        volver,
        400,
        scrollable: find.byType(Scrollable).first,
      );
      await tester.tap(volver);
      await tester.pumpAndSettle();
      expect(find.text('Confirmar cambios del plan'), findsNothing);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
  testWidgets(
    'empresas filtradas por plan cargan sin afirmar antes de recibir opciones',
    (tester) async {
      await tester.runAsync(iniciar);
      int solicitudes = 0;
      ApiClient.client = MockClient((r) async {
        if (r.url.path.endsWith('/planes')) return respuesta([planJson()]);
        expect(r.url.queryParameters['plan_id'], '1');
        solicitudes++;
        return respuesta({
          'total': 1,
          'pagina': 1,
          'tamano': 20,
          'empresas': [
            {
              'id': 5,
              'codigo': 'empresa-a',
              'nombre': 'Empresa filtrada',
              'estado': 'ACTIVA',
              'plan_id': 1,
              'plan_nombre': 'Plan de prueba',
            },
          ],
        });
      });
      await tester.pumpWidget(
        const MaterialApp(home: EmpresasSaasScreen(planId: 1)),
      );
      await tester.pumpAndSettle();
      expect(tester.takeException(), null);
      expect(find.text('Empresa filtrada'), findsOneWidget);
      expect(solicitudes, 1);
      await tester.pumpWidget(const SizedBox.shrink());
    },
  );
}
