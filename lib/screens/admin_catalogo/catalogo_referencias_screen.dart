import 'package:flutter/material.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';

class CatalogoReferenciasScreen extends StatefulWidget {
  const CatalogoReferenciasScreen({
    super.key,
    required this.recurso,
    required this.titulo,
  });
  final String recurso, titulo;
  @override
  State<CatalogoReferenciasScreen> createState() =>
      _CatalogoReferenciasScreenState();
}

class _CatalogoReferenciasScreenState extends State<CatalogoReferenciasScreen> {
  List<Map<String, dynamic>> _filas = [];
  bool _cargando = true;
  String? _error;
  String get _url => '${ApiConstants.baseUrl}/${widget.recurso}';
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final r = (await ApiClient.get(_url) as List)
          .cast<Map<String, dynamic>>();
      if (mounted) setState(() => _filas = r);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  Future<void> _editar([Map<String, dynamic>? fila]) async {
    final guardado = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => _ReferenciaForm(
          recurso: widget.recurso,
          titulo: widget.titulo,
          fila: fila,
        ),
      ),
    );
    if (guardado == true && mounted) _cargar();
  }

  Future<void> _estado(Map<String, dynamic> fila) async {
    if (_cargando) return;
    setState(() => _cargando = true);
    try {
      await ApiClient.patch(
        '$_url/${fila['id']}/${fila['activo'] == true ? 'desactivar' : 'activar'}',
      );
      if (mounted) await _cargar();
    } catch (e) {
      if (mounted) {
        setState(() {
          _error = '$e';
          _cargando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.titulo),
      actions: [
        IconButton(
          onPressed: _cargando ? null : _cargar,
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualizar',
        ),
      ],
    ),
    floatingActionButton: FloatingActionButton.extended(
      onPressed: _cargando ? null : () => _editar(),
      icon: const Icon(Icons.add),
      label: const Text('Nuevo'),
    ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        if (_cargando) const LinearProgressIndicator(),
        if (_error != null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (!_cargando && _filas.isEmpty) const Text('No hay registros.'),
        for (final f in _filas)
          Card(
            child: ListTile(
              title: Text('${f['nombre']}'),
              subtitle: Text(
                '${f['activo'] == true ? 'Activo' : 'Inactivo'}${f['anio'] != null ? ' · ${f['anio']}' : ''}${f['valor'] != null ? ' · ${f['tipo_descuento']}: ${f['valor']}' : ''}',
              ),
              trailing: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  IconButton(
                    onPressed: _cargando ? null : () => _editar(f),
                    icon: const Icon(Icons.edit_outlined),
                    tooltip: 'Editar ${f['nombre']}',
                  ),
                  IconButton(
                    onPressed: _cargando ? null : () => _estado(f),
                    icon: Icon(
                      f['activo'] == true ? Icons.toggle_on : Icons.toggle_off,
                    ),
                    tooltip: f['activo'] == true ? 'Desactivar' : 'Activar',
                  ),
                ],
              ),
            ),
          ),
      ],
    ),
  );
}

class _ReferenciaForm extends StatefulWidget {
  const _ReferenciaForm({
    required this.recurso,
    required this.titulo,
    this.fila,
  });
  final String recurso, titulo;
  final Map<String, dynamic>? fila;
  @override
  State<_ReferenciaForm> createState() => _ReferenciaFormState();
}

