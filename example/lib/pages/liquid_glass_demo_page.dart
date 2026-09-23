import 'package:flutter/cupertino.dart';
import 'package:cupertino_widgets/cupertino_widgets.dart';

/// [CupertinoNativeGlassContainer] — the iOS 26 Liquid Glass material as
/// a Flutter container. The glass shapes below are real SwiftUI `.glassEffect`
/// views refracting the colorful Flutter artwork rendered behind them; the
/// labels on top are ordinary Flutter widgets.
class LiquidGlassDemoPage extends StatefulWidget {
  const LiquidGlassDemoPage({super.key});

  @override
  State<LiquidGlassDemoPage> createState() => _LiquidGlassDemoPageState();
}

class _LiquidGlassDemoPageState extends State<LiquidGlassDemoPage> {
  static const _tints = ['None', 'Blue', 'Pink'];
  static const _transitions = [
    CupertinoGlassTransition.matchedGeometry,
    CupertinoGlassTransition.materialize,
    CupertinoGlassTransition.identity,
  ];
  static const _transitionLabels = ['Match', 'Materialize', 'None'];

  int _tintIndex = 0;
  bool _interactive = true;
  bool _clear = false;
  bool? _supported;

  _GlassCase _glassCase = _GlassCase.appear;
  CupertinoGlassTransition _transition =
      CupertinoGlassTransition.matchedGeometry;
  bool _glassOn = true;

  /// The items of the demo group, for the case currently selected.
  ///
  /// The three cases differ only in *what changes* between one config and the
  /// next, which is the whole point: the transition is chosen by the shape of
  /// the change, not by the widget.
  List<CupertinoNativeGlassGroupItem> get _glassItems {
    switch (_glassCase) {
      case _GlassCase.appear:
        // 0 → 1. The item never leaves the list — it only loses its glass — so
        // the group's box holds still while the material arrives.
        return [
          CupertinoNativeGlassGroupItem(
            actionId: 'appear',
            glassVisible: _glassOn,
            icon: CupertinoNativeIcon.named('sparkles'),
          ),
        ];
      case _GlassCase.swap:
        // 1 → 1. A new actionId is a new glass: SwiftUI removes one and inserts
        // the other in the same place, so there is no geometry to match.
        return [
          CupertinoNativeGlassGroupItem(
            actionId: _glassOn ? 'swap.undo' : 'swap.redo',
            icon: CupertinoNativeIcon.named(
              _glassOn ? 'arrow.uturn.backward' : 'arrow.uturn.forward',
            ),
          ),
        ];
      case _GlassCase.merge:
        // 2 → 1 and 1 → 2. The actionIds never change; only the union id does,
        // which is what takes the two glasses into and out of one shape.
        return [
          CupertinoNativeGlassGroupItem(
            actionId: 'merge.back',
            unionId: _glassOn ? 'pair' : null,
            icon: CupertinoNativeIcon.named('arrow.uturn.backward'),
          ),
          CupertinoNativeGlassGroupItem(
            actionId: 'merge.forward',
            unionId: _glassOn ? 'pair' : null,
            icon: CupertinoNativeIcon.named('arrow.uturn.forward'),
          ),
        ];
    }
  }

  @override
  void initState() {
    super.initState();
    CupertinoNativeGlassContainer.isSupported.then((v) {
      if (mounted) setState(() => _supported = v);
    });
  }

  CupertinoGlassVariant get _variant =>
      _clear ? CupertinoGlassVariant.clear : CupertinoGlassVariant.regular;

