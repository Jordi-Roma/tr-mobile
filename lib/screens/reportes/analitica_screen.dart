import 'package:flutter/material.dart';

import '../../core/session/contexto_sesion.dart';
import '../../models/analitica_models.dart';
import '../../services/analitica_service.dart';
import '../saas/saas_widgets.dart';
import 'serie_analitica.dart';
import 'solicitud_analitica.dart';
import '../../services/file_download_service.dart';

class AnaliticaScreen extends StatefulWidget {
  const AnaliticaScreen({super.key});
  @override
  State<AnaliticaScreen> createState() => _AnaliticaScreenState();
}

class _AnaliticaScreenState extends State<AnaliticaScreen> with PantallaSesion {
  EstadoAnalitica? _estado;
  ResultadoAnalitica? _resultado;
  String _origen = 'OFICIAL', _tipo = 'predicciones';
  String? _producto, _error;
  int? _sucursal, _grupo;
  int _revision = 0;
  bool _cargando = false, _bloqueada = false;
  bool _exportando = false;
  bool _mostrarDetalle = false;
  String? _aviso;
  final _desde = TextEditingController(), _hasta = TextEditingController();
  List<String> _productos = [];
  List<Map<String, dynamic>> _perfiles = [];
  Map<String, String> _aplicados = {};
  FuenteAnalitica? get _fuente =>
      _estado?.fuentes.where((f) => f.origen == _origen).firstOrNull;
  bool _vigente(int revision) =>
      vigente && !_bloqueada && revision == _revision;
  @override
  void initState() {
    super.initState();
    ContextoSesion.instance.addListener(_sesion);
    _cargarEstado();
  }

  void _sesion() {
    if (generacion == ContextoSesion.instance.generacion || !mounted) return;
    ++_revision;
    setState(() {
      _bloqueada = true;
      _mostrarDetalle = false;
      _estado = null;
      _resultado = null;
      _productos = [];
      _perfiles = [];
      _sucursal = null;
      _grupo = null;
      _producto = null;
      _tipo = 'predicciones';
      _origen = 'OFICIAL';
      _cargando = false;
      _exportando = false;
      _aviso = null;
      _error = 'La sesión cambió. Vuelve a abrir Analítica inteligente.';
    });
  }

  @override
  void dispose() {
    ++_revision;
    ContextoSesion.instance.removeListener(_sesion);
    _desde.dispose();
    _hasta.dispose();
    super.dispose();
  }