class _ReferenciaFormState extends State<_ReferenciaForm> {
  final _nombre = TextEditingController(),
      _descripcion = TextEditingController(),
      _anio = TextEditingController(),
      _valor = TextEditingController();
  final _form = GlobalKey<FormState>();
  bool _ocupado = true, _referenciasListas = false;
  String? _error;
  String _tipo = 'PORCENTAJE';
  String? _inicio, _fin;
  int? _temporada;
  List<Map<String, dynamic>> _temporadas = [],
      _productos = [],
      _sucursales = [];
  Set<int> _seleccion = {}, _sucursalesSeleccion = {};
  bool get _promo => widget.recurso == 'promociones';
  @override
  void initState() {
    super.initState();
    final f = widget.fila ?? {};
    _nombre.text = '${f['nombre'] ?? ''}';
    _descripcion.text = '${f['descripcion'] ?? ''}';
    _anio.text = '${f['anio'] ?? DateTime.now().year}';
    _valor.text = '${f['valor'] ?? ''}';
    _temporada = f['temporada_id'] as int?;
    _tipo = '${f['tipo_descuento'] ?? 'PORCENTAJE'}';
    _inicio = f['fecha_inicio'] as String?;
    _fin = f['fecha_fin'] as String?;
    _seleccion = ((f['productos'] as List?) ?? [])
        .map((p) => p['id'] as int)
        .toSet();
    _sucursalesSeleccion = ((f['sucursales'] as List?) ?? [])
        .map((p) => p['id'] as int)
        .toSet();
    _cargar();
  }

