import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class PaymentStatusVisual {
  final String label;
  final String description;
  final IconData icon;
  final Color color;
  final Color background;

  const PaymentStatusVisual({
    required this.label,
    required this.description,
    required this.icon,
    required this.color,
    required this.background,
  });
}

PaymentStatusVisual paymentStatusVisual(String estado) {
  switch (estado.toUpperCase()) {
    case 'PAGADO':
    case 'COMPLETADO':
    case 'COMPLETADA':
      return const PaymentStatusVisual(
        label: 'Aprobado',
        description: 'El pago fue confirmado correctamente.',
        icon: Icons.check_circle_outline,
        color: AppColors.success,
        background: AppColors.successSoft,
      );
    case 'PENDIENTE':
      return const PaymentStatusVisual(
        label: 'Pendiente',
        description: 'El pago todavía está esperando confirmación.',
        icon: Icons.hourglass_empty_outlined,
        color: AppColors.warning,
        background: AppColors.warningSoft,
      );
    case 'RECHAZADO':
      return const PaymentStatusVisual(
        label: 'Rechazado',
        description: 'La pasarela rechazó el pago o no pudo completarlo.',
        icon: Icons.cancel_outlined,
        color: AppColors.danger,
        background: AppColors.dangerSoft,
      );
    case 'CANCELADO':
    case 'CANCELADA':
      return const PaymentStatusVisual(
        label: 'Cancelado',
        description: 'El pago fue cancelado antes de completarse.',
        icon: Icons.cancel_outlined,
        color: AppColors.danger,
        background: AppColors.dangerSoft,
      );
    case 'EXPIRADO':
      return const PaymentStatusVisual(
        label: 'Expirado',
        description: 'El tiempo para completar el pago venció.',
        icon: Icons.timer_off_outlined,
        color: AppColors.danger,
        background: AppColors.dangerSoft,
      );
    case 'FALLIDO':
      return const PaymentStatusVisual(
        label: 'Fallido',
        description: 'El pago no pudo procesarse correctamente.',
        icon: Icons.error_outline,
        color: AppColors.danger,
        background: AppColors.dangerSoft,
      );
    default:
      return PaymentStatusVisual(
        label: estado.isEmpty ? 'Sin estado' : estado,
        description: 'Estado registrado por el sistema.',
        icon: Icons.info_outline,
        color: AppColors.textSecondary,
        background: AppColors.background,
      );
  }
}

class PaymentStatusBadge extends StatelessWidget {
  final String estado;
  final bool showIcon;

  const PaymentStatusBadge({
    super.key,
    required this.estado,
    this.showIcon = false,
  });

  @override
  Widget build(BuildContext context) {
    final visual = paymentStatusVisual(estado);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: visual.background,
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (showIcon) ...[
            Icon(visual.icon, size: 14, color: visual.color),
            const SizedBox(width: 5),
          ],
          Text(
            visual.label,
            style: TextStyle(
              fontWeight: FontWeight.w900,
              color: visual.color,
              fontSize: 11,
            ),
          ),
        ],
      ),
    );
  }
}
