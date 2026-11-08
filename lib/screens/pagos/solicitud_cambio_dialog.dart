import 'package:flutter/material.dart';

import '../../services/cambio_service.dart';
import 'selector_variante_cambio.dart';

class SolicitudCambioElegida {
  const SolicitudCambioElegida(this.cantidad, this.motivo, this.variante);
  final int cantidad, variante;
  final String motivo;
}

class SolicitudCambioDialog extends StatefulWidget {
  const SolicitudCambioDialog({
    super.key,
    required this.venta,
    required this.linea,
    required this.maximo,
  });
  final int venta, linea, maximo;
  @override
  State<SolicitudCambioDialog> createState() => _SolicitudCambioDialogState();
}

class _SolicitudCambioDialogState extends State<SolicitudCambioDialog> {
  final _cantidad = TextEditingController(text: '1'),
      _motivo = TextEditingController();
  List<Map<String, dynamic>> _opciones = [];
  int? _variante;
  int _consulta = 0;
  double? _credito;
  String? _error;
  bool _cargando = false;
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  @override
  void dispose() {
    _cantidad.dispose();
    _motivo.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    final n = int.tryParse(_cantidad.text), consulta = ++_consulta;
    setState(() {
      _variante = null;
      _opciones = [];
      _credito = null;
      _error = null;
      _cargando = false;
    });
    if (n == null || n < 1 || n > widget.maximo) return;
    setState(() => _cargando = true);
    try {
      final d = await CambioService.opcionesSolicitud(
        widget.venta,
        widget.linea,
        n,
      );
      if (!mounted || consulta != _consulta) return;
      setState(() {
        _opciones = (d['opciones'] as List).cast<Map<String, dynamic>>();
        _credito = double.parse('${d['credito_estimado']}');
      });
    } catch (e) {
      if (mounted && consulta == _consulta) setState(() => _error = '$e');
    } finally {
      if (mounted && consulta == _consulta) setState(() => _cargando = false);
    }
  }

  void _enviar() {
    final n = int.tryParse(_cantidad.text);
    if (n == null ||
        n < 1 ||
        n > widget.maximo ||
        _motivo.text.trim().length < 5 ||
        _variante == null) {
      setState(
        () => _error = 'Indica cantidad, motivo y producto con talla y color.',
      );
      return;
    }
    Navigator.pop(
      context,
      SolicitudCambioElegida(n, _motivo.text.trim(), _variante!),
    );
  }

  @override
  Widget build(BuildContext context) {
    final v = _opciones.where((o) => o['id'] == _variante).firstOrNull;
    final diferencia = v == null || _credito == null
        ? null
        : ((double.parse('${v['precio']}') * 100).round() *
                      (int.tryParse(_cantidad.text) ?? 0) -
                  (_credito! * 100).round()) /
              100;
    return AlertDialog(
      title: const Text('Solicitar cambio'),
      content: SizedBox(
        width: 460,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Máximo ${widget.maximo} prendas elegibles'),
              TextField(
                controller: _cantidad,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Cantidad a cambiar',
                ),
                onChanged: (_) => _cargar(),
              ),
              TextField(
                controller: _motivo,
                maxLength: 500,
                decoration: const InputDecoration(
                  labelText: 'Motivo del cambio',
                ),
              ),
              if (_cargando) const LinearProgressIndicator(),
              if (_error != null)
                Text(
                  _error!,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              SelectorVarianteCambio(
                opciones: _opciones,
                seleccion: _variante,
                onChanged: (v) => setState(() => _variante = v),
              ),
              if (diferencia != null)
                Text(
                  diferencia == 0
                      ? 'Sin diferencia estimada.'
                      : '${diferencia > 0 ? 'Pago estimado' : 'Reintegro estimado'}: Bs ${diferencia.abs().toStringAsFixed(2)}',
                ),
              const SizedBox(height: 12),
              const Text(
                'La tienda debe inspeccionar la prenda. Precio y stock se validarán nuevamente antes de confirmar el cambio. Esta solicitud no reserva existencias ni inicia un pago.',
              ),
              TextButton(
                onPressed: _cargando ? null : _cargar,
                child: const Text('Actualizar disponibilidad'),
              ),
            ],
          ),
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.pop(context),
          child: const Text('Volver'),
        ),
        FilledButton(
          onPressed: _cargando || _variante == null ? null : _enviar,
          child: const Text('Enviar solicitud'),
        ),
      ],
    );
  }
}
