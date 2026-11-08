class FuenteAnalitica {
  final String origen, estado, advertencia;
  final String? evaluadoEn, fuenteDatos;
  final List<Map<String, dynamic>> sucursales;
  final Map<String, dynamic> resumen;
  FuenteAnalitica(Map<String, dynamic> j)
    : origen = j['origen'] as String,
      estado = j['estado'] as String,
      advertencia = j['advertencia'] as String,
      evaluadoEn = j['evaluado_en'] as String?,
      fuenteDatos = j['fuente_datos'] as String?,
      sucursales = (j['sucursales'] as List).cast<Map<String, dynamic>>(),
      resumen = (j['resumen_historial'] as Map<String, dynamic>?) ?? {};
}

class EstadoAnalitica {
  final List<FuenteAnalitica> fuentes;
  final bool segmentacionPermitida;
  EstadoAnalitica(Map<String, dynamic> j)
    : fuentes = (j['fuentes'] as List)
          .map((e) => FuenteAnalitica(e as Map<String, dynamic>))
          .toList(),
      segmentacionPermitida = j['segmentacion_permitida'] == true;
}

class PuntoAnalitica {
  final String corte;
  final double reales, predichas, referencia;
  PuntoAnalitica(Map<String, dynamic> j)
    : corte = j['fecha_corte'] as String,
      reales = (j['unidades_reales'] as num).toDouble(),
      predichas = (j['unidades_predichas'] as num).toDouble(),
      referencia = (j['referencia_semana_anterior'] as num).toDouble();
}

class ResultadoAnalitica {
  final String estado, advertencia;
  final int pagina, tamano, total;
  final List<Map<String, dynamic>> filas, perfiles;
  final List<PuntoAnalitica> serie;
  final List<String> productos;
  final Map<String, dynamic>? metricas;
  final String? fechaCorte, entrenadoEn, dataset;
  final int? ventana, sinCompras;
  ResultadoAnalitica(Map<String, dynamic> j)
    : estado = j['estado'] as String,
      advertencia = j['advertencia'] as String,
      pagina = j['pagina'] as int,
      tamano = j['tamano'] as int,
      total = j['total_filas'] as int,
      filas = (j['filas'] as List).cast<Map<String, dynamic>>(),
      perfiles = ((j['perfiles'] as List?) ?? []).cast<Map<String, dynamic>>(),
      serie = ((j['serie'] as List?) ?? [])
          .map((e) => PuntoAnalitica(e as Map<String, dynamic>))
          .toList(),
      productos = ((j['productos'] as List?) ?? []).cast<String>(),
      metricas = j['metricas'] as Map<String, dynamic>?,
      fechaCorte = j['fecha_corte'] as String?,
      entrenadoEn = j['entrenado_en'] as String?,
      dataset = j['dataset_id'] as String?,
      ventana = j['ventana_dias'] as int?,
      sinCompras = j['clientes_sin_compras_ventana'] as int?;
}