  Color? get _tint => switch (_tintIndex) {
    1 => CupertinoColors.systemBlue,
    2 => CupertinoColors.systemPink,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoNativeSliverNavigationBar(
            largeTitle: 'Liquid Glass',
            leading: Navigator.canPop(context)
                ? CupertinoNativeButton.glass(
                    borderShape: CupertinoNativeButtonBorderShape.circle,
                    onPressed: () => Navigator.pop(context),
                    child: CupertinoSymbolImage.symbol(
                      CupertinoSymbols.chevronBackward,
                    ),
                  )
                : null,
          ),
          SliverPadding(
            padding: EdgeInsets.only(
              bottom:
                  MediaQuery.paddingOf(context).bottom +
                  MediaQuery.viewInsetsOf(context).bottom +
                  40,
            ),
            sliver: SliverList.list(
              children: [
                const SizedBox(height: 20),
                Container(
                  height: 400,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Stack(
                    children: [
                      const Positioned.fill(child: _Backdrop()),
                      // Glass card — its content is hosted INSIDE the glass by
                      // `route`: SwiftUI applies `glassEffect` to the hosted Flutter
                      // view, so the text is drawn above the material rather than
                      // refracted through it. It is a live engine — state and
                      // animations work in there as anywhere else.
                      Center(
                        child: CupertinoNativeGlassContainer(
                          shape: CupertinoGlassShape.roundedRect,
                          cornerRadius: 26,
                          variant: _variant,
                          tint: _tint,
                          interactive: _interactive,
                          // Tint and variant changes are interpolated by SwiftUI:
                          // one message, then CoreAnimation. Try the tint segments.
                          animateChanges: true,
                          width: 260,
                          height: 116,
                          route: 'glassCard',
                        ),
                      ),
                      // Glass capsule pinned to the bottom, like a mini player.
                      Positioned(
                        left: 24,
                        right: 24,
                        bottom: 20,
                        child: CupertinoNativeGlassContainer(
                          shape: CupertinoGlassShape.capsule,
                          variant: _variant,
                          tint: _tint,
                          interactive: _interactive,
                          // Tint and variant changes are interpolated by SwiftUI:
                          // one message, then CoreAnimation. Try the tint segments.
                          animateChanges: true,
                          height: 52,

                          route: 'glassNowPlaying',
                        ),
                      ),
                      // The group the transitions are demonstrated on. Its
                      // whole state is three values: which change, how it
                      // animates, and which way round it is.
                      Positioned(
                        top: 20,
                        left: 20,
                        child: CupertinoNativeGlassGroup(
                          // 0 is the shorthand for "one shared glass". The
                          // merge case states its union per item instead, so it
                          // asks for a real gap.
                          spacing: _glassCase == _GlassCase.merge ? 4 : 0,
                          transition: _transition,
                          tint: _tint,
                          clear: _clear,
                          interactive: _interactive,
                          onAction: (_) {},
                          items: _glassItems,
                        ),
                      ),
                      // A pressable glass circle — onPressed makes the container a
                      // liquid-glass button (tap it to cycle the tint).
                      Positioned(
                        top: 20,
                        right: 20,
                        child: CupertinoNativeGlassContainer(
                          shape: CupertinoGlassShape.circle,
                          variant: _variant,
                          tint: _tint,
                          interactive: _interactive,
                          // Tint and variant changes are interpolated by SwiftUI:
                          // one message, then CoreAnimation. Try the tint segments.
                          animateChanges: true,
                          width: 56,
                          height: 56,
                          icon: CupertinoNativeIcon.symbol(
                            CupertinoSymbols.paintbrush,
                          ),
                          onPressed: () => setState(
                            () => _tintIndex = (_tintIndex + 1) % _tints.length,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                CupertinoNativeList(
                  sections: [
                    CupertinoNativeListSection(
                      header: 'Glass',
                      footer: switch (_supported) {
                        true =>
                          'This device renders real Liquid Glass (iOS 26+). Touch '
                              'and hold the shapes — interactive glass shimmers and '
                              'stretches under your finger. The circle is a glass button: '
                              'tap it to cycle the tint.',
                        false =>
                          'This device runs iOS 25 or earlier: a static material '
                              'stands in. The real effect is iOS 26+ only.',
                        null => 'Checking Liquid Glass availability…',
                      },
                      children: [
                        CupertinoNativeListTile(
                          id: 'interactive',
                          title: 'Interactive',
                          subtitle: 'Shimmer on touch',
                          trailing: CupertinoNativeSwitch(
                            value: _interactive,
                            onChanged: (v) => setState(() => _interactive = v),
                          ),
                        ),
                        CupertinoNativeListTile(
                          id: 'clear',
                          title: 'Clear variant',
                          subtitle: 'More transparent glass',
                          trailing: CupertinoNativeSwitch(
                            value: _clear,
                            onChanged: (v) => setState(() => _clear = v),
                          ),
                        ),
                        CupertinoNativeListTile(
                          id: 'tint',
                          title: 'Tint',
                          trailing:
                              CupertinoNativeSlidingSegmentedControl<int>.menu(
                                children: {
                                  for (final (i, label) in _tints.indexed)
                                    i: Text(label),
                                },
                                groupValue: _tintIndex,
                                onValueChanged: (v) =>
                                    setState(() => _tintIndex = v!),
                              ),
                        ),
                      ],
                    ),
                    CupertinoNativeListSection(
                      header: 'Glass transitions',
                      footer:
                          'The group in the artwork above is driven by these '
                          'three controls. Appear is 0 → 1: a glass arrives '
                          'where there was nothing, keeping its slot so the box '
                          'does not move under it. Swap is 1 → 1: one glass '
                          'replaced by another in the same place, with no '
                          'geometry to match. Merge is 1 ⇄ 2: two glasses taken '
                          'into and out of one shared shape. Match is the '
                          'default and is what makes a merge travel; '
                          'Materialize is the one for a glass arriving or '
                          'leaving on its own.',
                      children: [
                        CupertinoNativeListTile(
                          id: 'glassCase',
                          title: 'Change',
                          subtitle: _glassCase.arrow,
                          trailing:
                              CupertinoNativeSlidingSegmentedControl<int>.menu(
                                children: {
                                  for (final (i, c)
                                      in _GlassCase.values.indexed)
                                    i: Text(c.label),
                                },
                                groupValue: _glassCase.index,
                                onValueChanged: (v) => setState(() {
                                  _glassCase = _GlassCase.values[v!];
                                  _glassOn = true;
                                }),
                              ),
                        ),
                        CupertinoNativeListTile(
                          id: 'glassTransition',
                          title: 'Transition',
                          trailing:
                              CupertinoNativeSlidingSegmentedControl<int>.menu(
                                children: {
                                  for (final (i, label)
                                      in _transitionLabels.indexed)
                                    i: Text(label),
                                },
                                groupValue: _transitions.indexOf(_transition),
                                onValueChanged: (v) => setState(
                                  () => _transition = _transitions[v!],
                                ),
                              ),
                        ),
                        CupertinoNativeListTile(
                          id: 'glassOn',
                          title: _glassOn ? 'Present' : 'Absent',
                          subtitle: switch (_glassCase) {
                            _GlassCase.appear =>
                              'Flip to materialise the glass in and out',
                            _GlassCase.swap =>
                              'Flip to replace the glass with its twin',
                            _GlassCase.merge =>
                              'Flip to unite the two glasses, and part them',
                          },
                          trailing: CupertinoNativeSwitch(
                            value: _glassOn,
                            onChanged: (v) => setState(() => _glassOn = v),
                          ),
                        ),
                      ],
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

/// The changes a glass group can be asked to make, as the demo drives them.
///
/// Four cases, three knobs: 0 → 1 and 1 → 0 are one, and 1 → 2 and 2 → 1 are
/// another, because each pair changes the same thing.
enum _GlassCase {
  /// 0 → 1 and 1 → 0 — a glass arrives where there was nothing, and leaves.
  appear('Appear', '0 → 1'),

  /// 1 → 1 — one glass replaced by another, in the same place.
  swap('Swap', '1 → 1'),

  /// 1 → 2 and 2 → 1 — two glasses join into one shape and part again.
  merge('Merge', '1 ⇄ 2');

  const _GlassCase(this.label, this.arrow);

  final String label;
  final String arrow;
}

/// Vivid Flutter-drawn artwork for the glass to refract.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2980), Color(0xFF26D0CE)],
        ),
      ),
      child: Stack(
        children: const [
          _Blob(top: -40, left: -30, size: 220, color: Color(0xFFFF6B9D)),
          _Blob(top: 120, right: -50, size: 260, color: Color(0xFFFFC371)),
          _Blob(bottom: -60, left: 60, size: 240, color: Color(0xFF7F7FD5)),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({
    this.top,
    this.left,
    this.right,
    this.bottom,
    required this.size,
    required this.color,
  });

  final double? top, left, right, bottom;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
