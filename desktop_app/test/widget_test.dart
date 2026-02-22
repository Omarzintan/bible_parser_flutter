import 'package:flutter_test/flutter_test.dart';

import 'package:bible_parser_desktop/main.dart';

void main() {
  testWidgets('Bible Parser Desktop app smoke test',
      (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const BibleParserDesktopApp());

    // Verify that app title appears
    expect(find.text('Bible Parser Desktop'), findsOneWidget);
  });
}
