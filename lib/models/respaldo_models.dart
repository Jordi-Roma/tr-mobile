class Respaldo {
  final String id, tipo, origen, estado, fecha, venceEn;
  final int? empresaId;
  final int bytes;
  Respaldo.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      tipo = j['tipo'] as String,
      origen = j['origen'] as String,
      estado = j['estado'] as String,
      fecha = j['fecha'] as String,
      venceEn = j['vence_en'] as String,
      empresaId = (j['empresa_id'] as num?)?.toInt(),
      bytes = (j['bytes'] as num).toInt();
  String get origenNombre => switch (origen) {
    'MANUAL' => 'Manual',
    'AUTOMATICO' => 'Automático',
    'PRE_RESTAURACION' => 'Preventivo antes de restaurar',
    _ => 'Otro origen',
  };
}

class PreviaRespaldo {
  final String id, tipo, confirmacion, destino;
  final int? empresaId;
  final int archivos;
  final Map<String, int> conteos, actuales;
  PreviaRespaldo.fromJson(Map<String, dynamic> j)
    : id = j['id'] as String,
      tipo = j['tipo'] as String,
      confirmacion = j['confirmacion'] as String,
      destino = j['destino'] as String,
      empresaId = (j['empresa_id'] as num?)?.toInt(),
      archivos = (j['archivos'] as num).toInt(),
      conteos = ((j['conteos'] as Map<String, dynamic>?) ?? {}).map(
        (k, v) => MapEntry(k, (v as num).toInt()),
      ),
      actuales = ((j['conteos_actuales'] as Map<String, dynamic>?) ?? {}).map(
        (k, v) => MapEntry(k, (v as num).toInt()),
      );
}

class ConfiguracionRespaldos {
  final int manualesSemana, retencionDias;
  final int? frecuenciaDias;
  final bool horarioEditable, manualesHabilitados, activa;
  final String fechaInicio, hora, zona;
  final String? ultimoRespaldo;
  ConfiguracionRespaldos.fromJson(Map<String, dynamic> j)
    : manualesSemana = ((j['politica'] as Map)['manuales_semana'] as num)
          .toInt(),
      retencionDias = ((j['politica'] as Map)['retencion_dias'] as num).toInt(),
      frecuenciaDias = ((j['politica'] as Map)['frecuencia_dias'] as num?)
          ?.toInt(),
      horarioEditable = (j['politica'] as Map)['horario_editable'] == true,
      manualesHabilitados =
          (j['politica'] as Map)['manuales_habilitados'] == true,
      activa = (j['programacion'] as Map)['activa'] == true,
      fechaInicio = (j['programacion'] as Map)['fecha_inicio'] as String,
      hora = ((j['programacion'] as Map)['hora_local'] as String).substring(
        0,
        5,
      ),
      zona = (j['programacion'] as Map)['zona_horaria'] as String,
      ultimoRespaldo = (j['programacion'] as Map)['ultimo_respaldo'] as String?;
  Map<String, dynamic> datos({
    required bool activar,
    required String inicio,
    required String hora,
    required String zona,
    required bool editable,
  }) => {
    'activa': activar,
    'fecha_inicio': inicio,
    'hora_local': editable ? hora : '02:00',
    'zona_horaria': editable ? zona : 'America/La_Paz',
  };
}
