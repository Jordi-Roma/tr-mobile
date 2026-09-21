import 'dart:typed_data';

Future<String?> guardarYMostrarArchivo({
  required Uint8List bytes,
  required String nombreArchivo,
  required String mimeType,
}) {
  throw UnsupportedError(
    'Descarga de archivos no soportada en esta plataforma.',
  );
}
