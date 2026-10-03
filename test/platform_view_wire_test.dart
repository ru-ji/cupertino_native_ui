import 'package:cupertino_widgets/cupertino_widgets.dart';
import 'package:cupertino_widgets/src/internal/bar_slot.dart';
import 'package:flutter/cupertino.dart'
    show CupertinoColors, CupertinoPageScaffold, OverlayVisibilityMode;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Pins the **wire format** every `CupertinoNative*` widget sends to Swift.
///
/// The Dart parameter names and the method-channel keys differ in places
/// (`activeColor` travels as `color` or `tint`, `value` as `selection`, `glass`
/// + `glassTint` as the native glass keys).
///
/// That is invisible to the compiler and to every other test: a wrong key
/// here still analyzes, still passes unit tests, and simply produces
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

    testWidgets('button sends its title weight as the 0...8 index', (
      tester,
    ) async {
      // The native side reads `Font.Weight(weightIndex:)`: 700 fell through
      // to regular.
      final params = await paramsOf(
        tester,
        const CupertinoNativeButton(
          onPressed: null,
          child: Text('Edit', style: TextStyle(fontWeight: FontWeight.w700)),
        ),
      );
      expect(params['fontWeight'], 6);
    }, variant: iOS);

    testWidgets('a button sharing a glass in the bar takes the bar weight', (
      tester,
    ) async {
      // Two buttons in one glass capsule in the bar: still bar buttons, so
      // their symbols take the system's medium weight.
      await paramsOf(
        tester,
        BarSlot(
          child: CupertinoNativeGlassContainer(
            shape: CupertinoGlassShape.capsule,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                CupertinoNativeButton(
                  onPressed: () {},
                  child: CupertinoSymbolImage.symbol(CupertinoSymbols.plus),
                ),
                CupertinoNativeButton(
                  onPressed: () {},
                  child: CupertinoSymbolImage.symbol(CupertinoSymbols.ellipsis),
                ),
              ],
            ),
          ),
        ),
      );
      final buttons = created.where((p) => p.containsKey('labelStyle'));
      expect(buttons, hasLength(2));
      for (final button in buttons) {
        expect((button['icon'] as Map)['weight'], 'medium');
      }
    }, variant: iOS);

    testWidgets('switch sends it as "color"', (tester) async {
      final params = await paramsOf(
        tester,
        const CupertinoNativeSwitch(value: true, activeTrackColor: green),
      );
      expect(params['color'], green.toARGB32());
      expect(params['value'], true);
    }, variant: iOS);

    testWidgets('checkbox sends it as "color"', (tester) async {
      final params = await paramsOf(
        tester,
        const CupertinoNativeCheckbox(
          value: true,
          activeColor: green,
          label: 'Subscribe',
        ),
      );
      expect(params['color'], green.toARGB32());
      expect(params['value'], true);
      expect(params['label'], 'Subscribe');
      expect(params['enabled'], isFalse, reason: 'onChanged is null: disabled');
    }, variant: iOS);

    testWidgets('stepper goes through the shared control view', (tester) async {
      final params = await paramsOf(
        tester,
        CupertinoNativeStepper(
          value: 3,
          max: 10,
          activeColor: green,
          onChanged: (_) {},
        ),
      );
      expect(params['kind'], 'stepper');
      expect(params['value'], 3);
      expect(params['tint'], green.toARGB32());
      expect(params['hug'], true, reason: 'no label: sized to the control');
      expect(params['enabled'], true);
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
    testWidgets('glass expands back to the five glass keys', (tester) async {
      final params = await paramsOf(
        tester,
        const CupertinoNativeTextField(
          placeholder: 'Search',
          cornerRadius: 22,
          glass: CupertinoNativeGlass.clear,
          glassTint: green,
        ),
      );
      expect(params['glass'], true);
      expect(params['glassCornerRadius'], 22.0);
      expect(params['glassVariant'], 'clear');
      // Always interactive.
      expect(params['glassInteractive'], true);
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

    testWidgets('icon spacing defaults to 8', (tester) async {
      final params = await paramsOf(
        tester,
        const CupertinoNativeTextField(placeholder: 'Plain'),
      );
      expect(params['iconSpacing'], 8.0);
    }, variant: iOS);

    testWidgets('icon spacing is sent as given', (tester) async {
      final params = await paramsOf(
        tester,
        const CupertinoNativeTextField(placeholder: 'Spaced', iconSpacing: 12),
      );
      expect(params['iconSpacing'], 12.0);
    }, variant: iOS);

    testWidgets('identity glass keeps its SwiftUI name', (tester) async {
      final params = await paramsOf(
        tester,
        const CupertinoNativeTextField(glass: CupertinoNativeGlass.identity),
      );
      expect(params['glass'], true);
      expect(params['glassVariant'], 'identity');
    }, variant: iOS);

    test('a transcribed field sends the UIKit clear-button names too', () {
      // Sent `editing` (the Flutter name) once, which Swift never matched:
      // the clear button of a field in a list or body never showed.
      final map = CupertinoNativeBody.textField(
        id: 'f',
        clearButtonMode: OverlayVisibilityMode.editing,
      ).toMap(isDark: false);
      expect((map['textField'] as Map)['clearButtonMode'], 'whileEditing');
    });
  });

  group('text editor', () {
    testWidgets('sends the keys NativeControlView reads', (tester) async {
      final params = await paramsOf(
        tester,
        CupertinoNativeTextEditor(
          text: '',
          onChanged: (_) {},
          style: const TextStyle(fontWeight: FontWeight.w700),
          glass: CupertinoNativeGlass.clear,
          glassTint: green,
          padding: const EdgeInsets.fromLTRB(1, 2, 3, 4),
          placeholderPadding: const EdgeInsets.only(top: 6, left: 7),
          maxLength: 280,
        ),
      );
      expect(params['kind'], 'textEditor');
      // `FontWeight.index`, 0...8, as the text field sends it.
      expect(params['fontWeight'], 6);
      expect(params['glass'], 'clear');
      expect(params['glassTint'], green.toARGB32());
      expect(params['padding'], {
        'left': 1.0,
        'top': 2.0,
        'right': 3.0,
        'bottom': 4.0,
      });
      expect(params['placeholderTop'], 6.0);
      expect(params['placeholderLeading'], 7.0);
      expect(params['maxLength'], 280);
      expect(params['keyboardType'], 'multiline');
      expect(params['textCapitalization'], 'sentences');
      expect(params.containsKey('prefix'), isFalse);
    }, variant: iOS);

    testWidgets('a prefix travels as one lowered node', (tester) async {
      final params = await paramsOf(
        tester,
        CupertinoNativeTextEditor(
          text: '',
          onChanged: (_) {},
          prefix: CupertinoNativeButton(
            onPressed: () {},
            child: const Text('Go'),
          ),
        ),
      );
      final prefix = params['prefix'] as List;
      expect(prefix, hasLength(1));
      expect((prefix.single as Map)['type'], 'button');
    }, variant: iOS);
  });

  group('list rows', () {
    Future<Map<Object?, Object?>> firstRow(
      WidgetTester tester,
      CupertinoNativeListTileCallback? onRowTap,
    ) async {
      final params = await paramsOf(
        tester,
        CupertinoNativeList(
          onRowTap: onRowTap,
          sections: [
            CupertinoNativeListSection(
              children: [CupertinoNativeListTile(id: 'a', title: 'A')],
            ),
          ],
        ),
      );
      final section = (params['sections'] as List).first as Map;
      return (section['rows'] as List).first as Map;
    }

    testWidgets('are not buttons when nobody listens', (tester) async {
      // A Button cell flashes the pressed highlight on every tap.
      expect((await firstRow(tester, null))['tappable'], false);
    }, variant: iOS);

    testWidgets('are buttons once onRowTap is given', (tester) async {
      expect((await firstRow(tester, (_) {}))['tappable'], true);
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
    final params = await paramsOf(
      tester,
      const CupertinoPageScaffold(
        backgroundColor: green,
        child: CupertinoScrollEdgeEffect(),
      ),
    );
    // A background the page chose fixes the wash to it, as SwiftUI's.
    expect(params['adaptive'], false);
    expect(params['edge'], 'top');
    expect(params['intensity'], 1.0);
    // The system PocketBlur's radius.
    expect(params['sigma'], 1.0);
    expect(params['tint'], green.withValues(alpha: 0.84).toARGB32());
  }, variant: iOS);

  // The system's bar items follow the content under its edge effect even
  // when the wash is fixed: the effect keeps measuring for them.
  testWidgets('scroll edge effect measures the content under a fixed wash', (
    tester,
  ) async {
    final params = await paramsOf(
      tester,
      CupertinoPageScaffold(
        backgroundColor: green,
        child: CupertinoScrollEdgeEffect(onBrightnessChanged: (_) {}),
      ),
    );
    expect(params['adaptive'], false);
    expect(params['tracksLuma'], true);
  }, variant: iOS);

  testWidgets('a bar button takes the brightness of the content under it', (
    tester,
  ) async {
    // A light app over dark content: the bar's glass goes dark, as the
    // system's does.
    final params = await paramsOf(
      tester,
      BarSlot(
        brightness: Brightness.dark,
        child: CupertinoNativeButton.icon(
          CupertinoSymbols.chevronBackward,
          onPressed: () {},
        ),
      ),
    );
    // Its own appearance only: the window keeps the app's.
    expect(params['appearanceDark'], true);
    expect(params['isDark'], false);
  }, variant: iOS);

  testWidgets('scroll edge effect does not blur the bottom edge', (
    tester,
  ) async {
    // The tab bar's edge is the wash alone, as the system's.
    final params = await paramsOf(
      tester,
      const CupertinoScrollEdgeEffect(
        edge: CupertinoScrollEdgeEffectEdge.bottom,
      ),
    );
    expect(params['sigma'], 0.0);
  }, variant: iOS);

  // Only the system backgrounds — a CupertinoPageScaffold's, and the one a
  // grouped list lays under its cards — let the wash adapt; any other colour
  // fixes it, wherever it comes from.
  testWidgets(
    'scroll edge effect follows the content on the system background',
    (tester) async {
      final params = await paramsOf(
        tester,
        const CupertinoPageScaffold(
          backgroundColor: CupertinoColors.systemBackground,
          child: CupertinoScrollEdgeEffect(),
        ),
      );
      expect(params['adaptive'], true);
    },
    variant: iOS,
  );

  testWidgets(
    'scroll edge effect follows the content on the grouped background',
    (tester) async {
      final params = await paramsOf(
        tester,
        const CupertinoPageScaffold(
          backgroundColor: CupertinoColors.systemGroupedBackground,
          child: CupertinoScrollEdgeEffect(),
        ),
      );
      expect(params['adaptive'], true);
    },
    variant: iOS,
  );

  testWidgets('scroll edge effect is fixed on a theme colour of the app', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: ThemeData(scaffoldBackgroundColor: green),
        home: const CupertinoPageScaffold(child: CupertinoScrollEdgeEffect()),
      ),
    );
    await tester.pump(const Duration(milliseconds: 100));
    expect(created.first['adaptive'], false);
    expect(created.first['tint'], green.withValues(alpha: 0.84).toARGB32());
  }, variant: iOS);

  // A tab bar laid over its tabs is in none of their scaffolds: the effect
  // finds the visible tab's under it, as the system's comes from that tab's
  // own scroll view.
  testWidgets('scroll edge effect takes the page showing under it', (
    tester,
  ) async {
    const red = Color(0xFFFF0000);
    Future<Color> washOver(int tab) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Stack(
            children: [
              IndexedStack(
                index: tab,
                children: const [
                  CupertinoPageScaffold(
                    backgroundColor: red,
                    child: SizedBox.expand(),
                  ),
                  CupertinoPageScaffold(
                    backgroundColor: green,
                    child: SizedBox.expand(),
                  ),
                ],
              ),
              const Positioned(
                left: 0,
                right: 0,
                bottom: 0,
                height: 80,
                child: CupertinoScrollEdgeEffect(
                  edge: CupertinoScrollEdgeEffectEdge.bottom,
                  style: CupertinoScrollEdgeEffectStyle.hard,
                ),
              ),
            ],
          ),
        ),
      );
      // Found after a frame, drawn on the next.
      await tester.pump();
      return tester
          .widget<ColoredBox>(
            find.descendant(
              of: find.byType(CupertinoScrollEdgeEffect),
              matching: find.byType(ColoredBox),
            ),
          )
          .color;
    }

    expect(await washOver(1), green.withValues(alpha: 0.91));
    expect(await washOver(0), red.withValues(alpha: 0.91));
  });

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

  testWidgets('glass group sends the transition and union fields', (
    tester,
  ) async {
    final params = await paramsOf(
      tester,
      CupertinoNativeGlassGroup(
        spacing: 4,
        mergeDistance: 12,
        transition: CupertinoGlassTransition.materialize,
        items: [
          const CupertinoNativeGlassGroupItem(
            actionId: 'play',
            title: 'Play',
            glassVisible: false,
            unionId: 'pair',
            transition: CupertinoGlassTransition.matchedGeometry,
          ),
          const CupertinoNativeGlassGroupItem(
            actionId: 'pause',
            title: 'Pause',
          ),
        ],
      ),
    );

    // The group's transition is the default for items that state none.
    expect(params['transition'], 'materialize');

    // The blend radius travels separately from the gap: they are two different
    // questions, and answering both with `spacing` is what made a union
    // impossible to isolate.
    expect(params['spacing'], 4);
    expect(params['mergeDistance'], 12);

    final stated = (params['items'] as List)[0] as Map;
    expect(stated['glassVisible'], false);
    expect(stated['unionId'], 'pair');
    // An item's own transition wins over the group's.
    expect(stated['transition'], 'matchedGeometry');

    // An item that says nothing keeps its glass, stands alone, and takes the
    // group's transition.
    final plain = (params['items'] as List)[1] as Map;
    expect(plain['glassVisible'], true);
    expect(plain['unionId'], isNull);
    expect(plain['transition'], isNull);
  }, variant: iOS);

  group('toolbarActions lowering', () {
    testWidgets('widgets become native nodes, in order', variant: iOS, (
      tester,
    ) async {
      final params = await paramsOf(
        tester,
        CupertinoNativeTextField(
          toolbarActions: [
            CupertinoNativeButton(
              onPressed: () {},
              child: CupertinoSymbolImage.symbol(CupertinoSymbols.chevronUp),
            ),
            const Spacer(),
            CupertinoNativeButton(onPressed: () {}, child: const Text('Done')),
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
          toolbarActions: [CupertinoNativeFlutterView('editorBar')],
        ),
      );
      final node = (params['keyboardToolbar'] as List).single as Map;
      expect(node['type'], 'flutter');
      expect(node['route'], 'editorBar');
    });

    testWidgets('a list row trailing lowers to native nodes', variant: iOS, (
      tester,
    ) async {
      final params = await paramsOf(
        tester,
        CupertinoNativeList(
          sections: [
            CupertinoNativeListSection(
              header: 'Connectivity',
              children: [
                CupertinoNativeListTile(
                  id: 'airplane',
                  title: 'Airplane Mode',
                  trailing: CupertinoNativeSwitch(
                    value: true,
                    onChanged: (_) {},
                  ),
                ),
              ],
            ),
          ],
        ),
      );

      final rows = ((params['sections'] as List).single as Map)['rows'] as List;
      final row = rows.single as Map;
      expect(row['id'], 'airplane');
      final trailing = row['trailing'] as List;
      expect(trailing, hasLength(1));
      final node = trailing.single as Map;
      expect(node['type'], 'toggle');
      expect(node['id'], 'item0');
      expect((node['toggle'] as Map)['value'], isTrue);
    });

    testWidgets('a checkbox lowers to a native checkbox node', variant: iOS, (
      tester,
    ) async {
      final params = await paramsOf(
        tester,
        CupertinoNativeList(
          sections: [
            CupertinoNativeListSection(
              children: [
                CupertinoNativeListTile(
                  id: 'newsletter',
                  title: 'Newsletter',
                  trailing: CupertinoNativeCheckbox(
                    value: true,
                    onChanged: (_) {},
                  ),
                ),
              ],
            ),
          ],
        ),
      );

      final rows = ((params['sections'] as List).single as Map)['rows'] as List;
      final node = ((rows.single as Map)['trailing'] as List).single as Map;
      expect(node['type'], 'checkbox');
      expect(node['id'], 'item0');
      expect((node['checkbox'] as Map)['value'], isTrue);
      expect((node['checkbox'] as Map)['enabled'], isTrue);
    });

    testWidgets('a stepper lowers to a native control node', variant: iOS, (
      tester,
    ) async {
      double? got;
      final params = await paramsOf(
        tester,
        CupertinoNativeList(
          sections: [
            CupertinoNativeListSection(
              children: [
                CupertinoNativeListTile(
                  id: 'guests',
                  title: 'Guests',
                  trailing: CupertinoNativeStepper(
                    value: 2,
                    onChanged: (v) => got = v,
                  ),
                ),
              ],
            ),
          ],
        ),
      );

      final rows = ((params['sections'] as List).single as Map)['rows'] as List;
      final node = ((rows.single as Map)['trailing'] as List).single as Map;
      expect(node['type'], 'control');
      final control = node['control'] as Map;
      expect(control['kind'], 'stepper');
      expect(control['value'], 2);
      expect(control['enabled'], isTrue);
      expect(got, isNull);
    });

    testWidgets('containers lower recursively, ids stay unique', variant: iOS, (
      tester,
    ) async {
      final params = await paramsOf(
        tester,
        CupertinoNativeTextField(
          toolbarActions: [
            CupertinoNativeGlassContainer(
              shape: CupertinoGlassShape.capsule,
              child: Row(
                children: [
                  CupertinoNativeButton(
                    onPressed: () {},
                    child: const Text('B'),
                  ),
                  const SizedBox(width: 8),
                  CupertinoNativeButton(
                    onPressed: () {},
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            const Spacer(),
          ],
        ),
      );

      final toolbar = params['keyboardToolbar'] as List;
      expect(toolbar, hasLength(2));

      // The glass container is a native glass node holding the lowered Row.
      final glass = toolbar[0] as Map;
      expect(glass['type'], 'glass');
      expect((glass['glass'] as Map)['shape'], 'capsule');
      final children = glass['children'] as List;
      expect(children, hasLength(1));
      expect((children[0] as Map)['type'], 'row');

      final row = (children[0] as Map)['children'] as List;
      expect(row, hasLength(3));
      // Ids are paths: item0.0.0 … — unique at any depth. Non-interactive
      // nodes (the spacer) carry none.
      expect((row[0] as Map)['id'], 'item0.0.0');
      expect((row[2] as Map)['id'], 'item0.0.2');
      expect((row[0] as Map)['type'], 'button');
      expect((row[1] as Map)['type'], 'spacer');
      expect((row[2] as Map)['type'], 'button');

      expect((toolbar[1] as Map)['type'], 'spacer');
    });
  });
}
