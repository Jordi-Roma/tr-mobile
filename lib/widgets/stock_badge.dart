import 'package:flutter/material.dart';
import '../core/constants/app_colors.dart';

class StockBadge extends StatelessWidget {
  final String text;
  final Color? textColor;
  final Color? backgroundColor;

  const StockBadge({
    super.key,
    required this.text,
    this.textColor,
    this.backgroundColor,
  });

  factory StockBadge.fromStock(int stockTotal) {
    if (stockTotal <= 0) {
      return const StockBadge(
        text: 'Agotado',
        textColor: AppColors.danger,
        backgroundColor: AppColors.dangerSoft,
      );
    } else if (stockTotal <= 5) {
      return StockBadge(
        text: 'Últimas $stockTotal unid.',
        textColor: AppColors.warning,
        backgroundColor: AppColors.warningSoft,
      );
    } else {
      return const StockBadge(
        text: 'En stock',
        textColor: AppColors.success,
        backgroundColor: AppColors.successSoft,
      );
    }
  }

  factory StockBadge.fromEstado(String estado) {
    return StockBadge(
      text: estado.replaceAll('_', ' '),
      textColor: AppColors.getStatusColor(estado),
      backgroundColor: AppColors.getStatusBackground(estado),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: backgroundColor ?? AppColors.accentSoft,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: TextStyle(
          fontSize: 11,
          fontWeight: FontWeight.w600,
          color: textColor ?? AppColors.accent,
        ),
      ),
    );
  }
}
