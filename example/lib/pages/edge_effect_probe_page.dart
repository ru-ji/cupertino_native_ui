import 'package:flutter/cupertino.dart';
import 'package:cupertino_widgets/cupertino_widgets.dart';
import 'package:haze/haze.dart';

import '../widgets/settings_ui.dart';

/// The scroll edge effect in its two hosting models, over identical content.
///
/// What to look for is the **tint**, not the blur. iOS derives a mix-in colour
/// from what passes under the bar, so the system's scrim recedes over a
/// bright, busy band and comes back over a flat one, while the blur holds.
/// [CupertinoScrollEdgeEffect] takes a fixed colour and cannot do that.
///
/// * **Native** runs in a [CupertinoNativeScaffold]: a real SwiftUI
///   `ScrollView` owns the content, so the system draws its own effect on it,
///   adaptation included.
/// * **Flutter page** has no scroll view for a native effect to attach to —
///   one hosted over it draws nothing at all — so the bar draws the
///   recreation. Tried twice: `.scrollEdgeEffectStyle` on a hosted SwiftUI
///   view, and iOS 26's `UIScrollEdgeElementContainerInteraction` pointed at
///   an empty `UIScrollView` whose offset Dart drove. Neither renders a
///   thing. `UIScrollEdgeEffect` blurs the content its own scroll view holds,
///   and an empty one holds none — being composited over the Flutter surface
///   buys nothing.
///
/// The third screen is about the other half of the same wall: what a Flutter
/// effect can reach once native controls are the ones scrolling under it.
class EdgeEffectProbePage extends StatelessWidget {
  const EdgeEffectProbePage({super.key});

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      largeTitle: false,
      title: 'Scroll Edge Effect',
      children: [
        SettingsSection(
          header: 'Compare',
          footer:
              'Scroll each one slowly with a bright band under the bar, then '
              'a dark one. The native screen thins its tint over the bright '
              'band and keeps the blur; the Flutter one holds a single tint '
              'throughout. Same content in both.',
          children: [
            SettingsRow(
              title: 'Native (SwiftUI ScrollView)',
              subtitle: 'The system effect, adaptive',
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => const _NativeProbe(),
                  title: 'Back',
                ),
              ),
            ),
            SettingsRow(
              title: 'Flutter page (Haze)',
              subtitle: 'The recreation, fixed tint',
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => const _HazeProbe(),
                  title: 'Back',
                ),
              ),
            ),
            SettingsRow(
              title: 'Native controls under the bar',
              subtitle: 'What the effect can and cannot reach',
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => const _NativeUnderBarProbe(),
                  title: 'Back',
                ),
              ),
            ),
            SettingsRow(
              title: 'Isolate the layers',
              subtitle: 'Blur alone, tint alone, and neither',
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => const _LayerIsolationProbe(),
                  title: 'Back',
                ),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// The system effect: a native scaffold, so the body really is inside a
/// SwiftUI `ScrollView` and `.scrollEdgeEffectStyle(.soft)` applies to it.
class _NativeProbe extends StatelessWidget {
  const _NativeProbe();

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CupertinoNativeScaffold(
        scrollEdgeEffect: CupertinoScrollEdgeEffectStyle.soft,
        appBar: const CupertinoNativeAppBar(
          title: 'Native',
          titleDisplayMode: CupertinoNativeToolbarTitleDisplayMode.large,
        ),
        body: 'edgeEffectProbe',
      ),
    );
  }
}

