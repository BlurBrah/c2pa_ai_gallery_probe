import 'dart:typed_data';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

import 'c2pa_platform.dart';
import 'pick_file_bytes.dart';

String _mimeForFileName(final String name) {
  final lower = name.toLowerCase();
  if (lower.endsWith('.png')) return 'image/png';
  if (lower.endsWith('.jpg') || lower.endsWith('.jpeg')) return 'image/jpeg';
  if (lower.endsWith('.webp')) return 'image/webp';
  if (lower.endsWith('.gif')) return 'image/gif';
  if (lower.endsWith('.avif')) return 'image/avif';
  if (lower.endsWith('.heic') || lower.endsWith('.heif')) return 'image/heic';
  return 'image/jpeg';
}

bool _c2paAvailable = false;
String? _c2paInitErrorMessage;

/// 直近の解析結果（バナー表示用）
enum _Verdict {
  none,
  noManifest,
  aiImage,
  /// digitalSourceType なしだが issuer / claimGenerator が既知の AI サービス
  aiImageInferred,
  manifestNoAiEvidence,
  error,
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  try {
    await initC2pa();
    _c2paAvailable = true;
  } on Object catch (e, st) {
    _c2paInitErrorMessage = e.toString();
    debugPrint('initC2pa() failed: $e\n$st');
    _c2paAvailable = false;
  }
  runApp(const C2paProbeApp());
}

class C2paProbeApp extends StatelessWidget {
  const C2paProbeApp({super.key});

  @override
  Widget build(final BuildContext context) {
    return MaterialApp(
      title: 'C2PA AI 判定プローブ',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: const HomePage(),
    );
  }
}

class HomePage extends StatefulWidget {
  const HomePage({super.key});

  @override
  State<HomePage> createState() => _HomePageState();
}

class _HomePageState extends State<HomePage> {
  String? _pickedLabel;
  Uint8List? _previewBytes;
  _Verdict _verdict = _Verdict.none;
  late String _log;

  @override
  void initState() {
    super.initState();
    if (_c2paAvailable) {
      _log = '画像を選ぶと C2PA マニフェストを読みます。\n'
          '・digitalSourceType（trainedAlgorithmicMedia 等）があれば AI 関連\n'
          '・ChatGPT 等は DST を付けないことがあり、issuer / claimGenerator でも推定（デモ）';
    } else {
      final detail = _c2paInitErrorMessage;
      _log = '⚠️ C2PA エンジンの初期化に失敗しました。\n'
          '${detail != null ? '\n$detail\n' : ''}'
          '（ネイティブ lib のロード失敗のときは Logcat の「initC2pa」付近を確認）';
    }
  }

  Future<void> _pickAndAnalyze() async {
    final result = await FilePicker.pickFiles(
      type: FileType.image,
      allowMultiple: false,
      withData: true,
    );
    if (!mounted) return;
    if (result == null || result.files.isEmpty) {
      setState(() => _log = '選択がキャンセルされました。');
      return;
    }

    final f = result.files.single;
    final bytes = await platformFileBytes(f);

    setState(() {
      _pickedLabel = f.path ?? f.name;
      _previewBytes = bytes;
      _verdict = _Verdict.none;
      _log = '読み込み中…';
    });

    if (!_c2paAvailable) {
      setState(() {
        _verdict = _Verdict.error;
        _log = '⚠️ C2PA エンジンが初期化されていません（起動時の C2pa.init / ネイティブ読込失敗）。\n'
            '${_c2paInitErrorMessage ?? ''}';
      });
      return;
    }

    if (bytes == null || bytes.isEmpty) {
      setState(() {
        _verdict = _Verdict.error;
        _log = '⚠️ 画像データを取得できませんでした。\n'
            'path: ${f.path ?? '(なし)'}';
      });
      return;
    }

    final mimeType = _mimeForFileName(f.name);

    try {
      final c2paResult = await analyzeBytes(bytes, mimeType);

      if (!mounted) return;

      if (c2paResult == null) {
        setState(() {
          _verdict = _Verdict.noManifest;
          _log = '✅ C2PA マニフェストなし\n'
              'カメラ写真・スクリーンショット・C2PA 非対応ツールの出力では、\n'
              '「AI ではない」とも「AI 生成」とも断定できません（C2PA がないだけ）。';
        });
        return;
      }

      final lines = <String>[
        '📄 C2PA マニフェスト検出',
        'generator : ${c2paResult.generator ?? '(なし)'}',
        'issuer    : ${c2paResult.issuer ?? '(なし)'}',
        'title     : ${c2paResult.title ?? '(なし)'}',
        '',
        '— actions (${c2paResult.actions.length}) —',
        ...c2paResult.actions.map((a) =>
            '  ${a.action}\n   digitalSourceType: ${a.digitalSourceType ?? '(なし)'}'),
        '',
        '— AI 関連（digitalSourceType が載ったアクション）—',
      ];

      if (c2paResult.hasDigitalSourceAiEvidence) {
        for (final a in c2paResult.aiActions) {
          lines.add('• ${a.digitalSourceType}  (${a.action})');
        }
      } else {
        lines.add(
          '（アクション上の DST なし — OpenAI 等は opened のみのことがある）',
        );
      }

      lines.add('');
      lines.add('— issuer / claimGenerator（デモ用ヒント）—');
      if (c2paResult.hasProvenanceHeuristicAiEvidence) {
        lines.add(c2paResult.provenanceHeuristicNote ?? '(詳細なし)');
      } else {
        lines.add('（既知パターンなし）');
      }

      lines.add('');
      lines.add('— 総合（このアプリの表示ルール）—');
      if (c2paResult.isAiRelated) {
        if (c2paResult.hasDigitalSourceAiEvidence) {
          lines.add('→ digitalSourceType により AI 関連と表示');
        }
        if (c2paResult.hasProvenanceHeuristicAiEvidence) {
          lines.add('→ issuer / claimGenerator により AI 関連と推定表示');
        }
      } else {
        lines.add('→ AI 関連なし（DST も issuer ヒントもなし）');
      }

      setState(() {
        if (!c2paResult.isAiRelated) {
          _verdict = _Verdict.manifestNoAiEvidence;
        } else if (c2paResult.hasDigitalSourceAiEvidence) {
          _verdict = _Verdict.aiImage;
        } else {
          _verdict = _Verdict.aiImageInferred;
        }
        _log = lines.join('\n');
      });
    } on Object catch (e, st) {
      if (!mounted) return;
      setState(() {
        _verdict = _Verdict.error;
        _log = 'C2PA 読み取りエラー:\n$e\n$st';
      });
    }
  }

