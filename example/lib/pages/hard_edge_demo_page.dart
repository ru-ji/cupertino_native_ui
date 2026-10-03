import 'package:flutter/cupertino.dart';
import 'package:cupertino_native_ui/cupertino_native_ui.dart';

/// A page with no Flutter in it, a SwiftUI `NavigationStack` in a `TabView`
/// over a native list, with the scroll edge effect set to `.hard` on every
/// edge: the system's own look for the navigation bar and the tab bar when
/// the content scrolls under them. "Soft" / "Hard" switches the style;
/// "Flutter" opens the same page drawn by Flutter, with the package's bars
/// and their recreation of the effect.
class HardEdgeDemoPage extends StatefulWidget {
  const HardEdgeDemoPage({super.key});

  @override
  State<HardEdgeDemoPage> createState() => _HardEdgeDemoPageState();
}

class _HardEdgeDemoPageState extends State<HardEdgeDemoPage> {
  /// Light green tea, so the bars' hard edge stands out against it.
  static const _background = Color(0xFFD5E8C4);

  static const _tabs = {
    'library': ('Library', 'books.vertical.fill'),
    'browse': ('Browse', 'square.grid.2x2.fill'),
    'settings': ('Settings', 'gearshape.fill'),
  };

  String _tab = 'library';

  /// Switched from the bar, to hold `.soft` against `.hard` over the same
  /// coloured page.
  CupertinoScrollEdgeEffectStyle _style = CupertinoScrollEdgeEffectStyle.hard;

  CupertinoNativeBody _body() => CupertinoNativeBody.list(
    id: 'rows',
    sections: _sections(_tabs[_tab]!.$1),
  );

  static List<CupertinoNativeListSection> _sections(String title) => [
    for (final (header, symbol, color) in const [
      ('Recently Added', 'clock.fill', CupertinoColors.systemBlue),
      ('Favorites', 'star.fill', CupertinoColors.systemYellow),
      ('Downloaded', 'arrow.down.circle.fill', CupertinoColors.systemGreen),
      ('Shared With You', 'person.2.fill', CupertinoColors.systemPink),
    ])
      CupertinoNativeListSection(
        header: header,
        children: [
          for (var i = 1; i <= 5; i++)
            CupertinoNativeListTile(
              id: '$header $i',
              title: '$title item $i',
              subtitle: header,
              leading: CupertinoNativeIcon.named(symbol, color: color),
              showChevron: true,
            ),
        ],
      ),
  ];

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CupertinoNativePageScaffold(
        scrollEdgeEffect: _style,
        backgroundColor: _background,
        navigationBar: CupertinoNativeScaffoldNavigationBar(
          title: _tabs[_tab]!.$1,
          titleDisplayMode: CupertinoNativeToolbarTitleDisplayMode.large,
          trailing: [
            CupertinoNativeToolbarItem(
              actionId: 'style',
              title: _style == CupertinoScrollEdgeEffectStyle.hard
                  ? 'Soft'
                  : 'Hard',
            ),
            const CupertinoNativeToolbarItem(
              actionId: 'flutter',
              title: 'Flutter',
            ),
          ],
        ),
        onToolbarAction: (_, actionId) => actionId == 'style'
            ? setState(
                () => _style = _style == CupertinoScrollEdgeEffectStyle.hard
                    ? CupertinoScrollEdgeEffectStyle.soft
                    : CupertinoScrollEdgeEffectStyle.hard,
              )
            : Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => _FlutterHardEdge(style: _style),
                ),
              ),
        tabBar: CupertinoNativeTabBar(
          scrollEdgeEffect: _style,
          currentIndex: _tabs.keys.toList().indexOf(_tab),
          items: [
            for (final MapEntry(key: id, value: (title, symbol))
                in _tabs.entries)
              CupertinoNativeTab(
                id: id,
                title: title,
                icon: CupertinoNativeIcon.named(symbol),
              ),
          ],
        ),
        nativeBody: _body(),
        onTabChanged: (id) => setState(() => _tab = id),
      ),
    );
  }
}

/// The same page in Flutter: the package's navigation bar and standalone tab
/// bar, each drawing its `.hard` effect over a native list.
class _FlutterHardEdge extends StatefulWidget {
  const _FlutterHardEdge({required this.style});

  final CupertinoScrollEdgeEffectStyle style;

  @override
  State<_FlutterHardEdge> createState() => _FlutterHardEdgeState();
}

class _FlutterHardEdgeState extends State<_FlutterHardEdge> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final tabs = _HardEdgeDemoPageState._tabs.values.toList();
    return CupertinoPageScaffold(
      backgroundColor: _HardEdgeDemoPageState._background,
      child: Stack(
        children: [
          CustomScrollView(
            slivers: [
              CupertinoNativeSliverNavigationBar(
                largeTitle: tabs[_tab].$1,
                scrollEdgeEffect: widget.style,
              ),
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(context).bottom + 100,
                ),
                sliver: SliverToBoxAdapter(
                  child: CupertinoNativeList(
                    sections: _HardEdgeDemoPageState._sections(tabs[_tab].$1),
                  ),
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: CupertinoNativeTabBar(
              scrollEdgeEffect: widget.style,
              currentIndex: _tab,
              onTap: (i) => setState(() => _tab = i),
              items: [
                for (final (i, (title, symbol)) in tabs.indexed)
                  CupertinoNativeTab(
                    id: '$i',
                    title: title,
                    icon: CupertinoNativeIcon.named(symbol),
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