/// The recreation, over the same bands — with the stacking order INVERTED on
/// purpose, for this page only.
///
/// A real bar puts its glass buttons over the effect: they are chrome, and
/// chrome does not dissolve. Here the effect is pushed last and given a much
/// taller rectangle than a bar's, so it lies over the leading button instead.
/// What the button does under it is the thing this screen is for — a
/// `BackdropFilter` cannot reach a platform view, and nothing on this page
/// publishes an edge region, so no bitmap stands in for it either.
///
/// Its tint is fixed, and that is not a shortcut: the system effect hosted
/// over this same page draws nothing at all. `UIScrollEdgeEffect` blurs the
/// content of the scroll view it belongs to, and a Flutter page has no scroll
/// view for it to belong to. Tested, not assumed.
class _HazeProbe extends StatelessWidget {
  const _HazeProbe();

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return CupertinoPageScaffold(
      child: Stack(
        children: [
          const Positioned.fill(
            child: SingleChildScrollView(child: EdgeEffectProbeBody()),
          ),
          // The bar row by hand rather than `CupertinoAppBar`: the bar owns
          // its own effect and paints its buttons over it, which is the one
          // thing this page is inverting.
          Positioned(
            top: top,
            left: 0,
            right: 0,
            height: 44,
            child: Row(
              children: [
                const SizedBox(width: 16),
                CupertinoNativeButton(
                  icon: CupertinoNativeIcon.symbol(
                    CupertinoSymbols.chevronBackward,
                    size: 20,
                  ),
                  style: CupertinoNativeButtonStyle.glass,
                  borderShape: CupertinoNativeButtonBorderShape.circle,
                  labelStyle: CupertinoNativeButtonLabelStyle.iconOnly,
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                const Text(
                  'Haze',
                  style: TextStyle(
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                    decoration: TextDecoration.none,
                    color: CupertinoColors.label,
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 44),
              ],
            ),
          ),
          // Last, so it lies over the leading button, and 110pt past the bar
          // instead of the bar's own overhang. It stays hit-transparent —
          // `CupertinoScrollEdgeEffect` is an `IgnorePointer` — so the button
          // underneath still takes its taps.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: top + 44 + 110,
            child: const CupertinoScrollEdgeEffect(),
          ),
        ],
      ),
    );
  }
}

/// Runs each layer of the effect on its own, so an artefact can be attributed
/// instead of guessed at. Tap the title to cycle.
///
/// * **Both** — the effect as shipped.
/// * **Blur only** — no tint. A line still there is the blur's, or the
///   filter's own boundary.
/// * **Tint only** — no blur, so no `BackdropFilter` is pushed at all. A line
///   still there cannot be a filter artefact; it is the gradient, or it is
///   not ours.
/// * **Neither** — nothing is drawn. A line still there is coming from the
///   page, not from the effect.
class _LayerIsolationProbe extends StatefulWidget {
  const _LayerIsolationProbe();

  @override
  State<_LayerIsolationProbe> createState() => _LayerIsolationProbeState();
}

