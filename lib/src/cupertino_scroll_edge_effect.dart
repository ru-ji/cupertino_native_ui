import 'package:flutter/cupertino.dart'
    show CupertinoColors, CupertinoDynamicColor;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';

import 'cupertino_native_edge_blur.dart';
import 'cupertino_native_tab_bar.dart' show CupertinoScrollEdgeEffectStyle;

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
    this.color,
    this.intensity = 1,
    this.onBrightnessChanged,
  }) : assert(intensity >= 0 && intensity <= 1);

  final CupertinoScrollEdgeEffectEdge edge;

  /// `soft` is the progressive blur plus wash; `hard` an opaque background that
  /// ends with the bar. `automatic` is `soft`.
  final CupertinoScrollEdgeEffectStyle style;

  /// Background of the `hard` style. Defaults to the system background.
  final Color? color;

  /// Kept for API stability: the iOS effect is always at full strength.
  final double intensity;

  /// Called when the adaptive wash flips, with the brightness of the content
  /// behind it — so chrome drawn over the effect can follow, as the system's
  /// bar items do: dark over [Brightness.light], light over [Brightness.dark].
  /// iOS only.
  final ValueChanged<Brightness>? onBrightnessChanged;

  /// The system's blur radius.
  static const double _radius = 1;

  @override
  Widget build(BuildContext context) {
    final background = CupertinoDynamicColor.resolve(
      color ?? CupertinoColors.systemBackground,
      context,
    );
    // `hard` is not a denser fade, it is the absence of one: an opaque
    // background that stops with the bar.
    if (style == CupertinoScrollEdgeEffectStyle.hard) {
      return IgnorePointer(child: ColoredBox(color: background));
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      // No tint and no intensity: the system's white bright wash, always on.
      return CupertinoNativeEdgeBlur(
        edge: edge,
        sigma: _radius,
        adaptiveTint: true,
        onBrightnessChanged: onBrightnessChanged,
      );
    }
    // The native blur is iOS only; elsewhere there is no soft effect.
    return const SizedBox.shrink();
  }
}
