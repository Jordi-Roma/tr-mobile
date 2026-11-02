import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:provider/provider.dart';
import 'package:mobile_tr/core/constants/api_constants.dart';
import 'package:mobile_tr/core/network/api_client.dart';
import 'package:mobile_tr/models/catalogo_models.dart';
import 'package:mobile_tr/models/carrito_models.dart';
import 'package:mobile_tr/providers/carrito_provider.dart';
import 'package:mobile_tr/services/mayorista_service.dart';
import 'package:mobile_tr/screens/mayorista/mayorista_screen.dart';

import 'cuenta_test.dart' show sesion, empresaA, usuario, jwt, jsonRespuesta;

final opciones = {
  'variantes': [
    {
      'producto_variante_id': 1,
      'talla': 'M',
      'color': 'Azul',
      'stock': 10,
      'precio_base': '50',
    },
    {
      'producto_variante_id': 2,
      'talla': 'S',
      'color': 'Negro',
      'stock': 10,
      'precio_base': '50',
    },
  ],
  'paquetes': [
    {
      'tipo': 'CUARTA',
      'cantidad': 3,
      'descuento': '10.00',
      'disponible': true,
      'motivo': null,
    },
    {
      'tipo': 'MEDIA',
      'cantidad': 6,
      'descuento': '15.00',
      'disponible': false,
      'motivo': 'Se requieren 3 tallas distintas.',
    },
    {
      'tipo': 'DOCENA',
      'cantidad': 12,
      'descuento': null,
      'disponible': false,
      'motivo': 'Sin porcentaje configurado.',
    },
  ],
};
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
  test('modelo conserva paquete y unidad como líneas separadas', () {
    Map<String, dynamic> item = {
      'id': 1,
      'producto_variante_id': 1,
      'producto_id': 1,
      'producto': 'Prenda',
      'categoria': 'Ropa',
      'talla': 'M',
      'color': 'Azul',
      'cantidad': 1,
      'precio_unitario': '45',
      'subtotal': '45',
      'stock_disponible': 10,
    };
    final paquete = CarritoItemResponse.fromJson({
      ...item,
      'paquete_id': 4,
      'tipo_compra': 'CUARTA',
      'descuento_mayorista': '10.00',
    });
    final unidad = CarritoItemResponse.fromJson({
      ...item,
      'id': 2,
      'precio_unitario': '50',
    });
    expect(paquete.paqueteId, 4);
    expect(paquete.tipoCompra, 'CUARTA');
    expect(unidad.paqueteId, isNull);
    expect(unidad.tipoCompra, 'UNIDAD');
  });
  test(
    'reintento de paquete mantiene clave y porcentaje usa redondeo monetario',
    () async {
      final claves = <String>[];
      ApiClient.client = MockClient((r) async {
        claves.add((jsonDecode(r.body) as Map)['clave_operacion'] as String);
        throw Exception('Respuesta perdida');
      });
      for (var i = 0; i < 2; i++) {
        await expectLater(
          MayoristaService.agregar(1, 2, 'CUARTA', {1: 1, 2: 2}),
          throwsA(isA<Exception>()),
        );
      }
      expect(claves[0], claves[1]);
      expect(
        OpcionMayorista({
          'tipo': 'CUARTA',
          'cantidad': 3,
          'descuento': '12.5',
          'disponible': true,
        }).precio(10.05),
        8.79,
      );
    },
  );
  testWidgets(
    'arma paquete fijo y muestra opciones sin variedad deshabilitadas',
    (tester) async {
      Map<String, dynamic>? enviado;
      ApiClient.client = MockClient((r) async {
        if (r.method == 'POST') {
          enviado = jsonDecode(r.body) as Map<String, dynamic>;
          return jsonRespuesta({'id': 1, 'items': [], 'total': 0});
        }
        if (r.url.path.endsWith('/carrito')) {
          return jsonRespuesta({'id': 1, 'items': [], 'total': 0});
        }
        return jsonRespuesta(opciones);
      });
      final detalle = CatalogoPrendaDetalle.fromJson({
        'producto_id': 1,
        'categoria_id': 1,
        'nombre': 'Prenda',
        'categoria': 'Ropa',
        'disponibilidad': [
          {
            'sucursal_id': 2,
            'sucursal': 'Centro',
            'ciudad': 'Santa Cruz',
            'variante_id': 1,
          },
        ],
      });
      tester.view.physicalSize = const Size(800, 2200);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);
      final provider = CarritoProvider();
      await tester.pumpWidget(
        ChangeNotifierProvider.value(
          value: provider,
          child: MaterialApp(home: MayoristaScreen(detalle: detalle)),
        ),
      );
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Santa Cruz · Centro').last);
      await tester.pumpAndSettle();
      expect(find.text('Se requieren 3 tallas distintas.'), findsOneWidget);
      await tester.ensureVisible(find.text('Armar Cuarta'));
      await tester.tap(find.text('Armar Cuarta'));
      await tester.pumpAndSettle();
      final cantidades = find.byType(TextFormField);
      await tester.enterText(cantidades.at(0), '1');
      await tester.enterText(cantidades.at(1), '2');
      await tester.pumpAndSettle();
      final agregar = find.text('Agregar paquete al carrito');
      await tester.ensureVisible(agregar);
      await tester.tap(agregar);
      await tester.pumpAndSettle();
      expect(enviado?['tipo'], 'CUARTA');
      expect((enviado?['seleccion'] as List).length, 2);
      expect(
        find.text('Paquete agregado. Puedes combinarlo con unidades normales.'),
        findsOneWidget,
      );
      await tester.pumpWidget(const SizedBox());
      provider.dispose();
    },
  );
}