class _LayerIsolationProbeState extends State<_LayerIsolationProbe> {
  static const _modes = ['Both', 'Blur only', 'Tint only', 'Neither'];
  int _mode = 0;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    final blur = _mode == 0 || _mode == 1;
    final tint = _mode == 0 || _mode == 2;
    return CupertinoPageScaffold(
      child: Stack(
        children: [
          const Positioned.fill(
            child: SingleChildScrollView(child: EdgeEffectProbeBody()),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: top + 44 + 110,
            child: IgnorePointer(
              child: Haze(
                sigma: blur ? 12 : 0,
                falloff: 1,
                plateau: 0.3,
                tint: tint
                    ? CupertinoDynamicColor.resolve(
                        CupertinoColors.systemBackground,
                        context,
                      )
                    : null,
                tintOpacity: 0.55,
              ),
            ),
          ),
          Positioned(
            top: top,
            left: 0,
            right: 0,
            height: 44,
            child: Row(
              children: [
                const SizedBox(width: 16),
                CupertinoNativeButton(
                  icon: CupertinoNativeIcon.symbol(
                    CupertinoSymbols.chevronBackward,
                    size: 20,
                  ),
                  style: CupertinoNativeButtonStyle.glass,
                  borderShape: CupertinoNativeButtonBorderShape.circle,
                  labelStyle: CupertinoNativeButtonLabelStyle.iconOnly,
                  onPressed: () => Navigator.pop(context),
                ),
                const Spacer(),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () =>
                      setState(() => _mode = (_mode + 1) % _modes.length),
                  child: Text(
                    _modes[_mode],
                    style: const TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                      color: CupertinoColors.white,
                    ),
                  ),
                ),
                const SizedBox(width: 16),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The content every probe scrolls: alternating bands chosen for what they do
/// to a tint — saturated gradients, flat white, flat black, and a high-noise
/// band that stands in for a photograph.
/// Native controls passing under a Flutter effect, next to their Flutter
/// counterparts, so the two behaviours are visible in the same scroll.
///
/// The Flutter widgets blur. The native ones cannot: a `BackdropFilter` only
/// filters its own render target, and over a platform view Flutter paints
/// into an overlay the embedder clears to transparent — so the shader has no
/// pixels of the control to read, and it would come back up crisp through the
/// bar. They dissolve instead, natively, along the same falloff the tint uses
/// (`CupertinoEdgeEffectCoverage` publishes the effect's rectangle; the
/// hosted views fade themselves).
///
/// What to look for, scrolling slowly:
///
/// * the Flutter control **softens** — it is genuinely blurred;
/// * the native control **thins out** — it is faded, not blurred, and there
///   is no way to blur it from Flutter's side;
/// * the bar's own back button stays **sharp** at any scroll position. It is
///   inside the effect's rectangle too, and only the widget tree can tell it
///   apart from a row that has scrolled up behind it.
class _NativeUnderBarProbe extends StatefulWidget {
  const _NativeUnderBarProbe();

  @override
  State<_NativeUnderBarProbe> createState() => _NativeUnderBarProbeState();
}

class _NativeUnderBarProbeState extends State<_NativeUnderBarProbe> {
  bool _switchValue = true;
  double _slider = 0.4;
  int _segment = 0;

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top;
    return CupertinoPageScaffold(
      child: Stack(
        children: [
          Positioned.fill(
            child: ListView(
              padding: EdgeInsets.only(
                top: top + 44 + 24,
                bottom: MediaQuery.paddingOf(context).bottom + 80,
              ),
              children: [
                for (var i = 0; i < 3; i++) ...[
                  _pair(
                    'Switch',
                    CupertinoSwitch(
                      value: _switchValue,
                      onChanged: (v) => setState(() => _switchValue = v),
                    ),
                    CupertinoNativeSwitch(
                      value: _switchValue,
                      onChanged: (v) => setState(() => _switchValue = v),
                    ),
                  ),
                  _pair(
                    'Glass action',
                    Container(
                      width: 44,
                      height: 44,
                      decoration: const BoxDecoration(
                        color: CupertinoColors.systemGrey4,
                        shape: BoxShape.circle,
                      ),
                    ),
                    CupertinoNativeButton(
                      icon: CupertinoNativeIcon.symbol(
                        CupertinoSymbols.star,
                        size: 20,
                      ),
                      style: CupertinoNativeButtonStyle.glass,
                      borderShape: CupertinoNativeButtonBorderShape.circle,
                      labelStyle: CupertinoNativeButtonLabelStyle.iconOnly,
                      onPressed: () {},
                    ),
                  ),
                  _pair(
                    'Slider',
                    SizedBox(
                      width: 140,
                      child: CupertinoSlider(
                        value: _slider,
                        onChanged: (v) => setState(() => _slider = v),
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: CupertinoNativeSlider(
                        value: _slider,
                        onChanged: (v) => setState(() => _slider = v),
                      ),
                    ),
                  ),
                  _pair(
                    'Segmented',
                    SizedBox(
                      width: 140,
                      child: CupertinoSlidingSegmentedControl<int>(
                        groupValue: _segment,
                        onValueChanged: (v) =>
                            setState(() => _segment = v ?? 0),
                        children: const {0: Text('A'), 1: Text('B')},
                      ),
                    ),
                    SizedBox(
                      width: 140,
                      child: CupertinoNativeSegmentedControl(
                        children: const ['A', 'B'],
                        groupValue: _segment,
                        onChanged: (v) => setState(() => _segment = v),
                      ),
                    ),
                  ),
                  // A band between each set, so the blur has something with
                  // structure to work on and the tint has a colour to sit on.
                  const _Band(
                    label: 'Warm gradient',
                    colors: [Color(0xFFFF6B9D), Color(0xFFFFC371)],
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            child: CupertinoAppBar(
              title: 'Under the bar',
              leading: CupertinoNativeButton(
                icon: CupertinoNativeIcon.symbol(
                  CupertinoSymbols.chevronBackward,
                  size: 20,
                ),
                style: CupertinoNativeButtonStyle.glass,
                borderShape: CupertinoNativeButtonBorderShape.circle,
                labelStyle: CupertinoNativeButtonLabelStyle.iconOnly,
                onPressed: () => Navigator.pop(context),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// One row: the same control twice, Flutter on the left, native on the
  /// right, at the same height — so the difference under the bar is the only
  /// difference between them.
  Widget _pair(String label, Widget flutter, Widget native) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
    child: Row(
      children: [
        SizedBox(
          width: 90,
          child: Text(
            label,
            style: const TextStyle(
              fontSize: 13,
              decoration: TextDecoration.none,
              color: CupertinoColors.secondaryLabel,
            ),
          ),
        ),
        Expanded(child: Center(child: flutter)),
        Expanded(child: Center(child: native)),
      ],
    ),
  );
}

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
