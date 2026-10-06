import 'package:cupertino_native_ui/cupertino_native_ui.dart';
import 'package:cupertino_native_ui/src/internal/legacy_sliver_navigation_bar.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

/// Every message to a native view makes iOS rebuild or re-lay out SwiftUI on
/// the main thread, which is also where Flutter draws while native views are
/// on screen. A rebuild of the Flutter side that changes nothing must send
/// nothing.
void main() {
  final iOS = TargetPlatformVariant.only(TargetPlatform.iOS);
  const codec = StandardMethodCodec();

  /// The methods sent to the package's native views, in order.
  late List<String> sent;

  setUp(() {
    sent = [];
    TestDefaultBinaryMessengerBinding
        .instance
        .defaultBinaryMessenger
        .allMessagesHandler = (channel, handler, message) {
      if (channel.startsWith('cupertino_native_ui/')) {
        sent.add(codec.decodeMethodCall(message).method);
        return Future.value(codec.encodeSuccessEnvelope(null));
      }
      if (channel == SystemChannels.platform_views.name) {
        return Future.value(codec.encodeSuccessEnvelope(null));
      }
      return handler?.call(message);
    };
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding
            .instance
            .defaultBinaryMessenger
            .allMessagesHandler =
        null;
  });

  /// Pumps [build] under a parent that rebuilds it on demand, the way a page
  /// calling `setState` does: every widget below is a new instance.
  Future<VoidCallback> pumpRebuildable(
    WidgetTester tester,
    Widget Function() build,
  ) async {
    final tick = ValueNotifier(0);
    addTearDown(tick.dispose);
    await tester.pumpWidget(
      MaterialApp(
        home: ValueListenableBuilder<int>(
          valueListenable: tick,
          builder: (context, value, child) =>
              Center(child: SizedBox(width: 390, height: 400, child: build())),
        ),
      ),
    );
    await tester.pump(const Duration(milliseconds: 200));
    return () => tick.value++;
  }

  testWidgets('a list sends nothing once created, nor on an idle rebuild', (
    tester,
  ) async {
    final rebuild = await pumpRebuildable(
      tester,
      () => CupertinoNativeList(
        sections: [
          CupertinoNativeListSection(
            children: [CupertinoNativeListTile(id: 'a', title: 'A')],
          ),
        ],
      ),
    );
    // Created with its config: resending it rebuilt every row, and asking
    // for its size forced a full layout, both in the middle of a push.
    expect(sent, isEmpty);
    rebuild();
    await tester.pump();
    expect(sent, isEmpty);
  }, variant: iOS);

  testWidgets('a list still sends a real change: Edit turns edit mode on', (
    tester,
  ) async {
    var editing = false;
    final rebuild = await pumpRebuildable(
      tester,
      () => CupertinoNativeList(
        editing: editing,
        reorderable: editing,
        sections: [
          CupertinoNativeListSection(
            children: [CupertinoNativeListTile(id: 'a', title: 'A')],
          ),
        ],
      ),
    );
    expect(sent, isEmpty);
    editing = true;
    rebuild();
    await tester.pump();
    expect(sent, ['updateList']);
  }, variant: iOS);

  testWidgets('a glass container with an icon ignores an idle rebuild', (
    tester,
  ) async {
    final rebuild = await pumpRebuildable(
      tester,
      () => CupertinoNativeGlassContainer(
        icon: CupertinoNativeIcon.symbol(CupertinoSymbols.star),
      ),
    );
    rebuild();
    await tester.pump();
    expect(sent.where((m) => m == 'updateGlass'), isEmpty);
  }, variant: iOS);

  testWidgets('a checkbox ignores a new onChanged closure', (tester) async {
    final rebuild = await pumpRebuildable(
      tester,
      () => CupertinoNativeCheckbox(value: true, onChanged: (_) {}),
    );
    rebuild();
    await tester.pump();
    expect(sent.where((m) => m == 'updateCheckbox'), isEmpty);
  }, variant: iOS);

  testWidgets('a context menu ignores a new list of the same actions', (
    tester,
  ) async {
    final rebuild = await pumpRebuildable(
      tester,
      () => CupertinoNativeContextMenu(
        // A list literal, as a page writes it: a new list on every build.
        actions: [
          for (final title in ['Share'])
            CupertinoNativeMenuAction(title: title, actionId: title),
        ],
        child: const SizedBox(width: 100, height: 100),
      ),
    );
    rebuild();
    await tester.pump(const Duration(milliseconds: 200));
    expect(sent.where((m) => m == 'updateContextMenu'), isEmpty);
  }, variant: iOS);

  testWidgets('the iOS 15-18 bar material speaks only when it changes', (
    tester,
  ) async {
    final progress = ValueNotifier(0.5);
    addTearDown(progress.dispose);
    final tick = ValueNotifier(0);
    addTearDown(tick.dispose);
    await tester.pumpWidget(
      ValueListenableBuilder<int>(
        valueListenable: tick,
        builder: (context, value, child) => ValueListenableBuilder<double>(
          valueListenable: progress,
          builder: (context, p, child) => LegacyBarMaterial(progress: p),
        ),
      ),
    );
    await tester.pump();
    // The bar rebuilds on every scroll frame.
    for (var i = 0; i < 5; i++) {
      tick.value++;
      await tester.pump();
    }
    expect(sent.where((m) => m == 'update').length, lessThanOrEqualTo(1));
    final before = sent.length;
    progress.value = 0.8;
    await tester.pump();
    expect(sent.length, before + 1);
  }, variant: iOS);

  testWidgets('a glass group sends nothing on its first idle rebuild', (
    tester,
  ) async {
    var back = false;
    final rebuild = await pumpRebuildable(
      tester,
      () => CupertinoNativeGlassGroup(
        items: [
          CupertinoNativeGlassGroupItem(
            actionId: back ? 'back' : 'more',
            title: back ? 'Back' : 'More',
          ),
        ],
      ),
    );
    // Created with its config: the first rebuild used to resend it, so every
    // untouched group beside a tapped one got a setConfig of its own.
    rebuild();
    await tester.pump();
    expect(sent.where((m) => m == 'setConfig'), isEmpty);
    back = true;
    rebuild();
    await tester.pump();
    expect(sent.where((m) => m == 'setConfig').length, 1);
  }, variant: iOS);
}
