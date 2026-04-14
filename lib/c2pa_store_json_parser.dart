import 'dart:convert';

import 'c2pa_result.dart';

C2paResult? parseC2paStoreJsonString(final String jsonString) {
  final storeJson = jsonDecode(jsonString) as Map<String, dynamic>;
  return parseC2paStoreJson(storeJson);
}

C2paResult? parseC2paStoreJson(final Map<String, dynamic> storeJson) {
  final manifests =
      (storeJson['manifests'] as Map?)?.cast<String, dynamic>() ?? const {};
  final activeLabel = storeJson['active_manifest'] as String?;
  final activeManifest = activeLabel != null
      ? manifests[activeLabel] as Map<String, dynamic>?
      : null;
  if (activeManifest == null) return null;

  final sig = activeManifest['signature_info'] as Map<String, dynamic>?;

  return C2paResult(
    title: _stringOrNull(activeManifest['title']),
    generator:
        _claimGeneratorFromManifest(activeManifest) ??
        _stringOrNull(sig?['common_name']) ??
        _stringOrNull(sig?['issuer']),
    issuer: _stringOrNull(sig?['issuer']),
    actions: extractActionsFromManifests(manifests),
  );
}

List<String> describeC2paStoreJson(final Map<String, dynamic> storeJson) {
  final activeLabel = storeJson['active_manifest'] as String?;
  final manifests =
      (storeJson['manifests'] as Map?)?.cast<String, dynamic>() ?? const {};
  final allActions = extractActionsFromManifests(manifests);
  final aiActions =
      allActions.where((final a) => kAiDst.contains(a.digitalSourceType)).toList();
  final lines = <String>[
    '---------- C2PA (native / raw reader.json) ----------',
    'active_manifest: ${activeLabel ?? "(なし)"}',
    'manifests: ${manifests.length}',
    'store-wide actions: ${allActions.length}',
    'store-wide aiActions: ${aiActions.length}',
  ];

  for (final entry in manifests.entries) {
    final manifest = entry.value as Map<String, dynamic>;
    final sig = manifest['signature_info'] as Map<String, dynamic>?;
    final actions = extractActionsFromManifest(manifest);
    final ingredients = (manifest['ingredients'] as List?) ?? const [];
    final marker = entry.key == activeLabel ? ' [active]' : '';

    lines.add('manifest: ${entry.key}$marker');
    lines.add('  claimGenerator: ${_claimGeneratorFromManifest(manifest)}');
    lines.add('  title: ${manifest['title'] ?? "(なし)"}');
    if (sig != null) {
      lines.add(
        '  issuer: ${sig['issuer'] ?? "(なし)"}, '
        'alg: ${sig['alg'] ?? "(なし)"}',
      );
    } else {
      lines.add('  issuer: (なし)');
    }
    for (final action in actions) {
      lines.add(
        '  action: ${action.action} '
        '(digitalSourceType: ${action.digitalSourceType ?? "(なし)"})',
      );
    }
    if (ingredients.isNotEmpty) {
      lines.add('  ingredients: ${ingredients.length}件');
    }
  }

  lines.add('----------------------');
  return lines;
}

List<C2paAction> extractActionsFromManifests(final Map<String, dynamic> manifests) {
  return manifests.values
      .whereType<Map<String, dynamic>>()
      .expand(extractActionsFromManifest)
      .toList();
}

List<C2paAction> extractActionsFromManifest(final Map<String, dynamic> manifest) {
  final assertions = (manifest['assertions'] as List?) ?? const [];
  return assertions
      .whereType<Map>()
      .where((final assertion) {
        final label = assertion['label'] as String?;
        return label != null && label.startsWith('c2pa.actions');
      })
      .expand((final assertion) {
        final data = assertion['data'];
        if (data is! Map) return const <C2paAction>[];
        final actions = data['actions'];
        if (actions is! List) return const <C2paAction>[];
        return actions.whereType<Map>().map((final action) {
          final rawDigitalSourceType =
              action['digitalSourceType'] as String? ??
              action['source_type'] as String?;
          return C2paAction(
            action: action['action'] as String? ?? '',
            digitalSourceType: _digitalSourceTypeSlug(rawDigitalSourceType),
          );
        });
      })
      .toList();
}

String? _claimGeneratorFromManifest(final Map<String, dynamic> manifest) {
  final legacy = manifest['claim_generator'] as String?;
  if (legacy != null && legacy.isNotEmpty) return legacy;

  final info = manifest['claim_generator_info'];
  if (info is! List || info.isEmpty) return null;
  final first = info.first;
  if (first is! Map) return null;
  final name = first['name'] as String?;
  final version = first['version'] as String?;
  if (name == null || name.isEmpty) return null;
  return version == null || version.isEmpty ? name : '$name/$version';
}

String? _digitalSourceTypeSlug(final String? rawValue) {
  if (rawValue == null || rawValue.isEmpty) return null;
  final normalized = rawValue.trim();
  if (!normalized.contains('/')) return normalized;
  return normalized.split('/').last;
}

String? _stringOrNull(final Object? value) => value is String ? value : null;
