/// IPTC NewsCodes digitalSourceType（AI 関連でよく使われるもの）
/// https://cv.iptc.org/newscodes/digitalsourcetype/
const Set<String> kAiDst = {
  'trainedAlgorithmicMedia',
  'compositeWithTrainedAlgorithmicMedia',
  'compositeSynthetic',
  'algorithmicMedia',
};

bool _textContainsAnyHint(final String? text, final List<String> hints) {
  if (text == null || text.isEmpty) return false;
  final lower = text.toLowerCase();
  for (final h in hints) {
    if (lower.contains(h.toLowerCase())) return true;
  }
  return false;
}

class C2paResult {
  const C2paResult({
    required this.title,
    required this.generator,
    required this.issuer,
    required this.actions,
  });

  final String? title;
  final String? generator;
  final String? issuer;
  final List<C2paAction> actions;

  List<C2paAction> get aiActions =>
      actions.where((a) => kAiDst.contains(a.digitalSourceType)).toList();

  /// digitalSourceType がアクション上に載っている（C2PA 上の明示）
  bool get hasDigitalSourceAiEvidence => aiActions.isNotEmpty;

  /// issuer / claimGenerator に既知の生成AIベンダー・製品名（デモ用ヒューリスティック）
  bool get hasProvenanceHeuristicAiEvidence =>
      _issuerSuggestsAi || _generatorSuggestsAi;

  bool get isAiRelated =>
      hasDigitalSourceAiEvidence || hasProvenanceHeuristicAiEvidence;

  String? get provenanceHeuristicNote {
    if (!hasProvenanceHeuristicAiEvidence) return null;
    final parts = <String>[];
    if (_issuerSuggestsAi && issuer != null) parts.add('issuer=$issuer');
    if (_generatorSuggestsAi && generator != null) {
      parts.add('claimGenerator=$generator');
    }
    return parts.isEmpty ? null : parts.join(' / ');
  }

  bool get _issuerSuggestsAi => _textContainsAnyHint(issuer, _issuerAiHints);

  bool get _generatorSuggestsAi =>
      _textContainsAnyHint(generator, _generatorAiHints);

  static const _issuerAiHints = [
    'openai',
    'google',
    'anthropic',
    'microsoft',
    'adobe',
  ];

  static const _generatorAiHints = [
    'chatgpt',
    'gpt-4',
    'gpt-4o',
    'gpt-5',
    'dall',
    'dall·e',
    'gemini',
    'bard',
    'imagen',
    'sora',
    'copilot',
    'midjourney',
    'stable diffusion',
    'firefly',
    'ideogram',
    'leonardo.ai',
    'canva',
  ];
}

class C2paAction {
  const C2paAction({required this.action, this.digitalSourceType});
  final String action;
  final String? digitalSourceType;
}
