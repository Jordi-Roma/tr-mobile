import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/testing.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_tr/core/constants/api_constants.dart';
import 'package:mobile_tr/core/network/api_client.dart';
import 'package:mobile_tr/providers/auth_provider.dart';
import 'package:mobile_tr/screens/auth/empresa_screen.dart';
import 'package:mobile_tr/screens/auth/recuperar_password_screen.dart';
import 'package:mobile_tr/screens/perfil/editar_perfil_screen.dart';
import 'package:mobile_tr/screens/perfil/direcciones_screen.dart';
import 'package:mobile_tr/screens/perfil/desactivar_cuenta_screen.dart';

import 'cuenta_test.dart'
    show sesion, empresaA, usuario, jwt, perfilJson, jsonRespuesta;

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late AuthProvider auth;
  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    ApiConstants.customHost = 'http://127.0.0.1:58127';
    await sesion.seleccionar(empresaA);
    auth = AuthProvider();
  });
  tearDown(() async {
    auth.dispose();
    ApiClient.client.close();
    await sesion.seleccionar(null);
  });
  Widget pantalla(Widget pagina) => ChangeNotifierProvider.value(
    value: auth,
    child: MaterialApp(home: pagina),
  );
  Finder campo(String texto) => find.widgetWithText(TextFormField, texto);

  testWidgets('directorio muestra empresas recibidas y busca por nombre', (
    tester,
  ) async {
    await tester.runAsync(() async {
      ApiClient.client = MockClient(
        (r) async => jsonRespuesta([
          {
            'id': 1,
            'nombre': 'Atelier Norte',
            'codigo': 'tienda-a',
            'estado': 'ACTIVA',
          },
          {
            'id': 2,
            'nombre': 'Casa Oliva',
            'codigo': 'tienda-b',
            'estado': 'ACTIVA',
          },
        ]),
      );
      await tester.pumpWidget(pantalla(const EmpresaScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Atelier Norte'), findsOneWidget);
      expect(find.text('Casa Oliva'), findsOneWidget);
      await tester.enterText(find.byType(TextField), 'norte');
      await tester.pump();
      expect(find.text('Casa Oliva'), findsNothing);
      expect(find.text('Atelier Norte'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('perfil carga datos y pide nuevo acceso al cambiar identidad', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await sesion.guardar(jwt(), usuario());
      Map<String, dynamic>? enviado;
      ApiClient.client = MockClient((r) async {
        if (r.method == 'GET') return jsonRespuesta(perfilJson());
        enviado = jsonDecode(r.body) as Map<String, dynamic>;
        return jsonRespuesta({...perfilJson(), 'sesion_revocada': true});
      });
      await tester.pumpWidget(pantalla(const EditarPerfilScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Cliente Nuevo'), findsOneWidget);
      await tester.enterText(campo('Nombre de usuario'), 'nuevo_cliente');
      await tester.ensureVisible(
        campo('Contraseña actual para cambiar usuario o correo'),
      );
      await tester.enterText(
        campo('Contraseña actual para cambiar usuario o correo'),
        'Actual-123',
      );
      await tester.ensureVisible(find.text('Guardar cambios'));
      await tester.tap(find.text('Guardar cambios'));
      await tester.pumpAndSettle();
      expect(enviado?['username'], 'nuevo_cliente');
      expect(enviado?['password_actual'], 'Actual-123');
      expect(auth.requiereLogin, true);
      expect(auth.estaAutenticado, false);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('perfil fallido permite reintentar sin guardar campos vacíos', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await sesion.guardar(jwt(), usuario());
      var fallo = true;
      ApiClient.client = MockClient(
        (r) async => fallo
            ? jsonRespuesta({'detail': 'No se pudo cargar.'}, 503)
            : jsonRespuesta(perfilJson()),
      );
      await tester.pumpWidget(pantalla(const EditarPerfilScreen()));
      await tester.pumpAndSettle();
      expect(find.text('Guardar cambios'), findsNothing);
      expect(find.text('Reintentar'), findsOneWidget);
      fallo = false;
      await tester.tap(find.text('Reintentar'));
      await tester.pumpAndSettle();
      expect(find.text('Cliente Nuevo'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('direcciones permite alta, edición y baja confirmada', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await sesion.guardar(jwt(), usuario());
      final direcciones = <Map<String, dynamic>>[];
      ApiClient.client = MockClient((r) async {
        if (r.url.path.endsWith('/ciudades')) {
          return jsonRespuesta([
            {'id': 1, 'nombre': 'Santa Cruz', 'activo': true},
          ]);
        }
        if (r.method == 'GET') {
          return jsonRespuesta({'direcciones': direcciones});
        }
        if (r.method == 'DELETE') {
          direcciones.clear();
          return jsonRespuesta({'mensaje': 'Desactivada'});
        }
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        direcciones.clear();
        direcciones.add({'id': 1, ...body});
        return jsonRespuesta(direcciones.single);
      });
      await tester.pumpWidget(pantalla(const DireccionesScreen()));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Nueva dirección'));
      await tester.pumpAndSettle();
      await tester.tap(find.byType(DropdownButtonFormField<int>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Santa Cruz').last);
      await tester.pumpAndSettle();
      await tester.enterText(campo('Dirección'), 'Calle Flutter 123');
      await tester.tap(find.text('Dirección principal'));
      await tester.tap(find.text('Guardar dirección'));
      await tester.pumpAndSettle();
      expect(find.text('Calle Flutter 123'), findsOneWidget);
      expect(find.text('Dirección principal'), findsOneWidget);
      await tester.tap(find.text('Editar'));
      await tester.pumpAndSettle();
      await tester.enterText(campo('Dirección'), 'Calle Flutter 456');
      await tester.tap(find.text('Guardar dirección'));
      await tester.pumpAndSettle();
      expect(find.text('Calle Flutter 456'), findsOneWidget);
      await tester.tap(find.text('Desactivar'));
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(FilledButton, 'Desactivar'));
      await tester.pumpAndSettle();
      expect(find.text('No tienes direcciones registradas.'), findsOneWidget);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('recuperación envía código y contraseña con empresa elegida', (
    tester,
  ) async {
    await tester.runAsync(() async {
      final cuerpos = <Map<String, dynamic>>[];
      ApiClient.client = MockClient((r) async {
        cuerpos.add(jsonDecode(r.body) as Map<String, dynamic>);
        return jsonRespuesta({
          'mensaje': 'Si la cuenta está disponible, enviaremos un código.',
        });
      });
      await tester.pumpWidget(pantalla(const RecuperarPasswordScreen()));
      await tester.enterText(campo('Usuario o correo'), 'cliente');
      await tester.tap(find.text('Solicitar código'));
      await tester.pumpAndSettle();
      await tester.enterText(campo('Código de seis dígitos'), '012345');
      await tester.enterText(campo('Nueva contraseña'), 'Nueva-segura-123');
      await tester.ensureVisible(campo('Confirmar nueva contraseña'));
      await tester.enterText(
        campo('Confirmar nueva contraseña'),
        'Nueva-segura-123',
      );
      await tester.ensureVisible(find.text('Restablecer contraseña'));
      await tester.tap(find.text('Restablecer contraseña'));
      await tester.pumpAndSettle();
      expect(cuerpos.last['codigo'], '012345');
      expect(cuerpos.last['empresa_codigo'], 'tienda-a');
      expect(auth.requiereLogin, true);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });

  testWidgets('desactivar requiere contraseña y confirmación explícita', (
    tester,
  ) async {
    await tester.runAsync(() async {
      await sesion.guardar(jwt(), usuario());
      Map<String, dynamic>? enviado;
      ApiClient.client = MockClient((r) async {
        enviado = jsonDecode(r.body) as Map<String, dynamic>;
        return jsonRespuesta({'mensaje': 'Desactivada'});
      });
      await tester.pumpWidget(pantalla(const DesactivarCuentaScreen()));
      final boton = find.widgetWithText(
        FilledButton,
        'Confirmar desactivación de mi cuenta',
      );
      expect(tester.widget<FilledButton>(boton).onPressed, null);
      await tester.enterText(find.byType(TextField), 'Actual-123');
      await tester.tap(find.byType(CheckboxListTile));
      await tester.pump();
      await tester.ensureVisible(boton);
      await tester.tap(boton);
      await tester.pumpAndSettle();
      expect(enviado?['confirmacion'], 'DESACTIVAR MI CUENTA');
      expect(auth.estaAutenticado, false);
      expect(auth.aviso, contains('historial'));
      await tester.pumpWidget(const SizedBox.shrink());
    });
  });
}
