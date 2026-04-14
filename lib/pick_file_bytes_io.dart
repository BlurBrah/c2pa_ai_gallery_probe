import 'dart:io';
import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<Uint8List?> platformFileBytes(PlatformFile f) async {
  final b = f.bytes;
  if (b != null && b.isNotEmpty) return b;
  final path = f.path;
  if (path == null || path.isEmpty) return b;
  try {
    return await File(path).readAsBytes();
  } on Object {
    return b;
  }
}
