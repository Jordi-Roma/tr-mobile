import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:mobile_tr/core/storage/base_offline.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  sqfliteFfiInit();
  databaseFactory = databaseFactoryFfi;

  test(
    'CU21 conserva la cola, deduplica y separa los datos al reabrir SQLite',
    () async {
      final directorio = await Directory.systemTemp.createTemp('stylear-cu21-');
      final ruta = '${directorio.path}/cu21.db';
      final primera = BaseOffline(ruta);
      const ambito = '11:9';
      const uuid = '2579d13e-5e45-4ca0-8a20-237224b0adf2';
      await primera.guardarDescarga(
        ambito,
        [
          {'id': 2, 'nombre': 'Centro'},
        ],
        {
          2: [
            {
              'variante_id': 4,
              'producto_id': 7,
              'nombre': 'Prenda',
              'stock': 2,
              'precio_centavos': 5000,
            },
          ],
        },
        {
          'RESERVA': [
            {'id': 12, 'estado': 'PENDIENTE'},
          ],
        },
      );
      await Future.wait(
        List.generate(
          20,
          (_) => primera.registrar(ambito, uuid, 'VENTA', 2, {
            'efectivo_centavos': 5000,
          }),
        ),
      );
      await primera.actualizar(ambito, uuid, {'estado': 'ENVIANDO'});
      await expectLater(
        primera.registrar(ambito, uuid, 'VENTA', 2, {
          'efectivo_centavos': 6000,
        }),
        throwsStateError,
      );
      await primera.cerrar();

      final reabierta = BaseOffline(ruta);
      addTearDown(() async {
        await reabierta.cerrar();
        await deleteDatabase(ruta);
        await directorio.delete();
      });
      expect((await reabierta.variantes(ambito, 2)).single['precio'], 5000);
      expect((await reabierta.historial(ambito)).single['id'], 12);
      final operacion = (await reabierta.operaciones(ambito)).single;
      expect(operacion['uuid'], uuid);
      expect(operacion['estado'], 'ENVIANDO');
      expect(await reabierta.operaciones('11:10'), isEmpty);
      expect(await reabierta.variantes('12:9', 2), isEmpty);

      await reabierta.guardarDescarga(ambito, [], {}, {});
      expect(await reabierta.variantes(ambito, 2), isEmpty);
      expect((await reabierta.operaciones(ambito)).single['uuid'], uuid);
      await reabierta.confirmar(ambito, uuid, 'VENTA', {
        'id': 5,
        'total': '50.00',
      });
      expect((await reabierta.operaciones(ambito)).single['remoto'], 5);
      expect((await reabierta.historial(ambito)).single['id'], 5);
    },
  );
}
