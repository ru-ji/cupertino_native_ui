import 'dart:io';

import 'package:cupertino_native_ui/cupertino_native_ui.dart';
import 'package:cupertino_native_ui/src/internal/widget_lowering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Checks every key Dart sends against what the **Swift source** reads.
///
/// The native side decodes Dart's maps with `Codable` structs (or reads
/// `args["key"]` by hand), and both silently ignore a key they do not know. A
/// renamed field on one side only (`appBar` → `navigationBar`, say) still
/// compiles, still passes every other test, and just stops working on a
/// device. These tests read the Swift files themselves, so a key Dart sends
/// that Swift does not declare fails here.
void main() {
  const sources = 'ios/cupertino_native_ui/Sources/cupertino_native_ui';

  final swift = {
    for (final file in Directory(sources).listSync(recursive: true))
      if (file is File && file.path.endsWith('.swift'))
        file.path: file.readAsStringSync(),
  };
  final allSwift = swift.values.join('\n');

  /// The stored properties (`let`/`var name:`) of a Swift struct or class.
  Set<String> fieldsOf(String type) {
    final start = RegExp(r'(struct|class) ' + type + r'\b[^{]*\{')
        .firstMatch(allSwift);
    expect(start, isNotNull, reason: 'Swift type $type not found');
    // The body runs to the first closing brace at the start of a line.
    final body = allSwift.substring(start!.end);
    final end = body.indexOf('\n}');
    return {
      for (final m in RegExp(
        r'^\s{4}(?:@Published\s+)?(?:let|var)\s+(\w+)\s*:',
        multiLine: true,
      ).allMatches(body.substring(0, end)))
        m.group(1)!,
    };
  }

  /// The keys a Swift file reads by hand: `args["key"]`, `dict["key"]`…
  Set<String> keysReadIn(String fileName) {
    final text = swift.entries
        .firstWhere((e) => e.key.endsWith('/$fileName'))
        .value;
    return {
      for (final m in RegExp(r'\w+\["(\w+)"\]').allMatches(text)) m.group(1)!,
    };
  }

  void expectKnown(Map map, Set<String> fields, String what) {
    final unknown = map.keys.cast<String>().toSet().difference(fields);
    expect(
      unknown,
      isEmpty,
      reason: '$what sends keys Swift does not read: $unknown',
    );
  }

  group('Codable models', () {
    test('toolbar entries match ToolbarContentConfig', () {
      final fields = fieldsOf('ToolbarContentConfig');
      expectKnown(
        const CupertinoNativeToolbarItem(
          actionId: 'a',
          systemImage: 'plus',
          pinned: true,
        ).toMap(),
        fields,
        'CupertinoNativeToolbarItem',
      );
      expectKnown(
        const CupertinoNativeToolbarItemGroup(
          items: [CupertinoNativeToolbarItem(actionId: 'a', title: 'A')],
        ).toMap(),
        fields,
        'CupertinoNativeToolbarItemGroup',
      );
      expectKnown(
        const CupertinoNativeToolbarSpacer().toMap(),
        fields,
        'CupertinoNativeToolbarSpacer',
      );
    });

    test('navigation bar matches NavigationBarConfig', () {
      expectKnown(
        const CupertinoNativeScaffoldNavigationBar(
          title: 'T',
          subtitle: 's',
          overflow: [CupertinoNativeToolbarItem(actionId: 'o', title: 'O')],
          search: CupertinoNativeSearchField(placeholder: 'Search'),
        ).toMap(),
        fieldsOf('NavigationBarConfig'),
        'CupertinoNativeScaffoldNavigationBar',
      );
    });

    test('search field matches SearchConfig', () {
      expectKnown(
        const CupertinoNativeSearchField(placeholder: 'p').toMap(),
        fieldsOf('SearchConfig'),
        'CupertinoNativeSearchField',
      );
    });

    test('tabs match TabItemConfig', () {
      expectKnown(
        const CupertinoNativeTab(
          id: 'home',
          title: 'Home',
          badge: '3',
          role: CupertinoNativeTabRole.prominent,
        ).toMap(),
        fieldsOf('TabItemConfig'),
        'CupertinoNativeTab',
      );
    });

    test('icons match IconConfig', () {
      expectKnown(
        const CupertinoNativeIcon.named('star', size: 20).toMap(),
        fieldsOf('IconConfig'),
        'CupertinoNativeIcon',
      );
    });

    test('menu items match MenuItemConfig', () {
      final fields = fieldsOf('MenuItemConfig');
      for (final item in <CupertinoNativeMenuItem>[
        const CupertinoNativeMenuAction(title: 'A', actionId: 'a'),
        const CupertinoNativeMenuToggle(title: 'T', actionId: 't', value: true),
        const CupertinoNativeSubmenu(title: 'S', items: []),
        const CupertinoNativeMenuSection(items: []),
        const CupertinoNativeMenuControlGroup(items: []),
      ]) {
        expectKnown(item.toMap(), fields, '${item.runtimeType}');
      }
    });

    test('photos picker matches PhotosPickerConfig', () {
      expectKnown(
        {
          ...CupertinoNativePhotosPicker(onChanged: (_) {}).nativeConfig,
          'isDark': false,
        },
        fieldsOf('PhotosPickerConfig'),
        'CupertinoNativePhotosPicker',
      );
    });
  });

  group('native body nodes', () {
    Map<String, Object?> nodeOf(Widget widget) {
      final node = LoweredTrailing(widget).node;
      expect(node, isNotNull, reason: '${widget.runtimeType} did not lower');
      return node!.toMap(isDark: false);
    }

    test('every lowered node matches BodyNodeConfig and its payload', () {
      final nodeFields = fieldsOf('BodyNodeConfig');
      final payloads = <String, String>{
        'slider': 'BodySliderConfig',
        'datePicker': 'DatePickerConfig',
        'control': 'ControlConfig',
        'photosPicker': 'PhotosPickerConfig',
        'toggle': 'ToggleConfig',
        'checkbox': 'CheckboxConfig',
        'button': 'ButtonConfig',
        'menu': 'MenuConfiguration',
        'symbol': 'SymbolConfig',
      };
      for (final widget in <Widget>[
        CupertinoNativeSlider(
          value: 0.5,
          divisions: 4,
          showTicks: true,
          neutralValue: 0,
          minimumIcon: const CupertinoNativeIcon.named('minus'),
          onChanged: (_) {},
        ),
        CupertinoNativeDatePicker(
          style: CupertinoNativeDatePickerStyle.graphical,
          onDateTimeChanged: (_) {},
        ),
        CupertinoNativeStepper(value: 1, onChanged: (_) {}),
        CupertinoNativeColorPicker(color: Colors.red, onChanged: (_) {}),
        const CupertinoNativeGauge(value: 0.3),
        CupertinoNativeMultiDatePicker(dates: const {}, onChanged: (_) {}),
        CupertinoNativeTextEditor(text: '', onChanged: (_) {}),
        CupertinoNativePhotosPicker(onChanged: (_) {}),
        CupertinoNativeSwitch(value: true, onChanged: (_) {}),
        CupertinoNativeCheckbox(value: true, onChanged: (_) {}),
        CupertinoNativeButton(onPressed: () {}, child: const Text('B')),
        const CupertinoNativeMenu(items: []),
        const CupertinoNativeSymbol('star'),
      ]) {
        final node = nodeOf(widget);
        final type = node['type'] as String;
        expectKnown(
          {...node}..remove(type),
          nodeFields,
          '${widget.runtimeType} node',
        );
        final payload = node[type];
        if (payload is Map && payloads[type] != null) {
          expectKnown(
            // `toMap(isDark:)` stamps the appearance on every payload; the
            // models that do not need it just ignore it.
            {...payload}..remove('isDark'),
            fieldsOf(payloads[type]!),
            '${widget.runtimeType} payload',
          );
        }
      }
    });
  });

  group('platform view creation params', () {
    final iOS = TargetPlatformVariant.only(TargetPlatform.iOS);
    late List<Map<Object?, Object?>> created;

    setUp(() {
      created = [];
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform_views, (
            call,
          ) async {
            if (call.method == 'create') {
              final params = (call.arguments as Map)['params'];
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

    Future<Map<Object?, Object?>> paramsOf(
      WidgetTester tester,
      Widget child,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Center(child: SizedBox(width: 390, height: 600, child: child)),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      expect(created, isNotEmpty);
      return created.first;
    }

    testWidgets('list matches ListConfig, rows match ListRowConfig', (
      tester,
    ) async {
      final params = await paramsOf(
        tester,
        CupertinoNativeList(
          editing: true,
          selection: const {'a'},
          reorderable: true,
          onReorder: (_, _, _) {},
          sections: const [
            CupertinoNativeListSection(
              header: 'H',
              children: [
                CupertinoNativeListTile(
                  id: 'a',
                  title: 'A',
                  badge: '2',
                  swipeActions: [
                    CupertinoNativeMenuAction(title: 'Del', actionId: 'd'),
                  ],
                  children: [CupertinoNativeListTile(id: 'b', title: 'B')],
                ),
              ],
            ),
          ],
        ),
      );
      expectKnown(params, fieldsOf('ListConfig'), 'CupertinoNativeList');
      final section = (params['sections'] as List).single as Map;
      expectKnown(section, fieldsOf('ListSectionConfig'), 'section');
      final row = (section['rows'] as List).single as Map;
      expectKnown(row, fieldsOf('ListRowConfig'), 'row');
      expectKnown(
        (row['children'] as List).single as Map,
        fieldsOf('ListRowConfig'),
        'child row',
      );
    }, variant: iOS);

    testWidgets('single-value controls match ControlConfig', (tester) async {
      final params = await paramsOf(
        tester,
        CupertinoNativeGauge(
          value: 0.4,
          label: 'L',
          currentValueLabel: '40',
          minimumValueLabel: '0',
          maximumValueLabel: '1',
          color: Colors.green,
        ),
      );
      expectKnown(params, fieldsOf('ControlConfig'), 'CupertinoNativeGauge');
    }, variant: iOS);

    testWidgets('symbol matches SymbolConfig', (tester) async {
      final params = await paramsOf(
        tester,
        const CupertinoNativeSymbol(
          'wifi',
          variableValue: 0.5,
          paletteColors: [Colors.red, Colors.blue],
          gradient: true,
        ),
      );
      expectKnown(params, fieldsOf('SymbolConfig'), 'CupertinoNativeSymbol');
    }, variant: iOS);

    testWidgets('menu matches MenuConfiguration', (tester) async {
      final params = await paramsOf(
        tester,
        CupertinoNativeMenu(
          items: const [],
          onPressed: () {},
          fixedOrder: true,
        ),
      );
      expectKnown(params, fieldsOf('MenuConfiguration'), 'CupertinoNativeMenu');
    }, variant: iOS);

    testWidgets('slider keys are all read by NativeSliderView', (tester) async {
      final params = await paramsOf(
        tester,
        CupertinoNativeSlider(
          value: 0.5,
          divisions: 4,
          showTicks: true,
          neutralValue: 0,
          minimumIcon: const CupertinoNativeIcon.named('minus'),
          maximumIcon: const CupertinoNativeIcon.named('plus'),
          onChanged: (_) {},
        ),
      );
      expectKnown(
        params,
        keysReadIn('NativeSliderView.swift'),
        'CupertinoNativeSlider',
      );
    }, variant: iOS);

    testWidgets('date picker keys are all read by NativeDatePickerView', (
      tester,
    ) async {
      final params = await paramsOf(
        tester,
        CupertinoNativeDatePicker(
          style: CupertinoNativeDatePickerStyle.wheel,
          onDateTimeChanged: (_) {},
        ),
      );
      expectKnown(
        params,
        keysReadIn('NativeDatePickerView.swift'),
        'CupertinoNativeDatePicker',
      );
    }, variant: iOS);
  });

  group('sheet', () {
    testWidgets('every key showSheet sends is read by NativeSheetManager', (
      tester,
    ) async {
      Map? sent;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.example.cupertino_native_ui/alert'),
        (call) async {
          if (call.method == 'showSheet') sent = call.arguments as Map;
          return null;
        },
      );
      await CupertinoNativeSheet.show(
        nativeBody: CupertinoNativeBody.text('Hi'),
        navigationBar: const CupertinoNativeScaffoldNavigationBar(title: 'T'),
        detentHeights: const [300],
        undimmedUpTo: CupertinoNativeSheetDetent.medium,
        dismissible: false,
        anchor: const Rect.fromLTWH(0, 0, 10, 10),
        preferredSize: const Size(300, 400),
      );
      expect(sent, isNotNull);
      expectKnown(
        sent!,
        keysReadIn('NativeSheetManager.swift'),
        'CupertinoNativeSheet.show',
      );
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
  });
}