  @override
  void dispose() {
    for (final c in [_nombre, _descripcion, _anio, _valor]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    try {
      if (widget.recurso == 'colecciones') {
        _temporadas = (await ApiClient.get(
          '${ApiConstants.baseUrl}/temporadas',
        ) as List).cast<Map<String, dynamic>>();
      }
      if (_promo) {
        _productos = (await ApiClient.get(
          '${ApiConstants.baseUrl}/productos',
        ) as List).cast<Map<String, dynamic>>();
        _sucursales = (await ApiClient.get(
          '${ApiConstants.baseUrl}/sucursales',
        ) as List).cast<Map<String, dynamic>>();
      }
      _referenciasListas = true;
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _fecha(bool inicio) async {
    final d = await showDatePicker(
      context: context,
      initialDate:
          DateTime.tryParse((inicio ? _inicio : _fin) ?? '') ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime(2200),
    );
    if (d != null && mounted) {
      setState(() {
        final texto = d.toIso8601String().substring(0, 10);
        if (inicio) {
          _inicio = texto;
        } else {
          _fin = texto;
        }
      });
    }
  }

  Future<void> _guardar() async {
    if (_ocupado ||
        !_referenciasListas ||
        !(_form.currentState?.validate() ?? false)) {
      return;
    }
    if (widget.recurso == 'colecciones' && _temporada == null) {
      setState(() => _error = 'Selecciona una temporada.');
      return;
    }
    if (_promo &&
        (_inicio == null ||
            _fin == null ||
            _seleccion.isEmpty ||
            _fin!.compareTo(_inicio!) < 0)) {
      setState(() => _error = 'Selecciona productos y un período válido.');
      return;
    }
    final body = <String, dynamic>{'nombre': _nombre.text.trim()};
    if (widget.recurso == 'temporadas') {
      body['anio'] = int.parse(_anio.text);
    } else {
      body['descripcion'] = _descripcion.text.trim();
    }
    if (widget.recurso == 'colecciones') body['temporada_id'] = _temporada;
    if (_promo) {
      body.addAll({
        'tipo_descuento': _tipo,
        'valor': _valor.text.trim(),
        'fecha_inicio': _inicio,
        'fecha_fin': _fin,
        'producto_ids': _seleccion.toList(),
        'sucursal_ids': _sucursalesSeleccion.toList(),
      });
    }
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final url = '${ApiConstants.baseUrl}/${widget.recurso}';
      if (widget.fila == null) {
        await ApiClient.post(url, body: body);
      } else {
        await ApiClient.put('$url/${widget.fila!['id']}', body: body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        '${widget.fila == null ? 'Crear' : 'Editar'} · ${widget.titulo}',
      ),
    ),
    body: Form(
      key: _form,
      child: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          if (_ocupado) const LinearProgressIndicator(),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          TextFormField(
            controller: _nombre,
            enabled: !_ocupado,
            maxLength: _promo
                ? 180
                : (widget.recurso == 'colecciones' ? 150 : 120),
            decoration: const InputDecoration(labelText: 'Nombre'),
            validator: (v) =>
                (v ?? '').trim().isEmpty ? 'Escribe un nombre.' : null,
          ),
          if (widget.recurso == 'temporadas')
            TextFormField(
              controller: _anio,
              enabled: !_ocupado,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Año'),
              validator: (v) {
                final n = int.tryParse(v ?? '');
                return n == null || n < 2000 || n > 2200
                    ? 'Indica un año entre 2000 y 2200.'
                    : null;
              },
            )
          else
            TextFormField(
              controller: _descripcion,
              enabled: !_ocupado,
              maxLength: _promo ? 10000 : 255,
              decoration: const InputDecoration(labelText: 'Descripción'),
            ),
          if (widget.recurso == 'colecciones')
            DropdownButtonFormField<int>(
              initialValue: _temporadas.any((v) => v['id'] == _temporada)
                  ? _temporada
                  : null,
              key: ValueKey(_temporadas.length),
              decoration: const InputDecoration(labelText: 'Temporada'),
              items: _temporadas
                  .map(
                    (v) => DropdownMenuItem(
                      value: v['id'] as int,
                      child: Text('${v['nombre']} · ${v['anio']}'),
                    ),
                  )
                  .toList(),
              onChanged: _ocupado
                  ? null
                  : (v) => setState(() => _temporada = v),
            ),
          if (_promo) ...[
            DropdownButtonFormField<String>(
              initialValue: _tipo,
              decoration: const InputDecoration(labelText: 'Tipo de descuento'),
              items: const [
                DropdownMenuItem(
                  value: 'PORCENTAJE',
                  child: Text('Porcentaje'),
                ),
                DropdownMenuItem(
                  value: 'MONTO_FIJO',
                  child: Text('Monto fijo'),
                ),
              ],
              onChanged: _ocupado ? null : (v) => setState(() => _tipo = v!),
            ),
            TextFormField(
              controller: _valor,
              enabled: !_ocupado,
              keyboardType: const TextInputType.numberWithOptions(
                decimal: true,
              ),
              decoration: const InputDecoration(
                labelText: 'Valor del descuento',
              ),
              validator: (v) {
                final n = double.tryParse(v ?? '');
                return n == null ||
                        !n.isFinite ||
                        n < 0 ||
                        (_tipo == 'PORCENTAJE' && (n <= 0 || n > 100))
                    ? 'Indica un descuento válido.'
                    : null;
              },
            ),
            OutlinedButton(
              onPressed: _ocupado ? null : () => _fecha(true),
              child: Text('Inicio: ${_inicio ?? 'Seleccionar fecha'}'),
            ),
            OutlinedButton(
              onPressed: _ocupado ? null : () => _fecha(false),
              child: Text('Fin: ${_fin ?? 'Seleccionar fecha'}'),
            ),
            const Text('Productos de la promoción'),
            for (final p in _productos)
              CheckboxListTile(
                title: Text('${p['nombre']}'),
                value: _seleccion.contains(p['id']),
                onChanged: _ocupado
                    ? null
                    : (v) => setState(() {
                        if (v == true) {
                          _seleccion.add(p['id'] as int);
                        } else {
                          _seleccion.remove(p['id']);
                        }
                      }),
              ),
            const Text('Sucursales (sin selección: todas)'),
            for (final p in _sucursales)
              CheckboxListTile(
                title: Text('${p['nombre']}'),
                value: _sucursalesSeleccion.contains(p['id']),
                onChanged: _ocupado
                    ? null
                    : (v) => setState(() {
                        if (v == true) {
                          _sucursalesSeleccion.add(p['id'] as int);
                        } else {
                          _sucursalesSeleccion.remove(p['id']);
                        }
                      }),
              ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _ocupado || !_referenciasListas ? null : _guardar,
            child: const Text('Guardar'),
          ),
        ],
      ),
    ),
  );
}
