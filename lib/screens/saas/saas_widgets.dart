import 'package:flutter/material.dart';

import '../../core/session/contexto_sesion.dart';
import '../../core/network/api_exceptions.dart';

mixin PantallaSesion<T extends StatefulWidget> on State<T> {
  final int generacion = ContextoSesion.instance.generacion;
  bool get vigente =>
      mounted && generacion == ContextoSesion.instance.generacion;
  String explicar(Object e) => e is ApiException
      ? e.message
      : 'No se pudo completar la solicitud. Inténtalo nuevamente.';
}

String hoyBolivia() => DateTime.now()
    .toUtc()
    .subtract(const Duration(hours: 4))
    .toIso8601String()
    .substring(0, 10);
String fechaSaas(Object? valor) =>
    valor == null ? 'Sin fecha' : valor.toString().replaceFirst('T', ' ');
String? validarFechaSaas(String? valor, {bool opcional = false}) {
  if (opcional && (valor == null || valor.isEmpty)) return null;
  final fecha = DateTime.tryParse(valor ?? '');
  return fecha != null &&
          RegExp(r'^\d{4}-\d{2}-\d{2}$').hasMatch(valor!) &&
          fecha.toIso8601String().startsWith(valor)
      ? null
      : 'Usa una fecha válida AAAA-MM-DD.';
}

Future<bool> confirmarSaas(
  BuildContext context,
  String titulo,
  String texto,
) async =>
    await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: Text(titulo),
        content: SingleChildScrollView(child: Text(texto)),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Confirmar'),
          ),
        ],
      ),
    ) ??
    false;

class ErrorSaas extends StatelessWidget {
  const ErrorSaas(this.mensaje, {super.key, this.reintentar});
  final String mensaje;
  final VoidCallback? reintentar;
  @override
  Widget build(BuildContext context) => Column(
    crossAxisAlignment: CrossAxisAlignment.start,
    children: [
      Semantics(
        liveRegion: true,
        child: Text(
          mensaje,
          style: TextStyle(color: Theme.of(context).colorScheme.error),
        ),
      ),
      if (reintentar != null)
        OutlinedButton(
          onPressed: reintentar,
          child: const Text('Volver a intentar'),
        ),
    ],
  );
}
