import 'dart:async';
import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:mobile_tr/core/constants/api_constants.dart';
import 'package:mobile_tr/core/network/api_client.dart';
import 'package:mobile_tr/core/network/api_exceptions.dart';
import 'package:mobile_tr/core/session/contexto_sesion.dart';
import 'package:mobile_tr/core/storage/session_storage.dart';
import 'package:mobile_tr/models/auth_models.dart';
import 'package:mobile_tr/models/empresa_models.dart';
import 'package:mobile_tr/providers/auth_provider.dart';

final sesion = ContextoSesion.instance;
final empresaA = EmpresaPublica(
  id: 1,
  codigo: 'tienda-a',
  nombre: 'Tienda A',
  estado: 'ACTIVA',
);
final empresaB = EmpresaPublica(
  id: 2,
  codigo: 'tienda-b',
  nombre: 'Tienda B',
  estado: 'ACTIVA',
);
UsuarioAutenticado usuario([int empresa = 1]) => UsuarioAutenticado(
  id: 10,
  nombre: 'Cliente',
  apellido: 'Prueba',
  username: 'cliente',
  correo: 'cliente@example.invalid',
  roles: ['CLIENTE'],
  empresaId: empresa,
  empresaCodigo: empresa == 1 ? 'tienda-a' : 'tienda-b',
);
String jwt({int empresa = 1, int? expiracion, bool legacy = false}) =>
    'header.${base64Url.encode(utf8.encode(jsonEncode({'sub': '10', 'sid': '50', 'exp': expiracion ?? DateTime.now().millisecondsSinceEpoch ~/ 1000 + 3600, if (!legacy) 'empresa_id': empresa}))).replaceAll('=', '')}.firma';
