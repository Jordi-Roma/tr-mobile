import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';
import '../../models/auth_models.dart';

class SessionStorage {
  SessionStorage._();

  static const String _keyToken = 'stylear_token';
  static const String _keyUser = 'stylear_user';

  static Future<void> saveSession({
    required String token,
    required UsuarioAutenticado usuario,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_keyToken, token);
    await prefs.setString(_keyUser, jsonEncode(usuario.toJson()));
  }

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_keyToken);
  }

  static Future<UsuarioAutenticado?> getUser() async {
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

  static Future<void> clearSession() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove(_keyToken);
    await prefs.remove(_keyUser);
  }
}