  Future<void> _cargarEstado() async {
    if (_bloqueada) return;
    final revision = ++_revision;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final e = await AnaliticaService.estado();
      if (!_vigente(revision)) return;
      setState(() => _estado = e);
      await _consultar();
    } catch (e) {
      if (_vigente(revision)) {
        setState(() {
          _error = explicar(e);
          _cargando = false;
        });
      }
    }
  }

  void _cambiar({String? origen, String? tipo}) {
    setState(() {
      _origen = origen ?? _origen;
      _tipo = tipo ?? _tipo;
      _producto = null;
      _sucursal = null;
      _grupo = null;
      _resultado = null;
      _productos = [];
      _perfiles = [];
      _desde.clear();
      _hasta.clear();
    });
    _consultar();
  }

  Future<void> _consultar({int pagina = 1, bool reutilizar = false}) async {
    if (_bloqueada || _estado == null) return;
    if (_tipo == 'segmentos' && !_estado!.segmentacionPermitida) return;
    if (!reutilizar &&
        (validarFechaSaas(_desde.text, opcional: true) != null ||
            validarFechaSaas(_hasta.text, opcional: true) != null ||
            (_desde.text.isNotEmpty &&
                _hasta.text.isNotEmpty &&
                _desde.text.compareTo(_hasta.text) > 0))) {
      setState(() => _error = 'Revisa el rango de fechas de corte.');
      return;
    }
    final filtros = reutilizar
        ? {..._aplicados, 'pagina': '$pagina'}
        : <String, String>{
            'origen': _origen,
            'pagina': '1',
            'tamano': '25',
            if (_tipo == 'predicciones') ...{
              if (_sucursal != null) 'sucursal_id': '$_sucursal',
              'producto_id': ?_producto,
              if (_desde.text.isNotEmpty) 'corte_desde': _desde.text,
              if (_hasta.text.isNotEmpty) 'corte_hasta': _hasta.text,
            } else if (_grupo != null)
              'grupo': '$_grupo',
          };
    final revision = ++_revision;
    setState(() {
      _cargando = true;
      _error = null;
      _resultado = null;
      _aplicados = filtros;
      if (!reutilizar) _mostrarDetalle = false;
    });
    try {
      final r = await AnaliticaService.consultar(_tipo, filtros);
      if (_vigente(revision)) {
        setState(() {
          _resultado = r;
          if (_tipo == 'predicciones') {
            _productos = r.productos;
            if (!_productos.contains(_producto)) _producto = null;
          }
          if (_tipo == 'segmentos') _perfiles = r.perfiles;
        });
      }
    } catch (e) {
      if (_vigente(revision)) setState(() => _error = explicar(e));
    } finally {
      if (_vigente(revision)) setState(() => _cargando = false);
    }
  }

  void _aplicarSolicitud(Map<String, dynamic> s) {
    if (_bloqueada ||
        s['tipo'] == 'SEGMENTOS' && _estado?.segmentacionPermitida != true) {
      return;
    }
    setState(() {
      _origen = s['origen'] as String;
      _tipo = s['tipo'] == 'PREDICCIONES' ? 'predicciones' : 'segmentos';
      _sucursal = s['sucursal_id'] as int?;
      _producto = s['producto_id'] as String?;
      _grupo = s['grupo'] as int?;
      _desde.text = (s['corte_desde'] as String?) ?? '';
      _hasta.text = (s['corte_hasta'] as String?) ?? '';
      _productos = [?_producto];
      _perfiles = _grupo == null
          ? []
          : [
              {'grupo': _grupo, 'nombre': 'Grupo $_grupo'},
            ];
      _resultado = null;
    });
    _consultar();
  }

  Future<void> _exportar(String formato) async {
    if (_exportando || _cargando || _bloqueada || _resultado == null) return;
    final revision = _revision;
    final solicitud =
        <String, dynamic>{
            ..._aplicados,
            'tipo': _tipo == 'predicciones' ? 'PREDICCIONES' : 'SEGMENTOS',
          }
          ..remove('pagina')
          ..remove('tamano');
    for (final clave in ['sucursal_id', 'grupo']) {
      if (solicitud[clave] != null) {
        solicitud[clave] = int.parse(solicitud[clave] as String);
      }
    }
    setState(() {
      _exportando = true;
      _aviso = null;
      _error = null;
    });
    try {
      final bytes = await AnaliticaService.exportar(solicitud, formato);
      if (!_vigente(revision)) return;
      final extension = formato == 'pdf' ? 'pdf' : 'xlsx';
      final ruta = await FileDownloadService.guardarYMostrarArchivo(
        bytes: bytes,
        nombreArchivo:
            'analitica_${solicitud['tipo'].toString().toLowerCase()}_${solicitud['origen'].toString().toLowerCase()}.$extension',
        mimeType: formato == 'pdf' ? 'application/pdf' : 'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet',
      );
      if (_vigente(revision)) {
        setState(
          () => _aviso = ruta == null
              ? 'Reporte del filtro completo guardado.'
              : 'Reporte guardado en $ruta',
        );
      }
    } catch (e) {
      if (_vigente(revision)) setState(() => _error = explicar(e));
    } finally {
      if (vigente) setState(() => _exportando = false);
    }
  }

  Widget _dato(String nombre, Object? valor) => SizedBox(
    width: 142,
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              nombre,
              style: const TextStyle(color: Color(0xff454545), height: 1.4),
            ),
            const SizedBox(height: 6),
            Text(
              '$valor',
              style: const TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
            ),
          ],
        ),
      ),
    ),
  );
  Widget _perfil(Map<String, dynamic> p) {
    final proporcion = (p['proporcion'] as num).toDouble().clamp(0.0, 1.0);
    final color = (p['grupo'] as int).isOdd
        ? const Color(0xff466333)
        : const Color(0xff2468aa);
    String numero(String clave, {double divisor = 1}) => p[clave] is num
        ? ((p[clave] as num) / divisor).toStringAsFixed(1)
        : '—';
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              '${p['nombre']}',
              style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              '${p['clientes']} clientes · ${(proporcion * 100).toStringAsFixed(1)} % del total',
              style: TextStyle(color: color, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Semantics(
              label:
                  '${p['nombre']}: ${(proporcion * 100).toStringAsFixed(1)} por ciento de clientes',
              child: ClipRRect(
                borderRadius: BorderRadius.circular(8),
                child: SizedBox(
                  height: 18,
                  child: Stack(
                    children: [
                      Container(color: const Color(0xffe8ebe3)),
                      FractionallySizedBox(
                        widthFactor: proporcion,
                        child: Container(color: color),
                      ),
                    ],
                  ),
                ),
              ),
            ),
            const SizedBox(height: 16),
            const Text(
              'Promedios por cliente',
              style: TextStyle(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text('Última compra hace: ${numero('recencia_media_dias')} días'),
            Text(
              'Compras en el período: ${numero('frecuencia_media_compras')}',
            ),
            Text(
              'Gasto en el período: Bs ${numero('gasto_medio_centavos', divisor: 100)}',
            ),
            if (p['descripcion'] != null &&
                p['recencia_media_dias'] == null) ...[
              const SizedBox(height: 12),
              Text(p['descripcion'] as String),
            ],
          ],
        ),
      ),
    );
  }

  String _n(Object? valor, [int decimales = 3]) =>
      (valor as num).toStringAsFixed(decimales);
  String _estadoTexto(String estado) => estado == 'HISTORIAL_INSUFICIENTE'
      ? 'Historial insuficiente'
      : estado == 'DISPONIBLE'
      ? 'Resultados disponibles'
      : 'Sin configuración de modelos';
  @override
  Widget build(BuildContext context) {
    final fuente = _fuente, r = _resultado, m = r?.metricas;
    return Scaffold(
      appBar: AppBar(title: const Text('Analítica inteligente')),
      body: DefaultTextStyle.merge(
        style: const TextStyle(color: Color(0xff30352c), height: 1.45),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              'Predicciones y patrones de compra',
              style: TextStyle(fontSize: 22, fontWeight: FontWeight.bold),
            ),
            DropdownButtonFormField<String>(
              key: ValueKey(('origen', _origen)),
              initialValue: _origen,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Origen de datos'),
              items: const [
                DropdownMenuItem(
                  value: 'OFICIAL',
                  child: Text('Historial oficial'),
                ),
                DropdownMenuItem(
                  value: 'DEMOSTRACION',
                  child: Text('Demostración sintética'),
                ),
              ],
              onChanged: _bloqueada
                  ? null
                  : (v) {
                      if (v != null) _cambiar(origen: v);
                    },
            ),
            DropdownButtonFormField<String>(
              key: ValueKey(('tipo', _tipo)),
              initialValue: _tipo,
              isExpanded: true,
              decoration: const InputDecoration(labelText: 'Análisis'),
              items: [
                const DropdownMenuItem(
                  value: 'predicciones',
                  child: Text('Predicción de ventas'),
                ),
                if (_estado?.segmentacionPermitida == true)
                  const DropdownMenuItem(
                    value: 'segmentos',
                    child: Text('Segmentación de clientes'),
                  ),
              ],
              onChanged: _bloqueada
                  ? null
                  : (v) {
                      if (v != null) _cambiar(tipo: v);
                    },
            ),
            if (fuente != null)
              Card(
                color: _origen == 'DEMOSTRACION'
                    ? const Color(0xffedf3f8)
                    : const Color(0xffedf1e8),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        _origen == 'DEMOSTRACION'
                            ? 'Demostración con datos sintéticos'
                            : 'Historial oficial',
                        style: const TextStyle(
                          fontSize: 18,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(_estadoTexto(fuente.estado)),
                      Text(fuente.advertencia),
                      if (_origen == 'DEMOSTRACION')
                        const Text(
                          'Datos ficticios asociados a sucursales para la demostración; no son ventas oficiales.',
                        ),
                      if (fuente.evaluadoEn != null)
                        ExpansionTile(
                          tilePadding: EdgeInsets.zero,
                          title: const Text('Ver origen y auditoría'),
                          children: [
                            Text(
                              'Auditoría: ${fuente.evaluadoEn} · ${fuente.fuenteDatos}. Instantánea, no consulta en vivo a Railway.',
                            ),
                          ],
                        ),
                      if (fuente.estado == 'HISTORIAL_INSUFICIENTE')
                        const Text(
                          'No hay modelos oficiales validados con este historial.',
                        ),
                      if (fuente.resumen['ventas_completadas'] != null)
                        Text(
                          'Ventas completadas auditadas: ${fuente.resumen['ventas_completadas']} · Clientes compradores: ${fuente.resumen['clientes_compradores']}.',
                        ),
                    ],
                  ),
                ),
              ),
            if (_tipo == 'predicciones') ...[
              DropdownButtonFormField<int>(
                key: ValueKey(('sucursal', _origen, _sucursal)),
                initialValue: _sucursal ?? 0,
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Sucursal'),
                items: [
                  const DropdownMenuItem(
                    value: 0,
                    child: Text('Todas las autorizadas'),
                  ),
                  ...?fuente?.sucursales.map(
                    (s) => DropdownMenuItem(
                      value: s['id'] as int,
                      child: Text(s['nombre'] as String),
                    ),
                  ),
                ],
                onChanged: _bloqueada
                    ? null
                    : (v) => setState(() => _sucursal = v == 0 ? null : v),
              ),
              DropdownButtonFormField<String>(
                key: ValueKey(('producto', _origen, _producto)),
                initialValue: _producto ?? '',
                isExpanded: true,
                decoration: const InputDecoration(labelText: 'Producto'),
                items: [
                  const DropdownMenuItem(
                    value: '',
                    child: Text('Todos los productos'),
                  ),
                  ..._productos.map(
                    (p) => DropdownMenuItem(value: p, child: Text(p)),
                  ),
                ],
                onChanged: _bloqueada
                    ? null
                    : (v) => setState(() => _producto = v == '' ? null : v),
              ),
              TextField(
                controller: _desde,
                enabled: !_bloqueada,
                decoration: const InputDecoration(
                  labelText: 'Corte desde (AAAA-MM-DD)',
                ),
              ),
              TextField(
                controller: _hasta,
                enabled: !_bloqueada,
                decoration: const InputDecoration(
                  labelText: 'Corte hasta (AAAA-MM-DD)',
                ),
              ),
            ] else
              DropdownButtonFormField<int>(
                key: ValueKey(('grupo', _grupo)),
                initialValue: _grupo ?? 0,
                decoration: const InputDecoration(labelText: 'Grupo'),
                items: [
                  const DropdownMenuItem(
                    value: 0,
                    child: Text('Todos los grupos'),
                  ),
                  ..._perfiles.map(
                    (p) => DropdownMenuItem(
                      value: p['grupo'] as int,
                      child: Text(p['nombre'] as String),
                    ),
                  ),
                  if (_grupo != null &&
                      !_perfiles.any((p) => p['grupo'] == _grupo))
                    DropdownMenuItem(
                      value: _grupo,
                      child: Text('Grupo $_grupo (solicitado)'),
                    ),
                ],
                onChanged: _bloqueada
                    ? null
                    : (v) => setState(() => _grupo = v == 0 ? null : v),
              ),
            FilledButton(
              onPressed: _cargando || _bloqueada || _estado == null
                  ? null
                  : () => _consultar(),
              child: const Text('Aplicar filtros'),
            ),
            SolicitudAnalitica(
              origen: _origen,
              habilitada: !_bloqueada && _estado != null,
              onAplicar: _aplicarSolicitud,
            ),
            if (_cargando)
              Semantics(
                label: 'Cargando analítica',
                child: const LinearProgressIndicator(),
              ),
            if (_error != null) ...[
              Text(_error!, style: const TextStyle(color: Color(0xff84251e))),
              if (!_bloqueada)
                OutlinedButton(
                  onPressed: () =>
                      _estado == null ? _cargarEstado() : _consultar(),
                  child: const Text('Reintentar'),
                ),
            ],
            if (r != null)
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      const Text(
                        'Descargar reporte del filtro completo',
                        style: TextStyle(fontWeight: FontWeight.bold),
                      ),
                      const Text(
                        'Incluye métricas, gráfico y origen. Máximo 5000 filas; no se limita a la página visible.',
                      ),
                      Wrap(
                        spacing: 8,
                        children: [
                          OutlinedButton(
                            onPressed: _exportando || _cargando
                                ? null
                                : () => _exportar('pdf'),
                            child: const Text('Descargar PDF'),
                          ),
                          OutlinedButton(
                            onPressed: _exportando || _cargando
                                ? null
                                : () => _exportar('excel'),
                            child: const Text('Descargar Excel'),
                          ),
                        ],
                      ),
                      if (_exportando) const LinearProgressIndicator(),
                      if (_aviso != null) Text(_aviso!),
                    ],
                  ),
                ),
              ),
            if (r != null && m != null) ...[
              Text(
                _tipo == 'predicciones'
                    ? 'Evaluación histórica de predicciones'
                    : 'Grupos de clientes',
                style: const TextStyle(
                  fontSize: 22,
                  fontWeight: FontWeight.bold,
                ),
              ),
              if (_origen != 'DEMOSTRACION') Text(r.advertencia),
              if (_tipo == 'predicciones') ...[
                const Text(
                  'Semanas de prueba; no es un pronóstico oficial vigente.',
                ),
                Wrap(
                  spacing: 8,
                  children: [
                    _dato('MAE (unidades)', _n(m['mae'])),

                    _dato('MAE referencia', _n(m['mae_referencia'])),
                  ],
                ),
                const Text(
                  'Gráfico y métricas del filtro completo, no solo de esta página.',
                ),
                const Text(
                  'El MAE indica cuántas unidades se desvía el modelo, en promedio. Un valor menor representa menos error en estas semanas de prueba.',
                ),
                ExpansionTile(
                  title: const Text('Ver evaluación del modelo'),
                  children: [
                    ListTile(
                      title: Text('RMSE: ${_n(m['rmse'])} unidades'),
                      subtitle: Text('Muestras evaluadas: ${m['muestras']}'),
                    ),
                    ListTile(
                      title: const Text('Identificación del modelo'),
                      subtitle: Text(
                        'Entrenado: ${r.entrenadoEn}\nDataset: ${r.dataset}',
                      ),
                    ),
                  ],
                ),
                SerieAnalitica(datos: r.serie),
              ] else ...[
                Text(
                  'Período analizado: ${r.ventana} días\nFecha de corte: ${r.fechaCorte}\nClientes sin compras en el período: ${r.sinCompras}',
                ),
                Wrap(
                  spacing: 8,
                  runSpacing: 8,
                  children: [
                    _dato('Clientes', m['clientes_analizados']),
                    _dato('Grupos', m['grupos']),
                  ],
                ),
                const Text(
                  'Distribución de clientes',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                ),
                const Text(
                  'Cada barra representa el porcentaje de clientes que pertenece al grupo.',
                ),
                for (final p in r.perfiles) _perfil(p),
                ExpansionTile(
                  title: const Text('Ver evaluación del modelo'),
                  children: [
                    ListTile(
                      title: Text('Silhouette: ${_n(m['silhouette'])}'),
                      subtitle: const Text(
                        'Mide la separación interna de los grupos; no es un porcentaje de exactitud.',
                      ),
                    ),
                    ListTile(
                      title: Text('ARI entre semillas: ${_n(m['ari_medio'])}'),
                      subtitle: const Text(
                        'Compara agrupaciones con distintas semillas; no garantiza estabilidad futura.',
                      ),
                    ),
                  ],
                ),
              ],
            ],
            if (r != null && r.total == 0)
              const Text(
                'No hay resultados para el origen y los filtros aplicados.',
              ),
            if (r != null && r.total > 0)
              OutlinedButton.icon(
                icon: Icon(
                  _mostrarDetalle
                      ? Icons.expand_less
                      : Icons.table_rows_outlined,
                ),
                label: Text(
                  _mostrarDetalle
                      ? 'Ocultar detalle del reporte'
                      : 'Ver detalle del reporte (${r.total} registros)',
                ),
                onPressed: () =>
                    setState(() => _mostrarDetalle = !_mostrarDetalle),
              ),
            if (_mostrarDetalle && r != null && r.filas.isNotEmpty) ...[
              const Text(
                'Detalle del filtro aplicado',
                style: TextStyle(fontSize: 20, fontWeight: FontWeight.bold),
              ),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: DataTable(
                  columns:
                      (_tipo == 'predicciones'
                              ? [
                                  'Corte / objetivo hasta',
                                  'Sucursal',
                                  'Producto',
                                  'Reales',
                                  'Predichas',
                                  'Referencia',
                                ]
                              : [
                                  'Cliente',
                                  'Grupo',
                                  'Recencia (días)',
                                  'Compras',
                                  'Gasto Bs',
                                ])
                          .map((t) => DataColumn(label: Text(t)))
                          .toList(),
                  rows: r.filas
                      .map(
                        (f) => DataRow(
                          cells:
                              (_tipo == 'predicciones'
                                      ? [
                                          '${f['fecha_corte']} / ${f['objetivo_hasta']}',
                                          f['sucursal'],
                                          f['producto_id'],
                                          _n(f['unidades_reales'], 1),
                                          _n(f['unidades_predichas'], 1),
                                          _n(
                                            f['referencia_semana_anterior'],
                                            1,
                                          ),
                                        ]
                                      : [
                                          f['cliente_id'],
                                          f['grupo'],
                                          f['recencia_dias'],
                                          f['frecuencia_compras'],
                                          ((f['gasto_centavos'] as num) / 100)
                                              .toStringAsFixed(2),
                                        ])
                                  .map((v) => DataCell(Text('$v')))
                                  .toList(),
                        ),
                      )
                      .toList(),
                ),
              ),
            ],
            if (_mostrarDetalle && r != null && r.total > 0)
              Wrap(
                spacing: 12,
                crossAxisAlignment: WrapCrossAlignment.center,
                children: [
                  OutlinedButton(
                    onPressed: _cargando || r.pagina <= 1
                        ? null
                        : () => _consultar(
                            pagina: r.pagina - 1,
                            reutilizar: true,
                          ),
                    child: const Text('Anterior'),
                  ),
                  Text('Página ${r.pagina} · ${r.total} registros'),
                  OutlinedButton(
                    onPressed: _cargando || r.pagina * r.tamano >= r.total
                        ? null
                        : () => _consultar(
                            pagina: r.pagina + 1,
                            reutilizar: true,
                          ),
                    child: const Text('Siguiente'),
                  ),
                ],
              ),
          ].expand((widget) => [widget, const SizedBox(height: 16)]).toList(),
        ),
      ),
    );
  }
}
