import 'dart:js_interop';
import 'dart:typed_data';

import 'package:web/web.dart' as web;

Future<String?> guardarYMostrarArchivo({
  required Uint8List bytes,
  required String nombreArchivo,
  required String mimeType,
}) async {
  final blob = web.Blob(
    <JSUint8Array>[bytes.toJS].toJS,
    web.BlobPropertyBag(type: mimeType),
  );
  final url = web.URL.createObjectURL(blob);

  web.HTMLAnchorElement()
    ..href = url
    ..download = nombreArchivo
    ..click();

  web.URL.revokeObjectURL(url);
  return null;
}
