import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../models/capacidades_plan.dart';
import '../../providers/auth_provider.dart';
import '../../providers/plan_provider.dart';
import '../saas/saas_widgets.dart';

class CapacidadesPlanVista extends StatelessWidget {
  const CapacidadesPlanVista(this.plan, {super.key});
  final CapacidadesPlan plan;
  @override
  Widget build(BuildContext context) {
    final c = plan.catalogo;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          plan.plan['nombre'] as String? ?? 'Sin plan asignado',
          style: Theme.of(context).textTheme.titleLarge,
        ),
        Text('Suscripción: ${plan.suscripcion['estado'] ?? 'Sin suscripción'}'),
        Text('Inicio: ${fechaSaas(plan.suscripcion['fecha_inicio'])}'),
        Text(
          'Vencimiento: ${plan.suscripcion['fecha_vencimiento'] ?? 'Sin vencimiento'}',
        ),
        if (!plan.operacionesHabilitadas)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Text(
              'Operaciones nuevas restringidas. Puedes consultar tus datos y resolver pendientes.',
            ),
          ),
        const SizedBox(height: 16),
        Text('Uso y cupos', style: Theme.of(context).textTheme.titleMedium),
        ...(c['limites'] as List).map((valor) {
          final l = valor as Map<String, dynamic>,
              clave = l['clave'] as String,
              cupo = plan.cupos[clave];
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(l['nombre'] as String),
            subtitle: Text(
              cupo == null
                  ? '${plan.limites[clave] ?? 'Sin límite'} ${l['unidad']}'
                  : 'Uso: ${cupo.uso} · Límite: ${cupo.limite ?? 'Sin límite'} · Disponibles: ${cupo.disponibles ?? 'Sin límite'}${cupo.agotado ? ' · Cupo agotado' : ''}',
            ),
          );
        }),
        const SizedBox(height: 16),
        Text(
          'Funciones del plan',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        ...(c['funciones'] as List).map((valor) {
          final f = valor as Map<String, dynamic>, clave = f['clave'] as String;
          return ListTile(
            contentPadding: EdgeInsets.zero,
            title: Text(f['nombre'] as String),
            subtitle: Text(
              plan.habilita(clave) ? 'Habilitada' : plan.motivo(clave),
            ),
          );
        }),
        const Text(
          'Un empleado con cuenta consume también un usuario. Los respaldos manuales se cuentan en los últimos siete días.',
        ),
        const Text(
          'Reportes básicos, mayorista, delivery, asistente, recomendaciones y vestidor se incluyen sin diferenciar planes, según tus permisos.',
        ),
      ],
    );
  }
}

class MiPlanScreen extends StatefulWidget {
  const MiPlanScreen({super.key});
  @override
  State<MiPlanScreen> createState() => _MiPlanScreenState();
}

class _MiPlanScreenState extends State<MiPlanScreen> {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) context.read<PlanProvider>().refrescar();
    });
  }

  @override
  Widget build(BuildContext context) {
    final p = context.watch<PlanProvider>();
    if (!context.watch<AuthProvider>().esAdmin) return const SizedBox.shrink();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi plan'),
        actions: [
          IconButton(
            onPressed: p.cargando ? null : p.refrescar,
            icon: const Icon(Icons.refresh),
            tooltip: 'Actualizar plan',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: p.refrescar,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            if (p.cargando) const LinearProgressIndicator(),
            if (p.error != null) ErrorSaas(p.error!, reintentar: p.refrescar),
            if (p.capacidades != null) CapacidadesPlanVista(p.capacidades!),
          ],
        ),
      ),
    );
  }
}
