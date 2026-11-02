import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../core/constants/api_constants.dart';
import '../core/network/api_client.dart';
import '../core/session/contexto_sesion.dart';
import '../core/session/clave_pago.dart';

const firebaseHabilitado = bool.fromEnvironment(
  'FIREBASE_ENABLED',
  defaultValue: false,
);
FirebaseOptions opcionesFirebase() => const FirebaseOptions(
  apiKey: String.fromEnvironment('FIREBASE_API_KEY'),
  appId: String.fromEnvironment('FIREBASE_APP_ID'),
  messagingSenderId: String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID'),
  projectId: String.fromEnvironment('FIREBASE_PROJECT_ID'),
  iosBundleId: String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID'),
);
@pragma('vm:entry-point')
Future<void> recibirPushFondo(RemoteMessage message) async {
  if (firebaseHabilitado && Firebase.apps.isEmpty) {
    await Firebase.initializeApp(options: opcionesFirebase());
  }
  // El aviso del sistema es genérico. Los datos se consultan con sesión al abrir la bandeja.
}

class FirebasePush {
  static final novedades = ValueNotifier<int>(0);
  static bool _escuchando = false;
  static bool _vinculando = false;
  static bool _sdkListo = false;
  static StreamSubscription<String>? _tokens;
  static StreamSubscription<RemoteMessage>? _mensajes;
  static StreamSubscription<RemoteMessage>? _aperturas;
  static int _generacion = -1;

  static void iniciar() {
    if (_escuchando) return;
    _escuchando = true;
    ContextoSesion.instance.addListener(_cambioSesion);
  }

  static void _cambioSesion() {
    final c = ContextoSesion.instance;
    if (c.generacion == _generacion) return;
    _generacion = c.generacion;
    novedades.value++;
    if (!firebaseHabilitado || kIsWeb || !_sdkListo) return;
    if (c.usuario == null) {
      unawaited(
        FirebaseMessaging.instance.deleteToken().catchError((Object _) {}),
      );
      return;
    }
    unawaited(_volverAVincular());
  }

  static Future<void> _volverAVincular() async {
    if (_vinculando) return;
    _vinculando = true;
    try {
      final gen = ContextoSesion.instance.generacion;
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) await _registrar(token, gen);
    } catch (_) {
      /* La bandeja permanece disponible; se permite activar otra vez. */
    } finally {
      _vinculando = false;
    }
  }

  static Future<String> activar() async {
    iniciar();
    if (!firebaseHabilitado) {
      return 'Firebase está pendiente de configuración. La bandeja sí está disponible.';
    }
    if (kIsWeb) {
      return 'La bandeja está disponible en web. Esta integración push se prepara para Android e iOS.';
    }
    final gen = ContextoSesion.instance.generacion;
    if (ContextoSesion.instance.usuario == null) {
      return 'Inicia sesión para activar avisos de tu cuenta.';
    }
    final estado = await ApiClient.get(
      '${ApiConstants.baseUrl}/notificaciones/estado',
    );
    if ((estado as Map)['push_configurado'] != true) {
      return 'Falta configurar Firebase en el servidor. Las notificaciones se conservan en la bandeja.';
    }
    final opciones = opcionesFirebase();
    if (opciones.apiKey.isEmpty ||
        opciones.appId.isEmpty ||
        opciones.projectId.isEmpty ||
        opciones.messagingSenderId.isEmpty) {
      return 'Faltan los datos públicos del proyecto Firebase para esta aplicación.';
    }
    if (Firebase.apps.isEmpty) await Firebase.initializeApp(options: opciones);
    _sdkListo = true;
    FirebaseMessaging.onBackgroundMessage(recibirPushFondo);
    final permiso = await FirebaseMessaging.instance.requestPermission();
    if (permiso.authorizationStatus == AuthorizationStatus.denied) {
      return 'No se autorizó el aviso push. Puedes consultar esta bandeja igualmente.';
    }
    _tokens ??= FirebaseMessaging.instance.onTokenRefresh.listen((token) {
      if (ContextoSesion.instance.usuario != null) {
        unawaited(
          _registrar(
            token,
            ContextoSesion.instance.generacion,
          ).catchError((Object _) {}),
        );
      }
    });
    _mensajes ??= FirebaseMessaging.onMessage.listen((_) {
      novedades.value++;
    });
    _aperturas ??= FirebaseMessaging.onMessageOpenedApp.listen((_) {
      novedades.value++;
    });
    final token = await FirebaseMessaging.instance.getToken();
    if (token == null) {
      return 'Aún no se obtuvo un token del dispositivo. Intenta nuevamente.';
    }
    await _registrar(token, gen);
    return 'Dispositivo registrado. El servidor enviará los avisos cuando procese su cola pendiente.';
  }

  static Future<void> _registrar(String token, int gen) async {
    final prefs = await SharedPreferences.getInstance();
    var instalacion = prefs.getString('stylear_push_instalacion');
    instalacion ??= nuevoIdentificador();
    await prefs.setString('stylear_push_instalacion', instalacion);
    ApiClient.validarGeneracion(gen);
    await ApiClient.post(
      '${ApiConstants.baseUrl}/notificaciones/dispositivos',
      body: {
        'instalacion_id': instalacion,
        'token': token,
        'plataforma': defaultTargetPlatform == TargetPlatform.iOS
            ? 'ios'
            : 'android',
      },
    );
  }
}
