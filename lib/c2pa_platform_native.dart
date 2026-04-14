import 'dart:convert';
import 'dart:typed_data';

import 'package:c2pa_flutter/c2pa_flutter.dart';
// ignore: implementation_imports
import 'package:c2pa_flutter/src/rust/api/reader.dart' as rust_reader;
import 'package:flutter/foundation.dart' show debugPrint, kDebugMode;

import 'c2pa_result.dart';
import 'c2pa_store_json_parser.dart';

Future<bool> initC2pa() async {
  await C2pa.init();
  return true;
}

void _debugLogManifestStore(final Map<String, dynamic> storeJson) {
  if (!kDebugMode) return;
  for (final line in describeC2paStoreJson(storeJson)) {
    debugPrint(line);
  }
}

Future<C2paResult?> analyzeBytes(Uint8List bytes, String mimeType) async {
  final String? jsonString;
  try {
    jsonString = rust_reader.readManifestFormat(
      fileBytes: bytes,
      mimeType: mimeType,
    );
  } on C2paException catch (e) {
    if (kDebugMode) debugPrint('C2PA read error: $e');
    return null;
  } on Object catch (e) {
    if (kDebugMode) debugPrint('C2PA read error: $e');
    return null;
  }

  if (jsonString == null) return null;

  final parsed = parseC2paStoreJsonString(jsonString);
  if (parsed == null) return null;

  _debugLogManifestStore(jsonDecode(jsonString) as Map<String, dynamic>);
  return parsed;
}
