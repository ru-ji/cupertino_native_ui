import 'package:flutter/cupertino.dart';
import 'package:cupertino_native_ui/cupertino_native_ui.dart';

/// [CupertinoNativeGlassContainer]: the iOS 26 Liquid Glass material as
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

  int _tintIndex = 0;
  bool _interactive = true;
  bool _clear = false;
  bool? _supported;

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
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: CustomScrollView(
        slivers: [
          CupertinoNativeSliverNavigationBar(largeTitle: 'Liquid Glass'),
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
                  child: Stack(
                    children: [
                      // Only the Flutter artwork is clipped: a Flutter clip
                      // around the native glass would cut every native view
                      // painted before it as well.
                      Positioned.fill(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(26),
                          child: const _Backdrop(),
                        ),
                      ),
                      // Glass card: a Flutter child: laid out by Flutter, its
                      // texts drawn by SwiftUI inside the glass, so they adapt
                      // to what is behind it.
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
                          child: Padding(
                            padding: const EdgeInsets.all(20),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                const Text(
                                  'Liquid Glass',
                                  style: TextStyle(
                                    fontSize: 22,
                                    fontWeight: FontWeight.w700,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text(
                                  'Native refraction · Flutter layout',
                                  style: TextStyle(
                                    fontSize: 13,
                                    color: CupertinoColors.secondaryLabel
                                        .resolveFrom(context),
                                  ),
                                ),
                              ],
                            ),
                          ),
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
                          child: const Align(
                            alignment: Alignment.centerLeft,
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 20),
                              child: Text(
                                'Now Playing: Deep Focus',
                                style: TextStyle(fontSize: 17),
                              ),
                            ),
                          ),
                        ),
                      ),
                      // A pressable glass circle: onPressed makes the container a
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
                              'and hold the shapes: interactive glass shimmers and '
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
                  ],
                ),
                const _TransitionsCard(),
              ],
            ),
          ),
        ],
      ),
    );
  }
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

/// The three changes SwiftUI animates on its own, one at a time on one stage.
///
/// Each is driven by nothing but `glassEffectID` and `glassEffectTransition`:
/// SwiftUI noticing that a glass with one id left and a glass with another
/// arrived. No width animation, no cross-fade: the transition is the effect.
enum _Change {
  /// A glass where there was none: `materialize`.
  arrive(
    'Arrive',
    '0 → 1',
    'The only change here that is really an arrival. The item keeps its '
        'slot and loses only its material, so the box does not move '
        'underneath the glass landing in it.',
  ),

  /// A different glass in the same place.
  swap(
    'Swap',
    '1 → 1',
    'A new id is a different glass, so one leaves and another arrives '
        'in its place, and matched geometry turns the content over.',
  ),

  /// Two glasses replaced by two differently sized ones: the Photos
  /// "Select" change.
  reshape(
    'Reshape',
    '1 ⇄ 2',
    'Both glasses are replaced at once, so matched geometry morphs each old '
        'shape into its new one. The 6pt gap is under the blend radius, which '
        'lets them run together on the way past.',
  );

  const _Change(this.label, this.arrow, this.blurb);

  final String label;
  final String arrow;
  final String blurb;
}

class _TransitionsCard extends StatefulWidget {
  const _TransitionsCard();

  @override
  State<_TransitionsCard> createState() => _TransitionsCardState();
}

class _TransitionsCardState extends State<_TransitionsCard> {
  _Change _change = _Change.arrive;

  /// One state per change, so switching back finds it where it was left.
  bool _shown = false;
  bool _isBack = false;
  bool _selecting = false;

  /// The menu the reshape's left glass opens, in both states.
  static const _menu = [
    CupertinoNativeMenuAction(
      title: 'Select',
      systemImage: 'checkmark.circle',
      actionId: 'menu.select',
    ),
    CupertinoNativeMenuAction(
      title: 'Sort By',
      systemImage: 'arrow.up.arrow.down',
      actionId: 'menu.sort',
    ),
    CupertinoNativeMenuAction(
      title: 'Delete',
      systemImage: 'trash',
      actionId: 'menu.delete',
      isDestructive: true,
    ),
  ];

  void _play() => setState(() {
    switch (_change) {
      case _Change.arrive:
        _shown = !_shown;
      case _Change.swap:
        _isBack = !_isBack;
      case _Change.reshape:
        _selecting = !_selecting;
    }
  });

  String get _buttonLabel => switch (_change) {
    _Change.arrive => _shown ? 'Remove' : 'Add',
    _Change.swap => 'Swap',
    _Change.reshape => _selecting ? 'Done' : 'Select',
  };

