import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_tr/core/constants/api_constants.dart';
import 'package:mobile_tr/core/network/api_client.dart';
import 'package:mobile_tr/screens/reportes/analitica_screen.dart';
import 'package:mobile_tr/screens/reportes/serie_analitica.dart';
import 'package:mobile_tr/screens/reportes/solicitud_analitica.dart';
import 'package:mobile_tr/services/analitica_service.dart';

import 'dart:convert';

import 'cuenta_test.dart' show sesion, empresaA, usuario, jwt, jsonRespuesta;

Map<String, dynamic> estado({bool admin = true}) => {
  'segmentacion_permitida': admin,
  'fuentes': [
    for (final origen in ['OFICIAL', 'DEMOSTRACION'])
      {
        'origen': origen,
        'estado': origen == 'OFICIAL' ? 'HISTORIAL_INSUFICIENTE' : 'DISPONIBLE',
        'advertencia': origen == 'OFICIAL'
            ? 'No hay modelo oficial validado.'
            : 'Datos sintéticos.',
        'evaluado_en': null,
        'fuente_datos': null,
        'sucursales': [
          {'id': 1, 'nombre': 'Centro', 'datos_disponibles': true},
        ],
      },
  ],
};
Map<String, dynamic> resultado({bool demo = false, int pagina = 1}) => {
  'estado': demo ? 'DISPONIBLE' : 'HISTORIAL_INSUFICIENTE',
  'advertencia': demo ? 'Demostración sintética.' : '',
  'pagina': pagina,
  'tamano': 25,
  'total_filas': demo ? 50 : 0,
  'metricas': demo
      ? {'mae': 4.47, 'rmse': 5.78, 'mae_referencia': 5.56, 'muestras': 50}
      : null,
  'filas': demo
      ? [
          {
            'sucursal': 'Centro',
            'producto_id': 'SYN-P01',
            'fecha_corte': '2026-01-01',
            'objetivo_hasta': '2026-01-08',
            'unidades_reales': 10,
            'unidades_predichas': 8,
            'referencia_semana_anterior': 7,
          },
        ]
      : [],
  'serie': demo
      ? [
          {
            'fecha_corte': '2026-01-01',
            'unidades_reales': 10,
            'unidades_predichas': 8,
            'referencia_semana_anterior': 7,
          },
          {
            'fecha_corte': '2026-01-08',
            'unidades_reales': 12,
            'unidades_predichas': 11,
            'referencia_semana_anterior': 10,
          },
        ]
      : [],
  'productos': demo ? ['SYN-P01'] : [],
};
Finder get vertical => find
    .byWidgetPredicate(
      (w) => w is Scrollable && w.axisDirection == AxisDirection.down,
    )
    .first;
