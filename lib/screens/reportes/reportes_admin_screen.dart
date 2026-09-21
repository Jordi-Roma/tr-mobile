import 'dart:convert';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/constants/app_colors.dart';
import '../../core/network/api_exceptions.dart';
import '../../models/reporte_models.dart';
import '../../services/file_download_service.dart';
import '../../services/reporte_service.dart';
import '../../services/voz_service.dart';

/// Pantalla de Reportes y Dashboard para el Administrador (CU21).
class ReportesAdminScreen extends StatefulWidget {
  const ReportesAdminScreen({super.key});

  @override
  State<ReportesAdminScreen> createState() => _ReportesAdminScreenState();
}

class _ReportesAdminScreenState extends State<ReportesAdminScreen>
    with SingleTickerProviderStateMixin {
  // ── Estado del catálogo ──────────────────────────────────────────────
  ReporteCatalogo? _catalogo;
  bool _cargandoCatalogo = false;
  String? _errorCatalogo;

  // ── Filtros seleccionados ────────────────────────────────────────────
  TipoReporte _tipoSeleccionado = TipoReporte.ventas;
  DateTime _fechaDesde = DateTime.now().subtract(const Duration(days: 30));
  DateTime _fechaHasta = DateTime.now();
  int? _sucursalId;
  String _agrupacion = 'DIA';
  bool _soloBajoStock = false;
  String? _estado;
  String? _metodoPago;
  String? _proveedorPago;
  String? _tipoEntrega;
  String? _rol;
  bool? _activo;

  // ── Estado del reporte ───────────────────────────────────────────────
  ReporteResultado? _resultado;
  bool _generando = false;
  String? _errorReporte;

  // ── Exportar ─────────────────────────────────────────────────────────
  bool _exportando = false;

  // ── Reportes Programados ──────────────────────────────────────────────
  List<ReporteProgramadoItem> _programados = [];
  bool _cargandoProgramados = false;
  String? _errorProgramados;
  int? _ejecutandoId;

  // ── Tab controller ───────────────────────────────────────────────────
  late TabController _tabController;

  static const _dateFormat = 'yyyy-MM-dd';

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _cargarCatalogo();
    _cargarProgramados();
  }

  @override
  void dispose() {
    VozService.cancelar();
    _tabController.dispose();
    super.dispose();
  }

  // ── Carga de catálogo ────────────────────────────────────────────────

  Future<void> _cargarCatalogo() async {
    setState(() {
      _cargandoCatalogo = true;
      _errorCatalogo = null;
    });
    try {
      final catalogo = await ReporteService.obtenerCatalogo();
      if (mounted) {
        setState(() => _catalogo = catalogo);
        // Generar automáticamente el reporte inicial con los filtros por defecto
        _generarReporte(irAResultados: false);
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorCatalogo = e.message);
    } catch (_) {
      if (mounted) {
        setState(
          () => _errorCatalogo = 'Error al cargar el catálogo de reportes.',
        );
      }
    } finally {
      if (mounted) setState(() => _cargandoCatalogo = false);
    }
  }

  // ── Generar reporte ──────────────────────────────────────────────────

  Future<void> _generarReporte({bool irAResultados = true}) async {
    setState(() {
      _generando = true;
      _errorReporte = null;
      _resultado = null;
    });

    try {
      final filtros = _buildFiltros();
      final resultado = await ReporteService.generar(filtros);
      if (mounted) {
        setState(() => _resultado = resultado);
        if (irAResultados) {
          _tabController.animateTo(1);
        }
      }
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorReporte = e.message);
    } catch (_) {
      if (mounted) {
        setState(() => _errorReporte = 'Error al generar el reporte.');
      }
    } finally {
      if (mounted) setState(() => _generando = false);
    }
  }

  // ── Exportar ─────────────────────────────────────────────────────────

  Future<void> _exportar(String formato) async {
    if (_resultado == null) return;

    setState(() => _exportando = true);

    try {
      final filtros = _buildFiltros();
      final Uint8List bytes;
      final String ext;
      final String mimeType;

      if (formato == 'html') {
        bytes = Uint8List.fromList(utf8.encode(_buildHtmlReporte(_resultado!)));
        ext = 'html';
        mimeType = 'text/html; charset=utf-8';
      } else if (formato == 'pdf') {
        bytes = await ReporteService.exportarPdf(filtros);
        ext = 'pdf';
        mimeType = 'application/pdf';
      } else {
        bytes = await ReporteService.exportarExcel(filtros);
        ext = 'xlsx';
        mimeType =
            'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet';
      }

      final fname =
          '${_tipoSeleccionado.valor.toLowerCase()}_${DateFormat(_dateFormat).format(_fechaDesde)}_${DateFormat(_dateFormat).format(_fechaHasta)}.$ext';
      final ubicacion = await FileDownloadService.guardarYMostrarArchivo(
        bytes: bytes,
        nombreArchivo: fname,
        mimeType: mimeType,
      );

      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            ubicacion == null
                ? 'Descarga iniciada.'
                : 'Archivo guardado en: $ubicacion',
          ),
          backgroundColor: AppColors.success,
          duration: const Duration(seconds: 4),
        ),
      );
    } on ApiException catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.message), backgroundColor: AppColors.danger),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Error al exportar el reporte.'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _exportando = false);
    }
  }

  String _buildHtmlReporte(ReporteResultado resultado) {
    final fechaDesde = DateFormat(_dateFormat).format(_fechaDesde);
    final fechaHasta = DateFormat(_dateFormat).format(_fechaHasta);
    final generadoEn = resultado.generadoEn.isNotEmpty
        ? resultado.generadoEn
        : DateTime.now().toIso8601String();

    final buffer = StringBuffer()
      ..writeln('<!doctype html>')
      ..writeln('<html lang="es">')
      ..writeln('<head>')
      ..writeln('<meta charset="utf-8">')
      ..writeln(
        '<meta name="viewport" content="width=device-width, initial-scale=1">',
      )
      ..writeln('<title>${_htmlEscape(resultado.titulo)}</title>')
      ..writeln('''
<style>
  :root { color-scheme: light; --accent:#82936a; --border:#deded8; --text:#181818; --muted:#6f6f6f; }
  * { box-sizing: border-box; }
  body { margin: 0; font-family: Arial, Helvetica, sans-serif; background: #f7f7f3; color: var(--text); }
  main { max-width: 1100px; margin: 32px auto; padding: 0 20px 40px; }
  .card { background: #fff; border: 1px solid var(--border); border-radius: 18px; padding: 24px; box-shadow: 0 10px 28px rgba(0,0,0,.06); }
  .eyebrow { color: var(--accent); font-size: 12px; font-weight: 800; letter-spacing: .18em; text-transform: uppercase; }
  h1 { margin: 8px 0 8px; font-size: 34px; line-height: 1.1; }
  .meta { color: var(--muted); margin: 4px 0; }
  .note { margin-top: 14px; padding: 12px 14px; background: #eef4e6; border-radius: 12px; color: #49613f; }
  .metrics { display: grid; grid-template-columns: repeat(auto-fit, minmax(180px, 1fr)); gap: 12px; margin: 24px 0; }
  .metric { border: 1px solid var(--border); border-radius: 14px; padding: 16px; background: #fbfbf8; }
  .metric span { display: block; color: var(--muted); font-size: 13px; font-weight: 700; }
  .metric strong { display: block; margin-top: 8px; font-size: 26px; }
  h2 { margin: 26px 0 12px; font-size: 20px; }
  .bars { display: grid; gap: 10px; margin-bottom: 18px; }
  .bar-row { display: grid; grid-template-columns: minmax(90px, 180px) 1fr minmax(60px, 100px); gap: 10px; align-items: center; }
  .bar-label { color: var(--muted); overflow-wrap: anywhere; }
  .bar-track { height: 18px; background: #eeeeea; border-radius: 999px; overflow: hidden; }
  .bar-fill { height: 100%; background: var(--accent); border-radius: 999px; }
  .bar-value { text-align: right; font-weight: 700; }
  .table-wrap { overflow-x: auto; border: 1px solid var(--border); border-radius: 14px; }
  table { width: 100%; border-collapse: collapse; min-width: 720px; }
  th, td { padding: 12px 14px; border-bottom: 1px solid var(--border); text-align: left; vertical-align: top; }
  th { background: #f1f1ee; color: #666; font-size: 13px; text-transform: uppercase; letter-spacing: .04em; }
  tr:last-child td { border-bottom: 0; }
  footer { margin-top: 20px; color: var(--muted); font-size: 12px; text-align: center; }
  @media print { body { background: #fff; } main { margin: 0; max-width: none; } .card { box-shadow: none; border: 0; } }
</style>
''')
      ..writeln('</head>')
      ..writeln('<body>')
      ..writeln('<main>')
      ..writeln('<section class="card">')
      ..writeln('<div class="eyebrow">Reporte StyleAR</div>')
      ..writeln('<h1>${_htmlEscape(resultado.titulo)}</h1>')
      ..writeln(
        '<p class="meta">Periodo: ${_htmlEscape(fechaDesde)} al ${_htmlEscape(fechaHasta)}</p>',
      )
      ..writeln('<p class="meta">Generado: ${_htmlEscape(generadoEn)}</p>')
      ..writeln('<p class="meta">Filas: ${resultado.totalFilas}</p>');

    final nota = resultado.nota?.trim();
    if (nota != null && nota.isNotEmpty) {
      buffer.writeln('<div class="note">${_htmlEscape(nota)}</div>');
    }

    if (resultado.indicadores.isNotEmpty) {
      buffer.writeln('<div class="metrics">');
      for (final indicador in resultado.indicadores) {
        buffer
          ..writeln('<div class="metric">')
          ..writeln('<span>${_htmlEscape(indicador.label)}</span>')
          ..writeln(
            '<strong>${_htmlEscape(_valorCelda(indicador.valor))}</strong>',
          )
          ..writeln('</div>');
      }
      buffer.writeln('</div>');
    }

    if (resultado.serieGrafico.isNotEmpty) {
      final maxVal = resultado.serieGrafico
          .map((e) => e.valor.toDouble())
          .reduce((a, b) => a > b ? a : b);
      buffer
        ..writeln('<h2>Evolución temporal</h2>')
        ..writeln('<div class="bars">');
      for (final item in resultado.serieGrafico) {
        final width = maxVal > 0
            ? (item.valor.toDouble() / maxVal * 100).clamp(2, 100)
            : 2;
        buffer
          ..writeln('<div class="bar-row">')
          ..writeln('<div class="bar-label">${_htmlEscape(item.label)}</div>')
          ..writeln(
            '<div class="bar-track"><div class="bar-fill" style="width:$width%"></div></div>',
          )
          ..writeln(
            '<div class="bar-value">${_htmlEscape(item.valor.toString())}</div>',
          )
          ..writeln('</div>');
      }
      buffer.writeln('</div>');
    }

    if (resultado.filas.isNotEmpty) {
      buffer
        ..writeln('<h2>Tabla de datos</h2>')
        ..writeln('<div class="table-wrap">')
        ..writeln('<table>')
        ..writeln('<thead><tr>');
      for (final columna in resultado.columnas) {
        buffer.writeln('<th>${_htmlEscape(columna.label)}</th>');
      }
      buffer.writeln('</tr></thead><tbody>');
      for (final fila in resultado.filas) {
        buffer.writeln('<tr>');
        for (final columna in resultado.columnas) {
          buffer.writeln(
            '<td>${_htmlEscape(_valorCelda(fila[columna.key]))}</td>',
          );
        }
        buffer.writeln('</tr>');
      }
      buffer
        ..writeln('</tbody>')
        ..writeln('</table>')
        ..writeln('</div>');
    }

    buffer
      ..writeln('<footer>Archivo HTML generado desde StyleAR.</footer>')
      ..writeln('</section>')
      ..writeln('</main>')
      ..writeln('</body>')
      ..writeln('</html>');

    return buffer.toString();
  }

  String _valorCelda(dynamic valor) {
    if (valor == null) return '';
    if (valor is bool) return valor ? 'Sí' : 'No';
    return valor.toString();
  }

  String _htmlEscape(String valor) {
    return const HtmlEscape(HtmlEscapeMode.element).convert(valor);
  }

  ReporteFiltros _buildFiltros() => ReporteFiltros(
    tipo: _tipoSeleccionado,
    fechaDesde: DateFormat(_dateFormat).format(_fechaDesde),
    fechaHasta: DateFormat(_dateFormat).format(_fechaHasta),
    sucursalId: _sucursalId,
    agrupacion: _agrupacion,
    soloBajoStock: _soloBajoStock,
    estado: _estado,
    metodoPago: _metodoPago,
    proveedorPago: _proveedorPago,
    tipoEntrega: _tipoEntrega,
    rol: _rol,
    activo: _activo,
  );

  // ── Selección de fechas ──────────────────────────────────────────────

  Future<void> _seleccionarFecha({required bool esDesde}) async {
    final picked = await showDatePicker(
      context: context,
      initialDate: esDesde ? _fechaDesde : _fechaHasta,
      firstDate: DateTime(2020),
      lastDate: DateTime.now(),
      locale: const Locale('es'),
    );
    if (picked != null && mounted) {
      setState(() {
        if (esDesde) {
          _fechaDesde = picked;
          if (_fechaDesde.isAfter(_fechaHasta)) _fechaHasta = _fechaDesde;
        } else {
          _fechaHasta = picked;
          if (_fechaHasta.isBefore(_fechaDesde)) _fechaDesde = _fechaHasta;
        }
      });
    }
  }

  // ── Operaciones de Reportes Programados ───────────────────────────────

  Future<void> _cargarProgramados() async {
    setState(() {
      _cargandoProgramados = true;
      _errorProgramados = null;
    });
    try {
      final list = await ReporteService.listarProgramados();
      if (mounted) setState(() => _programados = list);
    } on ApiException catch (e) {
      if (mounted) setState(() => _errorProgramados = e.message);
    } catch (e) {
      if (mounted) {
        setState(
          () => _errorProgramados = 'Error al cargar reportes programados: $e',
        );
      }
    } finally {
      if (mounted) setState(() => _cargandoProgramados = false);
    }
  }

  Future<void> _cambiarEstadoProgramado(
    ReporteProgramadoItem item,
    bool activo,
  ) async {
    try {
      await ReporteService.actualizarEstadoProgramado(item.id, activo);
      if (mounted) {
        _cargarProgramados();
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              activo
                  ? 'Reporte "${item.titulo}" activado.'
                  : 'Reporte "${item.titulo}" pausado.',
            ),
            backgroundColor: activo ? AppColors.success : AppColors.warning,
            duration: const Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al cambiar estado: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    }
  }

  Future<void> _ejecutarProgramado(ReporteProgramadoItem item) async {
    setState(() => _ejecutandoId = item.id);
    try {
      final res = await ReporteService.ejecutarProgramado(item.id);
      if (mounted) {
        _cargarProgramados();
        final msg =
            res['mensaje']?.toString() ??
            'Reporte ejecutado y enviado a ${item.destinatarioEmail}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('✅ $msg'),
            backgroundColor: AppColors.success,
            duration: const Duration(seconds: 4),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Error al ejecutar reporte: $e'),
            backgroundColor: AppColors.danger,
          ),
        );
      }
    } finally {
      if (mounted) setState(() => _ejecutandoId = null);
    }
  }

  Future<void> _eliminarProgramado(ReporteProgramadoItem item) async {
    final confirmar = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('¿Eliminar programación?'),
        content: Text(
          'Se eliminará la programación automática del reporte "${item.titulo}".',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text(
              'Eliminar',
              style: TextStyle(color: Colors.white),
            ),
          ),
        ],
      ),
    );

    if (confirmar == true) {
      try {
        await ReporteService.eliminarProgramado(item.id);
        if (mounted) {
          _cargarProgramados();
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(
              content: Text('Programación eliminada.'),
              backgroundColor: AppColors.textPrimary,
              duration: Duration(seconds: 2),
            ),
          );
        }
      } catch (e) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text('Error al eliminar: $e'),
              backgroundColor: AppColors.danger,
            ),
          );
        }
      }
    }
  }

  Future<void> _mostrarModalNuevoProgramado() async {
    final tituloCtrl = TextEditingController();
    final emailCtrl = TextEditingController(text: 'admin@tiendaropa.com');
    final horaCtrl = TextEditingController(text: '08:00');
    TipoReporte tipo = TipoReporte.ventas;
    String frecuencia = 'DIARIA';
    String formato = 'PDF';
    String diaSemanal = 'LUNES';
    int? sucursalId;
    bool soloBajoStock = false;
    bool guardando = false;
    String? errorModal;

    await showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (dialogCtx, setDialogState) {
            final sucursales = _catalogo?.sucursales ?? [];
            return AlertDialog(
              title: const Row(
                children: [
                  Icon(Icons.alarm_add, color: AppColors.primary),
                  SizedBox(width: 8),
                  Text(
                    'Programar Reporte',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              content: SizedBox(
                width: double.maxFinite,
                child: SingleChildScrollView(
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Título
                      TextField(
                        controller: tituloCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Título del reporte *',
                          hintText: 'Ej. Reporte diario de ventas',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Tipo de Reporte
                      DropdownButtonFormField<TipoReporte>(
                        initialValue: tipo,
                        decoration: const InputDecoration(
                          labelText: 'Tipo de reporte',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: TipoReporte.values
                            .map(
                              (t) => DropdownMenuItem(
                                value: t,
                                child: Text(
                                  t.etiqueta,
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            )
                            .toList(),
                        onChanged: (val) {
                          if (val != null) setDialogState(() => tipo = val);
                        },
                      ),
                      const SizedBox(height: 14),

                      // Frecuencia
                      DropdownButtonFormField<String>(
                        initialValue: frecuencia,
                        decoration: const InputDecoration(
                          labelText: 'Frecuencia de envío',
                          border: OutlineInputBorder(),
                          isDense: true,
                        ),
                        items: const [
                          DropdownMenuItem(
                            value: 'DIARIA',
                            child: Text('Diaria'),
                          ),
                          DropdownMenuItem(
                            value: 'SEMANAL',
                            child: Text('Semanal'),
                          ),
                          DropdownMenuItem(
                            value: 'MENSUAL',
                            child: Text('Mensual'),
                          ),
                        ],
                        onChanged: (val) {
                          if (val != null) {
                            setDialogState(() => frecuencia = val);
                          }
                        },
                      ),
                      const SizedBox(height: 14),

                      // Día si es semanal
                      if (frecuencia == 'SEMANAL') ...[
                        DropdownButtonFormField<String>(
                          initialValue: diaSemanal,
                          decoration: const InputDecoration(
                            labelText: 'Día de la semana',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: const [
                            DropdownMenuItem(
                              value: 'LUNES',
                              child: Text('Lunes'),
                            ),
                            DropdownMenuItem(
                              value: 'MARTES',
                              child: Text('Martes'),
                            ),
                            DropdownMenuItem(
                              value: 'MIERCOLES',
                              child: Text('Miércoles'),
                            ),
                            DropdownMenuItem(
                              value: 'JUEVES',
                              child: Text('Jueves'),
                            ),
                            DropdownMenuItem(
                              value: 'VIERNES',
                              child: Text('Viernes'),
                            ),
                            DropdownMenuItem(
                              value: 'SABADO',
                              child: Text('Sábado'),
                            ),
                            DropdownMenuItem(
                              value: 'DOMINGO',
                              child: Text('Domingo'),
                            ),
                          ],
                          onChanged: (val) {
                            if (val != null) {
                              setDialogState(() => diaSemanal = val);
                            }
                          },
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Hora
                      TextField(
                        controller: horaCtrl,
                        decoration: const InputDecoration(
                          labelText: 'Hora de ejecución (HH:mm) *',
                          hintText: '08:00',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(Icons.access_time, size: 18),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Formato
                      Row(
                        children: [
                          const Text(
                            'Formato: ',
                            style: TextStyle(
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('PDF'),
                            selected: formato == 'PDF',
                            selectedColor: AppColors.primary,
                            labelStyle: TextStyle(
                              color: formato == 'PDF'
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontSize: 12,
                            ),
                            onSelected: (_) =>
                                setDialogState(() => formato = 'PDF'),
                          ),
                          const SizedBox(width: 8),
                          ChoiceChip(
                            label: const Text('EXCEL'),
                            selected: formato == 'EXCEL',
                            selectedColor: AppColors.success,
                            labelStyle: TextStyle(
                              color: formato == 'EXCEL'
                                  ? Colors.white
                                  : AppColors.textPrimary,
                              fontSize: 12,
                            ),
                            onSelected: (_) =>
                                setDialogState(() => formato = 'EXCEL'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 14),

                      // Email Destinatario
                      TextField(
                        controller: emailCtrl,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Correo destinatario *',
                          hintText: 'ejemplo@empresa.com',
                          border: OutlineInputBorder(),
                          isDense: true,
                          prefixIcon: Icon(Icons.email_outlined, size: 18),
                        ),
                      ),
                      const SizedBox(height: 14),

                      // Sucursal
                      if (sucursales.isNotEmpty) ...[
                        DropdownButtonFormField<int?>(
                          initialValue: sucursalId,
                          decoration: const InputDecoration(
                            labelText: 'Sucursal',
                            border: OutlineInputBorder(),
                            isDense: true,
                          ),
                          items: [
                            const DropdownMenuItem<int?>(
                              value: null,
                              child: Text(
                                'Todas las sucursales',
                                style: TextStyle(fontSize: 13),
                              ),
                            ),
                            ...sucursales.map(
                              (s) => DropdownMenuItem<int?>(
                                value: s.id,
                                child: Text(
                                  '${s.nombre} (${s.ciudad})',
                                  style: const TextStyle(fontSize: 13),
                                ),
                              ),
                            ),
                          ],
                          onChanged: (val) =>
                              setDialogState(() => sucursalId = val),
                        ),
                        const SizedBox(height: 14),
                      ],

                      // Solo bajo stock
                      if (tipo == TipoReporte.inventario)
                        CheckboxListTile(
                          contentPadding: EdgeInsets.zero,
                          title: const Text(
                            'Solo bajo stock',
                            style: TextStyle(fontSize: 13),
                          ),
                          value: soloBajoStock,
                          onChanged: (v) =>
                              setDialogState(() => soloBajoStock = v ?? false),
                          controlAffinity: ListTileControlAffinity.leading,
                        ),

                      if (errorModal != null) ...[
                        const SizedBox(height: 8),
                        Text(
                          errorModal!,
                          style: const TextStyle(
                            color: AppColors.danger,
                            fontSize: 12,
                          ),
                        ),
                      ],
                    ],
                  ),
                ),
              ),
              actions: [
                TextButton(
                  onPressed: guardando ? null : () => Navigator.pop(ctx),
                  child: const Text('Cancelar'),
                ),
                ElevatedButton(
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.primary,
                  ),
                  onPressed: guardando
                      ? null
                      : () async {
                          final titulo = tituloCtrl.text.trim();
                          final email = emailCtrl.text.trim();
                          final hora = horaCtrl.text.trim();

                          if (titulo.isEmpty) {
                            setDialogState(
                              () => errorModal =
                                  'Ingresa un título para el reporte.',
                            );
                            return;
                          }
                          if (email.isEmpty || !email.contains('@')) {
                            setDialogState(
                              () => errorModal =
                                  'Ingresa un correo electrónico válido.',
                            );
                            return;
                          }
                          if (hora.isEmpty) {
                            setDialogState(
                              () =>
                                  errorModal = 'Ingresa la hora de ejecución.',
                            );
                            return;
                          }

                          setDialogState(() {
                            guardando = true;
                            errorModal = null;
                          });

                          try {
                            await ReporteService.crearProgramado({
                              'titulo': titulo,
                              'tipo': tipo.valor,
                              'frecuencia': frecuencia,
                              'hora': hora,
                              'dia': frecuencia == 'SEMANAL'
                                  ? diaSemanal
                                  : null,
                              'formato': formato,
                              'destinatario_email': email,
                              'sucursal_id': sucursalId,
                              'solo_bajo_stock': soloBajoStock,
                              'activo': true,
                            });
                            if (!dialogCtx.mounted) return;
                            Navigator.pop(ctx);
                            _cargarProgramados();
                            if (mounted) {
                              ScaffoldMessenger.of(context).showSnackBar(
                                const SnackBar(
                                  content: Text(
                                    '✅ Reporte programado guardado y activado.',
                                  ),
                                  backgroundColor: AppColors.success,
                                  duration: Duration(seconds: 3),
                                ),
                              );
                            }
                          } catch (e) {
                            setDialogState(() {
                              guardando = false;
                              errorModal = 'Error al guardar: $e';
                            });
                          }
                        },
                  child: guardando
                      ? const SizedBox(
                          width: 16,
                          height: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Guardar',
                          style: TextStyle(color: Colors.white),
                        ),
                ),
              ],
            );
          },
        );
      },
    );
  }

  // ── Operaciones de Generación por Voz / IA ───────────────────────────

  Future<void> _abrirDialogoVoz() async {
    final textController = TextEditingController();
    bool interpretando = false;
    bool escuchando = false;
    String? errorVoz;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return StatefulBuilder(
          builder: (modalContext, setModalState) {
            Future<void> interpretarActual() async {
              final texto = textController.text.trim();
              if (texto.isEmpty) {
                setModalState(
                  () => errorVoz = 'Por favor ingresa o dicta una consulta.',
                );
                return;
              }
              setModalState(() {
                interpretando = true;
                escuchando = false;
                errorVoz = null;
              });
              try {
                final res = await ReporteService.interpretar(texto);
                if (!modalContext.mounted) return;
                Navigator.pop(ctx);
                if (mounted) {
                  _aplicarInterpretacion(res, texto);
                }
              } catch (e) {
                if (!modalContext.mounted) return;
                setModalState(() {
                  interpretando = false;
                  errorVoz = 'Error al interpretar consulta: $e';
                });
              }
            }

            return Container(
              padding: EdgeInsets.only(
                left: 20,
                right: 20,
                top: 20,
                bottom: MediaQuery.of(modalContext).viewInsets.bottom + 20,
              ),
              decoration: const BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
              ),
              child: SingleChildScrollView(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Center(
                      child: Container(
                        width: 40,
                        height: 4,
                        decoration: BoxDecoration(
                          color: Colors.grey[300],
                          borderRadius: BorderRadius.circular(2),
                        ),
                      ),
                    ),
                    const SizedBox(height: 16),
                    Row(
                      children: [
                        Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.15),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.mic,
                            color: AppColors.accent,
                            size: 26,
                          ),
                        ),
                        const SizedBox(width: 12),
                        const Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                'Generar Reporte por Voz / IA',
                                style: TextStyle(
                                  fontSize: 16,
                                  fontWeight: FontWeight.bold,
                                  color: AppColors.textPrimary,
                                ),
                              ),
                              Text(
                                'Dicta por voz o escribe tu consulta en lenguaje natural',
                                style: TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          icon: const Icon(Icons.close),
                          onPressed: () async {
                            await VozService.cancelar();
                            if (ctx.mounted) Navigator.pop(ctx);
                          },
                        ),
                      ],
                    ),
                    const SizedBox(height: 16),
                    TextField(
                      controller: textController,
                      autofocus: true,
                      decoration: InputDecoration(
                        hintText: 'Ej. "Ventas de esta semana" o "Inventario bajo stock"',
                        hintStyle: const TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                        filled: true,
                        fillColor: AppColors.background,
                        border: OutlineInputBorder(
                          borderRadius: BorderRadius.circular(14),
                          borderSide: const BorderSide(color: AppColors.border),
                        ),
                        prefixIcon: Icon(
                          escuchando
                              ? Icons.graphic_eq
                              : Icons.record_voice_over_outlined,
                          color: escuchando
                              ? AppColors.danger
                              : AppColors.accent,
                        ),
                        suffixIcon: textController.text.isNotEmpty
                            ? IconButton(
                                icon: const Icon(Icons.clear, size: 18),
                                onPressed: () =>
                                    setModalState(() => textController.clear()),
                              )
                            : null,
                      ),
                      onChanged: (_) => setModalState(() {}),
                    ),
                    const SizedBox(height: 10),
                    OutlinedButton.icon(
                      style: OutlinedButton.styleFrom(
                        foregroundColor: escuchando
                            ? AppColors.danger
                            : AppColors.accent,
                        side: BorderSide(
                          color: escuchando
                              ? AppColors.danger
                              : AppColors.accent,
                        ),
                        minimumSize: const Size.fromHeight(44),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: interpretando
                          ? null
                          : () async {
                              if (escuchando) {
                                await VozService.detener();
                                setModalState(() => escuchando = false);
                                return;
                              }

                              setModalState(() {
                                escuchando = true;
                                errorVoz = null;
                              });
                              await VozService.escuchar(
                                onTexto: (texto, finalizado) {
                                  if (!modalContext.mounted) return;
                                  setModalState(() {
                                    textController.text = texto;
                                    textController.selection =
                                        TextSelection.fromPosition(
                                          TextPosition(
                                            offset: textController.text.length,
                                          ),
                                        );
                                    escuchando = !finalizado;
                                  });
                                  if (finalizado &&
                                      texto.trim().isNotEmpty &&
                                      !interpretando) {
                                    Future.microtask(interpretarActual);
                                  }
                                },
                                onError: (mensaje) {
                                  if (!modalContext.mounted) return;
                                  setModalState(() {
                                    escuchando = false;
                                    errorVoz = mensaje;
                                  });
                                },
                              );
                            },
                      icon: Icon(
                        escuchando
                            ? Icons.stop_circle_outlined
                            : Icons.mic_none,
                      ),
                      label: Text(
                        escuchando ? 'Detener dictado' : 'Dictar consulta',
                      ),
                    ),
                    const SizedBox(height: 12),
                    const Text(
                      'Sugerencias rápidas por comando de voz:',
                      style: TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                        color: AppColors.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Wrap(
                      spacing: 6,
                      runSpacing: 6,
                      children:
                          [
                            'Ventas de esta semana',
                            'Ventas del último mes',
                            'Inventario bajo stock',
                            'Productos más vendidos',
                            'Reservas de los últimos 15 días',
                            'Transferencias de este mes',
                          ].map((prompt) {
                            return ActionChip(
                              avatar: const Icon(
                                Icons.mic_none,
                                size: 14,
                                color: AppColors.primary,
                              ),
                              label: Text(
                                prompt,
                                style: const TextStyle(fontSize: 11),
                              ),
                              backgroundColor: Colors.grey[100],
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(16),
                                side: BorderSide(color: Colors.grey[300]!),
                              ),
                              onPressed: () {
                                setModalState(() {
                                  textController.text = prompt;
                                });
                              },
                            );
                          }).toList(),
                    ),
                    if (errorVoz != null) ...[
                      const SizedBox(height: 10),
                      Text(
                        errorVoz!,
                        style: const TextStyle(
                          color: AppColors.danger,
                          fontSize: 12,
                        ),
                      ),
                    ],
                    const SizedBox(height: 20),
                    ElevatedButton.icon(
                      style: ElevatedButton.styleFrom(
                        backgroundColor: AppColors.primary,
                        foregroundColor: Colors.white,
                        minimumSize: const Size.fromHeight(48),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12),
                        ),
                      ),
                      onPressed: interpretando ? null : interpretarActual,
                      icon: interpretando
                          ? const SizedBox(
                              width: 18,
                              height: 18,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                color: Colors.white,
                              ),
                            )
                          : const Icon(Icons.auto_awesome),
                      label: Text(
                        interpretando
                            ? 'Interpretando con IA...'
                            : 'Interpretar y Generar Reporte',
                        style: const TextStyle(fontWeight: FontWeight.bold),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        );
      },
    );
    await VozService.cancelar();
    textController.dispose();
  }

  void _aplicarInterpretacion(
    ReporteInterpretacionResultado res,
    String textoOriginal,
  ) {
    final f = res.filtros;
    if (f.containsKey('tipo') && f['tipo'] != null) {
      final t = TipoReporte.desdeValor(f['tipo'].toString());
      if (t != null) _tipoSeleccionado = t;
    }
    if (f.containsKey('fecha_desde') && f['fecha_desde'] != null) {
      try {
        _fechaDesde = DateTime.parse(f['fecha_desde'].toString());
      } catch (_) {}
    }
    if (f.containsKey('fecha_hasta') && f['fecha_hasta'] != null) {
      try {
        _fechaHasta = DateTime.parse(f['fecha_hasta'].toString());
      } catch (_) {}
    }
    if (f.containsKey('sucursal_id')) {
      final sucursalValor = f['sucursal_id'];
      if (sucursalValor is int) {
        _sucursalId = sucursalValor;
      } else {
        _sucursalId = int.tryParse(sucursalValor?.toString() ?? '');
      }
    }
    if (f.containsKey('agrupacion') && f['agrupacion'] != null) {
      _agrupacion = f['agrupacion'].toString();
    }
    if (f.containsKey('solo_bajo_stock') && f['solo_bajo_stock'] != null) {
      _soloBajoStock = f['solo_bajo_stock'] == true;
    }
    _estado = null;
    _metodoPago = null;
    _proveedorPago = null;
    _tipoEntrega = null;
    _rol = null;
    _activo = null;

    final estado = _textoFiltro(f['estado']);
    if (estado != null && _opcionesEstado().containsKey(estado)) {
      _estado = estado;
    }

    final metodoPago = _textoFiltro(f['metodo_pago']);
    if (metodoPago == 'TARJETA') {
      _metodoPago = metodoPago;
    }

    final proveedorPago = _textoFiltro(f['proveedor_pago']);
    if (proveedorPago == 'STRIPE') {
      _proveedorPago = proveedorPago;
    }

    final tipoEntrega = _textoFiltro(f['tipo_entrega']);
    if (tipoEntrega == 'RECOJO_SUCURSAL' || tipoEntrega == 'DELIVERY') {
      _tipoEntrega = tipoEntrega;
    }

    final rol = _textoFiltro(f['rol']);
    if (rol == 'CLIENTE' ||
        rol == 'ADMINISTRADOR' ||
        rol == 'ENCARGADO_SUCURSAL') {
      _rol = rol;
    }

    if (f.containsKey('activo')) {
      final activoValor = f['activo'];
      if (activoValor is bool) {
        _activo = activoValor;
      } else if (activoValor != null) {
        final textoActivo = activoValor.toString().toLowerCase();
        if (textoActivo == 'true') _activo = true;
        if (textoActivo == 'false') _activo = false;
      }
    }

    setState(() {});

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text('Voz/IA: "$textoOriginal" interpretado.'),
        backgroundColor: AppColors.success,
        duration: const Duration(seconds: 3),
      ),
    );

    _generarReporte(irAResultados: true);
  }

  String? _textoFiltro(dynamic valor) {
    final texto = valor?.toString().trim();
    if (texto == null || texto.isEmpty || texto.toLowerCase() == 'null') {
      return null;
    }
    return texto.toUpperCase();
  }

  bool _usaFiltroEstado() {
    return {
      TipoReporte.ventas,
      TipoReporte.reservas,
      TipoReporte.movimientos,
      TipoReporte.transferencias,
      TipoReporte.pagos,
      TipoReporte.deliveries,
    }.contains(_tipoSeleccionado);
  }

  bool _usaFiltroEntrega() {
    return {
      TipoReporte.ventas,
      TipoReporte.productosMasVendidos,
      TipoReporte.pagos,
    }.contains(_tipoSeleccionado);
  }

  Map<String, String> _opcionesEstado() {
    switch (_tipoSeleccionado) {
      case TipoReporte.ventas:
        return const {
          'PENDIENTE_PAGO': 'Pendiente de pago',
          'COMPLETADA': 'Completada',
          'ANULADA': 'Anulada',
          'RECHAZADA': 'Rechazada',
          'CANCELADA': 'Cancelada',
        };
      case TipoReporte.reservas:
        return const {
          'PENDIENTE': 'Pendiente',
          'CONFIRMADA': 'Confirmada',
          'CANCELADA': 'Cancelada',
          'VENCIDA': 'Vencida',
          'RECOGIDA': 'Recogida',
        };
      case TipoReporte.movimientos:
        return const {
          'ENTRADA': 'Entrada',
          'SALIDA': 'Salida',
          'AJUSTE_POSITIVO': 'Ajuste positivo',
          'AJUSTE_NEGATIVO': 'Ajuste negativo',
          'TRANSFERENCIA_ENTRADA': 'Transferencia entrada',
          'TRANSFERENCIA_SALIDA': 'Transferencia salida',
          'VENTA_PRESENCIAL': 'Venta presencial',
          'VENTA_DIGITAL': 'Venta digital',
        };
      case TipoReporte.transferencias:
        return const {
          'PENDIENTE': 'Pendiente',
          'ENVIADA': 'Enviada',
          'RECIBIDA': 'Recibida',
          'CANCELADA': 'Cancelada',
        };
      case TipoReporte.pagos:
        return const {
          'PENDIENTE': 'Pendiente',
          'PAGADO': 'Pagado',
          'RECHAZADO': 'Rechazado',
          'EXPIRADO': 'Expirado',
          'CANCELADO': 'Cancelado',
        };
      case TipoReporte.deliveries:
        return const {
          'PENDIENTE': 'Pendiente',
          'EN_PREPARACION': 'En preparación',
          'EN_CAMINO': 'En camino',
          'ENTREGADO': 'Entregado',
          'CANCELADO': 'Cancelado',
        };
      default:
        return const {};
    }
  }

  // ── Build ─────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        elevation: 0,
        title: const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Reportes & Dashboard',
              style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
            ),
            Text(
              'Panel de análisis',
              style: TextStyle(fontSize: 11, color: Colors.white70),
            ),
          ],
        ),
        actions: [
          IconButton(
            icon: const Icon(Icons.mic, color: AppColors.accent),
            tooltip: 'Generar reporte por voz / IA',
            onPressed: _abrirDialogoVoz,
          ),
          IconButton(
            icon: const Icon(Icons.refresh),
            tooltip: 'Recargar',
            onPressed: () {
              if (_tabController.index == 2) {
                _cargarProgramados();
              } else {
                _generarReporte(irAResultados: false);
              }
            },
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.accent,
          labelColor: Colors.white,
          unselectedLabelColor: Colors.white60,
          tabs: const [
            Tab(icon: Icon(Icons.tune, size: 18), text: 'Filtros'),
            Tab(icon: Icon(Icons.bar_chart, size: 18), text: 'Resultados'),
            Tab(icon: Icon(Icons.schedule, size: 18), text: 'Automáticos'),
          ],
        ),
      ),
      body: _cargandoCatalogo
          ? const Center(
              child: CircularProgressIndicator(color: AppColors.accent),
            )
          : _errorCatalogo != null
          ? _ErrorView(mensaje: _errorCatalogo!, onReintentar: _cargarCatalogo)
          : TabBarView(
              controller: _tabController,
              children: [
                _buildFiltrosTab(),
                _buildResultadosTab(),
                _buildProgramadosTab(),
              ],
            ),
    );
  }

  // ── Tab de Filtros ────────────────────────────────────────────────────

  Widget _buildFiltrosTab() {
    final sucursales = _catalogo?.sucursales ?? [];

    return SingleChildScrollView(
      padding: const EdgeInsets.all(20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Banner de Generación por Voz / IA
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              gradient: const LinearGradient(
                colors: [AppColors.primary, Color(0xFF2C3E50)],
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
              ),
              borderRadius: BorderRadius.circular(14),
              boxShadow: [
                BoxShadow(
                  color: AppColors.primary.withValues(alpha: 0.2),
                  blurRadius: 8,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
            child: Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: AppColors.accent.withValues(alpha: 0.25),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(
                    Icons.mic,
                    color: AppColors.accent,
                    size: 24,
                  ),
                ),
                const SizedBox(width: 12),
                const Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        'Generar por Voz / IA',
                        style: TextStyle(
                          color: Colors.white,
                          fontWeight: FontWeight.bold,
                          fontSize: 14,
                        ),
                      ),
                      SizedBox(height: 2),
                      Text(
                        'Dicta o selecciona consultas en lenguaje natural.',
                        style: TextStyle(color: Colors.white70, fontSize: 11),
                      ),
                    ],
                  ),
                ),
                ElevatedButton(
                  onPressed: _abrirDialogoVoz,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppColors.accent,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 14,
                      vertical: 8,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                    elevation: 0,
                  ),
                  child: const Text(
                    'Hablar',
                    style: TextStyle(fontSize: 12, fontWeight: FontWeight.bold),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),

          // Tipo de Reporte
          _SectionTitle(titulo: 'Tipo de Reporte'),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: TipoReporte.values.map((tipo) {
              final seleccionado = _tipoSeleccionado == tipo;
              return ChoiceChip(
                label: Text(tipo.etiqueta),
                selected: seleccionado,
                onSelected: (_) => setState(() {
                  _tipoSeleccionado = tipo;
                  _estado = null;
                  _metodoPago = null;
                  _proveedorPago = null;
                  _tipoEntrega = null;
                  _rol = null;
                  _activo = null;
                  _resultado = null;
                }),
                selectedColor: AppColors.primary,
                labelStyle: TextStyle(
                  color: seleccionado ? Colors.white : AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: seleccionado
                      ? FontWeight.w700
                      : FontWeight.normal,
                ),
                backgroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: BorderSide(
                    color: seleccionado ? AppColors.primary : AppColors.border,
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 24),

          // Rango de Fechas
          _SectionTitle(titulo: 'Rango de Fechas'),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: _DateSelector(
                  label: 'Desde',
                  fecha: _fechaDesde,
                  onTap: () => _seleccionarFecha(esDesde: true),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _DateSelector(
                  label: 'Hasta',
                  fecha: _fechaHasta,
                  onTap: () => _seleccionarFecha(esDesde: false),
                ),
              ),
            ],
          ),
          const SizedBox(height: 24),

          // Sucursal
          if (sucursales.isNotEmpty) ...[
            _SectionTitle(titulo: 'Sucursal'),
            const SizedBox(height: 10),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(10),
                border: Border.all(color: AppColors.border),
              ),
              child: DropdownButtonHideUnderline(
                child: DropdownButton<int?>(
                  value: _sucursalId,
                  isExpanded: true,
                  items: [
                    const DropdownMenuItem<int?>(
                      value: null,
                      child: Text(
                        'Todas las sucursales',
                        style: TextStyle(
                          fontSize: 13,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ),
                    ...sucursales.map(
                      (s) => DropdownMenuItem<int?>(
                        value: s.id,
                        child: Text(
                          '${s.nombre} (${s.ciudad})',
                          style: const TextStyle(fontSize: 13),
                        ),
                      ),
                    ),
                  ],
                  onChanged: (val) => setState(() {
                    _sucursalId = val;
                    _resultado = null;
                  }),
                ),
              ),
            ),
            const SizedBox(height: 24),
          ],

          // Agrupación
          _SectionTitle(titulo: 'Agrupación de datos'),
          const SizedBox(height: 10),
          Row(
            children: ['DIA', 'MES'].map((ag) {
              final sel = _agrupacion == ag;
              return Expanded(
                child: GestureDetector(
                  onTap: () => setState(() => _agrupacion = ag),
                  child: Container(
                    margin: const EdgeInsets.only(right: 8),
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    decoration: BoxDecoration(
                      color: sel ? AppColors.primary : Colors.white,
                      borderRadius: BorderRadius.circular(8),
                      border: Border.all(
                        color: sel ? AppColors.primary : AppColors.border,
                      ),
                    ),
                    child: Text(
                      ag == 'DIA' ? 'Por Día' : 'Por Mes',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 13,
                        fontWeight: FontWeight.w600,
                        color: sel ? Colors.white : AppColors.textPrimary,
                      ),
                    ),
                  ),
                ),
              );
            }).toList(),
          ),
          const SizedBox(height: 16),

          if (_usaFiltroEstado()) ...[
            _SectionTitle(titulo: 'Estado / tipo'),
            const SizedBox(height: 10),
            _DropdownFiltro<String>(
              value: _estado,
              hint: 'Todos',
              items: _opcionesEstado(),
              onChanged: (v) => setState(() {
                _estado = v;
                _resultado = null;
              }),
            ),
            const SizedBox(height: 16),
          ],

          if (_usaFiltroEntrega()) ...[
            _SectionTitle(titulo: 'Tipo de entrega'),
            const SizedBox(height: 10),
            _DropdownFiltro<String>(
              value: _tipoEntrega,
              hint: 'Todas',
              items: const {
                'RECOJO_SUCURSAL': 'Recojo en sucursal',
                'DELIVERY': 'Delivery',
              },
              onChanged: (v) => setState(() {
                _tipoEntrega = v;
                _resultado = null;
              }),
            ),
            const SizedBox(height: 16),
          ],

          if (_tipoSeleccionado == TipoReporte.pagos) ...[
            _SectionTitle(titulo: 'Pago'),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _DropdownFiltro<String>(
                    value: _metodoPago,
                    hint: 'Método',
                    items: const {'TARJETA': 'Tarjeta'},
                    onChanged: (v) => setState(() {
                      _metodoPago = v;
                      _resultado = null;
                    }),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: _DropdownFiltro<String>(
                    value: _proveedorPago,
                    hint: 'Proveedor',
                    items: const {'STRIPE': 'Stripe'},
                    onChanged: (v) => setState(() {
                      _proveedorPago = v;
                      _resultado = null;
                    }),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
          ],

          if (_tipoSeleccionado == TipoReporte.usuarios) ...[
            _SectionTitle(titulo: 'Usuarios'),
            const SizedBox(height: 10),
            _DropdownFiltro<String>(
              value: _rol,
              hint: 'Todos los roles',
              items: const {
                'CLIENTE': 'Cliente',
                'ADMINISTRADOR': 'Administrador',
                'ENCARGADO_SUCURSAL': 'Encargado de sucursal',
              },
              onChanged: (v) => setState(() {
                _rol = v;
                _resultado = null;
              }),
            ),
            const SizedBox(height: 10),
            _DropdownFiltro<bool>(
              value: _activo,
              hint: 'Todos los estados',
              items: const {true: 'Activos', false: 'Inactivos'},
              onChanged: (v) => setState(() {
                _activo = v;
                _resultado = null;
              }),
            ),
            const SizedBox(height: 16),
          ],

          // Solo bajo stock
          if (_tipoSeleccionado == TipoReporte.inventario)
            SwitchListTile.adaptive(
              value: _soloBajoStock,
              onChanged: (v) => setState(() => _soloBajoStock = v),
              title: const Text(
                'Solo productos con bajo stock',
                style: TextStyle(fontSize: 13),
              ),
              activeThumbColor: AppColors.accent,
              contentPadding: EdgeInsets.zero,
            ),

          const SizedBox(height: 30),

          // Botón generar
          ElevatedButton.icon(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppColors.primary,
              foregroundColor: Colors.white,
              minimumSize: const Size.fromHeight(50),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
              elevation: 0,
            ),
            onPressed: _generando ? null : _generarReporte,
            icon: _generando
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                      strokeWidth: 2,
                      color: Colors.white,
                    ),
                  )
                : const Icon(Icons.analytics_outlined),
            label: Text(
              _generando ? 'Generando...' : 'Generar Reporte',
              style: const TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
            ),
          ),

          if (_errorReporte != null) ...[
            const SizedBox(height: 12),
            _ErrorInline(mensaje: _errorReporte!),
          ],
        ],
      ),
    );
  }

  // ── Tab de Resultados ─────────────────────────────────────────────────

  Widget _buildResultadosTab() {
    if (_generando) {
      return const Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            CircularProgressIndicator(color: AppColors.accent),
            SizedBox(height: 16),
            Text(
              'Generando reporte...',
              style: TextStyle(color: AppColors.textSecondary),
            ),
          ],
        ),
      );
    }

    if (_resultado == null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.analytics_outlined,
                size: 72,
                color: AppColors.primary.withValues(alpha: 0.3),
              ),
              const SizedBox(height: 16),
              const Text(
                'Sin reporte cargado',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Genera el reporte para analizar ventas, inventario, reservas o transferencias.',
                textAlign: TextAlign.center,
                style: TextStyle(color: AppColors.textSecondary, fontSize: 13),
              ),
              const SizedBox(height: 20),
              ElevatedButton.icon(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 24,
                    vertical: 12,
                  ),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(10),
                  ),
                ),
                onPressed: () => _generarReporte(irAResultados: true),
                icon: const Icon(Icons.analytics_outlined),
                label: const Text('Generar reporte ahora'),
              ),
              const SizedBox(height: 10),
              TextButton.icon(
                onPressed: () => _tabController.animateTo(0),
                icon: const Icon(Icons.tune, size: 16),
                label: const Text('Personalizar filtros'),
              ),
            ],
          ),
        ),
      );
    }

    final r = _resultado!;

    if (r.sinDatos) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.inbox_outlined, size: 72, color: Colors.grey[300]),
              const SizedBox(height: 16),
              const Text(
                'Sin datos para los filtros seleccionados',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: AppColors.textSecondary,
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              if (r.nota != null)
                Text(
                  r.nota!,
                  textAlign: TextAlign.center,
                  style: const TextStyle(
                    color: AppColors.textSecondary,
                    fontSize: 12,
                  ),
                ),
              const SizedBox(height: 20),
              OutlinedButton.icon(
                onPressed: () => _tabController.animateTo(0),
                icon: const Icon(Icons.tune),
                label: const Text('Modificar filtros'),
              ),
            ],
          ),
        ),
      );
    }

    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Barra de acceso rápido a filtros
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(10),
              border: Border.all(color: AppColors.border),
            ),
            child: Row(
              children: [
                const Icon(Icons.tune, size: 18, color: AppColors.primary),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${_tipoSeleccionado.etiqueta} · ${DateFormat('d MMM', 'es').format(_fechaDesde)} al ${DateFormat('d MMM', 'es').format(_fechaHasta)}',
                    style: const TextStyle(
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      color: AppColors.textPrimary,
                    ),
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                TextButton(
                  style: TextButton.styleFrom(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 8,
                      vertical: 4,
                    ),
                    minimumSize: Size.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                  onPressed: () => _tabController.animateTo(0),
                  child: const Text('Cambiar', style: TextStyle(fontSize: 12)),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),

          // Encabezado del reporte
          _ReporteHeader(resultado: r),
          const SizedBox(height: 16),

          // Indicadores
          if (r.indicadores.isNotEmpty) ...[
            _GridIndicadores(indicadores: r.indicadores),
            const SizedBox(height: 16),
          ],

          // Gráfico de barras
          if (r.serieGrafico.isNotEmpty) ...[
            _GraficoBarras(serie: r.serieGrafico, titulo: r.titulo),
            const SizedBox(height: 16),
          ],

          // Tabla de datos
          if (r.filas.isNotEmpty) ...[
            _TablaReporte(columnas: r.columnas, filas: r.filas),
            const SizedBox(height: 20),
          ],

          // Botones de exportación
          _ExportButtons(
            exportando: _exportando,
            onPdf: () => _exportar('pdf'),
            onExcel: () => _exportar('excel'),
            onHtml: () => _exportar('html'),
          ),
          const SizedBox(height: 20),
        ],
      ),
    );
  }

  // ── Tab de Reportes Automáticos / Programados ──────────────────────────

  Widget _buildProgramadosTab() {
    return RefreshIndicator(
      onRefresh: _cargarProgramados,
      color: AppColors.accent,
      child: SingleChildScrollView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Cabecera informativa y botón para crear nuevo
            Container(
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppColors.border),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.04),
                    blurRadius: 8,
                    offset: const Offset(0, 2),
                  ),
                ],
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: AppColors.primary.withValues(alpha: 0.1),
                          shape: BoxShape.circle,
                        ),
                        child: const Icon(
                          Icons.schedule_send,
                          color: AppColors.primary,
                          size: 22,
                        ),
                      ),
                      const SizedBox(width: 10),
                      const Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'Reportes Automáticos Programados',
                              style: TextStyle(
                                fontSize: 15,
                                fontWeight: FontWeight.bold,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            Text(
                              'Se generan y envían por correo periódicamente',
                              style: TextStyle(
                                fontSize: 11,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 14),
                  ElevatedButton.icon(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppColors.primary,
                      foregroundColor: Colors.white,
                      minimumSize: const Size.fromHeight(44),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(10),
                      ),
                      elevation: 0,
                    ),
                    onPressed: _mostrarModalNuevoProgramado,
                    icon: const Icon(Icons.add_alarm, size: 18),
                    label: const Text(
                      'Programar Nuevo Reporte',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 20),

            if (_cargandoProgramados)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(40),
                  child: CircularProgressIndicator(color: AppColors.accent),
                ),
              )
            else if (_errorProgramados != null)
              Container(
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: AppColors.danger.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                    color: AppColors.danger.withValues(alpha: 0.3),
                  ),
                ),
                child: Column(
                  children: [
                    Text(
                      _errorProgramados!,
                      style: const TextStyle(
                        color: AppColors.danger,
                        fontSize: 13,
                      ),
                    ),
                    const SizedBox(height: 8),
                    TextButton.icon(
                      onPressed: _cargarProgramados,
                      icon: const Icon(Icons.refresh, size: 16),
                      label: const Text('Reintentar'),
                    ),
                  ],
                ),
              )
            else if (_programados.isEmpty)
              Center(
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: 40),
                  child: Column(
                    children: [
                      Icon(
                        Icons.alarm_off_outlined,
                        size: 64,
                        color: Colors.grey[300],
                      ),
                      const SizedBox(height: 16),
                      const Text(
                        'No hay reportes programados',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 6),
                      const Text(
                        'Crea tu primer reporte automático para recibir análisis periódicos.',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 12,
                          color: AppColors.textSecondary,
                        ),
                      ),
                    ],
                  ),
                ),
              )
            else
              ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: _programados.length,
                separatorBuilder: (_, _) => const SizedBox(height: 14),
                itemBuilder: (context, index) {
                  final item = _programados[index];
                  final ejecutandoEste = _ejecutandoId == item.id;

                  return Container(
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: Colors.white,
                      borderRadius: BorderRadius.circular(14),
                      border: Border.all(
                        color: item.activo
                            ? AppColors.border
                            : Colors.grey[300]!,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: Colors.black.withValues(alpha: 0.03),
                          blurRadius: 6,
                          offset: const Offset(0, 2),
                        ),
                      ],
                    ),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        // Título y Switch de estado
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Expanded(
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Text(
                                    item.titulo,
                                    style: TextStyle(
                                      fontSize: 15,
                                      fontWeight: FontWeight.bold,
                                      color: item.activo
                                          ? AppColors.textPrimary
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                  const SizedBox(height: 4),
                                  Text(
                                    '${item.frecuencia} a las ${item.hora}${item.dia != null ? ' (${item.dia})' : ''}',
                                    style: TextStyle(
                                      fontSize: 12,
                                      fontWeight: FontWeight.w600,
                                      color: item.activo
                                          ? AppColors.primary
                                          : AppColors.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                            Switch.adaptive(
                              value: item.activo,
                              activeThumbColor: AppColors.accent,
                              onChanged: (val) =>
                                  _cambiarEstadoProgramado(item, val),
                            ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Badges de Tipo, Formato, Sucursal
                        Wrap(
                          spacing: 6,
                          runSpacing: 6,
                          children: [
                            _BadgeChip(
                              icon: Icons.analytics_outlined,
                              label: item.tipo,
                              color: AppColors.primary,
                            ),
                            _BadgeChip(
                              icon: item.formato == 'PDF'
                                  ? Icons.picture_as_pdf
                                  : Icons.table_chart,
                              label: item.formato,
                              color: item.formato == 'PDF'
                                  ? AppColors.danger
                                  : AppColors.success,
                            ),
                            if (item.sucursalNombre != null)
                              _BadgeChip(
                                icon: Icons.storefront,
                                label: item.sucursalNombre!,
                                color: AppColors.accent,
                              )
                            else
                              const _BadgeChip(
                                icon: Icons.storefront,
                                label: 'Todas las sucursales',
                                color: AppColors.textSecondary,
                              ),
                            if (item.soloBajoStock)
                              const _BadgeChip(
                                icon: Icons.warning_amber,
                                label: 'Bajo stock',
                                color: AppColors.warning,
                              ),
                          ],
                        ),
                        const SizedBox(height: 12),

                        // Email destinatario
                        Row(
                          children: [
                            const Icon(
                              Icons.email_outlined,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                item.destinatarioEmail,
                                style: const TextStyle(
                                  fontSize: 12,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),

                        // Info de ejecuciones
                        const SizedBox(height: 6),
                        Row(
                          children: [
                            const Icon(
                              Icons.history,
                              size: 14,
                              color: AppColors.textSecondary,
                            ),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                item.ultimaEjecucion != null
                                    ? 'Última: ${item.ultimaEjecucion}'
                                    : 'Aún no se ha ejecutado',
                                style: const TextStyle(
                                  fontSize: 11,
                                  color: AppColors.textSecondary,
                                ),
                              ),
                            ),
                          ],
                        ),

                        const Divider(height: 20),

                        // Acciones: Ejecutar ahora y Eliminar
                        Row(
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          children: [
                            OutlinedButton.icon(
                              style: OutlinedButton.styleFrom(
                                foregroundColor: AppColors.primary,
                                side: const BorderSide(
                                  color: AppColors.primary,
                                ),
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 14,
                                  vertical: 8,
                                ),
                                shape: RoundedRectangleBorder(
                                  borderRadius: BorderRadius.circular(8),
                                ),
                              ),
                              onPressed: ejecutandoEste
                                  ? null
                                  : () => _ejecutarProgramado(item),
                              icon: ejecutandoEste
                                  ? const SizedBox(
                                      width: 14,
                                      height: 14,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: AppColors.primary,
                                      ),
                                    )
                                  : const Icon(
                                      Icons.play_arrow_rounded,
                                      size: 18,
                                    ),
                              label: Text(
                                ejecutandoEste
                                    ? 'Enviando...'
                                    : 'Ejecutar ahora',
                                style: const TextStyle(
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            IconButton(
                              icon: const Icon(
                                Icons.delete_outline,
                                color: AppColors.danger,
                                size: 20,
                              ),
                              tooltip: 'Eliminar programación',
                              onPressed: () => _eliminarProgramado(item),
                            ),
                          ],
                        ),
                      ],
                    ),
                  );
                },
              ),
          ],
        ),
      ),
    );
  }
}

