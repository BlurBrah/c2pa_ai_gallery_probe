import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';

Future<Uint8List?> platformFileBytes(PlatformFile f) async => f.bytes;
