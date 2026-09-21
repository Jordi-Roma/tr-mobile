import 'catalogo_models.dart';

class RecomendacionPrendaItem {
  final CatalogoPrendaItem prenda;
  final String motivo;
  final double? score;

  RecomendacionPrendaItem({
    required this.prenda,
    required this.motivo,
    this.score,
  });

  factory RecomendacionPrendaItem.fromJson(Map<String, dynamic> json) {
    return RecomendacionPrendaItem(
      prenda: CatalogoPrendaItem.fromJson(json),
      motivo: json['motivo']?.toString() ?? 'Recomendado para ti',
      score: json['score'] != null ? double.tryParse(json['score'].toString()) : null,
    );
  }
}

class PreferenciasIA {
  final List<int> categorias;
  final bool usarHistorial;

  PreferenciasIA({
    this.categorias = const [],
    this.usarHistorial = true,
  });

  factory PreferenciasIA.fromJson(Map<String, dynamic> json) {
    return PreferenciasIA(
      categorias: (json['categorias'] as List<dynamic>?)
              ?.map((e) => int.tryParse(e.toString()) ?? 0)
              .where((e) => e > 0)
              .toList() ??
          [],
      usarHistorial: json['usar_historial'] ?? true,
    );
  }

  Map<String, dynamic> toJson() => {
        'categorias': categorias,
        'usar_historial': usarHistorial,
      };
}
