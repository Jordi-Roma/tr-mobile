import 'package:flutter/material.dart';

class AppColors {
  AppColors._();

  // StyleAR Identity Palette
  static const Color primary = Color(0xFF111111);        // Sleek black / dark neutral
  static const Color primaryHover = Color(0xFF2A2A2A);
  static const Color surface = Color(0xFFFFFFFF);        // Pure white cards & modals
  static const Color background = Color(0xFFF5F5F2);     // Warm editorial light grey
  static const Color card = Color(0xFFFFFFFF);
  static const Color border = Color(0xFFE1E1DC);        // Subtle divider border
  
  // Accents & Indicators
  static const Color accent = Color(0xFF7C8F5A);         // Olive sage green (brand accent)
  static const Color accentSoft = Color(0xFFDDE5CF);     // Soft olive pill background
  static const Color textPrimary = Color(0xFF151515);    // High-contrast text
  static const Color textSecondary = Color(0xFF717171);  // Muted grey subtitles
  static const Color danger = Color(0xFFD94A38);         // Warning / error red
  static const Color dangerSoft = Color(0xFFFCEBE9);
  static const Color success = Color(0xFF3D8B5B);        // Confirmed / available green
  static const Color successSoft = Color(0xFFEAF5EF);
  static const Color warning = Color(0xFFE59819);        // Pending / warning amber
  static const Color warningSoft = Color(0xFFFEF7E9);
  static const Color info = Color(0xFF2D74B4);           // In progress blue
  static const Color infoSoft = Color(0xFFE8F2FB);

  // Status colors helper
  static Color getStatusColor(String estado) {
    switch (estado.toUpperCase()) {
      case 'PENDIENTE':
        return warning;
      case 'PREPARADA':
        return info;
      case 'EN_ATENCION':
        return const Color(0xFF8E44AD);
      case 'COMPLETADA':
        return success;
      case 'CANCELADA':
      case 'VENCIDA':
        return danger;
      default:
        return textSecondary;
    }
  }

  static Color getStatusBackground(String estado) {
    switch (estado.toUpperCase()) {
      case 'PENDIENTE':
        return warningSoft;
      case 'PREPARADA':
        return infoSoft;
      case 'EN_ATENCION':
        return const Color(0xFFF4ECF7);
      case 'COMPLETADA':
        return successSoft;
      case 'CANCELADA':
      case 'VENCIDA':
        return dangerSoft;
      default:
        return background;
    }
  }
}
