import 'package:flutter/material.dart';

import '../../models/saas_models.dart';
import '../../services/saas_service.dart';
import 'saas_widgets.dart';
import 'empresa_saas_screen.dart';
import 'plan_editor_screen.dart';
import 'historial_saas_screen.dart';

class PlanesSaasScreen extends StatefulWidget {
  const PlanesSaasScreen({super.key});
  @override
  State<PlanesSaasScreen> createState() => _PlanesSaasScreenState();
}

class _PlanesSaasScreenState extends State<PlanesSaasScreen>
    with PantallaSesion {
  List<PlanSaas> _planes = [], _comparacion = [];
  List<Map<String, dynamic>> _resumen = [];
  CatalogoSaas? _catalogo;
  bool _cargando = true;
  String? _error;
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
      final datos = await Future.wait<Object>([
        SaasService.planes(),
        SaasService.catalogo(),
        SaasService.resumen(),
        SaasService.comparacion(),
      ]);
      if (!vigente) return;
      setState(() {
        _planes = datos[0] as List<PlanSaas>;
        _catalogo = datos[1] as CatalogoSaas;
        _resumen = datos[2] as List<Map<String, dynamic>>;
        _comparacion = datos[3] as List<PlanSaas>;
      });
    } catch (e) {
      if (vigente) setState(() => _error = explicar(e));
    } finally {
      if (vigente) setState(() => _cargando = false);
    }
  }

  Future<void> _editar([PlanSaas? plan]) async {
    if (_catalogo == null) return;
    final cambio = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PlanEditorScreen(catalogo: _catalogo!, plan: plan),
      ),
    );
    if (vigente && cambio == true) await _cargar();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Planes'),
      actions: [
        IconButton(
          onPressed: _cargando ? null : _cargar,
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualizar planes',
        ),
      ],
    ),
    floatingActionButton: _catalogo == null
        ? null
        : FloatingActionButton.extended(
            onPressed: _cargando ? null : () => _editar(),
            icon: const Icon(Icons.add),
            label: const Text('Crear plan'),
          ),
    body: ListView(
      padding: const EdgeInsets.fromLTRB(16, 16, 16, 100),
      children: [
        const Text(
          'El precio de referencia no genera cobros automáticos de suscripción.',
        ),
        if (_cargando) const LinearProgressIndicator(),
        if (_error != null) ErrorSaas(_error!, reintentar: _cargar),
        ..._planes.map(
          (p) => Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(p.nombre, style: Theme.of(context).textTheme.titleLarge),
                  Text(
                    '${p.codigo} · ${p.activo ? 'Activo' : 'Inactivo'} · ${p.publico ? 'Público' : 'Oculto en registro'}',
                  ),
                  Text('${p.precio} ${p.moneda}'),
                  Text(p.descripcion),
                  Wrap(
                    spacing: 8,
                    children: [
                      OutlinedButton(
                        onPressed: _cargando ? null : () => _editar(p),
                        child: Text('Editar ${p.nombre}'),
                      ),
                      TextButton(
                        onPressed: () => Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) => HistorialSaasScreen(
                              plan: p,
                              catalogo: _catalogo,
                            ),
                          ),
                        ),
                        child: const Text('Historial'),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ),
        if (!_cargando && _planes.isEmpty)
          const Text('No hay planes registrados.'),
        const SizedBox(height: 20),
        Text(
          'Empresas por plan',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        const Text(
          'Cada empresa se cuenta una vez según su última suscripción.',
        ),
        ..._resumen.map(
          (r) => Card(
            child: ListTile(
              title: Text(r['nombre'] as String),
              subtitle: Text(
                '${r['empresas']} empresas · ${r['vigentes']} vigentes · ${r['no_vigentes']} no vigentes',
              ),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.push(
                context,
                MaterialPageRoute(
                  builder: (_) =>
                      EmpresasSaasScreen(planId: (r['id'] as num).toInt()),
                ),
              ),
            ),
          ),
        ),
        const SizedBox(height: 20),
        Text('Comparar planes', style: Theme.of(context).textTheme.titleLarge),
        if (_catalogo != null)
          ..._comparacion.map(
            (p) => ExpansionTile(
              title: Text(p.nombre),
              children: [
                ..._catalogo!.limites.map(
                  (l) => ListTile(
                    title: Text(l.nombre),
                    subtitle: Text(
                      '${p.limites[l.clave] ?? 'Sin límite'} ${l.unidad}',
                    ),
                  ),
                ),
                ..._catalogo!.funciones.map(
                  (f) => ListTile(
                    title: Text(f.nombre),
                    subtitle: Text(
                      (p.funciones[f.clave] ?? true)
                          ? 'Incluida'
                          : 'No incluida',
                    ),
                  ),
                ),
              ],
            ),
          ),
      ],
    ),
  );
}
