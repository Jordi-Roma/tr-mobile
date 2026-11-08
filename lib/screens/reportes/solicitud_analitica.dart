import 'package:flutter/material.dart';

import '../../services/analitica_service.dart';
import '../../services/voz_service.dart';
import '../saas/saas_widgets.dart';

class SolicitudAnalitica extends StatefulWidget {
  const SolicitudAnalitica({
    super.key,
    required this.origen,
    required this.habilitada,
    required this.onAplicar,
  });
  final String origen;
  final bool habilitada;
  final void Function(Map<String, dynamic>) onAplicar;
  @override
  State<SolicitudAnalitica> createState() => _SolicitudAnaliticaState();
}

class _SolicitudAnaliticaState extends State<SolicitudAnalitica>
    with PantallaSesion {
  final _texto = TextEditingController();
  Map<String, dynamic>? _preview;
  bool _ocupado = false, _escuchando = false;
  String? _error;
  String _entrada = 'TEXTO';
  int _revision = 0;
  @override
  void didUpdateWidget(covariant SolicitudAnalitica oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.origen != widget.origen || !widget.habilitada) {
      ++_revision;
      _preview = null;
      _ocupado = false;
      _escuchando = false;
      VozService.cancelar();
      if (!widget.habilitada) _texto.clear();
    }
  }

  @override
  void dispose() {
    ++_revision;
    VozService.cancelar();
    _texto.dispose();
    super.dispose();
  }

  Future<void> _interpretar() async {
    if (_ocupado || !widget.habilitada || _texto.text.trim().length < 3) return;
    final revision = ++_revision;
    setState(() {
      _ocupado = true;
      _preview = null;
      _error = null;
    });
    try {
      final p = await AnaliticaService.interpretar(
        _texto.text,
        widget.origen,
        _entrada,
      );
      if (vigente && revision == _revision && widget.habilitada) {
        setState(() => _preview = p);
      }
    } catch (e) {
      if (vigente && revision == _revision) {
        setState(() => _error = explicar(e));
      }
    } finally {
      if (vigente && revision == _revision) setState(() => _ocupado = false);
    }
  }

  Future<void> _dictar() async {
    if (_escuchando) {
      await VozService.cancelar();
      if (vigente) setState(() => _escuchando = false);
      return;
    }
    final revision = ++_revision;
    setState(() {
      _escuchando = true;
      _preview = null;
      _error = null;
    });
    try {
      await VozService.escuchar(
        onTexto: (texto, finalizado) {
          if (!vigente || revision != _revision || !widget.habilitada) return;
          setState(() {
            _texto.text = texto;
            _entrada = 'VOZ';
            if (finalizado) _escuchando = false;
          });
        },
        onError: (mensaje) {
          if (vigente && revision == _revision) {
            setState(() {
              _error = mensaje;
              _escuchando = false;
            });
          }
        },
      );
    } catch (_) {
      if (vigente && revision == _revision) {
        setState(() {
          _error = 'No se pudo activar el micrófono. Escribe la solicitud.';
          _escuchando = false;
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final solicitud = _preview?['solicitud'] as Map<String, dynamic>?;
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Solicitar reporte por texto o voz',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const Text(
              'Ejemplo: evaluación de predicciones de mi sucursal con datos sintéticos en PDF.',
            ),
            TextField(
              controller: _texto,
              maxLines: 3,
              maxLength: 1200,
              enabled: widget.habilitada,
              decoration: const InputDecoration(
                labelText: 'Solicitud de analítica',
              ),
              onChanged: (_) => setState(() {
                ++_revision;
                _preview = null;
                _ocupado = false;
                _entrada = 'TEXTO';
              }),
            ),
            Wrap(
              spacing: 8,
              children: [
                OutlinedButton(
                  onPressed: widget.habilitada ? _dictar : null,
                  child: Text(
                    _escuchando ? 'Detener dictado' : 'Dictar solicitud',
                  ),
                ),
                FilledButton(
                  onPressed: widget.habilitada && !_ocupado
                      ? _interpretar
                      : null,
                  child: const Text('Revisar solicitud'),
                ),
              ],
            ),
            if (_ocupado) const LinearProgressIndicator(),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: Color(0xff84251e))),
            if (_preview != null) ...[
              const Text(
                'Vista previa · Interpretación local por reglas',
                style: TextStyle(fontWeight: FontWeight.bold),
              ),
              Text(_preview!['mensaje'] as String),
              if (solicitud != null) ...[
                Text(
                  'Análisis: ${solicitud['tipo']} · Origen: ${solicitud['origen']}',
                ),
                Text(
                  'Sucursal: ${solicitud['sucursal_id'] ?? 'Todas las autorizadas'} · Producto: ${solicitud['producto_id'] ?? 'Todos'} · Grupo: ${solicitud['grupo'] ?? 'Todos'}',
                ),
                Text(
                  'Cortes: ${solicitud['corte_desde'] ?? 'Sin límite'} a ${solicitud['corte_hasta'] ?? 'Sin límite'} · Formato sugerido: ${_preview!['formato_sugerido']}',
                ),
                FilledButton(
                  onPressed: widget.habilitada
                      ? () => widget.onAplicar(solicitud)
                      : null,
                  child: const Text('Aplicar solicitud revisada'),
                ),
                const Text(
                  'Se mostrarán resultados; elige después la descarga PDF o Excel.',
                ),
              ],
            ],
          ],
        ),
      ),
    );
  }
}
