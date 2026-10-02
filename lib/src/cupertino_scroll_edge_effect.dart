import 'package:flutter/cupertino.dart'
    show CupertinoDynamicColor, CupertinoPageScaffold, CupertinoTheme;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Scaffold, Theme;
import 'package:flutter/widgets.dart';

import 'cupertino_native_edge_blur.dart';

/// iOS 26 Liquid Glass scroll-edge-effect style. Used both by the standalone
/// `CupertinoNativeTabBar` (mapped to the bar's background material) and by
/// `CupertinoNativePageScaffold`'s native scroll views. No effect below iOS 26.
enum CupertinoScrollEdgeEffectStyle { automatic, soft, hard }

/// Which screen edge a [CupertinoScrollEdgeEffect] hugs.
enum CupertinoScrollEdgeEffectEdge { top, bottom }

/// iOS 26's **scroll edge effect** — the progressive blur plus adaptive wash
/// where content meets a screen edge.
///
/// Built on [CupertinoNativeEdgeBlur], it samples native controls as well as
/// Flutter content. The app must set `FLTDisablePartialRepaint` in its
/// `Info.plist`. Other platforms draw nothing for `soft`.
///
/// Place it in a `Stack` behind a bar, sized to the region that should melt
/// into the edge:
///
/// ```dart
/// Stack(children: [
///   Positioned(top: 0, left: 0, right: 0, height: 120,
///     child: CupertinoScrollEdgeEffect(edge: CupertinoScrollEdgeEffectEdge.top)),
///   ...bar content...
/// ])
/// ```
class CupertinoScrollEdgeEffect extends StatelessWidget {
  const CupertinoScrollEdgeEffect({
    super.key,
    this.edge = CupertinoScrollEdgeEffectEdge.top,
    this.style = CupertinoScrollEdgeEffectStyle.soft,
    @Deprecated(
      'The effect takes the page background, as the system\'s does; it '
      'cannot be tinted on its own.',
    )
    this.color,
    this.intensity = 1,
    this.onBrightnessChanged,
  }) : assert(intensity >= 0 && intensity <= 1);

  final CupertinoScrollEdgeEffectEdge edge;

  /// `soft` is the progressive blur plus wash; `hard` the page's background
  /// over a blur, ending in a hard cutoff. `automatic` is `soft`.
  final CupertinoScrollEdgeEffectStyle style;

  /// Ignored. Both styles take the page's background — the nearest
  /// [CupertinoPageScaffold]'s or [Scaffold]'s, else the theme's — as the
  /// system's do, and offer no tint of their own.
  final Color? color;

  /// Kept for API stability: the iOS effect is always at full strength.
  final double intensity;

  /// Called when the adaptive wash flips, with the brightness of the content
  /// behind it — so chrome drawn over the effect can follow, as the system's
  /// bar items do: dark over [Brightness.light], light over [Brightness.dark].
  /// iOS only.
  final ValueChanged<Brightness>? onBrightnessChanged;

  /// The `.hard` wash: the page's colour at 91%, measured on iOS 26 over a
  /// green page. Without a blur under it.
  static const double _hardOpacity = 0.91;

  /// The page's background: the nearest scaffold's, Cupertino or Material,
  /// else its theme's.
  static Color _pageBackground(BuildContext context) {
    Color? color;
    var material = false;
    context.visitAncestorElements((element) {
      switch (element.widget) {
        case CupertinoPageScaffold(:final backgroundColor):
          color = backgroundColor;
          return false;
        case Scaffold(:final backgroundColor):
          color = backgroundColor;
          material = true;
          return false;
      }
      return true;
    });
    return CupertinoDynamicColor.resolve(
      color ??
          (material
              ? Theme.of(context).scaffoldBackgroundColor
              : CupertinoTheme.of(context).scaffoldBackgroundColor),
      context,
    );
  }

  @override
  Widget build(BuildContext context) {
    final background = _pageBackground(context);
    // `hard` is not a denser fade, it is the absence of one: one flat wash
    // that stops at a hard line.
    if (style == CupertinoScrollEdgeEffectStyle.hard) {
      return IgnorePointer(
        child: ColoredBox(color: background.withValues(alpha: _hardOpacity)),
      );
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      // No intensity: always on. No blur either: the wash alone. The bright
      // wash is the page's background, as the system's (grey on a grouped
      // page); the dark one stays black.
      return CupertinoNativeEdgeBlur(
        edge: edge,
        sigma: 0,
        adaptiveTint: true,
        tint: background,
        onBrightnessChanged: onBrightnessChanged,
      );
    }
    // The native blur is iOS only; elsewhere there is no soft effect.
    return const SizedBox.shrink();
  }
}
