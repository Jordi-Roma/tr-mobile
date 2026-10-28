import 'package:flutter/material.dart';

import '../../providers/catalogo_provider.dart';

class FiltrosCatalogoSheet extends StatefulWidget {
  final CatalogoProvider catalogo;
  const FiltrosCatalogoSheet({super.key, required this.catalogo});
  @override
  State<FiltrosCatalogoSheet> createState() => _FiltrosCatalogoSheetState();
}

class _FiltrosCatalogoSheetState extends State<FiltrosCatalogoSheet> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _min, _max;
  int? _talla, _color, _temporada, _coleccion;
  late String _orden;
  @override
  void initState() {
    super.initState();
    final c = widget.catalogo;
    _talla = c.tallaId;
    _color = c.colorId;
    _temporada = c.temporadaId;
    _coleccion = c.coleccionId;
    _orden = c.orden;
    _min = TextEditingController(text: c.precioMin?.toString() ?? '');
    _max = TextEditingController(text: c.precioMax?.toString() ?? '');
  }

  @override
  void dispose() {
    _min.dispose();
    _max.dispose();
    super.dispose();
  }

  double? _precio(String value) =>
      double.tryParse(value.trim().replaceAll(',', '.'));
  Widget _selector(
    String label,
    int? value,
    List<(int, String)> opciones,
    ValueChanged<int?> cambiar,
  ) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: DropdownButtonFormField<int>(
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: label),
      items: [
        const DropdownMenuItem<int>(value: null, child: Text('Todas')),
        ...opciones.map(
          (o) => DropdownMenuItem(value: o.$1, child: Text(o.$2)),
        ),
      ],
      onChanged: cambiar,
    ),
  );
  @override
  Widget build(BuildContext context) {
    final c = widget.catalogo;
    return SafeArea(
      child: SingleChildScrollView(
        padding: EdgeInsets.fromLTRB(
          24,
          24,
          24,
          24 + MediaQuery.viewInsetsOf(context).bottom,
        ),
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                children: [
                  const Expanded(
                    child: Text(
                      'Filtrar prendas',
                      style: TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                  ),
                  IconButton(
                    onPressed: () => Navigator.pop(context),
                    icon: const Icon(Icons.close),
                    tooltip: 'Cerrar filtros',
                  ),
                ],
              ),
              const SizedBox(height: 16),
              _selector(
                'Talla',
                _talla,
                c.tallas.map((x) => (x.id, x.nombre)).toList(),
                (v) => _talla = v,
              ),
              _selector(
                'Color',
                _color,
                c.colores.map((x) => (x.id, x.nombre)).toList(),
                (v) => _color = v,
              ),
              _selector(
                'Temporada',
                _temporada,
                c.temporadas.map((x) => (x.id, x.nombre)).toList(),
                (v) => _temporada = v,
              ),
              _selector(
                'Colección',
                _coleccion,
                c.colecciones.map((x) => (x.id, x.nombre)).toList(),
                (v) => _coleccion = v,
              ),
              TextFormField(
                controller: _min,
                decoration: const InputDecoration(
                  labelText: 'Precio mínimo (Bs)',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) =>
                    v!.trim().isNotEmpty &&
                        (_precio(v) == null ||
                            !_precio(v)!.isFinite ||
                            _precio(v)! < 0)
                    ? 'Ingresa un precio válido'
                    : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _max,
                decoration: const InputDecoration(
                  labelText: 'Precio máximo (Bs)',
                ),
                keyboardType: const TextInputType.numberWithOptions(
                  decimal: true,
                ),
                validator: (v) {
                  if (v!.trim().isEmpty) return null;
                  final max = _precio(v);
                  final min = _precio(_min.text);
                  if (max == null || !max.isFinite || max < 0) {
                    return 'Ingresa un precio válido';
                  }
                  if (min != null && max < min) {
                    return 'Debe ser mayor o igual al mínimo';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _orden,
                decoration: const InputDecoration(labelText: 'Ordenar por'),
                items: const [
                  DropdownMenuItem(
                    value: 'relevancia',
                    child: Text('Más recientes'),
                  ),
                  DropdownMenuItem(value: 'nombre', child: Text('Nombre')),
                  DropdownMenuItem(
                    value: 'precio-asc',
                    child: Text('Menor precio'),
                  ),
                  DropdownMenuItem(
                    value: 'precio-desc',
                    child: Text('Mayor precio'),
                  ),
                ],
                onChanged: (v) => _orden = v!,
              ),
              const SizedBox(height: 24),
              FilledButton(
                onPressed: () {
                  if (!_form.currentState!.validate()) return;
                  c.aplicarFiltrosAvanzados(
                    talla: _talla,
                    color: _color,
                    temporada: _temporada,
                    coleccion: _coleccion,
                    minimo: _precio(_min.text),
                    maximo: _precio(_max.text),
                    ordenElegido: _orden,
                  );
                  Navigator.pop(context);
                },
                child: const Text('Aplicar filtros'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
