import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_tr/core/constants/api_constants.dart';
import 'package:mobile_tr/core/network/api_client.dart';
import 'package:mobile_tr/services/devolucion_service.dart';

import 'cuenta_test.dart' show sesion, empresaA, usuario, jwt, jsonRespuesta;

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
    'aceptar conserva comprobante y reintegro pendiente por separado',
    () async {
      ApiClient.client = MockClient((r) async {
        expect(r.url.path, '/api/v1/posventa/devoluciones/4/aceptar');
        expect(jsonDecode(r.body), {'monto': '40.50'});
        return jsonRespuesta({
          'id': 4,
          'estado': 'REEMBOLSO_PENDIENTE',
          'aceptada_cliente_en': '2026-10-31T20:00:00Z',
          'comprobante': {'codigo': 'DEV-4', 'monto': '40.50'},
          'monto_aprobado': '40.50',
        });
      });
      final d = await DevolucionService.aceptar(4, 40.5);
      expect(d.estado, 'REEMBOLSO_PENDIENTE');
      expect(d.comprobante?['codigo'], 'DEV-4');
      expect(d.aceptadaClienteEn, isNotNull);
      expect(d.fechaReembolso, isNull);
    },
  );
  test('solicitud conserva clave al fallar y reintentar', () async {
    final claves = <String>[];
    ApiClient.client = MockClient((r) async {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      claves.add(body['clave_operacion'] as String);
      return claves.length == 1
          ? jsonRespuesta({'detail': 'Falla temporal'}, 503)
          : jsonRespuesta({'id': 4, 'estado': 'SOLICITADA'});
    });
    Future<void> solicitar() async {
      await DevolucionService.solicitar(
        ventaId: 42,
        motivo: 'Prenda dañada',
        observacion: '',
        items: [
          {'venta_detalle_id': 6, 'cantidad': 1},
        ],
      );
    }

    await expectLater(solicitar(), throwsException);
    await solicitar();
    expect(claves[0], claves[1]);
  });
  test(
    'inspección envía no vendibles y condición sin alterar cantidades',
    () async {
      ApiClient.client = MockClient((r) async {
        expect(jsonDecode(r.body), {
          'items': [
            {
              'detalle_id': 8,
              'cantidad_aceptada': 2,
              'cantidad_no_vendible': 1,
              'observacion': 'Costura dañada',
            },
          ],
        });
        return jsonRespuesta({'id': 4, 'estado': 'ESPERA_ACEPTACION'});
      });
      final d = await DevolucionService.recepcionar(
        id: 4,
        items: [
          {
            'detalle_id': 8,
            'cantidad_aceptada': 2,
            'cantidad_no_vendible': 1,
            'observacion': 'Costura dañada',
          },
        ],
      );
      expect(d.estado, 'ESPERA_ACEPTACION');
    },
  );
}
