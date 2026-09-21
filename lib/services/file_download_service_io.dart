import 'dart:io';
import 'dart:typed_data';

import 'package:open_filex/open_filex.dart';
import 'package:path_provider/path_provider.dart';

Future<String?> guardarYMostrarArchivo({
  required Uint8List bytes,
  required String nombreArchivo,
  required String mimeType,
}) async {
  final dir = await getApplicationDocumentsDirectory();
  final file = File('${dir.path}/$nombreArchivo');
  await file.writeAsBytes(bytes);

  final result = await OpenFilex.open(file.path);
  if (result.type == ResultType.done) return null;
  return file.path;
}
