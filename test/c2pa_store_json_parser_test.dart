import 'package:flutter_test/flutter_test.dart';

import 'package:c2pa_ai_gallery_probe/c2pa_store_json_parser.dart';

void main() {
  test('parses store-wide AI evidence from chained manifests', () {
    final storeJson = <String, dynamic>{
      'active_manifest': 'urn:c2pa:opened',
      'manifests': <String, dynamic>{
        'urn:c2pa:created': <String, dynamic>{
          'claim_generator_info': <Map<String, dynamic>>[
            <String, dynamic>{
              'name': 'ChatGPT',
              'version': '1.0',
            },
          ],
          'assertions': <Map<String, dynamic>>[
            <String, dynamic>{
              'label': 'c2pa.actions.v2',
              'data': <String, dynamic>{
                'actions': <Map<String, dynamic>>[
                  <String, dynamic>{
                    'action': 'c2pa.created',
                    'digitalSourceType':
                        'http://cv.iptc.org/newscodes/digitalsourcetype/trainedAlgorithmicMedia',
                  },
                ],
              },
            },
          ],
        },
        'urn:c2pa:opened': <String, dynamic>{
          'title': 'image.png',
          'claim_generator_info': <Map<String, dynamic>>[
            <String, dynamic>{'name': 'ChatGPT'},
          ],
          'signature_info': <String, dynamic>{
            'issuer': 'OpenAI',
            'common_name': 'OpenAI',
            'alg': 'Es256',
          },
          'ingredients': <Map<String, dynamic>>[
            <String, dynamic>{'active_manifest': 'urn:c2pa:created'},
          ],
          'assertions': <Map<String, dynamic>>[
            <String, dynamic>{
              'label': 'c2pa.actions.v2',
              'data': <String, dynamic>{
                'actions': <Map<String, dynamic>>[
                  <String, dynamic>{'action': 'c2pa.opened'},
                ],
              },
            },
          ],
        },
      },
    };

    final result = parseC2paStoreJson(storeJson);

    expect(result, isNotNull);
    expect(result!.title, 'image.png');
    expect(result.generator, 'ChatGPT');
    expect(result.issuer, 'OpenAI');
    expect(result.actions.map((final a) => a.action), contains('c2pa.created'));
    expect(
      result.aiActions.map((final a) => a.digitalSourceType),
      contains('trainedAlgorithmicMedia'),
    );
    expect(result.hasDigitalSourceAiEvidence, isTrue);
  });

  test('accepts legacy source_type when present', () {
    final manifest = <String, dynamic>{
      'assertions': <Map<String, dynamic>>[
        <String, dynamic>{
          'label': 'c2pa.actions',
          'data': <String, dynamic>{
            'actions': <Map<String, dynamic>>[
              <String, dynamic>{
                'action': 'c2pa.created',
                'source_type':
                    'http://cv.iptc.org/newscodes/digitalsourcetype/compositeWithTrainedAlgorithmicMedia',
              },
            ],
          },
        },
      ],
    };

    final actions = extractActionsFromManifest(manifest);

    expect(actions, hasLength(1));
    expect(actions.single.digitalSourceType, 'compositeWithTrainedAlgorithmicMedia');
  });
}
