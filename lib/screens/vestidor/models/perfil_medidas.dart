class PerfilMedidas {
  final double estaturaCm;
  final double pesoKg;
  final double factorAjuste;

  const PerfilMedidas({
    this.estaturaCm = 172.0,
    this.pesoKg = 68.0,
    this.factorAjuste = 1.0,
  });

  PerfilMedidas copyWith({
    double? estaturaCm,
    double? pesoKg,
    double? factorAjuste,
  }) {
    return PerfilMedidas(
      estaturaCm: estaturaCm ?? this.estaturaCm,
      pesoKg: pesoKg ?? this.pesoKg,
      factorAjuste: factorAjuste ?? this.factorAjuste,
    );
  }

  /// Calcula la escala métrica de píxeles por centímetro basada en la distancia
  /// anatómica medida del torso (hombros a caderas) respecto a la estatura real.
  /// En antropometría estándar, el torso representa aprox. el 30% de la estatura.
  double calcularPxPorCmTorso(double torsoPixeles) {
    final torsoCmEstimado = estaturaCm * 0.30;
    if (torsoCmEstimado <= 0) return 1.0;
    return (torsoPixeles / torsoCmEstimado) * factorAjuste;
  }

  /// Calcula la escala métrica para prendas inferiores (caderas a tobillos).
  /// En antropometría estándar, las piernas representan aprox. el 50% de la estatura.
  double calcularPxPorCmPiernas(double piernasPixeles) {
    final piernasCmEstimado = estaturaCm * 0.50;
    if (piernasCmEstimado <= 0) return 1.0;
    return (piernasPixeles / piernasCmEstimado) * factorAjuste;
  }

  String get resumen => '${estaturaCm.toInt()} cm • ${pesoKg.toInt()} kg';
}
