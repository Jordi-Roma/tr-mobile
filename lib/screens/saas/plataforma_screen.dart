import '../respaldos/respaldos_screen.dart';
import 'planes_saas_screen.dart';
import 'empresa_saas_screen.dart';
import 'historial_saas_screen.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exceptions.dart';
import '../../core/session/contexto_sesion.dart';
import '../../providers/auth_provider.dart';

/// Entrada exclusiva de plataforma. No carga providers ni operaciones de tienda.
class PlataformaScreen extends StatefulWidget {
  const PlataformaScreen({super.key});
  @override
  State<PlataformaScreen> createState() => _PlataformaScreenState();
}

class _PlataformaScreenState extends State<PlataformaScreen> {
  List<Map<String, dynamic>> _empresas = [];
  List<Map<String, dynamic>> _planes = [];
  String? _error;
  bool _cargando = true;
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    final gen = ContextoSesion.instance.generacion;
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final datos = await Future.wait([
        ApiClient.get('${ApiConstants.baseUrl}/saas/empresas'),
        ApiClient.get('${ApiConstants.baseUrl}/saas/planes'),
      ]);
      ApiClient.validarGeneracion(gen);
      if (!mounted) return;
      setState(() {
        _empresas = (datos[0] as List).cast<Map<String, dynamic>>();
        _planes = (datos[1] as List).cast<Map<String, dynamic>>();
      });
    } catch (e) {
      if (mounted && gen == ContextoSesion.instance.generacion) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'No se pudo cargar la plataforma.',
        );
      }
    } finally {
      if (mounted && gen == ContextoSesion.instance.generacion) {
        setState(() => _cargando = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    if (!auth.esAdminSaas) return const SizedBox.shrink();
    return Scaffold(
      appBar: AppBar(
        title: const Text('Plataforma StyleAR'),
        actions: [
          IconButton(
            onPressed: auth.cargando ? null : auth.logout,
            icon: const Icon(Icons.logout),
            tooltip: 'Cerrar sesión',
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _cargar,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            Text(
              'Administración SaaS',
              style: Theme.of(context).textTheme.headlineSmall,
            ),
            Text('Bienvenido, ${auth.usuario?.nombre ?? ''}'),
            const SizedBox(height: 16),
            Wrap(
              spacing: 12,
              children: [
                FilledButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const PlanesSaasScreen(),
                      ),
                    );
                    if (mounted) await _cargar();
                  },
                  icon: const Icon(Icons.assignment_outlined),
                  label: const Text('Gestionar planes'),
                ),
                FilledButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => const EmpresasSaasScreen(),
                      ),
                    );
                    if (mounted) await _cargar();
                  },
                  icon: const Icon(Icons.store_outlined),
                  label: const Text('Gestionar empresas'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const RespaldosScreen(plataforma: true),
                    ),
                  ),
                  icon: const Icon(Icons.backup_outlined),
                  label: const Text('Respaldos de plataforma'),
                ),
                OutlinedButton.icon(
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => const HistorialSaasScreen(),
                    ),
                  ),
                  icon: const Icon(Icons.history),
                  label: const Text('Auditoría de plataforma'),
                ),
              ],
            ),
            if (_cargando) const Center(child: CircularProgressIndicator()),
            if (_error != null) ...[
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
              OutlinedButton(
                onPressed: _cargando ? null : _cargar,
                child: const Text('Volver a intentar'),
              ),
            ],
            if (!_cargando && _error == null) ...[
              Text(
                'Empresas (${_empresas.length})',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (_empresas.isEmpty) const Text('No hay empresas registradas.'),
              ..._empresas.map(
                (e) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.store_outlined),
                    title: Text(e['nombre'] as String? ?? ''),
                    subtitle: Text(e['estado'] as String? ?? ''),
                  ),
                ),
              ),
              const SizedBox(height: 20),
              Text(
                'Planes (${_planes.length})',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              if (_planes.isEmpty) const Text('No hay planes registrados.'),
              ..._planes.map(
                (p) => Card(
                  child: ListTile(
                    leading: const Icon(Icons.assignment_outlined),
                    title: Text(p['nombre'] as String? ?? ''),
                    subtitle: Text(p['activo'] == true ? 'Activo' : 'Inactivo'),
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
