import 'dart:convert';
import 'dart:js_interop';
import 'dart:typed_data';

import 'c2pa_result.dart';

/// web/index.html で定義した window.c2paAnalyze を呼ぶ。
/// 返値は JSON 文字列。
@JS('c2paAnalyze')
external JSPromise<JSString> _jsAnalyze(JSUint8Array bytes, JSString mimeType);

Future<bool> initC2pa() async => true; // JS側でlazy init

Future<C2paResult?> analyzeBytes(Uint8List bytes, String mimeType) async {
  final jsStr = await _jsAnalyze(bytes.toJS, mimeType.toJS).toDart;
  final map = jsonDecode(jsStr.toDart) as Map<String, dynamic>;

  if (map['hasManifest'] != true) return null;

  final rawActions = (map['actions'] as List? ?? []).cast<Map<String, dynamic>>();
  final actions = rawActions
      .map((a) => C2paAction(
            action: a['action'] as String? ?? '',
            digitalSourceType: a['digitalSourceType'] as String?,
          ))
      .toList();

  return C2paResult(
    title: map['title'] as String?,
    generator: map['generator'] as String?,
    issuer: map['issuer'] as String?,
    actions: actions,
  );
}
