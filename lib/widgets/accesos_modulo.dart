import 'package:flutter/material.dart';

class AccesoModulo {
  const AccesoModulo(this.nombre, this.icono, this.abrir);
  final String nombre;
  final IconData icono;
  final VoidCallback abrir;
}

class AccesosModulo extends StatelessWidget {
  const AccesosModulo({super.key, required this.accesos});
  final List<AccesoModulo> accesos;
  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, constraints) {
      final columnas = constraints.maxWidth > 600 ? 4 : 2;
      final ancho = (constraints.maxWidth - (columnas - 1) * 12) / columnas;
      return Wrap(
        spacing: 12,
        runSpacing: 12,
        children: [
          for (final a in accesos)
            SizedBox(
              width: ancho,
              child: OutlinedButton(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.all(16),
                  minimumSize: Size(0, ancho),
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14),
                  ),
                ),
                onPressed: a.abrir,
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(a.icono, size: 28),
                    const SizedBox(height: 12),
                    Text(a.nombre, textAlign: TextAlign.center),
                  ],
                ),
              ),
            ),
        ],
      );
    },
  );
}
