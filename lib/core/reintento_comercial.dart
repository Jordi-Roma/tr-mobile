import 'dart:convert';
import 'dart:math';

/// Conserva una clave por contenido mientras la respuesta sea incierta.
class ReintentoComercial {
  String? _contenido;
  String? _clave;

  String clavePara(Object datos) {
    final contenido = jsonEncode(datos);
    if (_contenido != contenido || _clave == null) {
      final random = Random.secure();
      final bytes = List<int>.generate(16, (_) => random.nextInt(256));
      bytes[6] = (bytes[6] & 15) | 64;
      bytes[8] = (bytes[8] & 63) | 128;
      final hex = bytes.map((b) => b.toRadixString(16).padLeft(2, '0')).join();
      _clave =
          '${hex.substring(0, 8)}-${hex.substring(8, 12)}-${hex.substring(12, 16)}-${hex.substring(16, 20)}-${hex.substring(20)}';
      _contenido = contenido;
    }
    return _clave!;
  }

  void completar() {
    _contenido = null;
    _clave = null;
  }
}
