import 'package:flutter/material.dart';

class SelectorVarianteCambio extends StatelessWidget {
  const SelectorVarianteCambio({
    super.key,
    required this.opciones,
    required this.seleccion,
    required this.onChanged,
  });
  final List<Map<String, dynamic>> opciones;
  final int? seleccion;
  final ValueChanged<int?> onChanged;
  String _clave(Map<String, dynamic> v) =>
      '${v['producto_id'] ?? v['producto']}';
  @override
  Widget build(BuildContext context) {
    final actual = opciones.where((v) => v['id'] == seleccion).firstOrNull;
    final producto = actual == null ? null : _clave(actual);
    final productos = {for (final v in opciones) _clave(v): '${v['producto']}'};
    final tallas = opciones
        .where((v) => _clave(v) == producto)
        .map((v) => '${v['talla']}')
        .toSet();
    final colores = opciones
        .where((v) => _clave(v) == producto && v['talla'] == actual?['talla'])
        .map((v) => '${v['color']}')
        .toSet();
    Widget elegir(
      String nombre,
      String? valor,
      Iterable<String> valores,
      ValueChanged<String?>? cambio,
    ) => Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: DropdownButtonFormField<String>(
        key: ValueKey((nombre, valor, seleccion)),
        initialValue: valor,
        isExpanded: true,
        decoration: InputDecoration(labelText: nombre),
        items: valores
            .map(
              (v) => DropdownMenuItem(
                value: v,
                child: Text(
                  nombre == 'Producto' ? productos[v]! : v,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
            )
            .toList(),
        onChanged: cambio,
      ),
    );
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        elegir(
          'Producto',
          producto,
          productos.keys,
          (v) => onChanged(
            opciones.where((o) => _clave(o) == v).firstOrNull?['id'] as int?,
          ),
        ),
        elegir(
          'Talla',
          actual?['talla'] as String?,
          tallas,
          actual == null
              ? null
              : (v) => onChanged(
                  opciones
                          .where(
                            (o) => _clave(o) == producto && o['talla'] == v,
                          )
                          .firstOrNull?['id']
                      as int?,
                ),
        ),
        elegir(
          'Color',
          actual?['color'] as String?,
          colores,
          actual == null
              ? null
              : (v) => onChanged(
                  opciones
                          .where(
                            (o) =>
                                _clave(o) == producto &&
                                o['talla'] == actual['talla'] &&
                                o['color'] == v,
                          )
                          .firstOrNull?['id']
                      as int?,
                ),
        ),
        if (actual != null)
          Text(
            'Bs ${actual['precio']} por prenda · ${actual['disponible']} disponibles',
          ),
        if (opciones.isEmpty)
          const Text('Sin variantes disponibles para esta cantidad.'),
      ],
    );
  }
}
