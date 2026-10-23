import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/constants/api_constants.dart';
import '../../core/network/api_client.dart';
import '../../core/network/api_exceptions.dart';
import '../../models/empresa_models.dart';
import '../../providers/auth_provider.dart';

class EmpresaScreen extends StatefulWidget {
  const EmpresaScreen({super.key});
  @override
  State<EmpresaScreen> createState() => _EmpresaScreenState();
}

class _EmpresaScreenState extends State<EmpresaScreen> {
  List<EmpresaPublica> _empresas = [];
  String _consulta = '';
  String? _error;
  bool _cargando = true;
  @override
  void initState() {
    super.initState();
    _cargar();
  }

  Future<void> _cargar() async {
    setState(() {
      _cargando = true;
      _error = null;
    });
    try {
      final res = await ApiClient.get(
        '${ApiConstants.baseUrl}/empresas/publicas',
        withAuth: false,
      ) as List<dynamic>;
      if (mounted) {
        setState(
          () => _empresas = res
              .map((e) => EmpresaPublica.fromJson(e as Map<String, dynamic>))
              .toList(),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(
          () => _error = e is ApiException
              ? e.message
              : 'No se pudieron cargar las empresas.',
        );
      }
    } finally {
      if (mounted) setState(() => _cargando = false);
    }
  }

  String _normalizar(String s) => s
      .trim()
      .toLowerCase()
      .replaceAll(RegExp('[áàäâ]'), 'a')
      .replaceAll(RegExp('[éèëê]'), 'e')
      .replaceAll(RegExp('[íìïî]'), 'i')
      .replaceAll(RegExp('[óòöô]'), 'o')
      .replaceAll(RegExp('[úùüû]'), 'u')
      .replaceAll('ñ', 'n');
  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();
    final visibles = _empresas
        .where((e) => _normalizar(e.nombre).contains(_normalizar(_consulta)))
        .toList();
    return Scaffold(
      appBar: AppBar(title: const Text('StyleAR')),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.all(24),
          children: [
            Text(
              'Elige una empresa',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            const SizedBox(height: 12),
            const Text(
              'Entra a una tienda para descubrir su catálogo y acceder a tu cuenta.',
            ),
            const SizedBox(height: 24),
            TextField(
              decoration: const InputDecoration(
                labelText: 'Buscar empresa por nombre',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _consulta = v),
            ),
            const SizedBox(height: 20),
            if (auth.error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: Text(
                  auth.error!,
                  semanticsLabel: auth.error,
                  style: TextStyle(color: Theme.of(context).colorScheme.error),
                ),
              ),
            if (_cargando)
              const Center(child: CircularProgressIndicator())
            else if (_error != null) ...[
              Text(_error!),
              const SizedBox(height: 12),
              OutlinedButton(
                onPressed: _cargar,
                child: const Text('Volver a intentar'),
              ),
            ] else if (visibles.isEmpty)
              Text(
                _empresas.isEmpty
                    ? 'No hay empresas disponibles.'
                    : 'No encontramos esa empresa.',
              )
            else
              ...visibles.map(
                (e) => Card(
                  child: ListTile(
                    contentPadding: const EdgeInsets.all(16),
                    leading: CircleAvatar(
                      child: Text(
                        e.nombre.trim().isEmpty
                            ? 'E'
                            : e.nombre.trim()[0].toUpperCase(),
                      ),
                    ),
                    title: Text(e.nombre),
                    subtitle: const Text('Visitar tienda'),
                    trailing: const Icon(Icons.arrow_forward),
                    enabled: !auth.cargando,
                    onTap: () => auth.seleccionarEmpresa(e),
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
    );
  }
}
