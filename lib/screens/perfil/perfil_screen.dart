import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../core/constants/api_constants.dart';
import '../../core/constants/app_colors.dart';
import '../../models/perfil_models.dart';
import '../../providers/auth_provider.dart';
import '../../providers/carrito_provider.dart';
import '../../providers/favoritos_provider.dart';
import '../../widgets/custom_button.dart';
import '../../widgets/custom_text_field.dart';
import '../auth/login_screen.dart';
import '../delivery/historial_delivery_screen.dart';
import '../pagos/historial_pagos_screen.dart';
import 'proveedor_panel_screen.dart';

class PerfilScreen extends StatefulWidget {
  const PerfilScreen({super.key});

  @override
  State<PerfilScreen> createState() => _PerfilScreenState();
}

class _PerfilScreenState extends State<PerfilScreen> {
  PerfilResponse? _perfil;
  bool _cargando = true;

  @override
  void initState() {
    super.initState();
    _cargarDatos();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final auth = context.watch<AuthProvider>();
    if (auth.estaAutenticado && _perfil == null && !_cargando) {
      _cargarDatos();
    } else if (!auth.estaAutenticado && _perfil != null) {
      _perfil = null;
    }
  }

  Future<void> _cargarDatos() async {
    final auth = context.read<AuthProvider>();
    if (auth.estaAutenticado) {
      final res = await auth.obtenerPerfil();
      if (mounted) {
        setState(() {
          _perfil = res;
          _cargando = false;
        });
      }
    } else {
      if (mounted) {
        setState(() {
          _perfil = null;
          _cargando = false;
        });
      }
    }
  }