  @override
  Widget build(final BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        backgroundColor: Theme.of(context).colorScheme.inversePrimary,
        title: const Text('C2PA / digitalSourceType プローブ'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (!_c2paAvailable)
              Container(
                margin: const EdgeInsets.only(bottom: 12),
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: Colors.orange.shade50,
                  border: Border.all(color: Colors.orange),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  kIsWeb
                      ? '⚠️ C2PA エンジン初期化失敗（Web は index.html の c2pa-js を確認）。'
                      : '⚠️ C2PA エンジン初期化失敗（モバイル: c2pa_flutter の Rust ネイティブ。詳細はログ欄・Logcat）。',
                  style: const TextStyle(fontSize: 12, color: Colors.deepOrange),
                ),
              ),

            FilledButton.icon(
              onPressed: _pickAndAnalyze,
              icon: const Icon(Icons.photo_library_outlined),
              label: const Text('ギャラリーから画像を選ぶ'),
            ),

            if (_pickedLabel != null) ...[
              const SizedBox(height: 8),
              Text(
                _pickedLabel!,
                style: Theme.of(context).textTheme.bodySmall,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],

            if (_previewBytes != null) ...[
              const SizedBox(height: 12),
              ConstrainedBox(
                constraints: const BoxConstraints(maxHeight: 200),
                child: Image.memory(_previewBytes!, fit: BoxFit.contain),
              ),
            ],

            if (_verdict == _Verdict.aiImage ||
                _verdict == _Verdict.aiImageInferred) ...[
              const SizedBox(height: 16),
              Material(
                elevation: 1,
                borderRadius: BorderRadius.circular(12),
                color: Colors.deepPurple.shade50,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 14,
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(
                        Icons.auto_awesome,
                        size: 32,
                        color: Colors.deepPurple.shade700,
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              _verdict == _Verdict.aiImage
                                  ? 'AI画像です'
                                  : 'AI由来と推定',
                              style: Theme.of(context)
                                  .textTheme
                                  .titleLarge
                                  ?.copyWith(
                                    fontWeight: FontWeight.bold,
                                    color: Colors.deepPurple.shade900,
                                  ),
                            ),
                            const SizedBox(height: 4),
                            Text(
                              _verdict == _Verdict.aiImage
                                  ? 'digitalSourceType（trainedAlgorithmicMedia 等）で '
                                      'AI 由来が記録されています。'
                                  : 'アクションに digitalSourceType はありませんが、'
                                      'issuer / claimGenerator が OpenAI・ChatGPT 等に一致します。'
                                      '（ツール実装差によるデモ推定）',
                              style: Theme.of(context)
                                  .textTheme
                                  .bodySmall
                                  ?.copyWith(
                                    color: Colors.deepPurple.shade800,
                                  ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ] else if (_verdict == _Verdict.manifestNoAiEvidence) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.blueGrey.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.blueGrey.shade200),
                ),
                child: Text(
                  'マニフェストはあるが、DST も issuer ヒントもなし',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ] else if (_verdict == _Verdict.noManifest) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.amber.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.amber.shade300),
                ),
                child: Text(
                  'C2PA なし → 「AI / 非AI」はこのアプリからは断定できません',
                  style: Theme.of(context).textTheme.bodySmall,
                ),
              ),
            ] else if (_verdict == _Verdict.error) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.red.shade50,
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(color: Colors.red.shade200),
                ),
                child: Text(
                  '解析できませんでした（下のログを参照）',
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: Colors.red.shade900,
                      ),
                ),
              ),
            ],

            const SizedBox(height: 16),

            Expanded(
              child: DecoratedBox(
                decoration: BoxDecoration(
                  border: Border.all(color: Theme.of(context).dividerColor),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: SingleChildScrollView(
                  padding: const EdgeInsets.all(12),
                  child: SelectableText(
                    _log,
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          fontFamily: 'monospace',
                          fontSize: 12,
                        ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
