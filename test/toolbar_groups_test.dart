import 'package:cupertino_native_ui/cupertino_native_ui.dart';
import 'package:cupertino_native_ui/src/internal/bar_holes.dart';
import 'package:cupertino_native_ui/src/internal/toolbar_groups.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  CupertinoNativeButton glass(String label) =>
      CupertinoNativeButton.glass(onPressed: () {}, child: Text(label));

  /// A bar entry by its label: a button's title or symbol, the ••• menu
  /// with what it holds, or any other widget's type.
  Object name(Widget item) => switch (item) {
    CupertinoNativeButton(child: Text(:final data?)) => data,
    CupertinoNativeButton(child: CupertinoSymbolImage(:final name)) => name,
    BarOverflowMenu(:final hidden) => ['more', ...hidden.map(name)],
    _ => item.runtimeType.toString(),
  };

  /// What each group holds: the entries of a shared capsule, or the one
  /// entry standing alone.
  List<Object> shape(List<Widget> groups) => [
    for (final group in groups)
      switch ((group as BarHole).child!) {
        SharedGlassCapsule(:final items) => items.map(name).toList(),
        final alone => name(alone),
      },
  ];

  test('glass buttons side by side share one capsule', () {
    expect(shape(toolbarGroups([glass('a'), glass('b'), glass('c')])), [
      ['a', 'b', 'c'],
    ]);
  });

  test('a button in the default style joins the capsule', () {
    final plain = CupertinoNativeButton(
      onPressed: () {},
      child: const Text('p'),
    );
    expect(shape(toolbarGroups([glass('a'), plain, glass('b')])), [
      ['a', 'p', 'b'],
    ]);
  });

  test('a Spacer ends the capsule and is not drawn', () {
    expect(
      shape(
        toolbarGroups([glass('a'), glass('b'), const Spacer(), glass('c')]),
      ),
      [
        ['a', 'b'],
        'c',
      ],
    );
  });

  test('a prominent button, or any other widget, stands alone', () {
    final add = CupertinoNativeButton.glassProminent(
      onPressed: () {},
      child: const Text('add'),
    );
    expect(
      shape(
        toolbarGroups([
          glass('a'),
          glass('b'),
          add,
          const SizedBox(),
          glass('c'),
        ]),
      ),
      [
        ['a', 'b'],
        'add',
        'SizedBox',
        'c',
      ],
    );
  });

  test('a Flutter widget between buttons ends the capsule on both sides', () {
    const other = SizedBox();
    expect(shape(toolbarGroups([glass('a'), other, glass('b')])), [
      'a',
      'SizedBox',
      'b',
    ]);
    expect(shape(toolbarGroups([glass('a'), glass('b'), other, glass('c')])), [
      ['a', 'b'],
      'SizedBox',
      'c',
    ]);
    expect(shape(toolbarGroups([glass('a'), other, glass('b'), glass('c')])), [
      'a',
      'SizedBox',
      ['b', 'c'],
    ]);
  });

  test('what does not fit goes into the ••• menu, high priority last', () {
    // SwiftUI's own example: six items, 4 and 6 `.high`, on a 393pt phone
    // with a back button. 1, 2, 4 and 6 stay; 3 and 5 go into the menu.
    CupertinoNativeButton item({bool high = false}) =>
        CupertinoNativeButton.icon(
          CupertinoSymbols.ellipsis,
          onPressed: () {},
          visibilityPriority: high
              ? CupertinoNativeToolbarVisibilityPriority.high
              : CupertinoNativeToolbarVisibilityPriority.automatic,
        );
    final items = [for (var n = 1; n <= 6; n++) item(high: n == 4 || n == 6)];
    final groups = toolbarGroups(items, width: 393 - 2 * 16 - (44 + 12));
    final capsule = (groups.single as BarHole).child as SharedGlassCapsule;
    expect(capsule.items.sublist(0, 4), [
      items[0],
      items[1],
      items[3],
      items[5],
    ]);
    expect((capsule.items.last as BarOverflowMenu).hidden, [
      items[2],
      items[4],
    ]);
  });

  test('everything fits: no ••• menu', () {
    expect(shape(toolbarGroups([glass('a'), glass('b')], width: 400)), [
      ['a', 'b'],
    ]);
  });

  testWidgets('a capsule is one glass group calling the right buttons', (
    tester,
  ) async {
    final pressed = <String>[];
    CupertinoNativeButton button(String label) => CupertinoNativeButton.glass(
      onPressed: () => pressed.add(label),
      child: Text(label),
    );
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: SharedGlassCapsule([
          button('a'),
          button('b'),
          BarOverflowMenu([button('c')]),
        ]),
      ),
    );

    final group = tester.widget<CupertinoNativeGlassGroup>(
      find.byType(CupertinoNativeGlassGroup),
    );
    expect(find.byType(CupertinoNativeGlassGroup), findsOneWidget);
    expect(find.byType(CupertinoNativeButton), findsNothing);
    expect(group.spacing, 0);
    expect(group.items.map((i) => i.title ?? i.actionId), ['a', 'b', 'more']);
    expect(group.items.last.menuItems, hasLength(1));

    group.onAction!('b1');
    group.onAction!('m0');
    expect(pressed, ['b', 'c']);
  });

  test('three trailing items move the title to the leading side', () {
    expect(titleCentered(true, [glass('a'), glass('b')]), isTrue);
    expect(
      titleCentered(true, [glass('a'), const Spacer(), glass('b')]),
      isTrue,
    );
    expect(titleCentered(true, [glass('a'), glass('b'), glass('c')]), isFalse);
    expect(titleCentered(false, const []), isFalse);
  });
}
