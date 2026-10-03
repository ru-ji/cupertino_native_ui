import 'package:flutter/cupertino.dart';
import 'package:cupertino_widgets/cupertino_widgets.dart';

/// The scroll edge effect in its two hosting models, over identical content.
///
/// * **Native** runs in a [CupertinoNativePageScaffold]: a real SwiftUI
///   `ScrollView` owns the content, so the system draws its own effect on it,
///   adaptation included.
/// * **Flutter page** has no scroll view for a native effect to attach to,
///   so [CupertinoNativeNavigationBar] draws the recreation
///   ([CupertinoScrollEdgeEffect]) itself.
class EdgeEffectProbePage extends StatelessWidget {
  const EdgeEffectProbePage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoNativeSliverNavigationBar(largeTitle: 'Scroll Edge Effect'),
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom + 40,
            ),
            sliver: SliverToBoxAdapter(
              child: CupertinoNativeList(
                style: CupertinoNativeListStyle.insetGrouped,
                onRowTap: (id) => _open(context, id),
                sections: [
                  CupertinoNativeListSection(
                    header: 'Compare',
                    footer:
                        'Scroll each one slowly with a bright band under the '
                        'bar, then a dark one: both wash the content in the '
                        'page\'s colour and turn to a dark wash over dark '
                        'content. The Flutter one has no blur. Same content '
                        'in both.',
                    children: [
                      CupertinoNativeListTile(
                        id: 'native',
                        title: 'Native (SwiftUI ScrollView)',
                        subtitle: 'The system effect',
                        showChevron: true,
                      ),
                      CupertinoNativeListTile(
                        id: 'flutter',
                        title: 'Flutter page',
                        subtitle: 'The recreation',
                        showChevron: true,
                      ),
                      CupertinoNativeListTile(
                        id: 'glass',
                        title: 'Glass over bands',
                        subtitle: 'Liquid Glass over scrolling colours',
                        showChevron: true,
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  static void _open(BuildContext context, String id) {
    final page = switch (id) {
      'native' => const _NativeProbe(),
      'glass' => const _GlassProbe(),
      _ => const _FlutterProbe(),
    };
    Navigator.of(context)
        .push(CupertinoPageRoute<void>(builder: (_) => page, title: 'Back'));
  }
}

/// The system effect: a native scaffold, so the body really is inside a
/// SwiftUI `ScrollView` and `scrollEdgeEffect: soft` applies to it. The body
/// route ('edgeEffectProbe') is registered in `scaffold_routes.dart`. No
/// leading item needed: pushed onto Flutter's Navigator with nothing of its
/// own to pop, the scaffold adds its own back button automatically.
class _NativeProbe extends StatelessWidget {
  const _NativeProbe();

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CupertinoNativePageScaffold(
        scrollEdgeEffect: CupertinoScrollEdgeEffectStyle.soft,
        navigationBar: const CupertinoNativeScaffoldNavigationBar(
          title: 'Native',
          titleDisplayMode: CupertinoNativeToolbarTitleDisplayMode.large,
        ),
        body: 'edgeEffectProbe',
      ),
    );
  }
}

/// The recreation: plain Flutter content under [CupertinoNativeNavigationBar],
/// which draws its own [CupertinoScrollEdgeEffect] over whatever scrolls
/// beneath it — no manual `Stack` positioning needed.
class _FlutterProbe extends StatelessWidget {
  const _FlutterProbe();

  @override
  Widget build(BuildContext context) {
    // Under the bar's place: on iOS 26 it is 54pt, the 44pt title row and the
    // space under it, where a native page's content starts too.
    final top = MediaQuery.paddingOf(context).top + 54;
    return CupertinoPageScaffold(
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.only(top: top),
            child: const EdgeEffectProbeBody(),
          ),
          CupertinoNativeNavigationBar(title: 'Flutter page'),
        ],
      ),
    );
  }
}

