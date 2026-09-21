import 'dart:convert';
import 'dart:io';
import 'package:http/http.dart' as http;
import '../../../core/constants/api_constants.dart';
import '../../../core/network/api_client.dart';
import '../models/prenda_ar.dart';

class VestidorApiService {
  VestidorApiService._();

  static Future<PrendaAR> obtenerPrendaAR(int productoId) async {
    final response = await ApiClient.get(
      ApiConstants.vestidorPrenda(productoId),
      withAuth: false,
    );
    return PrendaAR.fromJson(response as Map<String, dynamic>);
  }

  static Future<List<Map<String, dynamic>>> listarPrendasDisponibles({int limite = 30}) async {
    final response = await ApiClient.get(
      ApiConstants.vestidorPrendasDisponibles,
      queryParams: {'limite': '$limite'},
      withAuth: false,
    );
    if (response is List) {
      return response.cast<Map<String, dynamic>>();
    }
    return [];
  }

  static Future<Map<String, dynamic>?> registrarSesion({
    int? clienteId,
    required int productoId,
    int? varianteId,
    String origen = 'MOVIL_AR',
  }) async {
    try {
      final response = await ApiClient.post(
        ApiConstants.vestidorSesion,
        body: {
          'cliente_id': clienteId,
          'producto_id': productoId,
          'variante_id': varianteId,
          'origen': origen,
        },
        withAuth: true,
      );
      return response as Map<String, dynamic>?;
    } catch (_) {
      // Si falla el registro de telemetría, no interrumpimos la experiencia visual del usuario
      return null;
    }
  }

  static Future<Map<String, dynamic>> probarPrendaConIA({
    required File imagen,
    required int productoId,
    String? talla,
    String? color,
    int? clienteId,
  }) async {
    final uri = Uri.parse(ApiConstants.vestidorProbarIa);
    final request = http.MultipartRequest('POST', uri);

    request.headers['Accept'] = 'application/json';
    request.fields['producto_id'] = productoId.toString();
    if (talla != null) request.fields['talla'] = talla;
    if (color != null) request.fields['color'] = color;
    if (clienteId != null) request.fields['cliente_id'] = clienteId.toString();

    request.files.add(await http.MultipartFile.fromPath('imagen', imagen.path));

    final streamedResponse = await request.send().timeout(
      const Duration(seconds: 90),
      onTimeout: () => throw Exception('El servidor de IA demoró más de lo esperado. Intenta nuevamente.'),
    );
    final response = await http.Response.fromStream(streamedResponse);

    if (response.statusCode >= 200 && response.statusCode < 300) {
      return jsonDecode(response.body) as Map<String, dynamic>;
    } else {
      throw Exception('Error al procesar prueba virtual con IA (${response.statusCode})');
    }
  }
}

