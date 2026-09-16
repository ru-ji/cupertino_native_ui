import 'package:flutter/cupertino.dart' show CupertinoColors;
import 'package:flutter/widgets.dart';
import 'package:cupertino_widgets/cupertino_widgets.dart';

import '../widgets/settings_ui.dart';

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
    return DemoScaffold(
      title: 'Liquid Glass',
      children: [
        const SizedBox(height: 20),
        Container(
          height: 400,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(kCardCornerRadius),
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
              // Two glass buttons merged into one capsule, like a toolbar group.
              Positioned(
                top: 20,
                left: 20,
                child: CupertinoNativeGlassGroup(
                  spacing: 0,
                  tint: _tint,
                  clear: _clear,
                  interactive: _interactive,
                  onAction: (_) {},
                  items: [
                    CupertinoNativeGlassGroupItem(
                      actionId: 'undo',
                      icon: CupertinoNativeIcon.named('arrow.uturn.backward'),
                    ),
                    CupertinoNativeGlassGroupItem(
                      actionId: 'redo',
                      icon: CupertinoNativeIcon.named('arrow.uturn.forward'),
                    ),
                  ],
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
                  icon: CupertinoNativeIcon.symbol(CupertinoSymbols.paintbrush),
                  onPressed: () => setState(
                    () => _tintIndex = (_tintIndex + 1) % _tints.length,
                  ),
                ),
              ),
            ],
          ),
        ),
        SettingsSection(
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
            SettingsRow(
              title: 'Interactive',
              subtitle: 'Shimmer on touch',
              trailing: CupertinoNativeSwitch(
                value: _interactive,
                onChanged: (v) => setState(() => _interactive = v),
              ),
            ),
            SettingsRow(
              title: 'Clear variant',
              subtitle: 'More transparent glass',
              trailing: CupertinoNativeSwitch(
                value: _clear,
                onChanged: (v) => setState(() => _clear = v),
              ),
            ),
            SettingsRow(
              title: 'Tint',
              trailing: CupertinoNativeSlidingSegmentedControl<int>.menu(
                children: {
                  for (final (i, label) in _tints.indexed) i: Text(label),
                },
                groupValue: _tintIndex,
                onValueChanged: (v) => setState(() => _tintIndex = v!),
              ),
            ),
          ],
        ),
      ],
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
