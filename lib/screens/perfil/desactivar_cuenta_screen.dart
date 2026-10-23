import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';

class DesactivarCuentaScreen extends StatefulWidget {
  const DesactivarCuentaScreen({super.key});
  @override
  State<DesactivarCuentaScreen> createState() => _DesactivarCuentaScreenState();
}

class _DesactivarCuentaScreenState extends State<DesactivarCuentaScreen> {
  final _password = TextEditingController();
  bool _confirmar = false;
  @override
  void dispose() {
    _password.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Desactivar mi cuenta')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              auth.empresa?.nombre ?? '',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: 20),
            const Text(
              'Se cerrarán todas tus sesiones y no podrás ingresar. Tus compras, reservas, pagos y direcciones se conservarán. No se eliminará tu historial.',
            ),
            const SizedBox(height: 12),
            const Text(
              'Para volver a habilitar la cuenta, contacta a la administración de tu empresa.',
            ),
            const SizedBox(height: 24),
            TextField(
              controller: _password,
              obscureText: true,
              decoration: const InputDecoration(labelText: 'Contraseña actual'),
              onChanged: (_) => setState(() {}),
            ),
            CheckboxListTile(
              contentPadding: EdgeInsets.zero,
              value: _confirmar,
              onChanged: auth.cargando
                  ? null
                  : (v) => setState(() => _confirmar = v ?? false),
              title: const Text(
                'Entiendo que perderé el acceso y quiero desactivar mi cuenta.',
              ),
            ),
            if (auth.error != null)
              Text(
                auth.error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            const SizedBox(height: 16),
            FilledButton(
              style: FilledButton.styleFrom(
                backgroundColor: Theme.of(context).colorScheme.error,
              ),
              onPressed: auth.cargando || !_confirmar || _password.text.isEmpty
                  ? null
                  : () => auth.desactivarCuenta(_password.text),
              child: Text(
                auth.cargando
                    ? 'Desactivando…'
                    : 'Confirmar desactivación de mi cuenta',
              ),
            ),
          ],
        ),
      ),
    );
  }
}