// ─── Widgets auxiliares ───────────────────────────────────────────────────────

class _DropdownFiltro<T> extends StatelessWidget {
  final T? value;
  final String hint;
  final Map<T, String> items;
  final ValueChanged<T?> onChanged;

  const _DropdownFiltro({
    required this.value,
    required this.hint,
    required this.items,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppColors.border),
      ),
      child: DropdownButtonHideUnderline(
        child: DropdownButton<T?>(
          value: value,
          isExpanded: true,
          hint: Text(
            hint,
            style: const TextStyle(
              fontSize: 13,
              color: AppColors.textSecondary,
            ),
          ),
          items: [
            DropdownMenuItem<T?>(
              value: null,
              child: Text(
                hint,
                style: const TextStyle(
                  fontSize: 13,
                  color: AppColors.textSecondary,
                ),
              ),
            ),
            ...items.entries.map(
              (entry) => DropdownMenuItem<T?>(
                value: entry.key,
                child: Text(entry.value, style: const TextStyle(fontSize: 13)),
              ),
            ),
          ],
          onChanged: onChanged,
        ),
      ),
    );
  }
}

class _BadgeChip extends StatelessWidget {
  final IconData icon;
  final String label;
  final Color color;

  const _BadgeChip({
    required this.icon,
    required this.label,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(6),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 12, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              fontSize: 11,
              fontWeight: FontWeight.w600,
              color: color,
            ),
          ),
        ],
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String titulo;
  const _SectionTitle({required this.titulo});

  @override
  Widget build(BuildContext context) => Text(
    titulo,
    style: const TextStyle(
      fontSize: 13,
      fontWeight: FontWeight.w700,
      color: AppColors.textSecondary,
      letterSpacing: 0.5,
    ),
  );
}

