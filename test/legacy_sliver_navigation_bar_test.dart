import 'package:cupertino_native_ui/src/internal/legacy_sliver_navigation_bar.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart' show RenderSliver;
import 'package:flutter_test/flutter_test.dart';

/// A page under the bar: [LegacySliverNavigationBar] over a long list, on a
/// 402pt wide phone with a 54pt Dynamic Island safe area.
Widget _page({
  bool search = true,
  NavigationBarBottomMode bottomMode = NavigationBarBottomMode.automatic,
  Brightness brightness = Brightness.light,
}) {
  return CupertinoApp(
    theme: CupertinoThemeData(brightness: brightness),
    builder: (context, child) => MediaQuery(
      data: const MediaQueryData(
        size: Size(402, 874),
        padding: EdgeInsets.only(top: 54),
        devicePixelRatio: 3,
      ),
      child: child!,
    ),
    home: CustomScrollView(
      physics: const BouncingScrollPhysics(
        parent: AlwaysScrollableScrollPhysics(),
      ),
      slivers: [
        LegacySliverNavigationBar(
          largeTitle: const Text('Folders'),
          searchField: search ? const _Field() : null,
          bottomMode: bottomMode,
        ),
        SliverList.builder(
          itemCount: 60,
          itemBuilder: (_, i) => SizedBox(height: 60, child: Text('row $i')),
        ),
      ],
    ),
  );
}

class _Field extends StatelessWidget {
  const _Field();

  @override
  Widget build(BuildContext context) => const Text('Search');
}

Finder get _largeTitle => find.text('Folders').first;
Finder get _material => find.byType(LegacyBarMaterial);
Finder get _hairline => find.byType(LegacyBarHairline);

/// The opacity the material/hairline is drawn with (0 when it is not built).
double _opacityOf(WidgetTester tester, Finder finder) {
  final opacities = find.descendant(of: finder, matching: find.byType(Opacity));
  if (opacities.evaluate().isEmpty) return 0;
  return tester.widget<Opacity>(opacities.first).opacity;
}

