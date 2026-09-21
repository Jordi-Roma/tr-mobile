import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/app_colors.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';

class RegistroScreen extends StatefulWidget {
  const RegistroScreen({super.key});

  @override
  State<RegistroScreen> createState() => _RegistroScreenState();
}

class _RegistroScreenState extends State<RegistroScreen> {
  final _formKey = GlobalKey<FormState>();
  final _nombreCtrl = TextEditingController();
  final _apellidoCtrl = TextEditingController();
  final _usernameCtrl = TextEditingController();
  final _correoCtrl = TextEditingController();
  final _telefonoCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();

  @override
  void dispose() {
    _nombreCtrl.dispose();
    _apellidoCtrl.dispose();
    _usernameCtrl.dispose();
    _correoCtrl.dispose();
    _telefonoCtrl.dispose();
    _passwordCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    final auth = context.read<AuthProvider>();
    final success = await auth.registrar(
      nombre: _nombreCtrl.text,
      apellido: _apellidoCtrl.text,
      username: _usernameCtrl.text,
      correo: _correoCtrl.text,
      password: _passwordCtrl.text,
      telefono: _telefonoCtrl.text,
    );

    if (success && mounted) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('¡Cuenta creada e inicio de sesión exitoso!'),
          backgroundColor: AppColors.success,
        ),
      );
      Navigator.of(context).pop(); // Vuelve a la pantalla principal
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    return Scaffold(
      appBar: AppBar(
        title: const Text('Crear Cuenta'),
      ),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Text(
                  'Únete a StyleAR',
                  style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(height: 6),
                const Text(
                  'Crea tu cuenta de cliente para explorar colecciones exclusivas y reservar tus prendas.',
                  style: TextStyle(
                    fontSize: 14,
                    color: AppColors.textSecondary,
                  ),
                ),
                const SizedBox(height: 24),

                // Mensaje de Error
                if (auth.error != null) ...[
                  Container(
                    padding: const EdgeInsets.all(12),
                    decoration: BoxDecoration(
                      color: AppColors.dangerSoft,
                      borderRadius: BorderRadius.circular(10),
                      border: Border.all(color: AppColors.danger.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const Icon(Icons.error_outline, color: AppColors.danger, size: 20),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            auth.error!,
                            style: const TextStyle(color: AppColors.danger, fontSize: 13),
                          ),
                        ),
                      ],
                    ),
                  ),
                  const SizedBox(height: 20),
                ],

                // Nombre y Apellido
                Row(
                  children: [
                    Expanded(
                      child: CustomTextField(
                        controller: _nombreCtrl,
                        label: 'Nombre *',
                        hintText: 'Juan',
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: CustomTextField(
                        controller: _apellidoCtrl,
                        label: 'Apellido *',
                        hintText: 'Pérez',
                        validator: (v) => (v == null || v.trim().isEmpty) ? 'Requerido' : null,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 16),

                // Nombre de Usuario
                CustomTextField(
                  controller: _usernameCtrl,
                  label: 'Nombre de Usuario *',
                  hintText: 'ej. juanperez99',
                  prefixIcon: Icons.alternate_email,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'El username es obligatorio';
                    if (v.trim().length < 4) return 'Mínimo 4 caracteres';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Correo
                CustomTextField(
                  controller: _correoCtrl,
                  label: 'Correo Electrónico *',
                  hintText: 'juan@correo.com',
                  prefixIcon: Icons.email_outlined,
                  keyboardType: TextInputType.emailAddress,
                  validator: (v) {
                    if (v == null || v.trim().isEmpty) return 'El correo es obligatorio';
                    if (!v.contains('@') || !v.contains('.')) return 'Correo inválido';
                    return null;
                  },
                ),
                const SizedBox(height: 16),

                // Teléfono
                CustomTextField(
                  controller: _telefonoCtrl,
                  label: 'Teléfono (opcional)',
                  hintText: 'ej. 70012345',
                  prefixIcon: Icons.phone_outlined,
                  keyboardType: TextInputType.phone,
                ),
                const SizedBox(height: 16),

                // Contraseña
                CustomTextField(
                  controller: _passwordCtrl,
                  label: 'Contraseña *',
                  hintText: 'Mínimo 8 caracteres con letras, números y símbolos',
                  prefixIcon: Icons.lock_outline,
                  isPassword: true,
                  validator: (v) {
                    if (v == null || v.isEmpty) return 'La contraseña es obligatoria';
                    if (v.length < 8) return 'Debe tener al menos 8 caracteres';
                    if (!v.contains(RegExp(r'[A-Z]'))) return 'Debe incluir una letra mayúscula';
                    if (!v.contains(RegExp(r'[a-z]'))) return 'Debe incluir una letra minúscula';
                    if (!v.contains(RegExp(r'[0-9]'))) return 'Debe incluir al menos un número';
                    if (!v.contains(RegExp(r'[!@#$%^&*(),.?":{}|<>]'))) {
                      return 'Debe incluir un símbolo especial (ej. !?#)';
                    }
                    return null;
                  },
                ),
                const SizedBox(height: 28),

                // Botón Registrarse
                CustomButton(
                  text: 'Crear Mi Cuenta',
                  isLoading: auth.cargando,
                  onPressed: _submit,
                ),
                const SizedBox(height: 20),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
