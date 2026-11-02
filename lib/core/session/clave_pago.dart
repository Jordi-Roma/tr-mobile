import 'dart:convert';
import 'dart:math';

import 'package:shared_preferences/shared_preferences.dart';

import '../session/contexto_sesion.dart';
import '../network/api_client.dart';

String nuevoIdentificador() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 15) | 64;
  bytes[8] = (bytes[8] & 63) | 128;
  final h = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
  return '${h.substring(0, 8)}-${h.substring(8, 12)}-${h.substring(12, 16)}-${h.substring(16, 20)}-${h.substring(20)}';
}

class ClavePago {
  static final _memoria = <String, Map<String, String>>{};
  static String _espacio(String medio) {
    final c = ContextoSesion.instance;
    return 'stylear_pago:${c.empresa?.id}:${c.usuario?.id}:$medio';
  }

  static Future<Map<String, dynamic>> preparar(
    Map<String, dynamic> body,
    String medio,
  ) async {
    final generacion = ContextoSesion.instance.generacion;
    final espacio = _espacio(medio);
    final huella = jsonEncode(body);
    final prefs = await SharedPreferences.getInstance();
    ApiClient.validarGeneracion(generacion);
    Map<String, String>? previo = _memoria[espacio];
    try {
      final datos = jsonDecode(prefs.getString(espacio) ?? 'null');
      if (datos is Map && datos['huella'] is String && datos['clave'] is String) {
        previo = {
          'huella': datos['huella'] as String,
          'clave': datos['clave'] as String,
        };
      }
    } catch (_) {
      /* Mantener la clave en memoria si la copia local está dañada. */
    }
    final actual = previo?['huella'] == huella
        ? previo!
        : {'huella': huella, 'clave': nuevoIdentificador()};
    _memoria[espacio] = actual;
    await prefs.setString(espacio, jsonEncode(actual));
    ApiClient.validarGeneracion(generacion);
    return {...body, 'clave_operacion': actual['clave']};
  }

  static Future<void> finalizar(String medio, String estado) async {
    if (estado == 'PENDIENTE') return;
    final espacio = _espacio(medio);
    _memoria.remove(espacio);
    await (await SharedPreferences.getInstance()).remove(espacio);
  }
}