Map<String, dynamic> perfilJson() => {
  'id': 10,
  'nombre': 'Cliente Nuevo',
  'apellido': 'Prueba',
  'username': 'cliente',
  'correo': 'cliente@example.invalid',
  'roles': ['CLIENTE'],
  'telefono': '70123456',
  'empresa_id': 1,
  'empresa_codigo': 'tienda-a',
  'sesion_revocada': false,
};
Map<String, dynamic> loginJson() => {
  ...perfilJson(),
  'usuario_id': 10,
  'access_token': jwt(),
  'token_type': 'bearer',
};
http.Response jsonRespuesta(Object cuerpo, [int estado = 200]) => http.Response(
  jsonEncode(cuerpo),
  estado,
  headers: {'content-type': 'application/json; charset=utf-8'},
);

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

  test('envía empresa y sesión únicamente a la API configurada', () async {
    await sesion.guardar(jwt(), usuario());
    final h = await ApiClient.headersPara(ApiConstants.perfil);
    expect(h['X-Empresa-Codigo'], 'tienda-a');
    expect(h['Authorization'], 'Bearer ${sesion.token!}');
    for (final url in [
      'https://otra.invalid/api/v1/perfil',
      '${ApiConstants.baseUrl}/empresas/publicas',
    ]) {
      final publicos = await ApiClient.headersPara(url);
      expect(publicos.containsKey('Authorization'), false);
      expect(publicos.containsKey('X-Empresa-Codigo'), false);
    }
    expect(
      (await ApiClient.headersPara(
        ApiConstants.login,
        withAuth: false,
      )).containsKey('Authorization'),
      false,
    );
  });

  test('sin empresa no inventa una tienda ni envía solicitudes', () async {
    await sesion.seleccionar(null);
    var llamadas = 0;
    ApiClient.client = MockClient((_) async {
      llamadas++;
      return jsonRespuesta({});
    });
    await expectLater(
      ApiClient.get(ApiConstants.perfil),
      throwsA(isA<ApiException>()),
    );
    expect(llamadas, 0);
  });

  test('rechaza JWT vencido, sin empresa o de otra empresa', () async {
    expect(ContextoSesion.sesionValida(jwt(expiracion: 1), usuario()), false);
    expect(ContextoSesion.sesionValida(jwt(legacy: true), usuario()), false);
    await expectLater(
      sesion.guardar(jwt(empresa: 2), usuario(2)),
      throwsStateError,
    );
    expect(sesion.token, null);
  });

  test('403 conserva la cuenta y 401 cierra y solicita ingresar', () async {
    await sesion.guardar(jwt(), usuario());
    var estado = 403;
    ApiClient.client = MockClient(
      (_) async => jsonRespuesta({'detail': 'Denegado'}, estado),
    );
    await expectLater(
      ApiClient.get(ApiConstants.perfil),
      throwsA(isA<ApiException>()),
    );
    expect(auth.estaAutenticado, true);
    estado = 401;
    await expectLater(
      ApiClient.get(ApiConstants.perfil),
      throwsA(isA<ApiException>()),
    );
    expect(auth.estaAutenticado, false);
    expect(auth.requiereLogin, true);
    expect(auth.empresa?.codigo, 'tienda-a');
  });

  test('un 401 tardío de A no borra la sesión nueva de B', () async {
    await sesion.guardar(jwt(), usuario());
    final iniciada = Completer<void>(), respuesta = Completer<http.Response>();
    ApiClient.client = MockClient((_) {
      iniciada.complete();
      return respuesta.future;
    });
    final solicitud = ApiClient.get(ApiConstants.perfil);
    final espera = expectLater(solicitud, throwsA(isA<ApiException>()));
    await iniciada.future;
    await sesion.seleccionar(empresaB);
    await sesion.guardar(jwt(empresa: 2), usuario(2));
    respuesta.complete(
      jsonRespuesta({'detail': 'Sesión anterior cerrada'}, 401),
    );
    await espera;
    expect(auth.estaAutenticado, true);
    expect(auth.empresa?.id, 2);
  });

  test(
    'el cierre gana a una escritura pendiente de sesión en almacenamiento',
    () async {
      final guardando = sesion.guardar(jwt(), usuario());
      final cerrando = sesion.cerrar(pedirLogin: true);
      await Future.wait([guardando, cerrando]);
      expect(await SessionStorage.getToken(), null);
      expect(await SessionStorage.getUser(), null);
    },
  );

  test('login incluye la empresa y conserva identidad recibida', () async {
    ApiClient.client = MockClient((r) async {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      expect(body, {
        'identificador': 'cliente',
        'password': 'Clave-123',
        'empresa_codigo': 'tienda-a',
      });
      expect(r.headers.containsKey('Authorization'), false);
      return jsonRespuesta(loginJson());
    });
    expect(await auth.login(' cliente ', 'Clave-123'), true);
    expect(auth.usuario?.empresaId, 1);
    expect((await SessionStorage.getUser())?.empresaCodigo, 'tienda-a');
  });

  test('perfil personal actualiza la cuenta sin cambiar su empresa', () async {
    await sesion.guardar(jwt(), usuario());
    ApiClient.client = MockClient((r) async {
      final body = jsonDecode(r.body) as Map<String, dynamic>;
      expect(body.containsKey('empresa_id'), false);
      expect(body['nombre'], 'Cliente Nuevo');
      return jsonRespuesta(perfilJson());
    });
    expect(
      await auth.actualizarPerfil(
        nombre: 'Cliente Nuevo',
        apellido: 'Prueba',
        telefono: '70123456',
      ),
      true,
    );
    expect(auth.usuario?.nombre, 'Cliente Nuevo');
    expect(auth.usuario?.empresaId, 1);
    expect(auth.estaAutenticado, true);
  });

  test(
    'cambiar identidad envía contraseña actual y obliga un nuevo acceso',
    () async {
      await sesion.guardar(jwt(), usuario());
      ApiClient.client = MockClient((r) async {
        final body = jsonDecode(r.body) as Map<String, dynamic>;
        expect(body['password_actual'], 'Clave-123');
        expect(body['username'], 'nuevo');
        return jsonRespuesta({...perfilJson(), 'sesion_revocada': true});
      });
      expect(
        await auth.actualizarPerfil(
          nombre: 'Cliente',
          apellido: 'Prueba',
          username: 'nuevo',
          passwordActual: 'Clave-123',
        ),
        true,
      );
      expect(auth.estaAutenticado, false);
      expect(auth.requiereLogin, true);
    },
  );

  test(
    'recuperación conserva empresa y confirma el código sin enviar sesión',
    () async {
      final cuerpos = <Map<String, dynamic>>[];
      ApiClient.client = MockClient((r) async {
        expect(r.headers.containsKey('Authorization'), false);
        cuerpos.add(jsonDecode(r.body) as Map<String, dynamic>);
        return jsonRespuesta({
          'mensaje': 'Si la cuenta está disponible, enviaremos un código.',
        });
      });
      expect(await auth.solicitarRecuperacion('cliente'), isNotNull);
      expect(
        await auth.confirmarRecuperacion(
          identificador: 'cliente',
          codigo: '012345',
          password: 'Nueva-123',
          confirmar: 'Nueva-123',
        ),
        true,
      );
      expect(cuerpos.every((b) => b['empresa_codigo'] == 'tienda-a'), true);
      expect(cuerpos.last['codigo'], '012345');
      expect(auth.requiereLogin, true);
    },
  );

  test('cambio de contraseña limpia la sesión al completar', () async {
    await sesion.guardar(jwt(), usuario());
    ApiClient.client = MockClient((r) async {
      expect(r.url.path.endsWith('/perfil/password'), true);
      expect((jsonDecode(r.body) as Map)['password_actual'], 'Actual-123');
      return jsonRespuesta({'mensaje': 'Actualizada'});
    });
    expect(
      await auth.cambiarPassword(
        passwordActual: 'Actual-123',
        nuevoPassword: 'Nueva-123',
        confirmarPasswordNuevo: 'Nueva-123',
      ),
      true,
    );
    expect(auth.estaAutenticado, false);
    expect(await SessionStorage.getToken(), null);
  });

  test(
    'desactivación incluye confirmación y limpia sesión sin cambiar empresa',
    () async {
      await sesion.guardar(jwt(), usuario());
      ApiClient.client = MockClient((r) async {
        expect(jsonDecode(r.body), {
          'password_actual': 'Actual-123',
          'confirmacion': 'DESACTIVAR MI CUENTA',
        });
        return jsonRespuesta({'mensaje': 'Cuenta desactivada'});
      });
      expect(await auth.desactivarCuenta('Actual-123'), true);
      expect(auth.estaAutenticado, false);
      expect(auth.empresa?.codigo, 'tienda-a');
      expect(auth.aviso, contains('historial'));
    },
  );

  test(
    'no restaura una sesión legada sin empresa en una tienda elegida',
    () async {
      await SessionStorage.setEmpresaCodigo('tienda-a');
      await SessionStorage.saveSession(
        token: jwt(legacy: true),
        usuario: usuario(),
      );
      ApiClient.client = MockClient(
        (r) async => jsonRespuesta({
          'id': 1,
          'nombre': 'Tienda A',
          'codigo': 'tienda-a',
          'estado': 'ACTIVA',
        }),
      );
      await auth.inicializar();
      expect(auth.inicializado, true);
      expect(auth.estaAutenticado, false);
      expect(auth.requiereLogin, true);
      expect(await SessionStorage.getToken(), null);
    },
  );
  test(
    'sesión guardada revocada en servidor conserva empresa y pide ingresar',
    () async {
      await SessionStorage.setEmpresaCodigo('tienda-a');
      await SessionStorage.saveSession(token: jwt(), usuario: usuario());
      ApiClient.client = MockClient((r) async {
        if (r.url.path.contains('/empresas/publica/')) {
          return jsonRespuesta({
            'id': 1,
            'nombre': 'Tienda A',
            'codigo': 'tienda-a',
            'estado': 'ACTIVA',
          });
        }
        return jsonRespuesta({'detail': 'La sesión se cerró.'}, 401);
      });
      await auth.inicializar();
      expect(auth.inicializado, true);
      expect(auth.estaAutenticado, false);
      expect(auth.empresa?.codigo, 'tienda-a');
      expect(auth.requiereLogin, true);
      expect(auth.aviso, contains('Inicia sesión'));
      expect(await SessionStorage.getToken(), null);
    },
  );
}
