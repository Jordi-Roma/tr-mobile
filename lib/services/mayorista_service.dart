import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../core/session/clave_pago.dart';

class VarianteMayorista {
  final int id, stock;
  final String talla, color;
  final double precioBase;
  VarianteMayorista(Map<String, dynamic> j)
    : id = (j['producto_variante_id'] as num).toInt(),
      stock = (j['stock'] as num).toInt(),
      talla = j['talla'].toString(),
      color = j['color'].toString(),
      precioBase = double.tryParse('${j['precio_base']}') ?? 0;
}

class OpcionMayorista {
  final String tipo;
  final int cantidad;
  final double? descuento;
  final bool disponible;
  final String? motivo;
  OpcionMayorista(Map<String, dynamic> j)
    : tipo = j['tipo'].toString(),
      cantidad = (j['cantidad'] as num).toInt(),
      descuento = double.tryParse('${j['descuento']}'),
      disponible = j['disponible'] == true,
      motivo = j['motivo']?.toString();
  String get nombre =>
      {'CUARTA': 'Cuarta', 'MEDIA': 'Media docena', 'DOCENA': 'Docena'}[tipo] ??
      tipo;
  String get regla => tipo == 'CUARTA'
      ? 'Mínimo 2 tallas y 2 colores.'
      : tipo == 'MEDIA'
      ? 'Mínimo 3 tallas y 3 colores.'
      : 'Al menos una prenda de cada talla definida para el modelo; mínimo dos tallas.';
  double precio(double base) =>
      (base * (1 - (descuento ?? 0) / 100) * 100 + 0.00000001).round() / 100;
}

class OpcionesMayorista {
  final List<VarianteMayorista> variantes;
  final List<OpcionMayorista> paquetes;
  OpcionesMayorista(Map<String, dynamic> j)
    : variantes = (j['variantes'] as List)
          .map((v) => VarianteMayorista(v as Map<String, dynamic>))
          .toList(),
      paquetes = (j['paquetes'] as List)
          .map((v) => OpcionMayorista(v as Map<String, dynamic>))
          .toList();
}

class MayoristaService {
  static Future<OpcionesMayorista> opciones(int pid, int sid) async =>
      OpcionesMayorista(
        await ApiClient.get(
          '${ApiConstants.baseUrl}/mayorista/productos/$pid?sucursal_id=$sid',
        ) as Map<String, dynamic>,
      );
  static Future<void> agregar(
    int pid,
    int sid,
    String tipo,
    Map<int, int> seleccion,
  ) async {
    final body = {
      'producto_id': pid,
      'sucursal_id': sid,
      'tipo': tipo,
      'seleccion': seleccion.entries
          .where((e) => e.value > 0)
          .map((e) => {'producto_variante_id': e.key, 'cantidad': e.value})
          .toList(),
    };
    await ApiClient.post(
      '${ApiConstants.baseUrl}/mayorista/paquetes',
      body: await ClavePago.preparar(body, 'paquete-mayorista'),
    );
    await ClavePago.finalizar('paquete-mayorista', 'AGREGADO');
  }
}
