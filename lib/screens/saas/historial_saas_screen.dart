import 'package:flutter/material.dart';

import '../../models/saas_models.dart';
import '../../services/saas_service.dart';
import 'saas_widgets.dart';

class HistorialSaasScreen extends StatefulWidget {
  const HistorialSaasScreen({super.key, this.plan, this.catalogo});
  final PlanSaas? plan;
  final CatalogoSaas? catalogo;
  @override
  State<HistorialSaasScreen> createState() => _HistorialSaasScreenState();
}

class _HistorialSaasScreenState extends State<HistorialSaasScreen>
    with PantallaSesion {
  List<Map<String, dynamic>> _filas = [];
  String? _error;
  bool _cargando = true;
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
      final filas = widget.plan == null
          ? await SaasService.eventos()
          : await SaasService.historial(widget.plan!.id);
      if (vigente) setState(() => _filas = filas);
    } catch (e) {
      if (vigente) setState(() => _error = explicar(e));
    } finally {
      if (vigente) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: Text(
        widget.plan == null
            ? 'Auditoría de plataforma'
            : 'Historial de ${widget.plan!.nombre}',
      ),
    ),
    body: RefreshIndicator(
      onRefresh: _cargar,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_cargando) const LinearProgressIndicator(),
          if (_error != null) ErrorSaas(_error!, reintentar: _cargar),
          if (!_cargando && _filas.isEmpty)
            const Text('Sin eventos registrados.'),
          ..._filas.map((h) {
            final antes = h['antes'] as Map<String, dynamic>?,
                despues = h['despues'] as Map<String, dynamic>?;
            return Card(
              child: ExpansionTile(
                title: Text(
                  widget.plan == null
                      ? (h['accion'] as String)
                      : antes == null
                      ? 'Creación del plan'
                      : 'Edición del plan',
                ),
                subtitle: Text(
                  '${fechaSaas(h['fecha'])} · Actor ${h['actor_id']}',
                ),
                children: [
                  if (despues == null)
                    ListTile(
                      title: Text(
                        'Empresa: ${h['empresa_id'] ?? 'Plataforma'}',
                      ),
                      subtitle: Text(
                        'Referencia: ${h['recurso_id'] ?? 'Sin referencia'}',
                      ),
                    ),
                  if (despues != null) ...[
                    ListTile(
                      title: Text(despues['nombre'] as String),
                      subtitle: Text(
                        'Precio: ${antes?['precio'] ?? '—'} → ${despues['precio']} ${despues['moneda']}\nActivo: ${antes?['activo'] ?? '—'} → ${despues['activo']}\nPúblico: ${antes?['publico'] ?? '—'} → ${despues['publico']}',
                      ),
                    ),
                    ListTile(
                      title: const Text('Descripción y condiciones'),
                      subtitle: Text(
                        '${despues['descripcion'] ?? ''}\n${despues['condiciones'] ?? ''}',
                      ),
                    ),
                    for (final grupo in ['limites', 'funciones'])
                      ...((despues[grupo] as Map<String, dynamic>).entries.map(
                        (v) => ListTile(
                          title: Text(widget.catalogo?.nombre(v.key) ?? v.key),
                          subtitle: Text(
                            '${(antes?[grupo] as Map?)?[v.key] ?? 'Predeterminado'} → ${v.value}',
                          ),
                        ),
                      )),
                    ListTile(
                      title: Text(
                        'Empresas afectadas: ${(h['impacto'] as Map?)?['total_empresas'] ?? 0}',
                      ),
                    ),
                  ],
                ],
              ),
            );
          }),
        ],
      ),
    ),
  );
}
