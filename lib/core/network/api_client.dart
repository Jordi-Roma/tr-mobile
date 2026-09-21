import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import '../storage/session_storage.dart';
import 'api_exceptions.dart';

class ApiClient {
  ApiClient._();

  static Future<Map<String, String>> _headers({bool withAuth = true}) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
      'Bypass-Tunnel-Reminder': 'true',
      'ngrok-skip-browser-warning': 'true',
    };

    if (withAuth) {
      final token = await SessionStorage.getToken();
      if (token != null && token.isNotEmpty) {
        headers['Authorization'] = 'Bearer $token';
      }
    }

    return headers;
  }

  static dynamic _processResponse(http.Response response) {
    dynamic decoded;
    try {
      decoded = jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      decoded = null;
    }

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return decoded;
    }

    // Manejo de errores de FastAPI (detail como string o como lista de validación)
    String errorMessage = 'Ocurrió un error en el servidor (${response.statusCode})';
    if (decoded is Map<String, dynamic> && decoded.containsKey('detail')) {
      final detail = decoded['detail'];
      if (detail is String) {
        errorMessage = detail;
      } else if (detail is List && detail.isNotEmpty) {
        final first = detail.first;
        if (first is Map && first.containsKey('msg')) {
          errorMessage = first['msg'].toString();
        }
      }
    }

    throw ApiException(
      errorMessage,
      statusCode: response.statusCode,
      data: decoded,
    );
  }

  static Future<dynamic> get(String url, {Map<String, String>? queryParams, bool withAuth = true}) async {
    try {
      var uri = Uri.parse(url);
      if (queryParams != null && queryParams.isNotEmpty) {
        uri = uri.replace(queryParameters: queryParams);
      }
      final headers = await _headers(withAuth: withAuth);
      final response = await http.get(uri, headers: headers);
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error de conexión con el servidor: $e');
    }
  }

  static Future<dynamic> post(String url, {dynamic body, bool withAuth = true}) async {
    try {
      final uri = Uri.parse(url);
      final headers = await _headers(withAuth: withAuth);
      final encodedBody = body != null ? jsonEncode(body) : null;
      final response = await http.post(uri, headers: headers, body: encodedBody);
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error de conexión con el servidor: $e');
    }
  }

  static Future<dynamic> put(String url, {dynamic body, bool withAuth = true}) async {
    try {
      final uri = Uri.parse(url);
      final headers = await _headers(withAuth: withAuth);
      final encodedBody = body != null ? jsonEncode(body) : null;
      final response = await http.put(uri, headers: headers, body: encodedBody);
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error de conexión con el servidor: $e');
    }
  }

  static Future<dynamic> patch(String url, {dynamic body, bool withAuth = true}) async {
    try {
      final uri = Uri.parse(url);
      final headers = await _headers(withAuth: withAuth);
      final encodedBody = body != null ? jsonEncode(body) : null;
      final response = await http.patch(uri, headers: headers, body: encodedBody);
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error de conexión con el servidor: $e');
    }
  }

  static Future<dynamic> delete(String url, {bool withAuth = true}) async {
    try {
      final uri = Uri.parse(url);
      final headers = await _headers(withAuth: withAuth);
      final response = await http.delete(uri, headers: headers);
      return _processResponse(response);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error de conexión con el servidor: $e');
    }
  }

  /// Realiza un POST y retorna el cuerpo de la respuesta como bytes crudos.
  /// Usado para descarga de archivos (PDF, Excel).
  static Future<Uint8List> postBytes(String url, {dynamic body, bool withAuth = true}) async {
    try {
      final uri = Uri.parse(url);
      final headers = await _headers(withAuth: withAuth);
      final encodedBody = body != null ? jsonEncode(body) : null;
      final response = await http.post(uri, headers: headers, body: encodedBody);

      if (response.statusCode >= 200 && response.statusCode < 300) {
        return response.bodyBytes;
      }

      dynamic decoded;
      try {
        decoded = jsonDecode(utf8.decode(response.bodyBytes));
      } catch (_) {
        decoded = null;
      }
      String errorMessage = 'Error al descargar archivo (${response.statusCode})';
      if (decoded is Map<String, dynamic> && decoded.containsKey('detail')) {
        final detail = decoded['detail'];
        if (detail is String) errorMessage = detail;
      }
      throw ApiException(errorMessage, statusCode: response.statusCode, data: decoded);
    } catch (e) {
      if (e is ApiException) rethrow;
      throw ApiException('Error de conexión con el servidor: $e');
    }
  }
}
