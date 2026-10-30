import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../core/validacion_cuenta.dart';

class RecuperarPasswordScreen extends StatefulWidget {
  const RecuperarPasswordScreen({super.key});
  @override
  State<RecuperarPasswordScreen> createState() =>
      _RecuperarPasswordScreenState();
}

class _RecuperarPasswordScreenState extends State<RecuperarPasswordScreen> {
  final _form = GlobalKey<FormState>();
  final _identificador = TextEditingController();
  final _codigo = TextEditingController();
  final _password = TextEditingController();
  final _confirmar = TextEditingController();
  bool _enviado = false;
  String? _mensaje;
  @override
  void dispose() {
    _identificador.dispose();
    _codigo.dispose();
    _password.dispose();
    _confirmar.dispose();
    super.dispose();
  }

  Future<void> _enviar() async {
    if (!_form.currentState!.validate()) return;
    final mensaje = await context.read<AuthProvider>().solicitarRecuperacion(
      _identificador.text,
    );
    if (mounted && mensaje != null) {
      setState(() {
        _enviado = true;
        _mensaje = mensaje;
      });
    }
  }

  Future<void> _confirmarCodigo() async {
    if (!_form.currentState!.validate()) return;
    await context.read<AuthProvider>().confirmarRecuperacion(
      identificador: _identificador.text,
      codigo: _codigo.text,
      password: _password.text,
      confirmar: _confirmar.text,
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperar acceso')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Form(
            key: _form,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                Text(
                  auth.empresa?.nombre ?? '',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
                const SizedBox(height: 12),
                const Text(
                  'Ingresa tu usuario o correo para solicitar un código de recuperación.',
                ),
                const SizedBox(height: 20),
                TextFormField(
                  controller: _identificador,
                  readOnly: _enviado,
                  autofillHints: const [AutofillHints.username],
                  decoration: const InputDecoration(
                    labelText: 'Usuario o correo',
                  ),
                  validator: (v) => (v ?? '').trim().isEmpty
                      ? 'Ingresa tu usuario o correo.'
                      : null,
                ),
                const SizedBox(height: 16),
                if (_mensaje != null)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 16),
                    child: Text(_mensaje!),
                  ),
                if (_enviado) ...[
                  TextFormField(
                    controller: _codigo,
                    keyboardType: TextInputType.number,
                    autofillHints: const [AutofillHints.oneTimeCode],
                    decoration: const InputDecoration(
                      labelText: 'Código de seis dígitos',
                    ),
                    validator: (v) => RegExp(r'^\d{6}$').hasMatch(v ?? '')
                        ? null
                        : 'Ingresa los seis dígitos.',
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _password,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Nueva contraseña',
                    ),
                    validator: validarPasswordCuenta,
                  ),
                  const SizedBox(height: 16),
                  TextFormField(
                    controller: _confirmar,
                    obscureText: true,
                    decoration: const InputDecoration(
                      labelText: 'Confirmar nueva contraseña',
                    ),
                    validator: (v) => v == _password.text
                        ? null
                        : 'Las contraseñas no coinciden.',
                  ),
                  const SizedBox(height: 20),
                  FilledButton(
                    onPressed: auth.cargando ? null : _confirmarCodigo,
                    child: const Text('Restablecer contraseña'),
                  ),
                  TextButton(
                    onPressed: auth.cargando
                        ? null
                        : () => setState(() {
                            _enviado = false;
                            _mensaje = null;
                            _codigo.clear();
                            _password.clear();
                            _confirmar.clear();
                          }),
                    child: const Text(
                      'Solicitar otro código o corregir la cuenta',
                    ),
                  ),
                ] else
                  FilledButton(
                    onPressed: auth.cargando ? null : _enviar,
                    child: const Text('Solicitar código'),
                  ),
                if (auth.error != null)
                  Padding(
                    padding: const EdgeInsets.only(top: 16),
                    child: Text(
                      auth.error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                if (auth.cargando)
                  const Padding(
                    padding: EdgeInsets.all(16),
                    child: Center(child: CircularProgressIndicator()),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