Future<void> elegirDemo(WidgetTester t) async {
  await t.tap(find.byType(DropdownButtonFormField<String>).first);
  await t.pumpAndSettle();
  await t.tap(find.text('Demostración sintética').last);
  await t.pump();
}

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
  test('escala ajustada incluye todos los valores y evita rango vacío', () {
    final rango = rangoSerie([430, 450, 480]);
    expect(rango.minimo, greaterThan(0));
    expect(rango.minimo, lessThan(430));
    expect(rango.maximo, greaterThan(480));
    final constante = rangoSerie([0, 0]);
    expect(constante.minimo, 0);
    expect(constante.maximo, greaterThan(0));
    final unico = rangoSerie([10]);
    expect(unico.minimo, lessThan(10));
    expect(unico.maximo, greaterThan(10));
  });
  testWidgets(
    'grupo solicitado sin asignaciones conserva filtro sin fallar el selector',
    (t) async {
      ApiClient.client = MockClient((r) async {
        if (r.url.path.endsWith('/estado')) return jsonRespuesta(estado());
        if (r.url.path.endsWith('/interpretar')) {
          return jsonRespuesta({
            'mensaje': 'Revisa los filtros',
            'formato_sugerido': 'PANTALLA',
            'solicitud': {
              'tipo': 'SEGMENTOS',
              'origen': 'DEMOSTRACION',
              'grupo': 6,
            },
          });
        }
        if (r.url.path.endsWith('/segmentos')) {
          expect(r.url.queryParameters['grupo'], '6');
          return jsonRespuesta({
            ...resultado(),
            'perfiles': [
              {'grupo': 1, 'nombre': 'Grupo 1'},
            ],
          });
        }
        return jsonRespuesta(resultado());
      });
      await t.pumpWidget(const MaterialApp(home: AnaliticaScreen()));
      await t.pumpAndSettle();
      final campo = find.byWidgetPredicate(
        (w) =>
            w is TextField &&
            w.decoration?.labelText == 'Solicitud de analítica',
      );
      await t.scrollUntilVisible(campo, 200, scrollable: vertical);
      await t.enterText(campo, 'Muéstrame segmento 6 de demostración');
      FocusManager.instance.primaryFocus?.unfocus();
      await t.pumpAndSettle();
      await t.ensureVisible(find.text('Revisar solicitud'));
      await t.pumpAndSettle();
      await t.tap(find.text('Revisar solicitud'));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('Aplicar solicitud revisada'),
        100,
        scrollable: vertical,
      );
      await t.tap(find.text('Aplicar solicitud revisada'));
      await t.pumpAndSettle();
      t.state<ScrollableState>(vertical).position.jumpTo(0);
      await t.pumpAndSettle();
      final grupo = find.byType(DropdownButtonFormField<int>);
      await t.scrollUntilVisible(grupo, 180, scrollable: vertical);
      expect(t.widget<DropdownButtonFormField<int>>(grupo).initialValue, 6);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'solicitud presenta vista previa y solo aplica con confirmación',
    (t) async {
      final aplicadas = <Map<String, dynamic>>[];
      ApiClient.client = MockClient((r) async {
        expect(r.url.path, endsWith('/analitica/interpretar'));
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        expect(body['origen_entrada'], 'TEXTO');
        return jsonRespuesta({
          'mensaje': 'Revisa los filtros.',
          'requiere_aclaracion': false,
          'formato_sugerido': 'PDF',
          'solicitud': {
            'tipo': 'PREDICCIONES',
            'origen': 'DEMOSTRACION',
            'sucursal_id': 1,
          },
        });
      });
      await t.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: SingleChildScrollView(
              child: SolicitudAnalitica(
                origen: 'OFICIAL',
                habilitada: true,
                onAplicar: aplicadas.add,
              ),
            ),
          ),
        ),
      );
      await t.enterText(
        find.byType(TextField),
        'Evaluación de predicciones sintéticas en PDF',
      );
      await t.tap(find.text('Revisar solicitud'));
      await t.pumpAndSettle();
      expect(aplicadas, isEmpty);
      await t.ensureVisible(find.text('Aplicar solicitud revisada'));
      await t.pumpAndSettle();
      await t.tap(find.text('Aplicar solicitud revisada'));
      await t.pumpAndSettle();
      expect(aplicadas.single['origen'], 'DEMOSTRACION');
    },
  );
  testWidgets('vista previa tardía no sobrevive a un cambio de contexto', (
    t,
  ) async {
    final pendiente = Completer<http.Response>();
    ApiClient.client = MockClient((r) => pendiente.future);
    Widget panel(bool habilitada) => MaterialApp(
      home: Scaffold(
        body: SingleChildScrollView(
          child: SolicitudAnalitica(
            origen: 'OFICIAL',
            habilitada: habilitada,
            onAplicar: (_) {},
          ),
        ),
      ),
    );
    await t.pumpWidget(panel(true));
    await t.enterText(
      find.byType(TextField),
      'Evaluación de predicciones sintéticas',
    );
    await t.tap(find.text('Revisar solicitud'));
    await t.pump();
    await t.pumpWidget(panel(false));
    pendiente.complete(
      jsonRespuesta({
        'mensaje': 'No debe aparecer',
        'solicitud': {'tipo': 'SEGMENTOS', 'origen': 'DEMOSTRACION'},
      }),
    );
    await t.pumpAndSettle();
    expect(find.text('No debe aparecer'), findsNothing);
    expect(t.widget<TextField>(find.byType(TextField)).controller!.text, '');
  });
  test(
    'descarga usa endpoint registrado y conserva origen y filtros',
    () async {
      ApiClient.client = MockClient((r) async {
        expect(r.url.path, endsWith('/analitica/exportar/pdf'));
        expect(jsonDecode(r.body), {
          'tipo': 'PREDICCIONES',
          'origen': 'DEMOSTRACION',
          'sucursal_id': 1,
        });
        return http.Response.bytes(
          [37, 80, 68, 70],
          200,
          headers: {'content-type': 'application/pdf'},
        );
      });
      final bytes = await AnaliticaService.exportar({
        'tipo': 'PREDICCIONES',
        'origen': 'DEMOSTRACION',
        'sucursal_id': 1,
      }, 'pdf');
      expect(bytes, [37, 80, 68, 70]);
    },
  );
  testWidgets(
    'administrador consulta grupos con métricas internas y perfiles legibles',
    (t) async {
      ApiClient.client = MockClient((r) async {
        if (r.url.path.endsWith('/estado')) return jsonRespuesta(estado());
        if (r.url.path.endsWith('/segmentos')) {
          return jsonRespuesta({
            ...resultado(demo: true),
            'serie': [],
            'total_filas': 3,
            'fecha_corte': '2026-02-24',
            'ventana_dias': 180,
            'clientes_sin_compras_ventana': 1,
            'metricas': {
              'silhouette': 0.453,
              'ari_medio': 1,
              'clientes_analizados': 149,
              'grupos': 2,
            },
            'perfiles': [
              {
                'grupo': 1,
                'nombre': 'Grupo 1',
                'clientes': 86,
                'proporcion': 0.577,
                'descripcion': 'Perfil sintético con mayor gasto observado.',
              },
            ],
            'filas': [
              {
                'cliente_id': 'SYN-C001',
                'grupo': 1,
                'recencia_dias': 3,
                'frecuencia_compras': 12,
                'gasto_centavos': 50000,
              },
            ],
          });
        }
        return jsonRespuesta(
          resultado(demo: r.url.queryParameters['origen'] == 'DEMOSTRACION'),
        );
      });
      await t.pumpWidget(const MaterialApp(home: AnaliticaScreen()));
      await t.pumpAndSettle();
      await elegirDemo(t);
      await t.pumpAndSettle();
      await t.tap(find.byType(DropdownButtonFormField<String>).at(1));
      await t.pumpAndSettle();
      await t.tap(find.text('Segmentación de clientes').last);
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('86 clientes · 57.7 % del total'),
        100,
        scrollable: vertical,
      );
      expect(
        find.text('Perfil sintético con mayor gasto observado.'),
        findsOneWidget,
      );
      expect(find.byType(SerieAnalitica), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets(
    'oficial por defecto y gráfico sintético accesible en pantalla estrecha',
    (t) async {
      t.view.physicalSize = const Size(320, 800);
      t.view.devicePixelRatio = 1;
      addTearDown(t.view.resetPhysicalSize);
      addTearDown(t.view.resetDevicePixelRatio);
      final origenes = <String>[];
      ApiClient.client = MockClient((r) async {
        if (r.url.path.endsWith('/estado')) return jsonRespuesta(estado());
        origenes.add(r.url.queryParameters['origen']!);
        return jsonRespuesta(
          resultado(demo: r.url.queryParameters['origen'] == 'DEMOSTRACION'),
        );
      });
      await t.pumpWidget(const MaterialApp(home: AnaliticaScreen()));
      await t.pumpAndSettle();
      expect(origenes, ['OFICIAL']);
      expect(find.text('Historial insuficiente'), findsOneWidget);
      await elegirDemo(t);
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('Evaluación histórica de predicciones'),
        100,
        scrollable: vertical,
      );
      await t.scrollUntilVisible(
        find.text('Semanas de prueba; no es un pronóstico oficial vigente.'),
        100,
        scrollable: vertical,
      );
      expect(
        find.text('Semanas de prueba; no es un pronóstico oficial vigente.'),
        findsOneWidget,
      );
      await t.scrollUntilVisible(
        find.byType(SerieAnalitica),
        100,
        scrollable: vertical,
      );
      await t.pumpAndSettle();
      expect(find.byType(SerieAnalitica), findsOneWidget);
      expect(find.byType(DataTable), findsNothing);
      await t.scrollUntilVisible(
        find.text('Ver detalle del reporte (50 registros)'),
        100,
        scrollable: vertical,
      );
      await t.tap(find.text('Ver detalle del reporte (50 registros)'));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.byType(DataTable),
        100,
        scrollable: vertical,
      );
      expect(find.byType(DataTable), findsOneWidget);
      await t.ensureVisible(find.text('Ocultar detalle del reporte'));
      await t.tap(find.text('Ocultar detalle del reporte'));
      await t.pumpAndSettle();
      expect(find.byType(DataTable), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
  testWidgets('cambiar a oficial descarta una respuesta sintética tardía', (
    t,
  ) async {
    final pendiente = Completer<http.Response>();
    ApiClient.client = MockClient((r) async {
      if (r.url.path.endsWith('/estado')) return jsonRespuesta(estado());
      if (r.url.queryParameters['origen'] == 'DEMOSTRACION') {
        return pendiente.future;
      }
      return jsonRespuesta(resultado());
    });
    await t.pumpWidget(const MaterialApp(home: AnaliticaScreen()));
    await t.pumpAndSettle();
    await elegirDemo(t);
    await t.pump();
    await t.tap(find.byType(DropdownButtonFormField<String>).first);
    await t.pump(const Duration(seconds: 1));
    await t.tap(find.text('Historial oficial').last);
    await t.pumpAndSettle();
    pendiente.complete(jsonRespuesta(resultado(demo: true)));
    await t.pumpAndSettle();
    await t.scrollUntilVisible(
      find.text('No hay resultados para el origen y los filtros aplicados.'),
      200,
      scrollable: vertical,
    );
    expect(find.byType(SerieAnalitica), findsNothing);
    expect(t.takeException(), isNull);
  });
  testWidgets('encargado no tiene opción de segmentos', (t) async {
    ApiClient.client = MockClient((r) async {
      expect(r.url.path.endsWith('/segmentos'), isFalse);
      return jsonRespuesta(
        r.url.path.endsWith('/estado') ? estado(admin: false) : resultado(),
      );
    });
    await t.pumpWidget(const MaterialApp(home: AnaliticaScreen()));
    await t.pumpAndSettle();
    await t.tap(find.byType(DropdownButtonFormField<String>).at(1));
    await t.pumpAndSettle();
    expect(find.text('Segmentación de clientes'), findsNothing);
    await t.pumpWidget(const SizedBox());
  });
  testWidgets(
    'cambio de sesión limpia resultados y bloquea consultas pendientes',
    (t) async {
      ApiClient.client = MockClient(
        (r) async => jsonRespuesta(
          r.url.path.endsWith('/estado') ? estado() : resultado(demo: true),
        ),
      );
      await t.pumpWidget(const MaterialApp(home: AnaliticaScreen()));
      await t.pumpAndSettle();
      await t.runAsync(() => sesion.seleccionar(null));
      await t.pumpAndSettle();
      await t.scrollUntilVisible(
        find.text('La sesión cambió. Vuelve a abrir Analítica inteligente.'),
        100,
        scrollable: vertical,
      );
      expect(find.byType(SerieAnalitica), findsNothing);
      expect(t.takeException(), isNull);
    },
  );
}
