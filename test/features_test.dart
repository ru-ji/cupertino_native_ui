// The deprecated names are exercised on purpose: they must keep working.
// ignore_for_file: deprecated_member_use, deprecated_member_use_from_same_package

import 'package:cupertino_widgets/cupertino_widgets.dart';
import 'package:cupertino_widgets/src/internal/widget_lowering.dart';
import 'package:flutter/cupertino.dart' show CupertinoApp, CupertinoThemeData;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Behaviour of the iOS 27 / iOS 15–26 additions, end to end on the Dart
/// side: what each widget sends at creation, and what it does with what the
/// native side sends back. The native side is played by hand — a platform
/// view's id is captured at creation and its channel is fed method calls.
void main() {
  final iOS = TargetPlatformVariant.only(TargetPlatform.iOS);
  late List<Map<Object?, Object?>> created;
  late List<int> ids;

  setUp(() {
    created = [];
    ids = [];
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, (call) async {
          if (call.method == 'create') {
            final args = call.arguments as Map;
            ids.add(args['id'] as int);
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
    expect(created, isNotEmpty, reason: 'no native view was created');
    return created.first;
  }

  /// Plays the native side: sends [method] on [channel] to Dart.
  Future<void> fromNative(
    WidgetTester tester,
    String channel,
    String method, [
    Object? arguments,
  ]) async {
    await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
      channel,
      const StandardMethodCodec().encodeMethodCall(
        MethodCall(method, arguments),
      ),
      (_) {},
    );
    await tester.pump();
  }

  group('toolbar items', () {
    test('systemImage and symbol are icon shorthands; icon wins', () {
      Map iconOf(CupertinoNativeToolbarItem item) => item.toMap()['icon'];
      expect(
        iconOf(
          const CupertinoNativeToolbarItem(actionId: 'a', systemImage: 'heart'),
        )['sfSymbol'],
        'heart',
      );
      expect(
        iconOf(
          const CupertinoNativeToolbarItem(
            actionId: 'a',
            symbol: CupertinoSymbols.plus,
          ),
        )['sfSymbol'],
        CupertinoSymbols.plus.value,
      );
      expect(
        iconOf(
          const CupertinoNativeToolbarItem(
            actionId: 'a',
            icon: CupertinoNativeIcon.named('star'),
            systemImage: 'heart',
          ),
        )['sfSymbol'],
        'star',
      );
    });

    test('an item needs a title or an icon', () {
      expect(
        () => CupertinoNativeToolbarItem(actionId: 'a'),
        throwsAssertionError,
      );
    });

    test('iOS 27 fields serialize by name', () {
      final map = const CupertinoNativeToolbarItem(
        actionId: 'share',
        systemImage: 'square.and.arrow.up',
        pinned: true,
        visibilityPriority: CupertinoNativeToolbarVisibilityPriority.high,
      ).toMap();
      expect(map['pinned'], isTrue);
      expect(map['visibilityPriority'], 'high');
    });

    test('a fixed spacer is ToolbarSpacer(.fixed)', () {
      expect(const CupertinoNativeToolbarSpacer(flexible: false).toMap(), {
        'type': 'spacer',
        'sharedBackgroundVisibility': false,
      });
    });

    test('navigation bar sends overflow and minimize behaviour', () {
      final map = const CupertinoNativeScaffoldNavigationBar(
        title: 'T',
        overflow: [CupertinoNativeToolbarItem(actionId: 'd', title: 'Dup')],
        minimizeBehavior: CupertinoNativeToolbarMinimizeBehavior.onScrollDown,
      ).toMap();
      expect((map['overflow'] as List).single['actionId'], 'd');
      expect(map['minimizeBehavior'], 'onScrollDown');
    });

    test('tab sends its badge and the prominent role', () {
      final map = const CupertinoNativeTab(
        id: 'inbox',
        title: 'Inbox',
        badge: '3',
        role: CupertinoNativeTabRole.prominent,
      ).toMap();
      expect(map['badge'], '3');
      expect(map['role'], 'prominent');
    });
  });

  group('CupertinoNativePickedMedia', () {
    test('listFrom reads loading, ready and failed items', () {
      final media = CupertinoNativePickedMedia.listFrom([
        {'id': 'a'},
        {
          'id': 'b',
          'path': '/tmp/b.jpg',
          'isVideo': false,
          'width': 2048,
          'height': 1536,
        },
        {'id': 'c', 'isVideo': true, 'error': true},
      ]);
      expect(media.map((m) => m.id), ['a', 'b', 'c']);
      expect(media[0].isLoading, isTrue);
      expect(media[1].isLoading, isFalse);
      expect(media[1].path, '/tmp/b.jpg');
      expect(media[1].width, 2048);
      expect(media[2].failed, isTrue);
      expect(media[2].isLoading, isFalse);
      expect(media[2].isVideo, isTrue);
    });

    test('listFrom treats null as nothing picked', () {
      expect(CupertinoNativePickedMedia.listFrom(null), isEmpty);
    });

    test('picker settings', () {
      final config = CupertinoNativePhotosPicker(
        onChanged: (_) {},
        style: CupertinoNativePhotosPickerStyle.compact,
        filter: CupertinoNativePhotosPickerFilter.videos,
        maxDimension: null,
        showsAlbums: true,
      ).nativeConfig;
      expect(config['style'], 'compact');
      expect(config['filter'], 'videos');
      expect(config['maxSelection'], 0, reason: 'null means no limit');
      expect(config['maxDimension'], isNull, reason: 'null keeps originals');
      expect(config['showsAlbums'], isTrue);
    });

    testWidgets('clearCache asks the plugin', (tester) async {
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        const MethodChannel('com.example.cupertino_widgets/alert'),
        (call) async {
          calls.add(call.method);
          return null;
        },
      );
      await CupertinoNativePhotosPicker.clearCache();
      expect(calls, ['clearPhotoCache']);
    }, variant: iOS);
  });

  group('slider', () {
    testWidgets('sends the new options', (tester) async {
      final params = await paramsOf(
        tester,
        CupertinoNativeSlider(
          value: 0,
          min: -1,
          max: 1,
          divisions: 4,
          showTicks: true,
          neutralValue: 0,
          minimumIcon: const CupertinoNativeIcon.named('speaker.fill'),
          onChanged: (_) {},
        ),
      );
      expect(params['divisions'], 4);
      expect(params['showTicks'], isTrue);
      expect(params['neutralValue'], 0);
      expect((params['minimumIcon'] as Map)['sfSymbol'], 'speaker.fill');
      expect(params['maximumIcon'], isNull);
    }, variant: iOS);

    testWidgets('reports drag start, changes and end', (tester) async {
      final log = <String>[];
      await paramsOf(
        tester,
        CupertinoNativeSlider(
          value: 0.2,
          onChanged: (v) => log.add('change $v'),
          onChangeStart: (v) => log.add('start $v'),
          onChangeEnd: (v) => log.add('end $v'),
        ),
      );
      final channel = 'adaptive_slider_${ids.single}';
      await fromNative(tester, channel, 'onChangeStart', 0.2);
      await fromNative(tester, channel, 'onChanged', 0.6);
      // Swift may send a whole number as an int.
      await fromNative(tester, channel, 'onChangeEnd', 1);
      expect(log, ['start 0.2', 'change 0.6', 'end 1.0']);
    }, variant: iOS);
  });

  group('list', () {
    testWidgets('edit mode, selection, reorder and row extras', (tester) async {
      final params = await paramsOf(
        tester,
        CupertinoNativeList(
          editing: true,
          selection: const {'b'},
          onReorder: (_, _, _) {},
          sections: const [
            CupertinoNativeListSection(
              children: [
                CupertinoNativeListTile(
                  id: 'a',
                  title: 'A',
                  badge: '5',
                  swipeActions: [
                    CupertinoNativeMenuAction(
                      title: 'Delete',
                      actionId: 'delete',
                      isDestructive: true,
                    ),
                  ],
                  children: [
                    CupertinoNativeListTile(
                      id: 'b',
                      title: 'B',
                      children: [CupertinoNativeListTile(id: 'c', title: 'C')],
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      );
      expect(params['editing'], isTrue);
      expect(params['selection'], ['b']);
      expect(params['reorderable'], isTrue);
      final row = ((params['sections'] as List).single['rows'] as List).single;
      expect(row['badge'], '5');
      expect((row['swipeActions'] as List).single['actionId'], 'delete');
      final child = (row['children'] as List).single as Map;
      expect(child['id'], 'b');
      expect(((child['children'] as List).single as Map)['id'], 'c');
    }, variant: iOS);

    testWidgets('without onReorder the rows are not reorderable', (
      tester,
    ) async {
      final params = await paramsOf(
        tester,
        const CupertinoNativeList(sections: []),
      );
      expect(params['reorderable'], isFalse);
      expect(params['editing'], isFalse);
    }, variant: iOS);

    testWidgets('dispatches selection, swipe and reorder events', (
      tester,
    ) async {
      Set<String>? selection;
      String? swiped;
      List<int>? moved;
      await paramsOf(
        tester,
        CupertinoNativeList(
          editing: true,
          onSelectionChanged: (s) => selection = s,
          onSwipeAction: (row, action) => swiped = '$row/$action',
          onReorder: (section, from, to) => moved = [section, from, to],
          sections: const [
            CupertinoNativeListSection(
              children: [CupertinoNativeListTile(id: 'a', title: 'A')],
            ),
          ],
        ),
      );
      final channel = 'cupertino_widgets/list_${ids.single}';
      await fromNative(tester, channel, 'onSelectionChanged', {
        'ids': ['a', 'b'],
      });
      await fromNative(tester, channel, 'onSwipeAction', {
        'rowId': 'a',
        'actionId': 'delete',
      });
      await fromNative(tester, channel, 'onReorder', {
        'section': 0,
        'from': 2,
        'to': 0,
      });
      expect(selection, {'a', 'b'});
      expect(swiped, 'a/delete');
      expect(moved, [0, 2, 0]);
    }, variant: iOS);
  });

  group('menu', () {
    testWidgets('a split button: onPressed on tap, the menu on hold', (
      tester,
    ) async {
      var pressed = 0;
      final params = await paramsOf(
        tester,
        CupertinoNativeMenu(
          items: const [],
          fixedOrder: true,
          onPressed: () => pressed++,
        ),
      );
      expect(params['hasPrimaryAction'], isTrue);
      expect(params['fixedOrder'], isTrue);
      await fromNative(
        tester,
        'cupertino_widgets/menu_${ids.single}',
        'onPrimaryAction',
      );
      expect(pressed, 1);
    }, variant: iOS);

    testWidgets('no onPressed, no primary action', (tester) async {
      final params = await paramsOf(
        tester,
        const CupertinoNativeMenu(items: []),
      );
      expect(params['hasPrimaryAction'], isFalse);
    }, variant: iOS);

    test('a control group is a row of actions', () {
      final map = const CupertinoNativeMenuControlGroup(
        items: [
          CupertinoNativeMenuAction(
            title: 'Copy',
            systemImage: 'doc.on.doc',
            actionId: 'copy',
          ),
        ],
      ).toMap();
      expect(map['type'], 'controlGroup');
      expect((map['items'] as List).single['actionId'], 'copy');
    });
  });

  group('single-value controls', () {
    testWidgets('stepper: hugs without a label, fills with one', (
      tester,
    ) async {
      final params = await paramsOf(
        tester,
        CupertinoNativeStepper(value: 3, max: 10, onChanged: (_) {}),
      );
      expect(params['kind'], 'stepper');
      expect(params['hug'], isTrue);
      expect(params['enabled'], isTrue);

      // A different widget of the same type in the same place would reuse the
      // native view: start from an empty tree to get a new one.
      await tester.pumpWidget(const SizedBox());
      created.clear();
      final labelled = await paramsOf(
        tester,
        const CupertinoNativeStepper(
          value: 3,
          label: 'Guests',
          onChanged: null,
        ),
      );
      expect(labelled['hug'], isFalse);
      expect(labelled['enabled'], isFalse, reason: 'null onChanged disables');
    }, variant: iOS);

    testWidgets('stepper reports a double even from an int', (tester) async {
      double? got;
      await paramsOf(
        tester,
        CupertinoNativeStepper(value: 1, onChanged: (v) => got = v),
      );
      await fromNative(
        tester,
        'cupertino_widgets/control_${ids.single}',
        'onChanged',
        2,
      );
      expect(got, 2.0);
    }, variant: iOS);

    testWidgets('color picker round-trips ARGB', (tester) async {
      Color? got;
      final params = await paramsOf(
        tester,
        CupertinoNativeColorPicker(
          color: const Color(0xFF112233),
          onChanged: (c) => got = c,
        ),
      );
      expect(params['color'], 0xFF112233);
      await fromNative(
        tester,
        'cupertino_widgets/control_${ids.single}',
        'onChanged',
        0x80FF0000,
      );
      expect(got, const Color(0x80FF0000));
    }, variant: iOS);

    testWidgets('multi-date picker sends and receives days', (tester) async {
      Set<DateTime>? got;
      final day = DateTime(2026, 9, 30);
      final params = await paramsOf(
        tester,
        CupertinoNativeMultiDatePicker(dates: {day}, onChanged: (d) => got = d),
      );
      expect(params['dates'], [day.millisecondsSinceEpoch.toDouble()]);
      await fromNative(
        tester,
        'cupertino_widgets/control_${ids.single}',
        'onChanged',
        [day.millisecondsSinceEpoch.toDouble()],
      );
      expect(got, {day});
    }, variant: iOS);

    testWidgets('a circular gauge hugs, a linear one fills', (tester) async {
      final ring = await paramsOf(
        tester,
        const CupertinoNativeGauge(
          value: 0.5,
          style: CupertinoNativeGaugeStyle.circularCapacity,
        ),
      );
      expect(ring['hug'], isTrue);
      expect(ring['gaugeStyle'], 'circularCapacity');
      // A different widget of the same type in the same place would reuse the
      // native view: start from an empty tree to get a new one.
      await tester.pumpWidget(const SizedBox());
      created.clear();
      final bar = await paramsOf(
        tester,
        const CupertinoNativeGauge(value: 0.5),
      );
      expect(bar['hug'], isFalse);
    }, variant: iOS);

    testWidgets('a pushed change is sent once, not on every rebuild', (
      tester,
    ) async {
      final updates = <Object?>[];
      Widget build(double value) => MaterialApp(
        home: Center(
          child: CupertinoNativeStepper(value: value, onChanged: (_) {}),
        ),
      );
      await tester.pumpWidget(build(1));
      await tester.pump(const Duration(milliseconds: 100));
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel('cupertino_widgets/control_${ids.single}'),
        (call) async {
          if (call.method == 'update') updates.add(call.arguments);
          return null;
        },
      );
      await tester.pumpWidget(build(1));
      expect(updates, isEmpty, reason: 'same props: nothing to send');
      await tester.pumpWidget(build(4));
      expect(updates, hasLength(1));
      expect((updates.single as Map)['value'], 4);
    }, variant: iOS);
  });

  group('lowering', () {
    test('slider drag start/end answer under their own ids', () {
      final log = <String>[];
      final lowered = LoweredTrailing(
        CupertinoNativeSlider(
          value: 0.5,
          onChanged: (v) => log.add('change $v'),
          onChangeStart: (v) => log.add('start $v'),
          onChangeEnd: (v) => log.add('end $v'),
        ),
      );
      lowered.dispatch('item0.start', 0.5);
      lowered.dispatch('item0', 0.7);
      lowered.dispatch('item0.end', null);
      expect(log, ['start 0.5', 'change 0.7', 'end 0.5']);
    });

    test('date picker keeps its style', () {
      final map = LoweredTrailing(
        CupertinoNativeDatePicker(
          style: CupertinoNativeDatePickerStyle.graphical,
          onDateTimeChanged: (_) {},
        ),
      ).node!.toMap(isDark: false);
      expect((map['datePicker'] as Map)['style'], 'graphical');
    });

    test('each single-value control lowers to a control node', () {
      final kinds = {
        for (final widget in <Widget>[
          CupertinoNativeStepper(value: 1, onChanged: (_) {}),
          CupertinoNativeColorPicker(color: Colors.red, onChanged: (_) {}),
          const CupertinoNativeGauge(value: 0.5),
          CupertinoNativeMultiDatePicker(dates: const {}, onChanged: (_) {}),
          CupertinoNativeTextEditor(text: '', onChanged: (_) {}),
        ])
          (LoweredTrailing(widget).node!.toMap(isDark: false)['control']
              as Map)['kind'],
      };
      expect(kinds, {
        'stepper',
        'colorPicker',
        'gauge',
        'multiDatePicker',
        'textEditor',
      });
    });

    test('a lowered control keeps the Flutter enabled rule', () {
      Map controlOf(Widget w) =>
          LoweredTrailing(w).node!.toMap(isDark: false)['control'] as Map;
      expect(
        controlOf(
          CupertinoNativeStepper(value: 1, onChanged: (_) {}),
        )['enabled'],
        isTrue,
      );
      expect(
        controlOf(
          const CupertinoNativeStepper(value: 1, onChanged: null),
        )['enabled'],
        isFalse,
      );
    });

    test('a lowered control calls its own onChanged', () {
      double? got;
      LoweredTrailing(
        CupertinoNativeStepper(value: 1, onChanged: (v) => got = v),
      ).dispatch('item0', 5);
      expect(got, 5.0);
    });

    test('a lowered photos picker decodes its selection', () {
      List<CupertinoNativePickedMedia>? got;
      final lowered = LoweredTrailing(
        CupertinoNativePhotosPicker(onChanged: (m) => got = m),
      );
      expect(lowered.node!.toMap(isDark: false)['type'], 'photosPicker');
      lowered.dispatch('item0', [
        {'id': 'x', 'path': '/tmp/x.jpg'},
      ]);
      expect(got?.single.path, '/tmp/x.jpg');
    });
  });

  group('native body', () {
    test('control defaults to enabled: events go through onBodyEvent', () {
      final map = CupertinoNativeBody.control(
        id: 'guests',
        control: const CupertinoNativeStepper(value: 2, onChanged: null),
      ).toMap(isDark: false);
      expect(map['type'], 'control');
      expect(map['id'], 'guests');
      expect((map['control'] as Map)['enabled'], isTrue);
      expect((map['control'] as Map)['value'], 2);
    });

    test('photosPicker node carries the picker settings', () {
      final map = CupertinoNativeBody.photosPicker(
        id: 'photos',
        picker: CupertinoNativePhotosPicker(
          showsAlbums: true,
          maxSelection: 4,
          onChanged: (_) {},
        ),
      ).toMap(isDark: false);
      expect(map['type'], 'photosPicker');
      final payload = map['photosPicker'] as Map;
      expect(payload['showsAlbums'], isTrue);
      expect(payload['maxSelection'], 4);
    });

    test('slider node carries the iOS 26 options', () {
      final payload =
          CupertinoNativeBody.slider(
                id: 's',
                value: 0,
                min: -1,
                max: 1,
                neutralValue: 0,
                showTicks: true,
              ).toMap(isDark: false)['slider']
              as Map;
      expect(payload['neutralValue'], 0);
      expect(payload['showTicks'], isTrue);
    });
  });

  group('sheet', () {
    const alert = MethodChannel('com.example.cupertino_widgets/alert');

    testWidgets('a native body sheet sends the tree and routes its events', (
      tester,
    ) async {
      final sent = <MethodCall>[];
      final events = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(alert, (
        call,
      ) async {
        sent.add(call);
        if (call.method == 'showSheet') {
          // Native reports while the sheet is up, then it closes.
          await fromNative(
            tester,
            'cupertino_widgets/sheet_events',
            'bodyEvent',
            {'id': 'notify', 'value': true},
          );
          await fromNative(
            tester,
            'cupertino_widgets/sheet_events',
            'toolbarAction',
            'done',
          );
        }
        return null;
      });
      await CupertinoNativeSheet.show(
        nativeBody: CupertinoNativeBody.toggle(id: 'notify', value: false),
        navigationBar: const CupertinoNativeScaffoldNavigationBar(title: 'T'),
        onBodyEvent: (id, value) => events.add('$id=$value'),
        onToolbarAction: (id) => events.add('action $id'),
      );
      final args = sent.single.arguments as Map;
      expect(args['route'], isNull);
      expect((args['nativeBody'] as Map)['type'], 'toggle');
      expect((args['navigationBar'] as Map)['title'], 'T');
      expect(events, ['notify=true', 'action done']);
    }, variant: iOS);

    testWidgets('route and nativeBody are exclusive', (tester) async {
      expect(
        () => CupertinoNativeSheet.show(
          route: 'a',
          nativeBody: CupertinoNativeBody.text('b'),
        ),
        throwsAssertionError,
      );
      expect(() => CupertinoNativeSheet.show(), throwsAssertionError);
    }, variant: iOS);

    testWidgets('updateNativeBody pushes the new tree', (tester) async {
      MethodCall? call;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(alert, (
        c,
      ) async {
        call = c;
        return null;
      });
      await CupertinoNativeSheet.updateNativeBody(
        CupertinoNativeBody.text('Updated'),
      );
      expect(call?.method, 'updateSheetBody');
      expect((call?.arguments as Map)['type'], 'text');
    }, variant: iOS);

    testWidgets('sheet options reach the native side', (tester) async {
      Map? args;
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(alert, (
        call,
      ) async {
        args = call.arguments as Map;
        return null;
      });
      await CupertinoNativeSheet.show(
        route: 'r',
        detentHeights: const [240],
        undimmedUpTo: CupertinoNativeSheetDetent.medium,
        dismissible: false,
      );
      expect(args!['detentHeights'], [240.0]);
      expect(args!['undimmedUpTo'], 'medium');
      expect(args!['dismissible'], isFalse);
    }, variant: iOS);
  });

  group('buttons and symbols', () {
    testWidgets('icon button is a glass circle with the symbol', (
      tester,
    ) async {
      final params = await paramsOf(
        tester,
        CupertinoNativeButton.icon(CupertinoSymbols.plus, onPressed: () {}),
      );
      expect(params['style'], 'glass');
      expect(params['borderShape'], 'circle');
      expect((params['icon'] as Map)['sfSymbol'], CupertinoSymbols.plus.value);
    }, variant: iOS);

    testWidgets('button role is sent', (tester) async {
      final params = await paramsOf(
        tester,
        CupertinoNativeButton(
          role: CupertinoNativeButtonRole.destructive,
          onPressed: () {},
          child: const Text('Delete'),
        ),
      );
      expect(params['role'], 'destructive');
    }, variant: iOS);

    testWidgets('symbol sends variable value, palette and gradient', (
      tester,
    ) async {
      final params = await paramsOf(
        tester,
        const CupertinoNativeSymbol(
          'speaker.wave.3',
          variableValue: 0.4,
          paletteColors: [Color(0xFFFF0000), Color(0xFF00FF00)],
          gradient: true,
        ),
      );
      expect(params['variableValue'], 0.4);
      expect(params['paletteColors'], [0xFFFF0000, 0xFF00FF00]);
      expect(params['gradient'], isTrue);
    }, variant: iOS);

    testWidgets('date picker style is sent', (tester) async {
      final params = await paramsOf(
        tester,
        CupertinoNativeDatePicker(
          style: CupertinoNativeDatePickerStyle.wheel,
          onDateTimeChanged: (_) {},
        ),
      );
      expect(params['style'], 'wheel');
    }, variant: iOS);
  });

  group('appearance in a CupertinoApp', () {
    // The other tests host widgets in a MaterialApp, and the widgets read the
    // app's brightness through Theme.of — which a CupertinoApp has no Theme
    // for. These pin that a CupertinoApp's own brightness still wins over the
    // phone's, both ways.
    for (final (appDark, phoneDark) in [(true, false), (false, true)]) {
      testWidgets('app dark: $appDark, phone dark: $phoneDark', (tester) async {
        tester.platformDispatcher.platformBrightnessTestValue = phoneDark
            ? Brightness.dark
            : Brightness.light;
        addTearDown(tester.platformDispatcher.clearPlatformBrightnessTestValue);
        await tester.pumpWidget(
          CupertinoApp(
            theme: CupertinoThemeData(
              brightness: appDark ? Brightness.dark : Brightness.light,
            ),
            home: Center(
              child: CupertinoNativeSlider(value: 0.5, onChanged: (_) {}),
            ),
          ),
        );
        await tester.pump(const Duration(milliseconds: 100));
        expect(created.single['isDark'], appDark);
      }, variant: iOS);
    }
  });

  group('light / dark switch at runtime', () {
    Future<List<Map>> updatesOnThemeSwitch(
      WidgetTester tester,
      Widget child,
      String channelPrefix,
    ) async {
      Widget app(Brightness b) => MaterialApp(
        theme: ThemeData(brightness: b),
        home: Center(child: SizedBox(width: 390, height: 400, child: child)),
      );
      await tester.pumpWidget(app(Brightness.light));
      await tester.pump(const Duration(milliseconds: 100));
      final updates = <Map>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        MethodChannel('$channelPrefix${ids.single}'),
        (call) async {
          if (call.method == 'update') updates.add(call.arguments as Map);
          return null;
        },
      );
      await tester.pumpWidget(app(Brightness.dark));
      await tester.pumpAndSettle();
      return updates;
    }

    testWidgets('single-value controls follow it', (tester) async {
      final updates = await updatesOnThemeSwitch(
        tester,
        CupertinoNativeStepper(value: 1, onChanged: (_) {}),
        'cupertino_widgets/control_',
      );
      expect(updates.last['isDark'], isTrue);
    }, variant: iOS);

    testWidgets('the photos picker follows it', (tester) async {
      CupertinoNativePhotosPicker.debugIsSupportedOverride = true;
      addTearDown(
        () => CupertinoNativePhotosPicker.debugIsSupportedOverride = null,
      );
      final updates = await updatesOnThemeSwitch(
        tester,
        CupertinoNativePhotosPicker(onChanged: (_) {}),
        'cupertino_widgets/photos_picker_',
      );
      expect(updates.last['isDark'], isTrue);
    }, variant: iOS);
  });

  group('list height', () {
    double boxHeight(WidgetTester tester) =>
        tester.getSize(find.byType(UiKitView)).height;

    // In a scroll view, as in an app: the list sizes itself.
    Future<String> pumpList(WidgetTester tester) async {
      await tester.pumpWidget(
        MaterialApp(
          home: ListView(children: const [CupertinoNativeList(sections: [])]),
        ),
      );
      await tester.pump(const Duration(milliseconds: 100));
      return 'cupertino_widgets/list_${ids.single}';
    }

    testWidgets('a plain measure lands at once', (tester) async {
      final channel = await pumpList(tester);
      await fromNative(tester, channel, 'onContentSize', {'height': 300.0});
      expect(boxHeight(tester), 300);
      await fromNative(tester, channel, 'onContentSize', {'height': 180.0});
      expect(boxHeight(tester), 180, reason: 'no animation for a re-measure');
    }, variant: iOS);

    testWidgets('an expansion animates with the rows', (tester) async {
      final channel = await pumpList(tester);
      await fromNative(tester, channel, 'onContentSize', {'height': 100.0});
      await fromNative(tester, channel, 'onContentSize', {
        'height': 200.0,
        'animated': true,
      });
      await tester.pump(const Duration(milliseconds: 125));
      final mid = boxHeight(tester);
      expect(mid, greaterThan(100));
      expect(mid, lessThan(200));
      await tester.pumpAndSettle();
      expect(boxHeight(tester), 200);
    }, variant: iOS);
  });
}