class _DateSelector extends StatelessWidget {
  final String label;
  final DateTime fecha;
  final VoidCallback onTap;
  const _DateSelector({
    required this.label,
    required this.fecha,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(10),
          border: Border.all(color: AppColors.border),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              label,
              style: const TextStyle(
                fontSize: 10,
                color: AppColors.textSecondary,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 2),
            Row(
              children: [
                const Icon(
                  Icons.calendar_today_outlined,
                  size: 14,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 6),
                Text(
                  DateFormat('d MMM yyyy', 'es').format(fecha),
                  style: const TextStyle(
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String mensaje;
  final VoidCallback onReintentar;
  const _ErrorView({required this.mensaje, required this.onReintentar});

  @override
  Widget build(BuildContext context) => Center(
    child: Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        const Icon(Icons.error_outline, color: AppColors.danger, size: 48),
        const SizedBox(height: 12),
        Text(
          mensaje,
          textAlign: TextAlign.center,
          style: const TextStyle(color: AppColors.textSecondary),
        ),
        const SizedBox(height: 16),
        OutlinedButton(
          onPressed: onReintentar,
          child: const Text('Reintentar'),
        ),
      ],
    ),
  );
}

class _ErrorInline extends StatelessWidget {
  final String mensaje;
  const _ErrorInline({required this.mensaje});

  @override
  Widget build(BuildContext context) => Container(
    padding: const EdgeInsets.all(12),
    decoration: BoxDecoration(
      color: AppColors.dangerSoft,
      borderRadius: BorderRadius.circular(8),
    ),
    child: Row(
      children: [
        const Icon(Icons.error_outline, color: AppColors.danger, size: 16),
        const SizedBox(width: 8),
        Expanded(
          child: Text(
            mensaje,
            style: const TextStyle(color: AppColors.danger, fontSize: 12),
          ),
        ),
      ],
    ),
  );
}

// ─── Encabezado del reporte ───────────────────────────────────────────────────

class _ReporteHeader extends StatelessWidget {
  final ReporteResultado resultado;
  const _ReporteHeader({required this.resultado});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            resultado.titulo,
            style: const TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.bold,
              color: AppColors.textPrimary,
            ),
          ),
          if (resultado.nota != null) ...[
            const SizedBox(height: 4),
            Text(
              resultado.nota!,
              style: const TextStyle(
                fontSize: 12,
                color: AppColors.textSecondary,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Row(
            children: [
              const Icon(
                Icons.access_time_outlined,
                size: 12,
                color: AppColors.textSecondary,
              ),
              const SizedBox(width: 4),
              Text(
                'Generado: ${resultado.generadoEn.split('T').first}',
                style: const TextStyle(
                  fontSize: 11,
                  color: AppColors.textSecondary,
                ),
              ),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color: AppColors.accentSoft,
                  borderRadius: BorderRadius.circular(20),
                ),
                child: Text(
                  '${resultado.totalFilas} registros',
                  style: const TextStyle(
                    fontSize: 10,
                    fontWeight: FontWeight.w600,
                    color: AppColors.accent,
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ─── Grid de indicadores KPI ──────────────────────────────────────────────────

class _GridIndicadores extends StatelessWidget {
  final List<ReporteIndicador> indicadores;
  const _GridIndicadores({required this.indicadores});

  @override
  Widget build(BuildContext context) {
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: indicadores.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 10,
        crossAxisSpacing: 10,
        childAspectRatio: 2.0,
      ),
      itemBuilder: (_, i) {
        final ind = indicadores[i];
        final isMoneda =
            ind.label.toLowerCase().contains('total') ||
            ind.label.toLowerCase().contains('ingreso') ||
            ind.label.toLowerCase().contains('promedio') ||
            ind.label.toLowerCase().contains('monto');
        final valorFmt = isMoneda
            ? NumberFormat.currency(
                locale: 'es_BO',
                symbol: 'Bs. ',
              ).format(ind.valor)
            : NumberFormat.decimalPattern('es').format(ind.valor);

        return Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: AppColors.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(
                ind.label,
                style: const TextStyle(
                  fontSize: 10,
                  color: AppColors.textSecondary,
                  fontWeight: FontWeight.w600,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
              const SizedBox(height: 4),
              Text(
                valorFmt,
                style: const TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

// ─── Gráfico de barras custom ─────────────────────────────────────────────────

class _GraficoBarras extends StatelessWidget {
  final List<ReporteSerieItem> serie;
  final String titulo;
  const _GraficoBarras({required this.serie, required this.titulo});

  @override
  Widget build(BuildContext context) {
    if (serie.isEmpty) return const SizedBox.shrink();

    final maxVal = serie
        .map((e) => e.valor.toDouble())
        .reduce((a, b) => a > b ? a : b);
    final isMoneda =
        titulo.toLowerCase().contains('venta') ||
        titulo.toLowerCase().contains('ingreso');

    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.bar_chart_outlined,
                size: 16,
                color: AppColors.accent,
              ),
              const SizedBox(width: 6),
              Text(
                'Evolución temporal',
                style: const TextStyle(
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                  color: AppColors.textPrimary,
                ),
              ),
            ],
          ),
          const SizedBox(height: 14),
          SizedBox(
            height: 180,
            child: _BarChartCustom(
              serie: serie,
              maxVal: maxVal,
              isMoneda: isMoneda,
            ),
          ),
        ],
      ),
    );
  }
}

class _BarChartCustom extends StatelessWidget {
  final List<ReporteSerieItem> serie;
  final double maxVal;
  final bool isMoneda;
  const _BarChartCustom({
    required this.serie,
    required this.maxVal,
    required this.isMoneda,
  });

  @override
  Widget build(BuildContext context) {
    // Muestra máx 12 items (condensar si hay más)
    final items = serie.length > 12
        ? [for (int i = 0; i < serie.length; i += serie.length ~/ 12) serie[i]]
        : serie;

    return LayoutBuilder(
      builder: (context, constraints) {
        const valueHeight = 18.0;
        const labelHeight = 18.0;
        const verticalGap = 6.0;
        final barMaxHeight =
            (constraints.maxHeight - valueHeight - labelHeight - verticalGap)
                .clamp(24.0, constraints.maxHeight);

        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: items.asMap().entries.map((entry) {
            final item = entry.value;
            final ratio = maxVal > 0 ? (item.valor.toDouble() / maxVal) : 0.0;
            final isMax =
                item.valor ==
                items.map((e) => e.valor).reduce((a, b) => a > b ? a : b);

            return Expanded(
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 2),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    SizedBox(
                      height: valueHeight,
                      child: Center(
                        child: isMax
                            ? Container(
                                padding: const EdgeInsets.symmetric(
                                  horizontal: 4,
                                  vertical: 2,
                                ),
                                decoration: BoxDecoration(
                                  color: AppColors.accent,
                                  borderRadius: BorderRadius.circular(4),
                                ),
                                child: Text(
                                  isMoneda
                                      ? 'Bs.${item.valor.toStringAsFixed(0)}'
                                      : item.valor.toStringAsFixed(0),
                                  style: const TextStyle(
                                    fontSize: 7,
                                    color: Colors.white,
                                    fontWeight: FontWeight.bold,
                                  ),
                                ),
                              )
                            : const SizedBox.shrink(),
                      ),
                    ),
                    const SizedBox(height: 2),
                    AnimatedContainer(
                      duration: Duration(milliseconds: 400 + entry.key * 50),
                      curve: Curves.easeOutCubic,
                      height: (barMaxHeight * ratio).clamp(4.0, barMaxHeight),
                      decoration: BoxDecoration(
                        color: isMax ? AppColors.accent : AppColors.primary,
                        borderRadius: const BorderRadius.vertical(
                          top: Radius.circular(4),
                        ),
                      ),
                    ),
                    const SizedBox(height: 4),
                    SizedBox(
                      height: labelHeight,
                      child: Text(
                        _shortLabel(item.label),
                        style: const TextStyle(
                          fontSize: 7,
                          color: AppColors.textSecondary,
                        ),
                        overflow: TextOverflow.ellipsis,
                        maxLines: 1,
                        textAlign: TextAlign.center,
                      ),
                    ),
                  ],
                ),
              ),
            );
          }).toList(),
        );
      },
    );
  }

  String _shortLabel(String label) {
    if (label.length > 5) return label.substring(0, 5);
    return label;
  }
}

// ─── Tabla de datos del reporte ───────────────────────────────────────────────

class _TablaReporte extends StatefulWidget {
  final List<ReporteColumna> columnas;
  final List<Map<String, dynamic>> filas;
  const _TablaReporte({required this.columnas, required this.filas});

  @override
  State<_TablaReporte> createState() => _TablaReporteState();
}

class _TablaReporteState extends State<_TablaReporte> {
  static const _pageSize = 15;
  int _pagina = 0;

  @override
  Widget build(BuildContext context) {
    final totalPaginas = (widget.filas.length / _pageSize).ceil();
    final inicio = _pagina * _pageSize;
    final fin = (inicio + _pageSize).clamp(0, widget.filas.length);
    final filasActuales = widget.filas.sublist(inicio, fin);

    return Container(
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppColors.border),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Encabezado de tabla
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                const Icon(
                  Icons.table_chart_outlined,
                  size: 16,
                  color: AppColors.accent,
                ),
                const SizedBox(width: 6),
                const Text(
                  'Tabla de datos',
                  style: TextStyle(fontSize: 13, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                Text(
                  '${widget.filas.length} filas',
                  style: const TextStyle(
                    fontSize: 11,
                    color: AppColors.textSecondary,
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          // Tabla con scroll horizontal
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: DataTable(
              headingRowHeight: 36,
              dataRowMinHeight: 32,
              dataRowMaxHeight: 48,
              columnSpacing: 16,
              headingTextStyle: const TextStyle(
                fontSize: 11,
                fontWeight: FontWeight.w700,
                color: AppColors.textSecondary,
              ),
              dataTextStyle: const TextStyle(
                fontSize: 11,
                color: AppColors.textPrimary,
              ),
              headingRowColor: WidgetStateProperty.all(AppColors.background),
              columns: widget.columnas
                  .map((c) => DataColumn(label: Text(c.label)))
                  .toList(),
              rows: filasActuales.map((fila) {
                return DataRow(
                  cells: widget.columnas.map((c) {
                    final val = fila[c.key];
                    String txt = val?.toString() ?? '-';
                    return DataCell(Text(txt));
                  }).toList(),
                );
              }).toList(),
            ),
          ),
          // Paginación
          if (totalPaginas > 1)
            Padding(
              padding: const EdgeInsets.all(10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  IconButton(
                    icon: const Icon(Icons.chevron_left),
                    onPressed: _pagina > 0
                        ? () => setState(() => _pagina--)
                        : null,
                    color: AppColors.primary,
                  ),
                  Text(
                    'Pág ${_pagina + 1} de $totalPaginas',
                    style: const TextStyle(
                      fontSize: 12,
                      color: AppColors.textSecondary,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.chevron_right),
                    onPressed: _pagina < totalPaginas - 1
                        ? () => setState(() => _pagina++)
                        : null,
                    color: AppColors.primary,
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

// ─── Botones de exportación ───────────────────────────────────────────────────

class _ExportButtons extends StatelessWidget {
  final bool exportando;
  final VoidCallback onPdf;
  final VoidCallback onExcel;
  final VoidCallback onHtml;
  const _ExportButtons({
    required this.exportando,
    required this.onPdf,
    required this.onExcel,
    required this.onHtml,
  });

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        const Divider(),
        const SizedBox(height: 8),
        if (exportando)
          const Center(
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                CircularProgressIndicator(
                  strokeWidth: 2,
                  color: AppColors.accent,
                ),
                SizedBox(width: 12),
                Text(
                  'Descargando...',
                  style: TextStyle(color: AppColors.textSecondary),
                ),
              ],
            ),
          )
        else
          Wrap(
            spacing: 12,
            runSpacing: 10,
            children: [
              _ExportButton(
                label: 'PDF',
                icon: Icons.picture_as_pdf_outlined,
                color: AppColors.danger,
                onPressed: onPdf,
              ),
              _ExportButton(
                label: 'Excel',
                icon: Icons.table_chart_outlined,
                color: AppColors.success,
                onPressed: onExcel,
              ),
              _ExportButton(
                label: 'HTML',
                icon: Icons.html_outlined,
                color: AppColors.accent,
                onPressed: onHtml,
              ),
            ],
          ),
      ],
    );
  }
}

class _ExportButton extends StatelessWidget {
  final String label;
  final IconData icon;
  final Color color;
  final VoidCallback onPressed;

  const _ExportButton({
    required this.label,
    required this.icon,
    required this.color,
    required this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          side: BorderSide(color: color),
          foregroundColor: color,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(10),
          ),
          padding: const EdgeInsets.symmetric(vertical: 12),
        ),
        onPressed: onPressed,
        icon: Icon(icon, size: 18),
        label: Text(label, style: const TextStyle(fontWeight: FontWeight.w600)),
      ),
    );
  }
}
