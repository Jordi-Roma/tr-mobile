import 'package:flutter/material.dart';
import '../../../core/constants/app_colors.dart';
import '../models/perfil_medidas.dart';

class MedidasBottomSheet extends StatefulWidget {
  final PerfilMedidas perfilActual;
  final ValueChanged<PerfilMedidas> onMedidasChanged;

  const MedidasBottomSheet({
    super.key,
    required this.perfilActual,
    required this.onMedidasChanged,
  });

  static Future<void> show(
    BuildContext context, {
    required PerfilMedidas perfilActual,
    required ValueChanged<PerfilMedidas> onMedidasChanged,
  }) {
    return showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      builder: (ctx) => MedidasBottomSheet(
        perfilActual: perfilActual,
        onMedidasChanged: onMedidasChanged,
      ),
    );
  }

  @override
  State<MedidasBottomSheet> createState() => _MedidasBottomSheetState();
}

class _MedidasBottomSheetState extends State<MedidasBottomSheet> {
  late double _estatura;
  late double _peso;
  late double _ajuste;

  @override
  void initState() {
    super.initState();
    _estatura = widget.perfilActual.estaturaCm;
    _peso = widget.perfilActual.pesoKg;
    _ajuste = widget.perfilActual.factorAjuste;
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 16,
        bottom: MediaQuery.of(context).viewInsets.bottom + 28,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Drag handle
          Center(
            child: Container(
              width: 40,
              height: 4,
              decoration: BoxDecoration(
                color: Colors.grey.shade300,
                borderRadius: BorderRadius.circular(2),
              ),
            ),
          ),
          const SizedBox(height: 16),

          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Calibración de Medidas AR',
                style: TextStyle(
                  fontFamily: 'Playfair Display',
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                  color: AppColors.primary,
                ),
              ),
              IconButton(
                icon: const Icon(Icons.close),
                onPressed: () => Navigator.of(context).pop(),
              ),
            ],
          ),
          const Text(
            'Ajusta tu estatura y complexión para una escala métrica exacta (px/cm) de la prenda en pantalla.',
            style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
          ),
          const SizedBox(height: 24),

          // Control Estatura
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Estatura',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_estatura.toInt()} cm',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: _estatura,
            min: 130,
            max: 210,
            divisions: 80,
            activeColor: AppColors.primary,
            onChanged: (val) {
              setState(() => _estatura = val);
              _notificar();
            },
          ),
          const SizedBox(height: 16),

          // Control Peso
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Peso aproximado',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
                decoration: BoxDecoration(
                  color: AppColors.primary.withValues(alpha: 0.08),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  '${_peso.toInt()} kg',
                  style: const TextStyle(
                    fontWeight: FontWeight.bold,
                    color: AppColors.primary,
                    fontSize: 15,
                  ),
                ),
              ),
            ],
          ),
          Slider(
            value: _peso,
            min: 40,
            max: 130,
            divisions: 90,
            activeColor: AppColors.primary,
            onChanged: (val) {
              setState(() => _peso = val);
              _notificar();
            },
          ),
          const SizedBox(height: 16),

          // Ajuste fino de holgura
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              const Text(
                'Calce deseado',
                style: TextStyle(fontWeight: FontWeight.w600, fontSize: 15),
              ),
              Text(
                _ajuste < 0.96
                    ? 'Ajustado'
                    : _ajuste > 1.05
                        ? 'Holgado'
                        : 'Estándar',
                style: const TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.accent,
                ),
              ),
            ],
          ),
          Slider(
            value: _ajuste,
            min: 0.90,
            max: 1.15,
            divisions: 25,
            activeColor: AppColors.accent,
            onChanged: (val) {
              setState(() => _ajuste = val);
              _notificar();
            },
          ),
          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 48,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.primary,
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              onPressed: () => Navigator.of(context).pop(),
              child: const Text(
                'Aplicar y Continuar',
                style: TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _notificar() {
    widget.onMedidasChanged(
      PerfilMedidas(
        estaturaCm: _estatura,
        pesoKg: _peso,
        factorAjuste: _ajuste,
      ),
    );
  }
}
