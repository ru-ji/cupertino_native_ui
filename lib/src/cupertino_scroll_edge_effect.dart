import 'package:flutter/cupertino.dart'
    show CupertinoColors, CupertinoDynamicColor;
import 'package:flutter/foundation.dart';
import 'package:flutter/widgets.dart';
import 'package:haze/haze.dart';

import 'cupertino_native_edge_blur.dart';
import 'cupertino_native_tab_bar.dart' show CupertinoScrollEdgeEffectStyle;

/// Which screen edge a [CupertinoScrollEdgeEffect] hugs.
enum CupertinoScrollEdgeEffectEdge { top, bottom }

/// iOS 26's **scroll edge effect** — the progressive blur plus adaptive wash
/// where content meets a screen edge.
///
/// On iOS it is a [CupertinoNativeEdgeBlur] rebuilt from the layers of the
/// system's own `ScrollEdgeEffectView`, read off a device:
///
/// * **blur** — Core Animation's `variableBlur`, at the radius the system's
///   `PocketBlur` uses (1pt), fading on Haze's curve;
/// * **wash** — the luminance of what is under the bar, measured by the render
///   server exactly where the system measures it (the 44pt bar below the status
///   bar), settling on one of three levels — white 85% over near-white
///   content, black 27% over mid content, black 47% over dark content — on the
///   system's 0.5s critically damped spring.
///
/// It samples native controls as well as Flutter content, live: nothing is
/// photographed, nothing is cut. The app must set `FLTDisablePartialRepaint`
/// to true in its `Info.plist` — see [CupertinoNativeEdgeBlur].
///
/// Everywhere else it falls back to [Haze] with the system's measured
/// parameters and a fixed wash.
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

  /// `soft` is the progressive blur plus wash. `hard` is the system's
  /// cut-off: an opaque background that ends with the bar, no blur and no
  /// fade — the way Flutter's own `AppBar` sits on a `Scaffold`. `automatic`
  /// is treated as `soft`, like the system default.
  final CupertinoScrollEdgeEffectStyle style;

  /// The page background: the colour of the bright wash on iOS, and of the
  /// fixed wash elsewhere. Defaults to the resolved system background — pass
  /// your page background when it differs (e.g. a grouped background).
  final Color? color;

  /// Scales the whole effect, 0 (nothing) to 1 (full). The system's effect is
  /// not always on: it comes up from zero as the header takes the content
  /// under it.
  final double intensity;

  /// Called when the adaptive wash flips, with the brightness of the content
  /// behind it — so chrome drawn over the effect can follow, as the system's
  /// bar items do: dark over [Brightness.light], light over [Brightness.dark].
  /// iOS only.
  final ValueChanged<Brightness>? onBrightnessChanged;

  /// The system's `PocketBlur` radius, read off a device (`variableBlur`
  /// `inputRadius`).
  static const double _radius = 1;

  /// Off iOS: the blur measured off screen recordings of the system effect
  /// (edge rise against depth, 10-90% of a Gaussian is 2.563 sigma), and one
  /// fixed wash standing in for the adaptive one.
  static const double _hazeSigma = 1.8;
  static const double _hazeTintAlpha = 0.6;

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
      // Exactly the "Adaptive wash over the bands" probe: no tint, no
      // intensity — always on, white bright wash.
      return CupertinoNativeEdgeBlur(
        edge: edge,
        sigma: _radius,
        adaptiveTint: true,
        onBrightnessChanged: onBrightnessChanged,
      );
    }
    return IgnorePointer(
      child: Haze(
        edge: edge == CupertinoScrollEdgeEffectEdge.top
            ? HazeEdge.top
            : HazeEdge.bottom,
        sigma: _hazeSigma * intensity,
        tint: background.withValues(
          alpha: background.a * _hazeTintAlpha * intensity,
        ),
      ),
    );
  }
}
