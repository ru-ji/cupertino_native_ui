import 'package:flutter_test/flutter_test.dart';

import 'package:cupertino_native_ui_example/app.dart';

void main() {
  testWidgets('demo catalog smoke test', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // The home page renders the large-title catalog scaffold.
    expect(find.text('Cupertino Widgets'), findsWidgets);
  });
}
