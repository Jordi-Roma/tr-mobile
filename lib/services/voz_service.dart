import 'package:speech_to_text/speech_recognition_result.dart';
import 'package:speech_to_text/speech_to_text.dart';

class VozService {
  VozService._();

  static final SpeechToText _speech = SpeechToText();
  static bool _inicializado = false;
  static String? _localeEspanol;
  static void Function(String mensaje)? _onErrorActual;

  static bool get escuchando => _speech.isListening;

  static Future<bool> inicializar({
    void Function(String mensaje)? onError,
  }) async {
    _onErrorActual = onError;
    if (_inicializado) return true;
    _inicializado = await _speech.initialize(
      onError: (error) {
        _onErrorActual?.call(
          error.errorMsg.isNotEmpty
              ? 'No se pudo reconocer la voz: ${error.errorMsg}'
              : 'No se pudo reconocer la voz. Intenta de nuevo.',
        );
      },
    );
    return _inicializado;
  }

  static Future<String?> _resolverLocaleEspanol() async {
    if (_localeEspanol != null) return _localeEspanol;

    try {
      final locales = await _speech.locales();
      const preferidos = ['es_BO', 'es_ES', 'es_MX', 'es_US'];

      for (final preferido in preferidos) {
        for (final locale in locales) {
          if (locale.localeId == preferido) {
            _localeEspanol = locale.localeId;
            return _localeEspanol;
          }
        }
      }

      for (final locale in locales) {
        if (locale.localeId.toLowerCase().startsWith('es')) {
          _localeEspanol = locale.localeId;
          return _localeEspanol;
        }
      }
    } catch (_) {
      return null;
    }

    return null;
  }

  static Future<void> escuchar({
    required void Function(String texto, bool finalizado) onTexto,
    void Function(String mensaje)? onError,
  }) async {
    final disponible = await inicializar(onError: onError);
    if (!disponible) {
      onError?.call('No se pudo activar el micrófono. Revisa permisos de voz.');
      return;
    }

    final localeId = await _resolverLocaleEspanol();

    await _speech.listen(
      listenOptions: SpeechListenOptions(
        localeId: localeId,
        listenMode: ListenMode.dictation,
        partialResults: true,
        cancelOnError: true,
        pauseFor: const Duration(seconds: 3),
        listenFor: const Duration(seconds: 20),
      ),
      onResult: (SpeechRecognitionResult result) {
        onTexto(result.recognizedWords, result.finalResult);
      },
    );
  }

  static Future<void> detener() async {
    if (_speech.isListening) {
      await _speech.stop();
    }
  }

  static Future<void> cancelar() async {
    if (_speech.isListening) {
      await _speech.cancel();
    }
  }
}
