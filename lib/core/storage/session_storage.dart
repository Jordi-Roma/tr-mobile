import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import 'package:flutter_secure_storage/flutter_secure_storage.dart';

import '../../models/auth_models.dart';
import 'sesion_offline.dart';

class SessionStorage {
  SessionStorage._();

  static const String _keyToken = 'stylear_token';
  static const String _keyUser = 'stylear_user';
  static const _seguro = FlutterSecureStorage();
  static const _keySesion = 'stylear_sesion_segura_v1';

  static Future<void> saveSession({
    required String token,
    required UsuarioAutenticado usuario,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    if (SesionOffline.disponible) {
      await _seguro.write(
        key: _keySesion,
        value: jsonEncode({'token': token, 'usuario': usuario.toJson()}),
      );
      await prefs.remove(_keyToken);
      await prefs.remove(_keyUser);
      return;
    }
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyUser, jsonEncode(usuario.toJson()));
  }

  static Future<String?> getToken() async {
    final segura = await _sesionSegura();
    if (segura != null) return segura['token'] as String?;
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  static Future<UsuarioAutenticado?> getUser() async {
    final segura = await _sesionSegura();
    if (segura != null) {
      return UsuarioAutenticado.fromJson(
        segura['usuario'] as Map<String, dynamic>,
      );
    }
    final prefs = await SharedPreferences.getInstance();
    final userJson = prefs.getString(_keyUser);
    if (userJson == null) return null;
    try {
      final map = jsonDecode(userJson) as Map<String, dynamic>;
      return UsuarioAutenticado.fromJson(map);
    } catch (_) {
      await clearSession();
      return null;
    }
  }

  static Future<String?> getEmpresaCodigo() async =>
      (await SharedPreferences.getInstance()).getString(
        'stylear_empresa_codigo_v1',
      );

  static Future<void> setEmpresaCodigo(String? codigo) async {
    final prefs = await SharedPreferences.getInstance();
    if (codigo == null) {
      await prefs.remove('stylear_empresa_codigo_v1');
    } else {
      await prefs.setString('stylear_empresa_codigo_v1', codigo);
    }
  }

  static Future<void> clearSession() async {
    if (SesionOffline.disponible) await _seguro.delete(key: _keySesion);
    await SesionOffline.cerrar();
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUser);
  }

  static Future<Map<String, dynamic>?> _sesionSegura() async {
    if (!SesionOffline.disponible) return null;
    final valor = await _seguro.read(key: _keySesion);
    return valor == null ? null : jsonDecode(valor) as Map<String, dynamic>;
  }
}
