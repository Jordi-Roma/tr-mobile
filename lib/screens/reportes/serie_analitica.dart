import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../models/analitica_models.dart';

/// Padded, explicit range: keeps variation visible without hiding the axis origin.
({double minimo, double maximo}) rangoSerie(List<double> valores) {
  if (valores.isEmpty) return (minimo: 0, maximo: 1);
  final minimo = valores.reduce(math.min), maximo = valores.reduce(math.max);
  final margen = math.max(
    (maximo - minimo) * .2,
    math.max(maximo.abs() * .02, 1.0),
  );
  return (
    minimo: math.max(0, (minimo - margen).floorToDouble()),
    maximo: (maximo + margen).ceilToDouble(),
  );
}

class SerieAnalitica extends StatefulWidget {
  const SerieAnalitica({super.key, required this.datos});
  final List<PuntoAnalitica> datos;
  @override
  State<SerieAnalitica> createState() => _SerieAnaliticaState();
}

class _SerieAnaliticaState extends State<SerieAnalitica> {
  bool _referencia = false;
  @override
  Widget build(BuildContext context) {
    final rango = rangoSerie([
      for (final p in widget.datos) ...[
        p.reales,
        p.predichas,
        if (_referencia) p.referencia,
      ],
    ]);
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              'Ventas por semana',
              style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 12),
            Wrap(
              spacing: 16,
              runSpacing: 8,
              children: [
                _leyenda('Ventas observadas', const Color(0xff466333)),
                _leyenda('Predicción del modelo', const Color(0xff2468aa)),
                if (_referencia)
                  _leyenda('Semana anterior', const Color(0xff934e81)),
              ],
            ),
            const SizedBox(height: 20),
            Semantics(
              label: 'Comparación semanal. Valores exactos disponibles en Ver valores del gráfico.',
              child: SizedBox(
                height: 220,
                child: CustomPaint(
                  painter: _SeriePainter(widget.datos, _referencia, rango),
                ),
              ),
            ),
            Text(
              'Escala vertical ajustada: ${rango.minimo.toStringAsFixed(0)} a ${rango.maximo.toStringAsFixed(0)} unidades.',
              style: const TextStyle(fontSize: 12, color: Color(0xff454545)),
            ),
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Comparar con la semana anterior'),
              value: _referencia,
              onChanged: (v) => setState(() => _referencia = v),
            ),
            ExpansionTile(
              tilePadding: EdgeInsets.zero,
              title: const Text('Ver valores del gráfico'),
              children: [
                for (final p in widget.datos)
                  ListTile(
                    contentPadding: EdgeInsets.zero,
                    title: Text('Semana ${p.corte}'),
                    subtitle: Text(
                      'Observadas: ${p.reales.toStringAsFixed(1)}\nPredicción: ${p.predichas.toStringAsFixed(1)}\nSemana anterior: ${p.referencia.toStringAsFixed(1)}',
                    ),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  Widget _leyenda(String texto, Color color) => Row(
    mainAxisSize: MainAxisSize.min,
    children: [
      Container(width: 16, height: 4, color: color),
      const SizedBox(width: 8),
      Flexible(
        child: Text(
          texto,
          style: const TextStyle(fontSize: 13, color: Color(0xff202020)),
        ),
      ),
    ],
  );
}

class _SeriePainter extends CustomPainter {
  _SeriePainter(this.datos, this.referencia, this.rango);
  final List<PuntoAnalitica> datos;
  final bool referencia;
  final ({double minimo, double maximo}) rango;
  @override
  void paint(Canvas canvas, Size size) {
    if (datos.isEmpty) return;
    final ancho = math.max(1.0, size.width - 54), alto = size.height - 40;
    void texto(String valor, double x, double y, {bool centrar = false}) {
      final t = TextPainter(
        text: TextSpan(
          text: valor,
          style: const TextStyle(fontSize: 11, color: Color(0xff454545)),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      t.paint(
        canvas,
        Offset(
          centrar
              ? (x - t.width / 2)
                    .clamp(0, math.max(0, size.width - t.width))
                    .toDouble()
              : x,
          y,
        ),
      );
    }

    for (var i = 0; i <= 4; i++) {
      final y = 8 + alto * i / 4;
      canvas.drawLine(
        Offset(42, y),
        Offset(42 + ancho, y),
        Paint()..color = const Color(0xffdeded8),
      );
      texto(
        (rango.maximo - (rango.maximo - rango.minimo) * i / 4).toStringAsFixed(
          0,
        ),
        0,
        y - 6,
      );
    }
    final series = [
      datos.map((p) => p.reales).toList(),
      datos.map((p) => p.predichas).toList(),
      if (referencia) datos.map((p) => p.referencia).toList(),
    ];
    const colores = [Color(0xff466333), Color(0xff2468aa), Color(0xff934e81)];
    for (var s = 0; s < series.length; s++) {
      final puntos = [
        for (var i = 0; i < datos.length; i++)
          Offset(
            42 + i * ancho / math.max(1, datos.length - 1),
            8 +
                alto -
                (series[s][i] - rango.minimo) *
                    alto /
                    (rango.maximo - rango.minimo),
          ),
      ];
      final path = Path()..moveTo(puntos.first.dx, puntos.first.dy);
      for (final p in puntos.skip(1)) {
        path.lineTo(p.dx, p.dy);
      }
      canvas.drawPath(
        path,
        Paint()
          ..color = colores[s]
          ..strokeWidth = 2.5
          ..style = PaintingStyle.stroke,
      );
      for (final p in puntos) {
        canvas.drawCircle(p, 2.5, Paint()..color = colores[s]);
      }
    }
    for (final i in {
      0,
      if (datos.length > 2) datos.length ~/ 2,
      datos.length - 1,
    }) {
      final fecha = DateTime.tryParse(datos[i].corte);
      texto(
        fecha == null
            ? datos[i].corte
            : '${fecha.day.toString().padLeft(2, '0')}/${fecha.month.toString().padLeft(2, '0')}',
        42 + i * ancho / math.max(1, datos.length - 1),
        alto + 20,
        centrar: true,
      );
    }
  }

  @override
  bool shouldRepaint(covariant _SeriePainter old) =>
      old.datos != datos || old.referencia != referencia || old.rango != rango;
}
