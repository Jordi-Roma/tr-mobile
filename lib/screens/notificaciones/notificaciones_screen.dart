import 'package:flutter/material.dart';

import '../../core/session/contexto_sesion.dart';
import '../../services/notificaciones_service.dart';
import '../../services/firebase_push_service.dart';
import '../carrito/pago_stripe_screen.dart';

class NotificacionesScreen extends StatefulWidget {
  const NotificacionesScreen({super.key});
  @override
  State<NotificacionesScreen> createState() => _NotificacionesScreenState();
}

class _NotificacionesScreenState extends State<NotificacionesScreen> {
  List<NotificacionPropia> notas = [];
  List<Map<String, dynamic>> reembolsos = [];
  bool ocupado = false;
  String? error, aviso;
  int generacion = 0;
  @override
  void initState() {
    super.initState();
    generacion = ContextoSesion.instance.generacion;
    ContextoSesion.instance.addListener(cambio);
    FirebasePush.novedades.addListener(novedad);
    cargar();
  }

  @override
  void dispose() {
    ContextoSesion.instance.removeListener(cambio);
    FirebasePush.novedades.removeListener(novedad);
    super.dispose();
  }

  void cambio() {
    if (mounted && generacion != ContextoSesion.instance.generacion) {
      generacion = ContextoSesion.instance.generacion;
      setState(() {
        notas = [];
        reembolsos = [];
        error = 'La sesión cambió. Actualiza para consultar tu cuenta actual.';
      });
    }
  }

  void novedad() {
    if (mounted && !ocupado) cargar();
  }

  Future<void> cargar() async {
    if (ocupado) return;
    setState(() {
      ocupado = true;
      error = null;
    });
    try {
      final datos = await Future.wait([
        NotificacionesService.listar(),
        NotificacionesService.reembolsos(),
      ]);
      if (mounted) {
        setState(() {
          notas = datos[0] as List<NotificacionPropia>;
          reembolsos = datos[1] as List<Map<String, dynamic>>;
        });
      }
    } catch (_) {
      if (mounted) {
        setState(() {
          notas = [];
          reembolsos = [];
          error = 'No se pudieron consultar las notificaciones. Reintenta.';
        });
      }
    } finally {
      if (mounted) setState(() => ocupado = false);
    }
  }

  Future<void> leer(NotificacionPropia n) async {
    try {
      await NotificacionesService.leer(n.id);
      await cargar();
    } catch (_) {
      if (mounted) setState(() => error = 'No se pudo marcar la notificación.');
    }
  }

  Future<void> activar() async {
    try {
      final texto = await FirebasePush.activar();
      if (mounted) setState(() => aviso = texto);
    } catch (_) {
      if (mounted) {
        setState(
          () => aviso =
              'No se pudo activar Firebase. La bandeja sigue disponible.',
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Mis notificaciones'),
      actions: [
        IconButton(
          onPressed: ocupado ? null : cargar,
          icon: const Icon(Icons.refresh),
          tooltip: 'Actualizar notificaciones',
        ),
      ],
    ),
    body: ListView(
      padding: const EdgeInsets.all(16),
      children: [
        const Text(
          'Las actualizaciones pertenecen a tu cuenta y empresa actual.',
        ),
        TextButton(
          onPressed: activar,
          child: const Text('Activar avisos push'),
        ),
        if (aviso != null) Text(aviso!),
        if (ocupado) const LinearProgressIndicator(),
        if (error != null) ...[
          Text(error!),
          TextButton(onPressed: cargar, child: const Text('Reintentar')),
        ],
        if (notas.isEmpty && !ocupado && error == null)
          const Text('No tienes notificaciones en esta empresa.'),
        for (final n in notas)
          Card(
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    n.titulo,
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                  Text(n.mensaje),
                  Text(n.leida ? 'Leída' : 'Sin leer'),
                  if (!n.leida)
                    TextButton(
                      onPressed: ocupado ? null : () => leer(n),
                      child: const Text('Marcar como leída'),
                    ),
                  if (n.ordenId != null)
                    TextButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => PagoStripeScreen(
                            checkoutUrl: '',
                            ordenId: n.ordenId!,
                          ),
                        ),
                      ),
                      child: Text('Consultar orden #${n.ordenId}'),
                    ),
                ],
              ),
            ),
          ),
        const SizedBox(height: 16),
        const Text(
          'Mis reembolsos de compras no completadas',
          style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
        ),
        for (final r in reembolsos)
          Card(
            child: ListTile(
              title: Text('Orden #${r['orden_id']} · ${r['estado']}'),
              subtitle: Text(
                '${r['monto']} ${r['moneda']} · ${r['motivo']}\nReferencia: ${r['referencia'] ?? 'Aún no confirmada'}',
              ),
            ),
          ),
      ],
    ),
  );
}
