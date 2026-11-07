import 'package:flutter/material.dart';

import '../../models/reporte_models.dart';
import '../../services/reporte_service.dart';
import '../saas/saas_widgets.dart';

class DashboardComercialTab extends StatefulWidget {
  const DashboardComercialTab({
    super.key,
    required this.catalogo,
    required this.encargado,
  });
  final ReporteCatalogo catalogo;
  final bool encargado;
  @override
  State<DashboardComercialTab> createState() => _DashboardComercialTabState();
}

class _DashboardComercialTabState extends State<DashboardComercialTab>
    with PantallaSesion {
  final _desde = TextEditingController(
        text: '${hoyBolivia().substring(0, 7)}-01',
      ),
      _hasta = TextEditingController(text: hoyBolivia());
  int? _sucursal;
  String? _canal;
  bool _comparar = true, _cargando = false;
  String? _error;
  Map<String, dynamic>? _resultado;
  @override
  void initState() {
    super.initState();
    if (widget.encargado) {
      _sucursal = widget.catalogo.sucursales.firstOrNull?.id;
    }
    _cargar();
  }

  @override
  void dispose() {
    _desde.dispose();
    _hasta.dispose();
    super.dispose();
  }

  Future<void> _cargar() async {
    if (_cargando) return;
    if (validarFechaSaas(_desde.text) != null ||
        validarFechaSaas(_hasta.text) != null ||
        _desde.text.compareTo(_hasta.text) > 0) {
      setState(() => _error = 'Revisa las fechas.');
      return;
    }
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final r = await ReporteService.dashboard({
        'fecha_desde': _desde.text,
        'fecha_hasta': _hasta.text,
        'sucursal_id': _sucursal,
        'tipo_venta': _canal,
        'comparar': _comparar,
      });
      if (vigente) setState(() => _resultado = r);
    } catch (e) {
      if (vigente) setState(() => _error = explicar(e));
    } finally {
      if (vigente) setState(() => _cargando = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final r = _resultado,
        d = r?['datos'] as Map<String, dynamic>?,
        c = r?['comparacion'] as Map<String, dynamic>?;
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text(
          'Dashboard comercial',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        TextField(
          controller: _desde,
          decoration: const InputDecoration(labelText: 'Desde (AAAA-MM-DD)'),
        ),
        TextField(
          controller: _hasta,
          decoration: const InputDecoration(labelText: 'Hasta (AAAA-MM-DD)'),
        ),
        DropdownButtonFormField<int>(
          initialValue: _sucursal,
          decoration: const InputDecoration(labelText: 'Sucursal'),
          isExpanded: true,
          items: [
            if (!widget.encargado)
              const DropdownMenuItem<int>(value: null, child: Text('Todas')),
            ...widget.catalogo.sucursales.map(
              (s) => DropdownMenuItem(value: s.id, child: Text(s.nombre)),
            ),
          ],
          onChanged: _cargando ? null : (v) => setState(() => _sucursal = v),
        ),
        DropdownButtonFormField<String>(
          initialValue: _canal,
          decoration: const InputDecoration(labelText: 'Canal'),
          items: const [
            DropdownMenuItem<String>(value: null, child: Text('Todos')),
            DropdownMenuItem(value: 'PRESENCIAL', child: Text('Presencial')),
            DropdownMenuItem(value: 'DIGITAL', child: Text('Digital')),
          ],
          onChanged: _cargando ? null : (v) => setState(() => _canal = v),
        ),
        SwitchListTile(
          title: const Text('Comparar período anterior'),
          value: _comparar,
          onChanged: _cargando ? null : (v) => setState(() => _comparar = v),
        ),
        FilledButton(
          onPressed: _cargando ? null : _cargar,
          child: const Text('Actualizar dashboard'),
        ),
        if (_cargando) const LinearProgressIndicator(),
        if (_error != null) ErrorSaas(_error!),
        if (d != null) ...[
          Text(
            'Consulta: ${(r!['filtros'] as Map)['fecha_desde']} al ${(r['filtros'] as Map)['fecha_hasta']}',
          ),
          ...{
            'ventas': 'Ventas completadas',
            'ventas_presenciales': 'Presenciales',
            'ventas_digitales': 'Digitales',
            'importe_vendido': 'Importe vendido BOB',
            'reservas_pendientes': 'Reservas pendientes',
            'reservas_vencidas': 'Reservas vencidas',
            'existencias_bajas': 'Existencias bajas actuales',
          }.entries.map(
            (e) =>
                ListTile(title: Text(e.value), trailing: Text('${d[e.key]}')),
          ),
          const Text(
            'Flujos por moneda',
            style: TextStyle(fontWeight: FontWeight.bold),
          ),
          ...(d['flujos'] as List).map((v) {
            final f = v as Map;
            return ListTile(
              title: Text('${f['moneda']}'),
              subtitle: Text(
                'Cobrado: ${f['cobrado']} · Reembolsado: ${f['reembolsado']} · Neto: ${f['neto']}',
              ),
            );
          }),
          const Text(
            'El neto no representa ganancia. El inventario es actual y no se compara históricamente.',
          ),
          if (c != null)
            ExpansionTile(
              title: Text(
                'Comparación: ${c['fecha_desde']} al ${c['fecha_hasta']}',
              ),
              children: (c['indicadores'] as Map<String, dynamic>).entries.map((
                e,
              ) {
                final v = e.value as Map;
                return ListTile(
                  title: Text(e.key.replaceAll('_', ' ')),
                  subtitle: Text(
                    'Actual: ${v['actual']} · Anterior: ${v['anterior']} · Diferencia: ${v['diferencia']}\n${v['variacion_porcentual'] == null ? 'Sin porcentaje: base anterior cero' : 'Variación: ${v['variacion_porcentual']} %'}',
                  ),
                );
              }).toList(),
            ),
          ExpansionTile(
            title: const Text('Serie de ventas'),
            children: (d['serie_ventas'] as List).map((v) {
              final x = v as Map;
              return ListTile(
                title: Text('${x['fecha']}'),
                subtitle: Text('${x['ventas']} ventas · ${x['importe']} BOB'),
              );
            }).toList(),
          ),
          ExpansionTile(
            title: const Text('Productos más vendidos'),
            children: (d['productos_mas_vendidos'] as List).map((v) {
              final x = v as Map;
              return ListTile(
                title: Text('${x['nombre']} · ${x['sku']}'),
                subtitle: Text(
                  '${x['unidades']} unidades · ${x['importe']} BOB',
                ),
              );
            }).toList(),
          ),
          ExpansionTile(
            title: const Text('Cómo se calculan las métricas'),
            children: (r['definiciones'] as Map<String, dynamic>).values
                .map((v) => ListTile(title: Text(v as String)))
                .toList(),
          ),
        ],
      ],
    );
  }
}
