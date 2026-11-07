import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_tr/core/constants/api_constants.dart';
import 'package:mobile_tr/core/network/api_client.dart';
import 'package:mobile_tr/core/session/contexto_sesion.dart';
import 'package:mobile_tr/models/reporte_models.dart';
import 'package:mobile_tr/models/empresa_models.dart';
import 'package:mobile_tr/screens/reportes/programados_reportes_tab.dart';
import 'package:mobile_tr/services/reporte_service.dart';

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
  tearDown(() => ApiClient.client.close());
  test(
    'detalle mantiene totales completos e importes decimales del servidor',
    () {
      final r = ReporteResultado.fromJson({
        'tipo': 'VENTAS',
        'pagina': 2,
        'tamano': 20,
        'total_filas': 5200,
        'filas': [
          {'codigo': '21'},
        ],
        'resumen': {
          'importe': '10400.00',
          'importes_por_moneda': [
            {'moneda': 'BOB', 'importe': '10400.00'},
          ],
        },
        'serie_grafico': [
          {'label': '2026-11-06', 'valor': '10400.00'},
        ],
      });
      expect(r.totalFilas, 5200);
      expect(r.pagina, 2);
      expect(r.filas.length, 1);
      expect(r.resumen['importe'], '10400.00');
      expect(r.serieGrafico.single.valor, 10400);
    },
  );
  test('editar título conserva pausa y filtros concurrentes tras revisar conflicto', () {
    final original = <String, dynamic>{
      'titulo': 'Original',
      'activo': true,
      'filtros': <String, dynamic>{'agrupacion': 'DIA', 'estado': null},
    };
    final editado = <String, dynamic>{
      ...original,
      'titulo': 'Editado',
      'filtros': <String, dynamic>{'agrupacion': 'MES', 'estado': null},
    };
    final vigente = <String, dynamic>{
      ...original,
      'activo': false,
      'filtros': <String, dynamic>{'agrupacion': 'DIA', 'estado': 'COMPLETADA'},
    };
    expect(cambiosProgramado(original, editado, vigente), {
      'titulo': 'Editado',
      'filtros': {'agrupacion': 'MES', 'estado': 'COMPLETADA'},
    });
  });
  test(
    'detalle remoto envía página, tamaño y canal; voz identifica su origen',
    () async {
      final enviados = <Map<String, dynamic>>[];
      ApiClient.client = MockClient((r) async {
        enviados.add(jsonDecode(r.body) as Map<String, dynamic>);
        if (r.url.path.endsWith('/interpretar')) {
          return http.Response(
            jsonEncode({'interpretado': false, 'advertencias': []}),
            200,
          );
        }
        expect(r.url.path, endsWith('/reportes/detalle'));
        return http.Response(
          jsonEncode({
            'tipo': 'VENTAS',
            'pagina': 2,
            'tamano': 20,
            'total_filas': 5200,
          }),
          200,
        );
      });
      const f = ReporteFiltros(
        tipo: TipoReporte.ventas,
        fechaDesde: '2026-11-01',
        fechaHasta: '2026-11-06',
        sucursalId: 7,
        tipoVenta: 'DIGITAL',
      );
      await ReporteService.detalle(f, pagina: 2);
      expect(enviados.first, containsPair('pagina', 2));
      expect(enviados.first, containsPair('tamano', 20));
      expect(enviados.first, containsPair('tipo_venta', 'DIGITAL'));
      await ReporteService.interpretar('ventas de hoy', origen: 'VOZ');
      expect(enviados.last, {'texto': 'ventas de hoy', 'origen': 'VOZ'});
    },
  );
  test('programación usa revisión y solo los cambios explícitos', () async {
    ApiClient.client = MockClient((r) async {
      expect(r.method, 'PATCH');
      expect(jsonDecode(r.body), {
        'revision': 4,
        'cambios': {'titulo': 'Corregido'},
      });
      return http.Response('{}', 200);
    });
    await ReporteService.editarProgramado(7, 4, {'titulo': 'Corregido'});
  });
}
