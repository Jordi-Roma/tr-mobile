import 'package:flutter/material.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exceptions.dart';

class DireccionesScreen extends StatefulWidget {
  const DireccionesScreen({super.key});
  @override
  State<DireccionesScreen> createState() => _DireccionesScreenState();
}

class _DireccionesScreenState extends State<DireccionesScreen> {
  List<Map<String, dynamic>> _direcciones = [], _ciudades = [];
  bool _ocupado = true;
  String? _error;
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final res = await Future.wait([
        ApiClient.get(ApiConstants.perfilDirecciones),
        ApiClient.get('${ApiConstants.baseUrl}/ciudades'),
      ]);
      if (!mounted) return;
      setState(() {
        _direcciones = ((res[0] as Map<String, dynamic>)['direcciones'] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .toList();
        _ciudades = (res[1] as List)
            .map((e) => Map<String, dynamic>.from(e as Map))
            .where((e) => e['activo'] == true)
            .toList();
      });
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'No se pudieron cargar las direcciones.',
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _editar([Map<String, dynamic>? direccion]) async {
    final datos = await showDialog<Map<String, dynamic>>(
      context: context,
      builder: (_) =>
          _DireccionDialog(ciudades: _ciudades, direccion: direccion),
    );
    if (datos == null || !mounted) return;
    await _operar(() async {
      if (direccion == null) {
        await ApiClient.post(ApiConstants.perfilDirecciones, body: datos);
      } else {
        await ApiClient.put(
          '${ApiConstants.perfilDirecciones}/${direccion['id']}',
          body: datos,
        );
      }
    });
  }

  Future<void> _eliminar(Map<String, dynamic> direccion) async {
    final confirma = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Desactivar dirección'),
        content: Text(direccion['direccion'] as String),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Desactivar'),
          ),
        ],
      ),
    );
    if (confirma == true) {
      await _operar(
        () => ApiClient.delete(
          '${ApiConstants.perfilDirecciones}/${direccion['id']}',
        ),
      );
    }
  }

  Future<void> _operar(Future<dynamic> Function() operacion) async {
    if (!mounted) return;
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      await operacion();
      if (mounted) await _cargar();
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'No se pudo guardar la dirección.',
        );
      }
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Mis direcciones')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _ocupado ? null : _editar,
        icon: const Icon(Icons.add),
        label: const Text('Nueva dirección'),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
          children: [
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              TextButton(
                onPressed: _ocupado ? null : _cargar,
                child: const Text('Volver a intentar'),
              ),
            ],
            if (_ocupado) const Center(child: CircularProgressIndicator()),
            if (!_ocupado && _direcciones.isEmpty)
              const Text('No tienes direcciones registradas.'),
            ..._direcciones.map((d) {
              final nombreCiudad =
                  _ciudades
                      .where((c) => c['id'] == d['ciudad_id'])
                      .firstOrNull?['nombre'] ??
                  'Ciudad registrada';
              return Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        d['direccion'] as String,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(nombreCiudad.toString()),
                      if (d['referencia'] != null)
                        Text(d['referencia'] as String),
                      if (d['es_principal'] == true)
                        const Text('Dirección principal'),
                      Row(
                        children: [
                          TextButton(
                            onPressed: _ocupado ? null : () => _editar(d),
                            child: const Text('Editar'),
                          ),
                          TextButton(
                            onPressed: _ocupado ? null : () => _eliminar(d),
                            child: const Text('Desactivar'),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              );
            }),
          ],
        ),
      ),
    );
  }
}

class _DireccionDialog extends StatefulWidget {
  final List<Map<String, dynamic>> ciudades;
  final Map<String, dynamic>? direccion;
  const _DireccionDialog({required this.ciudades, this.direccion});
  @override
  State<_DireccionDialog> createState() => _DireccionDialogState();
}

class _DireccionDialogState extends State<_DireccionDialog> {
  final _form = GlobalKey<FormState>();
  late final TextEditingController _direccion, _referencia;
  int? _ciudad;
  bool _principal = false;
  @override
  void initState() {
    super.initState();
    _direccion = TextEditingController(
      text: widget.direccion?['direccion'] as String?,
    );
    _referencia = TextEditingController(
      text: widget.direccion?['referencia'] as String?,
    );
    final ciudad = widget.direccion?['ciudad_id'];
    if (widget.ciudades.any((c) => c['id'] == ciudad)) _ciudad = ciudad as int?;
    _principal = widget.direccion?['es_principal'] == true;
  }

  @override
  void dispose() {
    _direccion.dispose();
    _referencia.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(
        widget.direccion == null ? 'Nueva dirección' : 'Editar dirección',
      ),
      content: SingleChildScrollView(
        child: Form(
          key: _form,
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              DropdownButtonFormField<int>(
                initialValue: _ciudad,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Ciudad'),
                items: widget.ciudades
                    .map(
                      (c) => DropdownMenuItem<int>(
                        value: (c['id'] as num).toInt(),
                        child: Text(c['nombre'] as String),
                      ),
                    )
                    .toList(),
                onChanged: (v) => setState(() => _ciudad = v),
                validator: (v) => v == null ? 'Selecciona una ciudad.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _direccion,
                decoration: const InputDecoration(labelText: 'Dirección'),
                validator: (v) =>
                    (v ?? '').trim().isEmpty ? 'Ingresa una dirección.' : null,
              ),
              const SizedBox(height: 16),
              TextFormField(
                controller: _referencia,
                decoration: const InputDecoration(
                  labelText: 'Referencia (opcional)',
                ),
              ),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Dirección principal'),
                value: _principal,
                onChanged: (v) => setState(() => _principal = v),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: () {
            if (_form.currentState!.validate()) {
              Navigator.pop(context, {
                'ciudad_id': _ciudad,
                'direccion': _direccion.text.trim(),
                'referencia': _referencia.text.trim().isEmpty
                    ? null
                    : _referencia.text.trim(),
                'es_principal': _principal,
              });
            }
          },
          child: const Text('Guardar dirección'),
        ),
      ],
    );
  }
}