void main() {
  testWidgets('at rest the header is the Figma "Large" bar plus a search row', (
    tester,
  ) async {
    await tester.pumpWidget(_page());
    // 54 status + 44 bar + 52 large title + 52 search row = 202 (the kit's 202).
    final sliver = tester.renderObject<RenderSliver>(
      find.byType(SliverPersistentHeader),
    );
    expect(sliver.geometry!.paintExtent, 54 + 44 + 52 + 52);
    // The large title sits 3pt below the bar row: 54 + 44 + 3 above its 41pt line
    // box, over the search row.
    expect(tester.getTopLeft(_largeTitle).dy, 54 + 44 + 3);
    // A phone narrower than 414pt keeps a 16pt margin.
    expect(tester.getTopLeft(_largeTitle).dx, 16);
    // Nothing scrolled under it yet: no material, no hairline.
    expect(_opacityOf(tester, _material), 0);
    expect(_opacityOf(tester, _hairline), 0);
  });

  testWidgets('no search field: the header is 54 + 44 + 52', (tester) async {
    await tester.pumpWidget(_page(search: false));
    final sliver = tester.renderObject<RenderSliver>(
      find.byType(SliverPersistentHeader),
    );
    expect(sliver.geometry!.paintExtent, 54 + 44 + 52);
  });

  testWidgets('scrolling consumes the search row first, then the large title', (
    tester,
  ) async {
    await tester.pumpWidget(_page());
    final restTop = tester.getTopLeft(_largeTitle).dy;

    // 26pt: half of the search row. The title holds still while the row goes.
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    position.jumpTo(26);
    await tester.pump();
    expect(tester.getTopLeft(_largeTitle).dy, restTop);

    // 26pt more: the row is gone, and the title now rides up with the scroll.
    position.jumpTo(52 + 26);
    await tester.pump();
    expect(tester.getTopLeft(_largeTitle).dy, restTop - 26);

    // Past the search row and the title (104pt), the header is at its minimum.
    position.jumpTo(104);
    await tester.pumpAndSettle();
    final sliver = tester.renderObject<RenderSliver>(
      find.byType(SliverPersistentHeader),
    );
    expect(sliver.geometry!.paintExtent, 54 + 44);
  });

  testWidgets('the inline title replaces the large one near the collapse', (
    tester,
  ) async {
    await tester.pumpWidget(_page());
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    // The two "Folders": the large title's fade first, the inline one's second.
    List<double> fades() => tester
        .widgetList<AnimatedOpacity>(
          find.ancestor(
            of: find.text('Folders'),
            matching: find.byType(AnimatedOpacity),
          ),
        )
        .map((a) => a.opacity)
        .toList();

    expect(fades(), [1.0, 0.0]); // at rest: the large title only

    position.jumpTo(104);
    await tester.pumpAndSettle();
    expect(fades(), [0.0, 1.0]); // collapsed: the inline title only
  });

  testWidgets('the material and the hairline come in once the bar has '
      'collapsed, over 10pt', (tester) async {
    await tester.pumpWidget(_page());
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;

    position.jumpTo(104); // exactly collapsed: nothing under it yet
    await tester.pump();
    expect(_opacityOf(tester, _material), 0);

    position.jumpTo(109); // 5 of 10
    await tester.pump();
    expect(_opacityOf(tester, _material), closeTo(0.5, 1e-9));
    expect(_opacityOf(tester, _hairline), closeTo(0.5, 1e-9));

    position.jumpTo(140);
    await tester.pump();
    expect(_opacityOf(tester, _material), 1);
    expect(_opacityOf(tester, _hairline), 1);
  });

  testWidgets('the hairline is one device pixel', (tester) async {
    await tester.pumpWidget(_page());
    tester.state<ScrollableState>(find.byType(Scrollable)).position.jumpTo(200);
    await tester.pump();
    expect(
      tester
          .getSize(
            find
                .descendant(of: _hairline, matching: find.byType(SizedBox))
                .first,
          )
          .height,
      closeTo(1 / 3, 1e-9),
    );
  });

  testWidgets('a pull past the top stretches the header and the title '
      'follows it down', (tester) async {
    await tester.pumpWidget(_page());
    final restTop = tester.getTopLeft(_largeTitle).dy;
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    position.jumpTo(-80); // overscroll, as a drag past the top
    await tester.pump();
    expect(tester.getTopLeft(_largeTitle).dy, greaterThan(restTop + 40));
    // The search field rides down as well.
    expect(tester.getTopLeft(find.text('Search')).dy, greaterThan(restTop));
  });

  testWidgets('a scroll that ends half way snaps to the nearest edge', (
    tester,
  ) async {
    await tester.pumpWidget(_page());
    final position = tester
        .state<ScrollableState>(find.byType(Scrollable))
        .position;
    // Inside the search row, under half: back to the top.
    await tester.drag(find.byType(CustomScrollView), const Offset(0, -10));
    await tester.pumpAndSettle();
    expect(position.pixels, 0);
  });

  test('where a resting scroll settles', () {
    double? at(double p, {bool search = true}) =>
        legacyBarSnapTarget(p, collapsibleSearch: search);

    // The search row (0…52): to the nearer end.
    expect(at(10), 0);
    expect(at(26), 0);
    expect(at(27), 52);
    expect(at(51), 52);
    // The large title (52…104).
    expect(at(60), 52);
    expect(at(78), 52);
    expect(at(79), 104);
    expect(at(103), 104);
    // Already on an edge, or past them: nothing to do.
    expect(at(0), isNull);
    expect(at(52), isNull);
    expect(at(104), isNull);
    expect(at(500), isNull);
    // No collapsible search: the title alone (0…52).
    expect(at(10, search: false), 0);
    expect(at(40, search: false), 52);
  });

  testWidgets('dark and light draw different materials', (tester) async {
    await tester.pumpWidget(_page(brightness: Brightness.dark));
    expect(
      LegacyBarMaterialStyle.of(tester.element(find.byType(CustomScrollView))),
      LegacyBarMaterialStyle.dark,
    );
    await tester.pumpWidget(_page());
    expect(
      LegacyBarMaterialStyle.of(tester.element(find.byType(CustomScrollView))),
      LegacyBarMaterialStyle.light,
    );
  });

  testWidgets('a push flies the title into the next back button', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(_pages(navigator));
    navigator.currentState!.pushNamed('Quick Notes');
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 150));
    // Mid-flight: a "Folders" on its way, between the large title's 34pt
    // and the back button's 17pt.
    final sizes = tester
        .widgetList<Text>(find.text('Folders'))
        .map((text) => text.style?.fontSize)
        .whereType<double>();
    expect(sizes.any((size) => size > 17 && size < 34), isTrue);
    await tester.pumpAndSettle();
    // The new page's back button took the title over: its only "Folders".
    expect(find.text('Folders'), findsOneWidget);
    expect(tester.takeException(), isNull);

    navigator.currentState!.pop();
    await tester.pumpAndSettle();
    expect(find.text('Quick Notes'), findsNothing);
    expect(tester.takeException(), isNull);
  });
}

/// Two pages with the bar, the second pushed over the first.
Widget _pages(GlobalKey<NavigatorState> navigator) {
  Widget page(String title) => CustomScrollView(
    slivers: [
      LegacySliverNavigationBar(largeTitle: Text(title)),
      SliverList.builder(
        itemCount: 20,
        itemBuilder: (_, i) => SizedBox(height: 60, child: Text('$title $i')),
      ),
    ],
  );
  return CupertinoApp(
    navigatorKey: navigator,
    builder: (context, child) => MediaQuery(
      data: const MediaQueryData(
        size: Size(414, 736),
        padding: EdgeInsets.only(top: 20),
      ),
      child: child!,
    ),
    home: page('Folders'),
    onGenerateRoute: (settings) =>
        CupertinoPageRoute(builder: (_) => page(settings.name!)),
  );
}
