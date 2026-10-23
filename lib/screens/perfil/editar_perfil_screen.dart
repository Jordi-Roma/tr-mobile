import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../core/validacion_cuenta.dart';

class EditarPerfilScreen extends StatefulWidget {
  const EditarPerfilScreen({super.key});
  @override
  State<EditarPerfilScreen> createState() => _EditarPerfilScreenState();
}

class _EditarPerfilScreenState extends State<EditarPerfilScreen> {
  final _form = GlobalKey<FormState>();
  final _nombre = TextEditingController(),
      _apellido = TextEditingController(),
      _usuario = TextEditingController(),
      _correo = TextEditingController(),
      _telefono = TextEditingController(),
      _password = TextEditingController();
  bool _cargando = true;
  bool _perfilDisponible = false;
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() => _cargando = true);
    final p = await context.read<AuthProvider>().obtenerPerfil();
    if (!mounted) return;
    _perfilDisponible = p != null;
    if (p != null) {
      _nombre.text = p.nombre;
      _apellido.text = p.apellido;
      _usuario.text = p.username;
      _correo.text = p.correo;
      _telefono.text = p.telefono ?? '';
    }
    setState(() => _cargando = false);
  }

  @override
  void dispose() {
    for (final c in [
      _nombre,
      _apellido,
      _usuario,
      _correo,
      _telefono,
      _password,
    ]) {
      c.dispose();
    }
    super.dispose();
  }

  Future<void> _guardar() async {
    if (!_perfilDisponible || !_form.currentState!.validate()) return;
    final auth = context.read<AuthProvider>();
    final ok = await auth.actualizarPerfil(
      nombre: _nombre.text,
      apellido: _apellido.text,
      username: _usuario.text,
      correo: _correo.text,
      telefono: _telefono.text,
      passwordActual: _password.text,
    );
    if (ok && mounted && auth.estaAutenticado) Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    return Scaffold(
      appBar: AppBar(title: const Text('Editar perfil')),
      body: SafeArea(
        child: _cargando
            ? const Center(child: CircularProgressIndicator())
            : !_perfilDisponible
            ? Center(
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(auth.error ?? 'No se pudo cargar el perfil.'),
                    TextButton(
                      onPressed: _cargar,
                      child: const Text('Reintentar'),
                    ),
                  ],
                ),
              )
            : SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Form(
                  key: _form,
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Text(
                        auth.empresa?.nombre ?? '',
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _nombre,
                        decoration: const InputDecoration(labelText: 'Nombre'),
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? 'Ingresa tu nombre.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _apellido,
                        decoration: const InputDecoration(
                          labelText: 'Apellido',
                        ),
                        validator: (v) => (v ?? '').trim().isEmpty
                            ? 'Ingresa tu apellido.'
                            : null,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _telefono,
                        keyboardType: TextInputType.phone,
                        decoration: const InputDecoration(
                          labelText: 'Teléfono',
                        ),
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _usuario,
                        decoration: const InputDecoration(
                          labelText: 'Nombre de usuario',
                        ),
                        validator: validarUsuarioCuenta,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _correo,
                        keyboardType: TextInputType.emailAddress,
                        decoration: const InputDecoration(
                          labelText: 'Correo electrónico',
                        ),
                        validator: validarCorreoCuenta,
                      ),
                      const SizedBox(height: 16),
                      TextFormField(
                        controller: _password,
                        obscureText: true,
                        autofillHints: const [AutofillHints.password],
                        decoration: const InputDecoration(
                          labelText:
                              'Contraseña actual para cambiar usuario o correo',
                        ),
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'Si cambias tu usuario o correo, confirma tu contraseña actual. Se cerrarán tus sesiones y volverás a ingresar.',
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
                      const SizedBox(height: 24),
                      FilledButton(
                        onPressed: auth.cargando ? null : _guardar,
                        child: Text(
                          auth.cargando ? 'Guardando…' : 'Guardar cambios',
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
    );
  }
}