/// Liquid Glass buttons and containers held still over the bands: scrolling
/// slides bright, dark and coloured content behind them, to see whether the
/// glass adapts to what is under it, as the system's does.
class _GlassProbe extends StatelessWidget {
  const _GlassProbe();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return CupertinoPageScaffold(
      child: Stack(
        children: [
          SingleChildScrollView(
            padding: EdgeInsets.only(top: top + 60),
            child: const EdgeEffectProbeBody(),
          ),
          // Buttons, as a bar would hold them.
          Positioned(
            top: top + 8,
            left: 16,
            right: 16,
            child: Row(
              children: [
                CupertinoNativeButton.icon(
                  CupertinoSymbols.chevronBackward,
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                CupertinoNativeButton.glass(
                  onPressed: () {},
                  child: const Text('Edit'),
                ),
                const SizedBox(width: 12),
                CupertinoNativeButton.glassProminent(
                  onPressed: () {},
                  child: const Text('Done'),
                ),
              ],
            ),
          ),
          // Containers in the middle of the screen.
          Align(
            alignment: Alignment.center,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 16,
              children: [
                CupertinoNativeGlassContainer(
                  shape: CupertinoGlassShape.capsule,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 20,
                    vertical: 12,
                  ),
                  // Symbol and text drawn by SwiftUI inside the glass, laid
                  // out by this Row.
                  child: const Row(
                    mainAxisSize: MainAxisSize.min,
                    spacing: 8,
                    children: [
                      CupertinoSymbolImage('sparkles', weight: FontWeight.w600),
                      Text(
                        'Glass container',
                        style: TextStyle(
                          fontSize: 17,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const CupertinoNativeGlassContainer(
                  shape: CupertinoGlassShape.circle,
                  icon: CupertinoNativeIcon.named('heart.fill', size: 24),
                  width: 64,
                  height: 64,
                ),
                // Small, like a control: only small glass flips between light
                // and dark with what is behind it.
                const CupertinoNativeGlassContainer(width: 120, height: 44),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.paddingOf(context).bottom + 16,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: 12,
              children: [
                // The same three symbols as a Flutter Row in a glass
                // container's child: laid out by Flutter, drawn by SwiftUI
                // inside the glass. To hold against the native group below.
                CupertinoNativeGlassContainer(
                  shape: CupertinoGlassShape.capsule,
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      for (final symbol in const [
                        CupertinoSymbols.plus,
                        CupertinoSymbols.squareAndArrowUp,
                        CupertinoSymbols.ellipsis,
                      ])
                        SizedBox.square(
                          dimension: 44,
                          child: Center(
                            child: CupertinoSymbolImage.symbol(symbol),
                          ),
                        ),
                    ],
                  ),
                ),
                // Three buttons sharing one glass, as a toolbar's: one native
                // group, the symbols drawn inside the glass.
                CupertinoNativeGlassGroup(
                  spacing: 0,
                  onAction: (_) {},
                  items: [
                    for (final symbol in const [
                      CupertinoSymbols.plus,
                      CupertinoSymbols.squareAndArrowUp,
                      CupertinoSymbols.ellipsis,
                    ])
                      CupertinoNativeGlassGroupItem(
                        actionId: symbol.name,
                        icon: CupertinoNativeIcon.symbol(symbol),
                        unionId: 'toolbar',
                      ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The content both probes scroll: alternating bands chosen for what they do
/// to a tint — saturated gradients, flat white, flat black, and a high-noise
/// band that stands in for a photograph.
class EdgeEffectProbeBody extends StatelessWidget {
  const EdgeEffectProbeBody({super.key});

  static const _bands = <(String, List<Color>)>[
    ('Flat white', [Color(0xFFFFFFFF), Color(0xFFFFFFFF)]),
    ('Warm gradient', [Color(0xFFFF6B9D), Color(0xFFFFC371)]),
    ('Flat black', [Color(0xFF000000), Color(0xFF000000)]),
    ('Cool gradient', [Color(0xFF1A2980), Color(0xFF26D0CE)]),
    ('Busy — photo-like', [Color(0xFF7F7FD5), Color(0xFF86A8E7)]),
    ('Flat mid grey', [Color(0xFF808080), Color(0xFF808080)]),
    ('Vivid', [Color(0xFFFF0080), Color(0xFFFFD200)]),
    ('Flat white', [Color(0xFFFFFFFF), Color(0xFFFFFFFF)]),
    ('Deep', [Color(0xFF0F2027), Color(0xFF2C5364)]),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (final (label, colors) in _bands)
          _Band(label: label, colors: colors),
        SizedBox(height: MediaQuery.paddingOf(context).bottom + 80),
      ],
    );
  }
}

class _Band extends StatelessWidget {
  const _Band({required this.label, required this.colors});

  final String label;
  final List<Color> colors;

  /// Readable on either end of the palette, so the label never becomes the
  /// thing you are judging.
  Color get _ink {
    final c = colors.first;
    final luminance = (c.r * 0.299 + c.g * 0.587 + c.b * 0.114);
    return luminance > 0.6 ? const Color(0xFF000000) : const Color(0xFFFFFFFF);
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 180,
      alignment: Alignment.center,
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: colors,
        ),
      ),
      child: Text(
        label,
        style: TextStyle(
          fontSize: 20,
          fontWeight: FontWeight.w700,
          decoration: TextDecoration.none,
          color: _ink,
        ),
      ),
    );
  }
}
