import 'package:flutter/material.dart';
import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../core/network/api_exceptions.dart';
import '../core/storage/session_storage.dart';
import '../models/auth_models.dart';
import '../models/perfil_models.dart';

class AuthProvider extends ChangeNotifier {
  UsuarioAutenticado? _usuario;
  String? _token;
  bool _cargando = false;
  String? _error;

  UsuarioAutenticado? get usuario => _usuario;
  String? get token => _token;
  bool get cargando => _cargando;
  String? get error => _error;
  bool get estaAutenticado => _token != null && _usuario != null;

  bool get esCliente => _usuario?.esCliente ?? false;
  bool get esAdmin => _usuario?.esAdmin ?? false;
  bool get esEncargado => _usuario?.esEncargado ?? false;
  bool get esAdminOEncargado => _usuario?.esAdminOEncargado ?? false;

  void limpiarError() {
    _error = null;
    notifyListeners();
  }

  Future<void> inicializar() async {
    _token = await SessionStorage.getToken();
    _usuario = await SessionStorage.getUser();
    notifyListeners();
  }

  Future<bool> login(String identificador, String password) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final response = await ApiClient.post(
        ApiConstants.login,
        body: {
          'identificador': identificador.trim(),
          'password': password,
        },
        withAuth: false,
      );

      final loginRes = LoginResponse.fromJson(response);
      _token = loginRes.accessToken;
      _usuario = loginRes.toUsuario();

      await SessionStorage.saveSession(
        token: _token!,
        usuario: _usuario!,
      );

      _cargando = false;
      notifyListeners();
      return true;
    } catch (e) {
      _cargando = false;
      _error = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> registrar({
    required String nombre,
    required String apellido,
    required String username,
    required String correo,
    required String password,
    String? telefono,
  }) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      await ApiClient.post(
        ApiConstants.registro,
        body: {
          'nombre': nombre.trim(),
          'apellido': apellido.trim(),
          'username': username.trim().toLowerCase(),
          'correo': correo.trim().toLowerCase(),
          'password': password,
          if (telefono != null && telefono.isNotEmpty) 'telefono': telefono.trim(),
        },
        withAuth: false,
      );

      // Iniciar sesión automáticamente tras el registro
      return await login(username, password);
    } catch (e) {
      _cargando = false;
      _error = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    try {
      await ApiClient.post(ApiConstants.logout, body: {});
    } catch (_) {}

    await SessionStorage.clearSession();
    _token = null;
    _usuario = null;
    _error = null;
    notifyListeners();
  }

  Future<PerfilResponse?> obtenerPerfil() async {
    try {
      final res = await ApiClient.get(ApiConstants.perfil);
      return PerfilResponse.fromJson(res);
    } catch (e) {
      _error = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return null;
    }
  }

  Future<bool> actualizarPerfil({
    required String nombre,
    required String apellido,
    String? telefono,
  }) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      final res = await ApiClient.put(
        ApiConstants.perfil,
        body: {
          'nombre': nombre.trim(),
          'apellido': apellido.trim(),
          'telefono': (telefono != null && telefono.trim().isNotEmpty) ? telefono.trim() : null,
        },
      );

      final perfilActualizado = PerfilResponse.fromJson(res);
      _usuario = UsuarioAutenticado(
        id: perfilActualizado.id,
        nombre: perfilActualizado.nombre,
        apellido: perfilActualizado.apellido,
        username: perfilActualizado.username,
        correo: perfilActualizado.correo,
        roles: perfilActualizado.roles,
      );
      await SessionStorage.saveSession(token: _token!, usuario: _usuario!);

      _cargando = false;
      notifyListeners();
      return true;
    } catch (e) {
      _cargando = false;
      _error = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> cambiarPassword({
    required String passwordActual,
    required String nuevoPassword,
    required String confirmarPasswordNuevo,
  }) async {
    _cargando = true;
    _error = null;
    notifyListeners();

    try {
      await ApiClient.put(
        ApiConstants.perfilPassword,
        body: {
          'password_actual': passwordActual,
          'password_nuevo': nuevoPassword,
          'confirmar_password_nuevo': confirmarPasswordNuevo,
        },
      );
      _cargando = false;
      notifyListeners();
      return true;
    } catch (e) {
      _cargando = false;
      _error = e is ApiException ? e.message : e.toString();
      notifyListeners();
      return false;
    }
  }
}
