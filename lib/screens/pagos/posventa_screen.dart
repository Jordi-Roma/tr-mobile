import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../providers/auth_provider.dart';
import '../../widgets/accesos_modulo.dart';
import 'cambios_screen.dart';
import 'devoluciones_screen.dart';
import 'configuracion_comercial_screen.dart';

class PosventaScreen extends StatelessWidget {
  const PosventaScreen({super.key});
  @override
  Widget build(BuildContext context) {
    void abrir(Widget pantalla) =>
        Navigator.of(context)
            .push(MaterialPageRoute<void>(builder: (_) => pantalla));
    return Scaffold(
      appBar: AppBar(title: const Text('Devoluciones y cambios')),
      body: ListView(
        padding: const EdgeInsets.all(20),
        children: [
          const Text(
            'Elige una opción para consultar solicitudes o definir las políticas de tu empresa.',
          ),
          const SizedBox(height: 20),
          AccesosModulo(
            accesos: [
              AccesoModulo(
                'Devoluciones',
                Icons.assignment_return_outlined,
                () => abrir(const DevolucionesScreen()),
              ),
              AccesoModulo(
                'Cambios',
                Icons.swap_horiz,
                () => abrir(const CambiosScreen()),
              ),
              if (context.watch<AuthProvider>().esAdmin)
                AccesoModulo(
                  'Políticas posventa',
                  Icons.rule,
                  () => abrir(
                    const ConfiguracionComercialScreen(politicas: true),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
