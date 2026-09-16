import 'package:cupertino_widgets/cupertino_widgets.dart';
import 'package:flutter/cupertino.dart' show OverlayVisibilityMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the **wire format** every `CupertinoNative*` widget sends to Swift.
///
/// The Dart-facing parameter names were unified in 0.1.0 (`color` / `tint` /
/// `accentColor` / `primaryColor` all became `activeColor`, `selection` became
/// `value`, the five `glass*` parameters became one `CupertinoGlass`) while the
/// method-channel keys deliberately did **not** change — the Swift side still
/// reads the old spellings.
///
/// That combination is invisible to the compiler and to every other test: a
/// wrong key here still analyzes, still passes unit tests, and simply produces
/// a widget that ignores the property on a real device. These tests decode the
/// actual `creationParams` handed to `UiKitView` and assert the keys.
///
/// The expected keys must match
/// `ios/cupertino_widgets/Sources/cupertino_widgets/Models/*.swift`.
void main() {
  // Every widget here only builds a native view on iOS; the variant applies
  // the platform override per test (a global override trips the test
  // framework's debug-variable invariant check).
  final iOS = TargetPlatformVariant.only(TargetPlatform.iOS);
  late List<Map<Object?, Object?>> created;

  setUp(() {
    created = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
          if (call.method == 'create') {
            final args = call.arguments as Map;
            final params = args['params'];
            if (params is Uint8List) {
              final decoded = const StandardMessageCodec().decodeMessage(
                ByteData.sublistView(params),
              );
              if (decoded is Map) created.add(decoded);
            }
          }
          return null;
        });
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, null);
  });

  /// Pumps [child] on a fake iOS platform and returns the params of the first
  /// native view it creates.
  Future<Map<Object?, Object?>> paramsOf(
    WidgetTester tester,
    Widget child,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: Center(child: SizedBox(width: 390, height: 400, child: child)),
      ),
    );
    // Several widgets schedule a delayed intrinsic-size request after the
    // native view is created; pump past it so no timer outlives the tree.
    await tester.pump(const Duration(milliseconds: 100));
    expect(
      created,
      isNotEmpty,
      reason: 'the widget never created a native platform view',
    );
    return created.first;
  }

  const green = Color(0xFF34C759);

  group('activeColor keeps its per-widget channel key', () {
    testWidgets('button sends it as "color"', (tester) async {
      final params = await paramsOf(
        tester,
        const CupertinoNativeButton(
          color: green,
          onPressed: null,
          child: Text('Save'),
        ),
      );
      expect(params['color'], green.toARGB32());
      expect(params['title'], 'Save');
    }, variant: iOS);

    testWidgets('switch sends it as "color"', (tester) async {
      final params = await paramsOf(
        tester,
        const CupertinoNativeSwitch(value: true, activeTrackColor: green),
      );
      expect(params['color'], green.toARGB32());
      expect(params['value'], true);
    }, variant: iOS);

    testWidgets('segmented control sends it as "color"', (tester) async {
      final params = await paramsOf(
        tester,
        CupertinoNativeSlidingSegmentedControl<int>(
          children: const {0: Text('A'), 1: Text('B')},
          groupValue: 1,
          thumbColor: green,
          onValueChanged: (_) {},
        ),
      );
      expect(params['color'], green.toARGB32());
      expect(params['selectedIndex'], 1);
      expect(params['items'], ['A', 'B']);
    }, variant: iOS);

    testWidgets('progress indicator sends it as "color"', (tester) async {
      final params = await paramsOf(
        tester,
        const CupertinoNativeActivityIndicator(color: green),
      );
      expect(params['color'], green.toARGB32());
    }, variant: iOS);

    testWidgets('date picker sends it as "tint"', (tester) async {
      final params = await paramsOf(
        tester,
        CupertinoNativeDatePicker(
          initialDateTime: DateTime(2026, 1, 1),
          onDateTimeChanged: (_) {},
          activeColor: green,
        ),
      );
      expect(params['tint'], green.toARGB32());
    }, variant: iOS);

    // The tab bar serializes itself two different ways and both had to keep
    // their keys: standalone it is a UIKit view taking `tint`/`selectedIndex`,
    // nested in a scaffold it is a SwiftUI TabView taking the
    // `accentColor`/`selection` of TabBarConfig.swift.
    testWidgets('standalone tab bar sends it as "tint"', (tester) async {
      final params = await paramsOf(
        tester,
        const CupertinoNativeTabBar(
          currentIndex: 1,
          activeColor: green,
          items: [
            CupertinoNativeTab(title: 'Home', id: 'home'),
            CupertinoNativeTab(title: 'Profile', id: 'profile'),
          ],
        ),
      );
      expect(params['tint'], green.toARGB32());
      // Standalone it travels as `selectedIndex`.
      expect(params['selectedIndex'], 1);
    }, variant: iOS);

    test('tab bar nested in a scaffold sends it as "accentColor"', () {
      final map = const CupertinoNativeTabBar(
        activeColor: green,
        items: [CupertinoNativeTab(title: 'Home', id: 'home')],
      ).toMap();

      expect(map['accentColor'], green.toARGB32());
      // `currentIndex` is the Dart name; the scaffold takes the tab's id as
      // `selection`.
      expect(map['selection'], 'home');
    });

    testWidgets('scaffold sends it as "primaryColor"', (tester) async {
      final params = await paramsOf(
        tester,
        const CupertinoNativePageScaffold(body: 'home', activeColor: green),
      );
      expect(params['primaryColor'], green.toARGB32());
      expect(params['body'], 'home');
    }, variant: iOS);

    testWidgets('list sends it as "tint"', (tester) async {
      final params = await paramsOf(
        tester,
        const CupertinoNativeList(
          activeColor: green,
          sections: [
            CupertinoNativeListSection(
              children: [CupertinoNativeListTile(id: 'a', title: 'Row A')],
            ),
          ],
        ),
      );
      expect(params['tint'], green.toARGB32());
    }, variant: iOS);
  });

  group('text field', () {
    testWidgets('CupertinoGlass expands back to the five glass keys', (
      tester,
    ) async {
      final params = await paramsOf(
        tester,
        const CupertinoNativeTextField(
          placeholder: 'Search',
          glass: CupertinoGlass(
            cornerRadius: 22,
            variant: CupertinoGlassVariant.clear,
            interactive: false,
            tint: green,
          ),
        ),
      );
      expect(params['glass'], true);
      expect(params['glassCornerRadius'], 22.0);
      expect(params['glassVariant'], 'clear');
      expect(params['glassInteractive'], false);
      expect(params['glassTint'], green.toARGB32());
    }, variant: iOS);

    testWidgets('no glass sends the defaults the Swift side expects', (
      tester,
    ) async {
      final params = await paramsOf(
        tester,
        const CupertinoNativeTextField(placeholder: 'Plain'),
      );
      expect(params['glass'], false);
      // Swift reads these unconditionally, so they must stay non-null.
      expect(params['glassCornerRadius'], 16.0);
      expect(params['glassVariant'], 'regular');
      expect(params['glassInteractive'], true);
    }, variant: iOS);

    testWidgets('Flutter enums map to UIKit case names', (tester) async {
      final params = await paramsOf(
        tester,
        const CupertinoNativeTextField(
          clearButtonMode: OverlayVisibilityMode.notEditing,
          verticalAlignment: TextAlignVertical.bottom,
        ),
      );
      // Flutter spells these differently from UIKit — see text_field_wire.dart.
      expect(params['clearButtonMode'], 'unlessEditing');
      expect(params['verticalAlignment'], 'bottom');
    }, variant: iOS);
  });

  testWidgets('the switch keeps the pre-rename platform view id', (
    tester,
  ) async {
    // CupertinoNativeToggle became CupertinoNativeSwitch on the Dart side
    // only; this id is registered in FlutterCupertinoPlugin.swift.
    final viewTypes = <String>[];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
          if (call.method == 'create') {
            viewTypes.add((call.arguments as Map)['viewType'] as String);
          }
          return null;
        });

    await tester.pumpWidget(
      const MaterialApp(
        home: Center(child: CupertinoNativeSwitch(value: false)),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));

    expect(
      viewTypes,
      contains('com.example.cupertino_widgets/cupertino_native_toggle'),
    );
  }, variant: iOS);

  // The bars' edge effect is a native view on iOS: pin what it asks Swift
  // for — the adaptive wash, the system's radius, and the page colour.
  testWidgets('scroll edge effect runs the adaptive native blur', (
    tester,
  ) async {
    final params = await paramsOf(tester, const CupertinoScrollEdgeEffect());
    expect(params['adaptive'], true);
    expect(params['edge'], 'top');
    expect(params['intensity'], 1.0);
    expect(params['sigma'], lessThanOrEqualTo(1.0));
    expect(params['tint'], isNull);
  }, variant: iOS);

  // The group is one platform view for several glasses — the only arrangement
  // in which they can merge. If the items stop travelling as one payload,
  // there is no group left, just a row.
  testWidgets('glass group sends its items as one payload', (tester) async {
    final params = await paramsOf(
      tester,
      CupertinoNativeGlassGroup(
        spacing: 4,
        items: [
          CupertinoNativeGlassGroupItem(
            actionId: 'back',
            icon: CupertinoNativeIcon.symbol(CupertinoSymbols.chevronBackward),
          ),
          const CupertinoNativeGlassGroupItem(
            actionId: 'edit',
            title: 'Edit',
            shape: CupertinoGlassGroupShape.capsule,
          ),
        ],
      ),
    );

    expect(params['spacing'], 4.0);
    final items = params['items'] as List;
    expect(items.length, 2);
    expect((items[0] as Map)['actionId'], 'back');
    expect((items[1] as Map)['shape'], 'capsule');
    // The id is also the morph identity on the SwiftUI side.
    expect((items[1] as Map)['actionId'], 'edit');
  }, variant: iOS);

  group('keyboard toolbar lowering', () {
    testWidgets('widgets become native nodes, in order', variant: iOS, (
      tester,
    ) async {
      final params = await paramsOf(
        tester,
        CupertinoNativeTextField(
          keyboardToolbar: [
            CupertinoNativeButton(
              onPressed: () {},
              child: CupertinoSymbolImage.symbol(CupertinoSymbols.chevronUp),
            ),
            const Spacer(),
            CupertinoNativeButton(
              onPressed: () {},
              child: const Text('Done'),
            ),
          ],
        ),
      );

      final toolbar = params['keyboardToolbar'] as List?;
      expect(toolbar, isNotNull, reason: 'the key the Swift config reads');
      expect(toolbar, hasLength(3));

      final first = toolbar![0] as Map;
      expect(first['type'], 'button');
      expect(first['id'], 'item0');
      // ButtonConfig requires a non-null `title` and `style`; a symbol-only
      // button must still carry the icon the native side draws.
      final firstButton = first['button'] as Map;
      expect(firstButton['style'], isNotNull);
      expect(firstButton['icon'], isNotNull);

      expect((toolbar[1] as Map)['type'], 'spacer');

      final last = toolbar[2] as Map;
      expect(last['type'], 'button');
      expect(((last['button'] as Map)['title']), 'Done');
    });

    testWidgets('a Flutter island carries its route', variant: iOS, (
      tester,
    ) async {
      final params = await paramsOf(
        tester,
        const CupertinoNativeTextField(
          keyboardToolbar: [CupertinoNativeFlutterView('editorBar')],
        ),
      );
      final node = (params['keyboardToolbar'] as List).single as Map;
      expect(node['type'], 'flutter');
      expect(node['route'], 'editorBar');
    });
  });
}
