import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Theme;
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
              title: 'Native variable blur',
              subtitle: 'Core Animation blur over native controls',
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => const _NativeBlurProbe(),
                  title: 'Back',
                ),
              ),
            ),
            SettingsRow(
              title: 'Native blur over the bands',
              subtitle: 'The system page, recreated: record both',
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => const _NativeBandsProbe(),
                  title: 'Back',
                ),
              ),
            ),
            SettingsRow(
              title: 'Adaptive wash over the bands',
              subtitle: 'Opens straight in Native adaptive',
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => const _NativeBandsProbe(initialMode: 1),
                  title: 'Back',
                ),
              ),
            ),
            SettingsRow(
              title: 'Haze vs native',
              subtitle: 'Side by side, to calibrate the native radius',
              onTap: () => Navigator.of(context).push(
                CupertinoPageRoute<void>(
                  builder: (_) => const _HazeVsNativeProbe(),
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

/// Core Animation's `variableBlur`, hosted as a platform view over native and
/// Flutter controls: the candidate for blurring native views LIVE, glass
/// included, with no snapshot.
///
/// Same stack as [_LayerIsolationProbe]: content, then the effect, then the
/// bar row on top. Nothing here publishes an edge region, so no native
/// control is photographed or cut — whatever blurs is the live view.
///
/// Tap the title to cycle, same sigma and tint in every mode:
///
/// * **Native blur** — the Core Animation blur alone. The right column
///   (native) should soften exactly like the left one (Flutter).
/// * **Native + tint** — with Haze's wash on top, same colour and curve.
/// * **Haze** — the Flutter shader, for comparison: its right column comes
///   back crisp, since a shader filter cannot reach a platform view.
class _NativeBlurProbe extends StatefulWidget {
  const _NativeBlurProbe();

  @override
  State<_NativeBlurProbe> createState() => _NativeBlurProbeState();
}

class _NativeBlurProbeState extends State<_NativeBlurProbe> {
  static const _modes = ['Native blur', 'Native + tint', 'Haze'];
  // Apple's own: the system PocketBlur's variableBlur has inputRadius 1.
  static const double _sigma = 1;
  int _mode = 0;
  bool _switchValue = true;
  double _slider = 0.4;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final tint = CupertinoDynamicColor.resolve(
      CupertinoColors.systemBackground,
      context,
    ).withValues(alpha: .55);
    return CupertinoPageScaffold(
      child: Stack(
        children: [
          Positioned.fill(
            child: ListView(
              padding: EdgeInsets.only(
                top: padding.top + 44 + 24,
                bottom: padding.bottom + 80,
              ),
              children: [
                for (var i = 0; i < 4; i++) ...[
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
                    'Prominent',
                    Container(
                      height: 34,
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: CupertinoColors.activeBlue,
                        borderRadius: BorderRadius.circular(17),
                      ),
                      child: const Text(
                        'Flutter',
                        style: TextStyle(
                          fontSize: 15,
                          decoration: TextDecoration.none,
                          color: CupertinoColors.white,
                        ),
                      ),
                    ),
                    CupertinoNativeButton(
                      title: 'Native',
                      style: CupertinoNativeButtonStyle.glassProminent,
                      borderShape: CupertinoNativeButtonBorderShape.capsule,
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
                  // Structure for the blur to work on, colour for the tint.
                  const _Band(
                    label: 'Warm gradient',
                    colors: [Color(0xFFFF6B9D), Color(0xFFFFC371)],
                  ),
                ],
              ],
            ),
          ),
          // After the content, so a native effect composites above every
          // control it should blur; before the bar row, so the bar stays
          // sharp on top of it.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: padding.top + 44 + 110,
            child: switch (_mode) {
              0 => const CupertinoNativeEdgeBlur(sigma: _sigma),
              1 => CupertinoNativeEdgeBlur(sigma: _sigma, tint: tint),
              _ => IgnorePointer(
                child: Haze(sigma: _sigma, tint: tint),
              ),
            },
          ),
          Positioned(
            top: padding.top,
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
                      color: CupertinoColors.label,
                    ),
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// The system page's bands — the ones "Native (SwiftUI ScrollView)" scrolls —
/// under Core Animation's blur and Haze's wash, so the two screens can
/// be recorded back to back and compared frame by frame.
///
/// The effect rectangle is the system's own: status bar, 44pt bar, 44pt
/// overhang. Every other band carries a native switch and a glass button, so
/// native views pass under the effect too.
///
/// Tap the title to cycle: native with Haze's wash, native blur alone,
/// and Haze for comparison — same sigma throughout.
class _NativeBandsProbe extends StatefulWidget {
  const _NativeBandsProbe({this.initialMode = 0});

  /// Index into the modes, so a mode can be opened without tapping the
  /// title — a tap over the native effect may never reach Flutter.
  final int initialMode;

  @override
  State<_NativeBandsProbe> createState() => _NativeBandsProbeState();
}

class _NativeBandsProbeState extends State<_NativeBandsProbe> {
  static const _modes = [
    'Native + tint',
    'Native adaptive',
    'Native blur',
    'Haze',
  ];
  // Apple's own: the system PocketBlur's variableBlur has inputRadius 1.
  static const double _sigma = 1;
  late int _mode = widget.initialMode;

  /// What the adaptive wash reports behind the bar; the title follows it.
  /// Null until the first measurement: the app theme stands in, as it does
  /// for the wash itself.
  Brightness? _behind;
  bool _switchValue = true;

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final tint = CupertinoDynamicColor.resolve(
      CupertinoColors.systemBackground,
      context,
    ).withValues(alpha: .55);
    const bands = EdgeEffectProbeBody._bands;
    return CupertinoPageScaffold(
      child: Stack(
        children: [
          Positioned.fill(
            child: SingleChildScrollView(
              child: Column(
                children: [
                  SizedBox(height: padding.top + 44),
                  for (var i = 0; i < bands.length; i++)
                    Stack(
                      children: [
                        _Band(label: bands[i].$1, colors: bands[i].$2),
                        if (i.isOdd)
                          Positioned(
                            top: 16,
                            right: 16,
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                CupertinoNativeSwitch(
                                  value: _switchValue,
                                  onChanged: (v) =>
                                      setState(() => _switchValue = v),
                                ),
                                const SizedBox(width: 12),
                                CupertinoNativeButton(
                                  icon: CupertinoNativeIcon.symbol(
                                    CupertinoSymbols.star,
                                    size: 20,
                                  ),
                                  style: CupertinoNativeButtonStyle.glass,
                                  borderShape:
                                      CupertinoNativeButtonBorderShape.circle,
                                  labelStyle:
                                      CupertinoNativeButtonLabelStyle.iconOnly,
                                  onPressed: () {},
                                ),
                              ],
                            ),
                          ),
                      ],
                    ),
                  SizedBox(height: padding.bottom + 80),
                ],
              ),
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height: padding.top + 44 + 44,
            child: switch (_mode) {
              0 => CupertinoNativeEdgeBlur(sigma: _sigma, tint: tint),
              // The system's luma-tracked light/dark wash (see LumaTracker).
              1 => CupertinoNativeEdgeBlur(
                sigma: _sigma,
                adaptiveTint: true,
                onBrightnessChanged: (b) => setState(() => _behind = b),
              ),
              2 => const CupertinoNativeEdgeBlur(sigma: _sigma),
              _ => IgnorePointer(
                child: Haze(sigma: _sigma, tint: tint),
              ),
            },
          ),
          Positioned(
            top: padding.top,
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
                  // White over the dark wash, like the system's bar items;
                  // the same ~0.5s as the wash's own flip.
                  child: AnimatedDefaultTextStyle(
                    duration: const Duration(milliseconds: 500),
                    curve: Curves.easeOutCubic,
                    style: TextStyle(
                      fontSize: 17,
                      fontWeight: FontWeight.w600,
                      decoration: TextDecoration.none,
                      color:
                          _mode == 1 &&
                              (_behind ?? Theme.of(context).brightness) ==
                                  Brightness.dark
                          ? CupertinoColors.white
                          : CupertinoColors.black,
                    ),
                    child: Text(_modes[_mode]),
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 60),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Haze on the left half, the native blur on the right, over the same
/// content with the same sigma and tint — to make the two match by eye.
///
/// Tap the title to cycle the native radius scale. Core Animation's
/// `inputRadius` is not documented to be a Gaussian sigma, so the factor under
/// which the right half looks like the left one IS the calibration.
///
/// The "Haze" and "Native" labels are Flutter text painted over each effect.
/// A dark ghost of the label on the native side only would mean its backdrop
/// captures Flutter content drawn above it.
class _HazeVsNativeProbe extends StatefulWidget {
  const _HazeVsNativeProbe();

  @override
  State<_HazeVsNativeProbe> createState() => _HazeVsNativeProbeState();
}

class _HazeVsNativeProbeState extends State<_HazeVsNativeProbe> {
  static const _scales = [1.0, 0.75, 0.5, 0.35, 0.25];
  // Apple's own: the system PocketBlur's variableBlur has inputRadius 1.
  static const double _sigma = 1;
  int _scale = 0;

  static const _text = TextStyle(
    fontSize: 13,
    decoration: TextDecoration.none,
    color: CupertinoColors.label,
  );
  static const _labelStyle = TextStyle(
    fontSize: 17,
    fontWeight: FontWeight.w600,
    decoration: TextDecoration.none,
    color: CupertinoColors.label,
  );

  @override
  Widget build(BuildContext context) {
    final padding = MediaQuery.paddingOf(context);
    final half = MediaQuery.sizeOf(context).width / 2;
    final effectHeight = padding.top + 44 + 44;
    final tint = CupertinoDynamicColor.resolve(
      CupertinoColors.systemBackground,
      context,
    ).withValues(alpha: .55);
    const bands = EdgeEffectProbeBody._bands;
    return CupertinoPageScaffold(
      child: Stack(
        children: [
          Positioned.fill(
            child: ListView(
              padding: EdgeInsets.only(
                top: padding.top + 44,
                bottom: padding.bottom + 80,
              ),
              children: [
                for (final (label, colors) in bands) ...[
                  Row(
                    children: [
                      for (var side = 0; side < 2; side++)
                        Expanded(
                          child: _Band(label: label, colors: colors),
                        ),
                    ],
                  ),
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 10),
                    child: Row(
                      children: [
                        for (var side = 0; side < 2; side++)
                          const Expanded(
                            child: Padding(
                              padding: EdgeInsets.symmetric(horizontal: 12),
                              child: Text(
                                'The quick brown fox jumps over the lazy '
                                'dog. 0123456789',
                                style: _text,
                              ),
                            ),
                          ),
                      ],
                    ),
                  ),
                ],
              ],
            ),
          ),
          Positioned(
            top: 0,
            left: 0,
            width: half,
            height: effectHeight,
            child: IgnorePointer(
              child: Haze(sigma: _sigma, tint: tint),
            ),
          ),
          Positioned(
            top: 0,
            right: 0,
            width: half,
            height: effectHeight,
            child: CupertinoNativeEdgeBlur(
              sigma: _sigma,
              tint: tint,
              radiusScale: _scales[_scale],
            ),
          ),
          // Flutter text over each effect: the capture test.
          Positioned(
            top: padding.top + 50,
            left: 0,
            width: half,
            child: const Center(child: Text('Haze', style: _labelStyle)),
          ),
          Positioned(
            top: padding.top + 50,
            right: 0,
            width: half,
            child: const Center(child: Text('Native', style: _labelStyle)),
          ),
          Positioned(
            top: padding.top,
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
                      setState(() => _scale = (_scale + 1) % _scales.length),
                  child: Text(
                    'Native radius ×${_scales[_scale]}',
                    style: _labelStyle,
                  ),
                ),
                const Spacer(),
                const SizedBox(width: 60),
              ],
            ),
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
                tint: tint
                    ? CupertinoDynamicColor.resolve(
                        CupertinoColors.systemBackground,
                        context,
                      ).withValues(alpha: .55)
                    : null,
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
/// Native controls passing under the bar's effect, next to their Flutter
/// counterparts, so the two behaviours are visible in the same scroll.
///
/// The effect is a native blur composited above the page, so both columns
/// should soften identically as they scroll under the bar — the native ones
/// live, glass included — and the bar's own back button, painted over the
/// effect, stays sharp at any scroll position.
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
