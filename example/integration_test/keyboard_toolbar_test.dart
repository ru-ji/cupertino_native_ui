import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

import 'package:cupertino_native_ui/cupertino_native_ui.dart';
import 'package:cupertino_native_ui_example/pages/text_field_demo_page.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('the toolbar demo page builds with its field', (tester) async {
    await tester.pumpWidget(const CupertinoApp(home: TextFieldDemoPage()));
    await tester.pump(const Duration(milliseconds: 800));

    expect(find.byKey(const Key('toolbar-field')), findsOneWidget);
  });

  testWidgets('focusing a field with toolbar actions must not crash', (
    tester,
  ) async {
    // Focus is driven through a FocusNode, not `tester.tap`.
    //
    // A synthetic tap never reaches a Flutter platform view, so the previous
    // tap-based version of this test left the field unfocused and the keyboard
    // down: it asserted `takeException() == null` over a path that was never
    // run, and passed for that reason. The inset assertion at the end is what
    // stops that from happening again.
    final node = FocusNode();
    addTearDown(node.dispose);

    await tester.pumpWidget(
      CupertinoApp(
        home: Scaffold(
          // A ListView, not a Center: `Center` hands its child loose width
          // constraints, the platform view has no intrinsic width, and the
          // native container then comes back `frame = (0 0; 0 0)` with no
          // backing text input for focus to land on.
          body: ListView(
            children: [
              Padding(
                padding: const EdgeInsets.all(12),
                child: CupertinoNativeTextField(
                  key: const Key('focus-field'),
                  focusNode: node,
                  height: 48,
                  placeholder: 'focus me',
                  toolbarActions: [
                    CupertinoNativeButton(
                      onPressed: () {},
                      child: const Text('B'),
                    ),
                    const Spacer(),
                    CupertinoNativeButton(
                      onPressed: () {},
                      child: const Text('Done'),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );

    // Give the platform view time to be created. A `focus` command sent before
    // its channel exists is dropped, and the Flutter-side focus succeeds
    // anyway, so `node.hasFocus` is not a usable signal that the native field
    // heard anything, which is why the loop below watches the inset instead.
    for (var i = 0; i < 6; i++) {
      await tester.pump(const Duration(milliseconds: 300));
    }

    var attempts = 0;
    while (tester.view.viewInsets.bottom == 0 && attempts < 20) {
      attempts++;
      node.requestFocus();
      await tester.pump(const Duration(milliseconds: 300));
      if (tester.view.viewInsets.bottom > 0) break;
      // Drop and re-take focus so the focus-change callback fires again and the
      // native `focus` command is re-sent.
      node.unfocus();
      await tester.pump(const Duration(milliseconds: 100));
    }
    // ignore: avoid_print
    print('TOOLBAR-TEST focused after $attempts attempt(s)');

    // The guard that keeps this test honest. If focus never reaches the native
    // field there is no keyboard and no accessory bar, so this fails instead of
    // passing vacuously.
    expect(
      tester.view.viewInsets.bottom,
      greaterThan(0),
      reason:
          'the native keyboard never came up, so the toolbar was never built '
          'and this test proved nothing',
    );
    expect(tester.takeException(), isNull);

    // Hold the keyboard up: the old `.keyboard` placement crashed on the first
    // focus or shortly after, and the accessory install is asynchronous.
    await tester.pump(const Duration(seconds: 6));
    expect(tester.takeException(), isNull);
  });
}
