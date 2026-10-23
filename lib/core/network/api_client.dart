import 'dart:async';
import 'dart:convert';
import 'dart:typed_data';

import 'package:http/http.dart' as http;

import '../constants/api_constants.dart';
import '../session/contexto_sesion.dart';
import 'api_exceptions.dart';

class ApiClient {
  ApiClient._();
  static http.Client client = http.Client();
  static final _contexto = ContextoSesion.instance;

  static bool esApi(Uri uri) {
    final base = Uri.parse(ApiConstants.baseUrl);
    final prefijo = base.path.replaceFirst(RegExp(r'/$'), '');
    return uri.scheme == base.scheme &&
        uri.host == base.host &&
        uri.port == base.port &&
        (uri.path == prefijo || uri.path.startsWith('$prefijo/'));
  }

  static Future<Map<String, String>> headersPara(
    String url, {
    bool withAuth = true,
  }) async {
    final uri = Uri.parse(url);
    final headers = <String, String>{
      'Accept': 'application/json',
      'ngrok-skip-browser-warning': 'true',
    };
    if (!esApi(uri)) return headers;
    if (uri.path.contains('/empresas/public')) return headers;
    if (_contexto.empresa == null) {
      throw ApiException(
        'Selecciona una empresa antes de continuar.',
        statusCode: 400,
      );
    }
    if (_contexto.token != null &&
        (_contexto.usuario == null ||
            !ContextoSesion.sesionValida(
              _contexto.token!,
              _contexto.usuario!,
            ))) {
      unawaited(
        _contexto.cerrar(
          mensaje: 'Tu sesión venció. Inicia sesión nuevamente.',
          pedirLogin: true,
        ),
      );
      throw ApiException('Tu sesión venció.', statusCode: 401);
    }
    if (_contexto.usuario != null &&
        (_contexto.usuario!.empresaId != _contexto.empresa!.id ||
            _contexto.usuario!.empresaCodigo != _contexto.empresa!.codigo)) {
      throw ApiException(
        'La sesión no corresponde a la empresa seleccionada.',
        statusCode: 403,
      );
    }
    headers['X-Empresa-Codigo'] = _contexto.empresa!.codigo;
    if (withAuth && _contexto.token != null) {
      headers['Authorization'] = 'Bearer ${_contexto.token!}';
    }
    return headers;
  }

  static void validarGeneracion(int generacion) {
    if (generacion != _contexto.generacion) {
      throw ApiException(
        'La sesión o empresa cambió. Se descartó la respuesta anterior.',
        statusCode: 409,
      );
    }
  }

  static dynamic procesarRespuesta(
    http.Response response, {
    bool withAuth = true,
    bool propia = true,
  }) {
    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {}
    if (response.statusCode >= 200 && response.statusCode < 300) return decoded;
    if (response.statusCode == 401 &&
        withAuth &&
        propia &&
        _contexto.token != null) {
      unawaited(
        _contexto.cerrar(
          mensaje: 'Tu sesión venció o se cerró. Inicia sesión nuevamente.',
          pedirLogin: true,
        ),
      );
    }
    String mensaje =
        'No se pudo completar la solicitud (${response.statusCode}).';
    if (decoded is Map<String, dynamic>) {
      final detail = decoded['detail'];
      if (detail is String) {
        mensaje = detail;
      } else if (detail is Map && detail['mensaje'] is String) {
        mensaje = detail['mensaje'] as String;
      } else if (detail is List) {
        final errores = detail
            .whereType<Map>()
            .map((e) => e['msg'])
            .whereType<String>()
            .join(' ');
        if (errores.isNotEmpty) mensaje = errores;
      }
    }
    throw ApiException(mensaje, statusCode: response.statusCode, data: decoded);
  }

  static Future<http.Response> _solicitar(
    String metodo,
    String url, {
    dynamic body,
    bool withAuth = true,
  }) async {
    final generacion = _contexto.generacion;
    final uri = Uri.parse(url);
    try {
      final request = http.Request(metodo, uri);
      request.headers.addAll(await headersPara(url, withAuth: withAuth));
      validarGeneracion(generacion);
      if (body != null) {
        request.headers['Content-Type'] = 'application/json';
        request.body = jsonEncode(body);
      }
      final response = await http.Response.fromStream(
        await client.send(request).timeout(const Duration(seconds: 30)),
      ).timeout(const Duration(seconds: 30));
      validarGeneracion(generacion);
      return response;
    } on ApiException {
      rethrow;
    } on TimeoutException {
      throw ApiException('La solicitud tardó demasiado. Inténtalo nuevamente.');
    } catch (_) {
      throw ApiException(
        'No se pudo conectar con el servidor. Revisa tu conexión.',
      );
    }
  }

  static Future<dynamic> _json(
    String metodo,
    String url, {
    dynamic body,
    bool withAuth = true,
  }) async {
    final generacion = _contexto.generacion;
    final response = await _solicitar(
      metodo,
      url,
      body: body,
      withAuth: withAuth,
    );
    validarGeneracion(generacion);
    return procesarRespuesta(
      response,
      withAuth: withAuth,
      propia: esApi(Uri.parse(url)),
    );
  }

  static Future<dynamic> get(
    String url, {
    Map<String, String>? queryParams,
    bool withAuth = true,
  }) {
    if (queryParams != null && queryParams.isNotEmpty) {
      url = Uri.parse(url).replace(queryParameters: queryParams).toString();
    }
    return _json('GET', url, withAuth: withAuth);
  }

  static Future<dynamic> post(
    String url, {
    dynamic body,
    bool withAuth = true,
  }) => _json('POST', url, body: body, withAuth: withAuth);
  static Future<dynamic> put(
    String url, {
    dynamic body,
    bool withAuth = true,
  }) => _json('PUT', url, body: body, withAuth: withAuth);
  static Future<dynamic> patch(
    String url, {
    dynamic body,
    bool withAuth = true,
  }) => _json('PATCH', url, body: body, withAuth: withAuth);
  static Future<dynamic> delete(String url, {bool withAuth = true}) =>
      _json('DELETE', url, withAuth: withAuth);
  static Future<Uint8List> postBytes(
    String url, {
    dynamic body,
    bool withAuth = true,
  }) async {
    final generacion = _contexto.generacion;
    final res = await _solicitar('POST', url, body: body, withAuth: withAuth);
    validarGeneracion(generacion);
    if (res.statusCode >= 200 && res.statusCode < 300) return res.bodyBytes;
    procesarRespuesta(res, withAuth: withAuth, propia: esApi(Uri.parse(url)));
    throw ApiException('No se pudo descargar el archivo.');
  }
}
