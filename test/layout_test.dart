import 'package:cupertino_native_ui/cupertino_native_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// The other tests host every widget in a fixed 390×600 box, which hides how
/// they lay out where apps actually put them: in a scroll view or a Column
/// (no height limit) and in a Row (no width limit). These pin that.
void main() {
  final iOS = TargetPlatformVariant.only(TargetPlatform.iOS);

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, (_) async {
          return null;
        });
    CupertinoNativePhotosPicker.debugIsSupportedOverride = true;
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, null);
    CupertinoNativePhotosPicker.debugIsSupportedOverride = null;
  });

  Future<void> pumpIn(WidgetTester tester, Widget page) async {
    await tester.pumpWidget(MaterialApp(home: Scaffold(body: page)));
    await tester.pump(const Duration(milliseconds: 100));
  }

  final widgets = <String, Widget Function()>{
    'slider': () => CupertinoNativeSlider(value: 0.5, onChanged: (_) {}),
    'switch': () => CupertinoNativeSwitch(value: true, onChanged: (_) {}),
    'checkbox': () => CupertinoNativeCheckbox(value: true, onChanged: (_) {}),
    'button': () =>
        CupertinoNativeButton(onPressed: () {}, child: const Text('Go')),
    'icon button': () =>
        CupertinoNativeButton.icon(CupertinoSymbols.plus, onPressed: () {}),
    'menu': () => const CupertinoNativeMenu(items: []),
    'date picker': () => CupertinoNativeDatePicker(onDateTimeChanged: (_) {}),
    'calendar': () => CupertinoNativeDatePicker(
      style: CupertinoNativeDatePickerStyle.graphical,
      onDateTimeChanged: (_) {},
    ),
    'stepper': () => CupertinoNativeStepper(value: 1, onChanged: (_) {}),
    'color picker': () =>
        CupertinoNativeColorPicker(color: Colors.red, onChanged: (_) {}),
    'gauge': () => const CupertinoNativeGauge(value: 0.5),
    'multi-date picker': () =>
        CupertinoNativeMultiDatePicker(dates: const {}, onChanged: (_) {}),
    'text editor': () => CupertinoNativeTextEditor(text: '', onChanged: (_) {}),
    'symbol': () => const CupertinoNativeSymbol('star'),
    'list': () => const CupertinoNativeList(sections: []),
    'photos picker': () => CupertinoNativePhotosPicker(onChanged: (_) {}),
  };

  group('in a scroll view (no height limit)', () {
    for (final MapEntry(key: name, value: build) in widgets.entries) {
      testWidgets(name, (tester) async {
        await pumpIn(tester, ListView(children: [build()]));
        expect(tester.takeException(), isNull);
      }, variant: iOS);
    }
  });

  group('photos picker without a height', () {
    testWidgets('inline falls back to a few grid rows', (tester) async {
      await pumpIn(
        tester,
        ListView(children: [CupertinoNativePhotosPicker(onChanged: (_) {})]),
      );
      expect(tester.getSize(find.byType(UiKitView)).height, 420);
    }, variant: iOS);

    testWidgets('compact falls back to one row of thumbnails', (tester) async {
      await pumpIn(
        tester,
        ListView(
          children: [
            CupertinoNativePhotosPicker(
              style: CupertinoNativePhotosPickerStyle.compact,
              onChanged: (_) {},
            ),
          ],
        ),
      );
      expect(tester.getSize(find.byType(UiKitView)).height, 96);
    }, variant: iOS);

    testWidgets('a given height wins', (tester) async {
      await pumpIn(
        tester,
        ListView(
          children: [
            SizedBox(
              height: 250,
              child: CupertinoNativePhotosPicker(onChanged: (_) {}),
            ),
          ],
        ),
      );
      expect(tester.getSize(find.byType(UiKitView)).height, 250);
    }, variant: iOS);
  });

  group('in a Row (no width limit)', () {
    // Sized to their content: fine as they are.
    for (final name in [
      'switch',
      'checkbox',
      'button',
      'icon button',
      'menu',
      'date picker',
      'stepper',
      'color picker',
      'symbol',
    ]) {
      testWidgets('$name sizes itself', (tester) async {
        await pumpIn(tester, Row(children: [widgets[name]!()]));
        expect(tester.takeException(), isNull);
      }, variant: iOS);
    }

    // Full-width by nature, like Flutter's own Slider or TextField: in a Row
    // they need an Expanded, and with one they are fine.
    for (final name in [
      'slider',
      'gauge',
      'multi-date picker',
      'text editor',
      'list',
    ]) {
      testWidgets('$name fills an Expanded', (tester) async {
        await pumpIn(
          tester,
          Row(children: [Expanded(child: widgets[name]!())]),
        );
        expect(tester.takeException(), isNull);
      }, variant: iOS);
    }
  });
}
