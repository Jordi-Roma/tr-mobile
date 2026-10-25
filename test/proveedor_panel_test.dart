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
import 'package:mobile_tr/screens/perfil/proveedor_panel_screen.dart';
import 'package:mobile_tr/services/proveedor_panel_service.dart';

final sesion = ContextoSesion.instance;
final empresa = EmpresaPublica(id: 1, codigo: 'tienda-a', nombre: 'Tienda A', estado: 'ACTIVA');
http.Response respuesta(Object json, [int status = 200]) => http.Response(
  jsonEncode(json), status, headers: {'content-type': 'application/json; charset=utf-8'},
);
Object datos(String path) {
  if (path.endsWith('/perfil')) return {'id': 20, 'nombre': 'Proveedor autorizado', 'activo': true};
  if (path.endsWith('/productos')) return [{'producto_id': 5, 'nombre': 'Prenda propia', 'categoria': 'Ropa', 'material': 'Algodón', 'genero': 'UNISEX', 'activo': true, 'variantes': 1}];
  if (path.endsWith('/stock')) return [{'producto_id': 5, 'producto': 'Prenda propia', 'sku': 'SKU5', 'sucursal': 'Centro', 'stock_disponible': 9, 'stock_reservado': 2, 'stock_real': 7}];
  return [{'id': 1, 'producto': 'Entrega propia', 'sku': 'SKU5', 'sucursal': 'Centro', 'cantidad': 4, 'fecha_movimiento': '2026-10-24T10:00:00Z'}];
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ApiConstants.customHost = 'http://127.0.0.1:58127';
    await sesion.seleccionar(empresa);
    final payload = base64Url.encode(utf8.encode(jsonEncode({
      'sub': '10', 'sid': '50', 'empresa_id': 1,
      'exp': DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600,
    }))).replaceAll('=', '');
    await sesion.guardar('header.$payload.firma', UsuarioAutenticado(
      id: 10, nombre: 'Proveedor', apellido: 'Prueba', username: 'proveedor',
      correo: 'proveedor@example.invalid', roles: ['PROVEEDOR'], empresaId: 1, empresaCodigo: 'tienda-a',
    ));
  });
  tearDown(() async {
    ApiClient.client.close();
    await sesion.seleccionar(null);
  });

  testWidgets('consulta datos autorizados por empresa sin acciones de escritura', (tester) async {
    final llamadas = <String>[];
    ApiClient.client = MockClient((request) async {
      expect(request.method, 'GET');
      expect(request.headers['X-Empresa-Codigo'], 'tienda-a');
      expect(request.headers['Authorization'], startsWith('Bearer '));
      expect(request.url.queryParameters.containsKey('proveedor_id'), isFalse);
      llamadas.add(request.url.path);
      return respuesta(datos(request.url.path));
    });
    await tester.pumpWidget(const MaterialApp(home: ProveedorPanelScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Proveedor autorizado'), findsOneWidget);
    await tester.tap(find.text('Productos')); await tester.pumpAndSettle();
    expect(find.text('Prenda propia'), findsOneWidget);
    await tester.tap(find.text('Stock')); await tester.pumpAndSettle();
    expect(find.text('7'), findsOneWidget);
    await tester.tap(find.text('Entregas')); await tester.pumpAndSettle();
    expect(find.text('Entrega propia'), findsOneWidget);
    expect(llamadas.length, 4);
    expect(find.text('Crear'), findsNothing);
    expect(find.text('Editar'), findsNothing);
  });

  testWidgets('CU10 consulta detalles y existencias del producto sin nuevas escrituras', (tester) async {
    final llamadas = <String>[];
    ApiClient.client = MockClient((request) async {
      expect(request.method, 'GET');
      llamadas.add(request.url.path);
      return respuesta(datos(request.url.path));
    });
    await tester.pumpWidget(const MaterialApp(home: ProveedorPanelScreen()));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Productos')); await tester.pumpAndSettle();
    await tester.tap(find.text('Prenda propia')); await tester.pumpAndSettle();
    expect(find.text('Algodón'), findsOneWidget);
    expect(find.text('UNISEX'), findsOneWidget);
    expect(find.textContaining('SKU5'), findsWidgets);
    expect(find.textContaining('Disponible: 9'), findsOneWidget);
    expect(llamadas.length, 4);
    expect(find.text('Guardar'), findsNothing);
    expect(find.text('Editar'), findsNothing);
  });

  testWidgets('sin vínculo informa el motivo y permite reintentar', (tester) async {
    var autorizado = false;
    ApiClient.client = MockClient((request) async =>
      !autorizado && request.url.path.endsWith('/perfil')
        ? respuesta({'detail': 'Tu usuario no está vinculado a un proveedor activo.'}, 403)
        : respuesta(datos(request.url.path)));
    await tester.pumpWidget(const MaterialApp(home: ProveedorPanelScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Tu usuario no está vinculado a un proveedor activo.'), findsOneWidget);
    expect(find.text('Proveedor autorizado'), findsNothing);
    autorizado = true;
    await tester.tap(find.text('Reintentar')); await tester.pumpAndSettle();
    expect(find.text('Proveedor autorizado'), findsOneWidget);
  });

  test('descarta una respuesta pendiente cuando cambia la empresa', () async {
    final pendiente = Completer<http.Response>();
    final enviada = Completer<void>();
    ApiClient.client = MockClient((request) {
      enviada.complete();
      return pendiente.future;
    });
    final solicitud = ProveedorPanelService.obtenerPerfil();
    final verificacion = expectLater(solicitud, throwsA(isA<Exception>()));
    await enviada.future;
    await sesion.seleccionar(EmpresaPublica(id: 2, codigo: 'tienda-b', nombre: 'Tienda B', estado: 'ACTIVA'));
    pendiente.complete(respuesta(datos('/perfil')));
    await verificacion;
  });

  testWidgets('una recarga rechazada retira los datos previos', (tester) async {
    var autorizado = true;
    ApiClient.client = MockClient((request) async => autorizado
      ? respuesta(datos(request.url.path))
      : respuesta({'detail': 'Vínculo retirado.'}, 403));
    await tester.pumpWidget(const MaterialApp(home: ProveedorPanelScreen()));
    await tester.pumpAndSettle();
    expect(find.text('Proveedor autorizado'), findsOneWidget);
    autorizado = false;
    await tester.tap(find.byTooltip('Actualizar información')); await tester.pumpAndSettle();
    expect(find.text('Proveedor autorizado'), findsNothing);
    expect(find.text('Vínculo retirado.'), findsOneWidget);
  });
}
