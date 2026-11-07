class FuncionPlan {
  final bool incluida;
  final bool habilitada;
  final String? motivo;
  FuncionPlan.fromJson(Map<String, dynamic> json)
    : incluida = json['incluida'] == true,
      habilitada = json['habilitada'] == true,
      motivo = json['motivo'] as String?;
}

class CupoPlan {
  final int? limite;
  final int uso;
  final int? disponibles;
  final bool agotado;
  final String? motivo;
  CupoPlan.fromJson(Map<String, dynamic> json)
    : limite = (json['limite'] as num?)?.toInt(),
      uso = (json['uso'] as num?)?.toInt() ?? 0,
      disponibles = (json['disponibles'] as num?)?.toInt(),
      agotado = json['agotado'] == true,
      motivo = json['motivo'] as String?;
}

class CapacidadesPlan {
  final int empresaId;
  final bool operacionesHabilitadas;
  final Map<String, dynamic> plan, suscripcion, catalogo;
  final Map<String, FuncionPlan> funciones;
  final Map<String, CupoPlan> cupos;
  final Map<String, dynamic> limites, uso;
  CapacidadesPlan.fromJson(Map<String, dynamic> json)
    : empresaId = (json['empresa_id'] as num).toInt(),
      operacionesHabilitadas = json['operaciones_habilitadas'] == true,
      plan = Map<String, dynamic>.from(json['plan'] as Map),
      suscripcion = Map<String, dynamic>.from(json['suscripcion'] as Map),
      catalogo = Map<String, dynamic>.from(json['catalogo'] as Map),
      limites = Map<String, dynamic>.from(json['limites'] as Map),
      uso = Map<String, dynamic>.from(json['uso'] as Map),
      funciones = (json['funciones'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, FuncionPlan.fromJson(v as Map<String, dynamic>)),
      ),
      cupos = (json['cupos'] as Map<String, dynamic>).map(
        (k, v) => MapEntry(k, CupoPlan.fromJson(v as Map<String, dynamic>)),
      );

  bool habilita(String clave) => funciones[clave]?.habilitada == true;
  String motivo(String clave) => explicarMotivo(funciones[clave]?.motivo);
  static String explicarMotivo(String? motivo) => switch (motivo) {
    'FUNCION_NO_INCLUIDA' => 'No incluido en tu plan.',
    'SUSCRIPCION_NO_VIGENTE' => 'La suscripción no está vigente.',
    'CUPO_AGOTADO' => 'Se alcanzó el cupo de tu plan.',
    _ => 'Actualiza la información de tu plan.',
  };
}