  void _abrirEditarPerfil({bool focusTelefono = false}) {
    final auth = context.read<AuthProvider>();
    final nombreCtrl = TextEditingController(text: _perfil?.nombre ?? auth.usuario?.nombre ?? '');
    final apellidoCtrl = TextEditingController(text: _perfil?.apellido ?? auth.usuario?.apellido ?? '');
    final telefonoCtrl = TextEditingController(text: _perfil?.telefono ?? '');
    final telefonoFocus = FocusNode();

    if (focusTelefono) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        telefonoFocus.requestFocus();
      });
    }

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text(
                  focusTelefono ? 'Editar Teléfono' : 'Editar Datos Personales',
                  style: const TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CustomTextField(controller: nombreCtrl, label: 'Nombre'),
            const SizedBox(height: 12),
            CustomTextField(controller: apellidoCtrl, label: 'Apellido'),
            const SizedBox(height: 12),
            CustomTextField(
              controller: telefonoCtrl,
              focusNode: telefonoFocus,
              label: 'Teléfono',
              keyboardType: TextInputType.phone,
              hintText: 'Ej: 77123456',
            ),
            const SizedBox(height: 20),
            CustomButton(
              text: 'Guardar Cambios',
              onPressed: () async {
                final ok = await auth.actualizarPerfil(
                  nombre: nombreCtrl.text,
                  apellido: apellidoCtrl.text,
                  telefono: telefonoCtrl.text,
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                if (ok) {
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  await _cargarDatos();
                  if (mounted) {
                    ScaffoldMessenger.of(context).showSnackBar(
                      const SnackBar(
                        content: Text('Perfil actualizado correctamente.'),
                        backgroundColor: AppColors.success,
                        duration: Duration(seconds: 2),
                      ),
                    );
                  }
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(auth.error ?? 'Error al actualizar perfil.'),
                      backgroundColor: AppColors.danger,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _abrirCambiarPassword() {
    final actualCtrl = TextEditingController();
    final nuevoCtrl = TextEditingController();
    final confirmarCtrl = TextEditingController();

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: EdgeInsets.only(
          left: 24,
          right: 24,
          top: 24,
          bottom: MediaQuery.of(ctx).viewInsets.bottom + 24,
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                const Text(
                  'Cambiar Contraseña',
                  style: TextStyle(
                    fontFamily: 'Playfair Display',
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                    color: AppColors.primary,
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.close),
                  onPressed: () => Navigator.of(ctx).pop(),
                ),
              ],
            ),
            const SizedBox(height: 16),
            CustomTextField(
              controller: actualCtrl,
              label: 'Contraseña Actual',
              isPassword: true,
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: nuevoCtrl,
              label: 'Nueva Contraseña (mínimo 8 caracteres)',
              isPassword: true,
            ),
            const SizedBox(height: 12),
            CustomTextField(
              controller: confirmarCtrl,
              label: 'Confirmar Nueva Contraseña',
              isPassword: true,
            ),
            const SizedBox(height: 20),
            CustomButton(
              text: 'Actualizar Contraseña',
              onPressed: () async {
                if (nuevoCtrl.text != confirmarCtrl.text) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Las contraseñas no coinciden.'),
                      backgroundColor: AppColors.danger,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                if (nuevoCtrl.text.length < 8) {
                  ScaffoldMessenger.of(context).hideCurrentSnackBar();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('La nueva contraseña debe tener al menos 8 caracteres.'),
                      backgroundColor: AppColors.danger,
                      duration: Duration(seconds: 2),
                    ),
                  );
                  return;
                }
                final auth = context.read<AuthProvider>();
                final ok = await auth.cambiarPassword(
                  passwordActual: actualCtrl.text,
                  nuevoPassword: nuevoCtrl.text,
                  confirmarPasswordNuevo: confirmarCtrl.text,
                );
                if (!mounted) return;
                ScaffoldMessenger.of(context).hideCurrentSnackBar();
                if (ok) {
                  if (ctx.mounted) Navigator.of(ctx).pop();
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                      content: Text('Contraseña actualizada con éxito.'),
                      backgroundColor: AppColors.success,
                      duration: Duration(seconds: 2),
                    ),
                  );
                } else {
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                      content: Text(auth.error ?? 'Error al actualizar contraseña.'),
                      backgroundColor: AppColors.danger,
                      duration: const Duration(seconds: 3),
                    ),
                  );
                }
              },
            ),
          ],
        ),
      ),
    );
  }

  void _abrirConfiguracionHost() {
    final hostCtrl = TextEditingController(text: ApiConstants.customHost ?? '');

    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Conexión con Backend'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Si pruebas en un celular físico, introduce la IP local de tu PC (ej. 192.168.1.10). Deja vacío para usar localhost/10.0.2.2:',
              style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 14),
            CustomTextField(
              controller: hostCtrl,
              hintText: '192.168.x.x',
              prefixIcon: Icons.wifi,
            ),
            const SizedBox(height: 8),
            Text(
              'Host actual: ${ApiConstants.baseUrl}',
              style: const TextStyle(fontSize: 11, color: AppColors.primary),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(ctx).pop(),
            child: const Text('Cancelar'),
          ),
          ElevatedButton(
            onPressed: () {
              ApiConstants.customHost = hostCtrl.text.trim().isEmpty ? null : hostCtrl.text.trim();
              Navigator.of(ctx).pop();
              setState(() {});
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<AuthProvider>();

    if (!auth.estaAutenticado) {
      return Scaffold(
        appBar: AppBar(title: const Text('Mi Cuenta')),
        body: Center(
          child: Padding(
            padding: const EdgeInsets.all(32),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.account_circle_outlined, size: 72, color: AppColors.textSecondary),
                const SizedBox(height: 16),
                const Text(
                  'Inicia sesión para ver tu perfil',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold, color: AppColors.textPrimary),
                ),
                const SizedBox(height: 8),
                const Text(
                  'Accede a tus reservas, configura tus datos personales y gestiona tus pedidos.',
                  textAlign: TextAlign.center,
                  style: TextStyle(fontSize: 13, color: AppColors.textSecondary),
                ),
                const SizedBox(height: 24),
                CustomButton(
                  text: 'Iniciar Sesión',
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const LoginScreen()),
                    );
                  },
                ),
              ],
            ),
          ),
        ),
      );
    }

    if (_cargando) {
      return const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      );
    }

    final nombre = _perfil?.nombre ?? auth.usuario?.nombre ?? 'Usuario';
    final apellido = _perfil?.apellido ?? auth.usuario?.apellido ?? '';
    final nombreCompleto = '$nombre $apellido'.trim();
    final username = _perfil?.username ?? auth.usuario?.username ?? '';
    final correo = _perfil?.correo ?? auth.usuario?.correo ?? '';
    final roles = _perfil?.roles ?? auth.usuario?.roles ?? [];

    return Scaffold(
      appBar: AppBar(
        title: const Text('Mi Perfil'),
        actions: [
          IconButton(
            icon: const Icon(Icons.settings_ethernet_outlined),
            tooltip: 'Configurar IP del Backend',
            onPressed: _abrirConfiguracionHost,
          ),
        ],
      ),
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _cargarDatos,
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 16),
            children: [
              // Cabecera de Usuario
              Card(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 30,
                        backgroundColor: AppColors.primary,
                        child: Text(
                          nombre.isNotEmpty ? nombre[0].toUpperCase() : 'U',
                          style: const TextStyle(
                            color: Colors.white,
                            fontSize: 24,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              nombreCompleto.isNotEmpty ? nombreCompleto : 'Usuario',
                              style: const TextStyle(
                                fontSize: 18,
                                fontWeight: FontWeight.w700,
                                color: AppColors.textPrimary,
                              ),
                            ),
                            const SizedBox(height: 2),
                            Text(
                              '@$username',
                              style: const TextStyle(
                                fontSize: 13,
                                color: AppColors.textSecondary,
                              ),
                            ),
                            const SizedBox(height: 8),
                            Wrap(
                              spacing: 6,
                              children: roles.map((rol) {
                                return Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                                  decoration: BoxDecoration(
                                    color: AppColors.accentSoft,
                                    borderRadius: BorderRadius.circular(12),
                                  ),
                                  child: Text(
                                    rol,
                                    style: const TextStyle(
                                      fontSize: 10,
                                      fontWeight: FontWeight.w600,
                                      color: AppColors.accent,
                                    ),
                                  ),
                                );
                              }).toList(),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              const SizedBox(height: 20),

              // Opciones de Configuración
              const Text(
                'CONFIGURACIÓN DE CUENTA',
                style: TextStyle(
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 0.8,
                  color: AppColors.textSecondary,
                ),
              ),
              const SizedBox(height: 8),

              Card(
                child: Column(
                  children: [
                    ListTile(
                      leading: const Icon(Icons.person_outline, color: AppColors.primary),
                      title: const Text('Editar Datos Personales'),
                      subtitle: Text(correo.isNotEmpty ? correo : 'Sin correo'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () => _abrirEditarPerfil(focusTelefono: false),
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.lock_outline, color: AppColors.primary),
                      title: const Text('Cambiar Contraseña'),
                      subtitle: const Text('Actualiza tu clave de acceso'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: _abrirCambiarPassword,
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.credit_card_outlined, color: AppColors.primary),
                      title: Text(auth.esAdminOEncargado ? 'Historial de pagos' : 'Mis pagos'),
                      subtitle: const Text('Consulta pagos registrados y su estado'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const HistorialPagosScreen()),
                        );
                      },
                    ),
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.local_shipping_outlined, color: AppColors.primary),
                      title: Text(auth.esAdminOEncargado ? 'Historial de delivery' : 'Mis deliveries'),
                      subtitle: const Text('Consulta envios a domicilio y su estado'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () {
                        Navigator.of(context).push(
                          MaterialPageRoute(builder: (_) => const HistorialDeliveryScreen()),
                        );
                      },
                    ),
                    if (auth.esProveedor) ...[
                      const Divider(),
                      ListTile(
                        leading: const Icon(Icons.storefront_outlined, color: AppColors.primary),
                        title: const Text('Panel proveedor'),
                        subtitle: const Text('Consulta tus productos, stock y entregas'),
                        trailing: const Icon(Icons.chevron_right),
                        onTap: () {
                          Navigator.of(context).push(
                            MaterialPageRoute(builder: (_) => const ProveedorPanelScreen()),
                          );
                        },
                      ),
                    ],
                    const Divider(),
                    ListTile(
                      leading: const Icon(Icons.phone_outlined, color: AppColors.primary),
                      title: const Text('Teléfono'),
                      subtitle: Text((_perfil?.telefono != null && _perfil!.telefono!.isNotEmpty)
                          ? _perfil!.telefono!
                          : 'No registrado (Toca para editar)'),
                      trailing: const Icon(Icons.edit_outlined, size: 18),
                      onTap: () => _abrirEditarPerfil(focusTelefono: true),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 24),

              // Cerrar Sesión
              CustomButton(
                text: 'Cerrar Sesión',
                isOutlined: true,
                icon: Icons.logout,
                backgroundColor: AppColors.danger,
                textColor: AppColors.danger,
                onPressed: () {
                  showDialog(
                    context: context,
                    builder: (ctx) => AlertDialog(
                      title: const Text('¿Cerrar Sesión?'),
                      content: const Text('Tendrás que volver a ingresar tus credenciales para acceder a tus reservas.'),
                      actions: [
                        TextButton(
                          onPressed: () => Navigator.of(ctx).pop(),
                          child: const Text('Cancelar'),
                        ),
                        ElevatedButton(
                          style: ElevatedButton.styleFrom(backgroundColor: AppColors.danger),
                          onPressed: () {
                            Navigator.of(ctx).pop();
                            ScaffoldMessenger.of(context).hideCurrentSnackBar();
                            setState(() {
                              _perfil = null;
                            });
                            context.read<CarritoProvider>().limpiarCarrito();
                            context.read<FavoritosProvider>().limpiar();
                            context.read<AuthProvider>().logout();
                          },
                          child: const Text('Cerrar Sesión'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }
}