  /// The glass on stage. Keyed by the change, so switching changes builds a
  /// fresh group instead of animating one change into another.
  Widget _glass() => switch (_change) {
    _Change.arrive => CupertinoNativeGlassGroup(
      key: const ValueKey(_Change.arrive),
      transition: CupertinoGlassTransition.materialize,
      onAction: (_) => _play(),
      items: [
        CupertinoNativeGlassGroupItem(
          actionId: 'back',
          glassVisible: _shown,
          icon: const CupertinoNativeIcon.named('chevron.backward'),
        ),
      ],
    ),
    _Change.swap => CupertinoNativeGlassGroup(
      key: const ValueKey(_Change.swap),
      onAction: (_) => _play(),
      items: [
        CupertinoNativeGlassGroupItem(
          actionId: _isBack ? 'leading.back' : 'leading.more',
          icon: CupertinoNativeIcon.named(
            _isBack ? 'chevron.backward' : 'ellipsis',
          ),
        ),
      ],
    ),
    _Change.reshape => CupertinoNativeGlassGroup(
      key: const ValueKey(_Change.reshape),
      spacing: 6,
      // Only the X, the Select capsule and the menu's Select change state.
      onAction: (id) {
        if (id == 'close' || id == 'select' || id == 'menu.select') _play();
      },
      items: _selecting
          ? [
              const CupertinoNativeGlassGroupItem(
                actionId: 'menu.wide',
                shape: CupertinoGlassGroupShape.capsule,
                icon: CupertinoNativeIcon.named('line.3.horizontal'),
                title: '•••',
                menuItems: _menu,
              ),
              const CupertinoNativeGlassGroupItem(
                actionId: 'close',
                shape: CupertinoGlassGroupShape.capsule,
                icon: CupertinoNativeIcon.named('xmark'),
                width: 44,
              ),
            ]
          : [
              const CupertinoNativeGlassGroupItem(
                actionId: 'menu',
                shape: CupertinoGlassGroupShape.capsule,
                icon: CupertinoNativeIcon.named('line.3.horizontal'),
                width: 44,
                menuItems: _menu,
              ),
              const CupertinoNativeGlassGroupItem(
                actionId: 'select',
                shape: CupertinoGlassGroupShape.capsule,
                title: 'Select',
              ),
            ],
    ),
  };

  @override
  Widget build(BuildContext context) {
    final labels = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 12, 20, 8),
            child: Text(
              'GLASS TRANSITIONS',
              style: TextStyle(fontSize: 13, color: labels),
            ),
          ),
          // A rounded background, not a clip: the card holds native views.
          DecoratedBox(
            decoration: BoxDecoration(
              color: CupertinoColors.secondarySystemGroupedBackground
                  .resolveFrom(context),
              borderRadius: BorderRadius.circular(26),
            ),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  CupertinoNativeSlidingSegmentedControl<int>(
                    children: {
                      for (final c in _Change.values) c.index: Text(c.label),
                    },
                    groupValue: _change.index,
                    onValueChanged: (i) =>
                        setState(() => _change = _Change.values[i!]),
                  ),
                  const SizedBox(height: 12),
                  // The stage: only the Flutter artwork is clipped, the
                  // glass sits over it unclipped.
                  SizedBox(
                    height: 190,
                    child: Stack(
                      children: [
                        Positioned.fill(
                          child: ClipRRect(
                            borderRadius: BorderRadius.circular(18),
                            child: const _Backdrop(),
                          ),
                        ),
                        // A hairline to hold one state against the other.
                        Align(
                          child: SizedBox(
                            width: 230,
                            height: 1,
                            child: ColoredBox(
                              color: CupertinoColors.white.withValues(
                                alpha: 0.3,
                              ),
                            ),
                          ),
                        ),
                        Center(child: _glass()),
                      ],
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(6, 14, 6, 0),
                    child: Text.rich(
                      TextSpan(
                        children: [
                          TextSpan(
                            text: '${_change.arrow}   ',
                            style: const TextStyle(
                              fontWeight: FontWeight.w600,
                              fontFeatures: [FontFeature.tabularFigures()],
                            ),
                          ),
                          TextSpan(text: _change.blurb),
                        ],
                      ),
                      style: TextStyle(
                        fontSize: 13,
                        height: 1.35,
                        color: labels,
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  CupertinoNativeButton.glass(
                    expand: true,
                    onPressed: _play,
                    child: Text(_buttonLabel),
                  ),
                ],
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
            child: Text(
              'Each glass is tappable too: the change is driven by the glass as '
              'much as by the button under it.',
              style: TextStyle(fontSize: 13, color: labels),
            ),
          ),
        ],
      ),
    );
  }
}
