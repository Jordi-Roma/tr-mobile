import 'package:flutter/material.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';

class ConfiguracionComercialScreen extends StatefulWidget {
  const ConfiguracionComercialScreen({super.key, this.politicas = false});
  final bool politicas;
  @override
  State<ConfiguracionComercialScreen> createState() =>
      _ConfiguracionComercialScreenState();
}

class _ConfiguracionComercialScreenState
    extends State<ConfiguracionComercialScreen> {
  final _titular = TextEditingController();
  final _plazoCambios = TextEditingController(),
      _plazoDevoluciones = TextEditingController();
  final _condicionesCambios = TextEditingController(),
      _condicionesDevoluciones = TextEditingController();
  Map<String, dynamic>? _datos;
  String? _error;
  bool _ocupado = true, _primero = false, _segundo = false;
  String get _url =>
      '${ApiConstants.baseUrl}/${widget.politicas ? 'posventa/politica' : 'pagos-empresa/configuracion'}';
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    for (final c in [
      _titular,
      _plazoCambios,
      _plazoDevoluciones,
      _condicionesCambios,
      _condicionesDevoluciones,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _cargar() async {
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final d = await ApiClient.get(_url) as Map<String, dynamic>;
      if (!mounted) return;
      setState(() {
        _datos = d;
        _primero =
            d[widget.politicas ? 'cambios_habilitados' : 'stripe_habilitado'] ==
            true;
        _segundo =
            d[widget.politicas
                ? 'devoluciones_habilitadas'
                : 'qr_habilitado'] ==
            true;
        _titular.text = '${d['titular'] ?? ''}';
        _plazoCambios.text = '${d['plazo_cambios'] ?? ''}';
        _plazoDevoluciones.text = '${d['plazo_devoluciones'] ?? ''}';
        _condicionesCambios.text = '${d['condiciones_cambios'] ?? ''}';
        _condicionesDevoluciones.text =
            '${d['condiciones_devoluciones'] ?? ''}';
      });
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Future<void> _guardar() async {
    if (_ocupado || _datos == null) return;
    final cambios = int.tryParse(_plazoCambios.text),
        devoluciones = int.tryParse(_plazoDevoluciones.text);
    if (widget.politicas &&
        ((_primero &&
                (cambios == null ||
                    cambios < 1 ||
                    cambios > 365 ||
                    _condicionesCambios.text.trim().length < 5)) ||
            (_segundo &&
                (devoluciones == null ||
                    devoluciones < 1 ||
                    devoluciones > 365 ||
                    _condicionesDevoluciones.text.trim().length < 5)))) {
      setState(
        () => _error = 'Indica plazo entre 1 y 365 días y condiciones para cada política habilitada.',
      );
      return;
    }
    final body = <String, dynamic>{'version': _datos!['version'] ?? 0};
    if (widget.politicas) {
      body.addAll({
        'cambios_habilitados': _primero,
        'devoluciones_habilitadas': _segundo,
        'plazo_cambios': cambios,
        'plazo_devoluciones': devoluciones,
        'condiciones_cambios': _condicionesCambios.text.trim(),
        'condiciones_devoluciones': _condicionesDevoluciones.text.trim(),
      });
    } else {
      body.addAll({
        'stripe_habilitado': _primero,
        'qr_habilitado': _segundo,
        'titular': _titular.text.trim(),
      });
    }
    setState(() {
      _ocupado = true;
      _error = null;
    });
    try {
      final d = await ApiClient.put(_url, body: body) as Map<String, dynamic>;
      if (mounted) {
        setState(() => _datos = d);
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Configuración guardada.')),
        );
      }
    } catch (e) {
      if (mounted) setState(() => _error = '$e');
    } finally {
      if (mounted) setState(() => _ocupado = false);
    }
  }

  Widget _campo(
    TextEditingController c,
    String nombre, {
    bool numero = false,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 14),
    child: TextField(
      controller: c,
      enabled: !_ocupado,
      keyboardType: numero ? TextInputType.number : TextInputType.text,
      maxLength: numero ? 3 : (c == _titular ? 180 : 2000),
      decoration: InputDecoration(labelText: nombre),
    ),
  );
  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(widget.politicas ? 'Políticas posventa' : 'Pagos de prueba'),
    ),
    body: ListView(
      padding: const EdgeInsets.all(20),
      children: [
        if (_error != null && _datos == null)
          Text(
            _error!,
            style: TextStyle(color: Theme.of(context).colorScheme.error),
          ),
        if (_ocupado) const LinearProgressIndicator(),
        if (_datos != null) ...[
          if (widget.politicas) ...[
            SwitchListTile(
              title: const Text('Habilitar cambios'),
              value: _primero,
              onChanged: _ocupado ? null : (v) => setState(() => _primero = v),
            ),
            _campo(_plazoCambios, 'Plazo de cambios (días)', numero: true),
            _campo(_condicionesCambios, 'Condiciones de cambios'),
            SwitchListTile(
              title: const Text('Habilitar devoluciones'),
              value: _segundo,
              onChanged: _ocupado ? null : (v) => setState(() => _segundo = v),
            ),
            _campo(
              _plazoDevoluciones,
              'Plazo de devoluciones (días)',
              numero: true,
            ),
            _campo(_condicionesDevoluciones, 'Condiciones de devoluciones'),
          ] else ...[
            const Text(
              'Configuración de pruebas. QR es una simulación y no permite transferir dinero. Las credenciales se configuran únicamente en el servidor.',
            ),
            SwitchListTile(
              title: const Text('Habilitar Stripe de prueba'),
              value: _primero,
              onChanged: _ocupado ? null : (v) => setState(() => _primero = v),
            ),
            SwitchListTile(
              title: const Text('Habilitar QR simulado'),
              value: _segundo,
              onChanged: _ocupado ? null : (v) => setState(() => _segundo = v),
            ),
            _campo(_titular, 'Titular del comercio'),
            Text(
              'Conexión Stripe: ${_datos!['stripe_conexion'] ?? 'Sin configurar'}',
            ),
          ],
          const SizedBox(height: 16),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          FilledButton(
            onPressed: _ocupado ? null : _guardar,
            child: const Text('Guardar configuración'),
          ),
        ],
        TextButton(
          onPressed: _ocupado ? null : _cargar,
          child: const Text('Volver a cargar configuración'),
        ),
      ],
    ),
  );
}
