import 'package:flutter_test/flutter_test.dart';

import 'package:c2pa_ai_gallery_probe/main.dart';

void main() {
  testWidgets('ホームに画像選択ボタンがある', (final WidgetTester tester) async {
    await tester.pumpWidget(const C2paProbeApp());
    expect(find.text('ギャラリーから画像を選ぶ'), findsOneWidget);
  });
}
