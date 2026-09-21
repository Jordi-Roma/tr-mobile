import 'dart:typed_data';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../models/reporte_models.dart';

class ReporteService {
  ReporteService._();

  /// Devuelve el catálogo de tipos de reporte y sucursales disponibles.
  static Future<ReporteCatalogo> obtenerCatalogo() async {
    final res = await ApiClient.get(ApiConstants.reportesCatalogo);
    return ReporteCatalogo.fromJson(res as Map<String, dynamic>);
  }

  /// Genera un reporte según los filtros indicados.
  static Future<ReporteResultado> generar(ReporteFiltros filtros) async {
    final res = await ApiClient.post(
      ApiConstants.reportesGenerar,
      body: filtros.toJson(),
    );
    return ReporteResultado.fromJson(res as Map<String, dynamic>);
  }

  /// Exporta el reporte como PDF (bytes).
  static Future<Uint8List> exportarPdf(ReporteFiltros filtros) async {
    return ApiClient.postBytes(
      ApiConstants.reportesExportarPdf,
      body: filtros.toJson(),
    );
  }

  /// Exporta el reporte como Excel (bytes).
  static Future<Uint8List> exportarExcel(ReporteFiltros filtros) async {
    return ApiClient.postBytes(
      ApiConstants.reportesExportarExcel,
      body: filtros.toJson(),
    );
  }

  /// Interpreta un texto o dictado por voz para extraer filtros de reporte automáticamente.
  static Future<ReporteInterpretacionResultado> interpretar(String texto) async {
    final res = await ApiClient.post(
      ApiConstants.reportesInterpretar,
      body: {'texto': texto},
    );
    return ReporteInterpretacionResultado.fromJson(res as Map<String, dynamic>);
  }

  /// Lista las programaciones automáticas de reportes existentes.
  static Future<List<ReporteProgramadoItem>> listarProgramados() async {
    final res = await ApiClient.get(ApiConstants.reportesProgramados);
    if (res is List) {
      return res
          .map((e) => ReporteProgramadoItem.fromJson(e as Map<String, dynamic>))
          .toList();
    }
    return [];
  }

  /// Crea una nueva programación automática de reporte.
  static Future<Map<String, dynamic>> crearProgramado(Map<String, dynamic> datos) async {
    final res = await ApiClient.post(
      ApiConstants.reportesProgramados,
      body: datos,
    );
    return res is Map<String, dynamic> ? res : {};
  }

  /// Activa o pausa una programación automática.
  static Future<Map<String, dynamic>> actualizarEstadoProgramado(int id, bool activo) async {
    final res = await ApiClient.patch(
      ApiConstants.reporteProgramadoEstado(id),
      body: {'activo': activo},
    );
    return res is Map<String, dynamic> ? res : {};
  }

  /// Elimina una programación de reporte.
  static Future<Map<String, dynamic>> eliminarProgramado(int id) async {
    final res = await ApiClient.delete(
      ApiConstants.reporteProgramadoDetalle(id),
    );
    return res is Map<String, dynamic> ? res : {};
  }

  /// Ejecuta inmediatamente un reporte programado y simula envío.
  static Future<Map<String, dynamic>> ejecutarProgramado(int id) async {
    final res = await ApiClient.post(
      ApiConstants.reporteProgramadoEjecutar(id),
    );
    return res is Map<String, dynamic> ? res : {};
  }
}

