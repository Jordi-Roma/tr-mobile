import 'dart:typed_data';

import 'file_download_service_stub.dart'
    if (dart.library.io) 'file_download_service_io.dart'
    if (dart.library.html) 'file_download_service_web.dart'
    as impl;

class FileDownloadService {
  FileDownloadService._();

  static Future<String?> guardarYMostrarArchivo({
    required Uint8List bytes,
    required String nombreArchivo,
    required String mimeType,
  }) {
    return impl.guardarYMostrarArchivo(
      bytes: bytes,
      nombreArchivo: nombreArchivo,
      mimeType: mimeType,
    );
  }
}
