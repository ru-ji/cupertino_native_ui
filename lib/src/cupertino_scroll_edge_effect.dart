import 'package:flutter/cupertino.dart'
    show CupertinoColors, CupertinoDynamicColor;
import 'package:flutter/widgets.dart';
import 'package:haze/haze.dart';

import 'cupertino_native_tab_bar.dart' show CupertinoScrollEdgeEffectStyle;

/// Which screen edge a [CupertinoScrollEdgeEffect] hugs.
enum CupertinoScrollEdgeEffectEdge { top, bottom }

/// iOS 26's **scroll edge effect** — the progressive blur plus gradient scrim
/// that appears where content meets the screen edge — with the system's own
/// parameters filled in.
///
/// SwiftUI's effect is bound to native scroll views, so it can't be applied to
/// standalone bars hosted in Flutter. This is the [Haze] progressive blur
/// tuned to match it:
///
/// * **sigma 12** — Apple's bar materials use a 24pt blur radius (the values
///   in Apple's published iOS 18 Figma, transcribed by Haze-for-Compose's
///   `CupertinoMaterials`), and that blur takes sigma as `radius / 2`.
/// * **one plateau, shared** — wash and blur are both held constant over the
///   bar region and then released on a curve whose start and end are equally
///   undetectable. They used to disagree: the alpha sat flat while the radius
///   was already shedding under it, so the boundary the tint hid was the one
///   the blur drew.
/// * **tint** — the page background, white in light mode and black in dark,
///   so the edge melts into the page. The system derives this colour from the
///   content beneath the scroll view; pass [color] when the page sits on
///   something other than `systemBackground` (e.g. a grouped background).
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
  }) : assert(intensity >= 0 && intensity <= 1);

  final CupertinoScrollEdgeEffectEdge edge;

  /// `soft` is the progressive blur plus scrim. `hard` is the system's
  /// cut-off: an opaque background that ends with the bar, no blur and no
  /// fade — the way Flutter's own `AppBar` sits on a `Scaffold`. `automatic`
  /// is treated as `soft`, like the system default.
  final CupertinoScrollEdgeEffectStyle style;

  /// Tint override. Defaults to the resolved system background.
  final Color? color;

  /// Scales the whole effect, 0 (nothing) to 1 (full). Both the blur and the
  /// scrim ramp together — the system's effect is not always on, it comes up
  /// from zero as the header takes the content under it.
  final double intensity;

  /// Peak blur at the edge, in points.
  ///
  /// Measured, and it is small. Tracking hard band boundaries as they travel
  /// up through the system effect in a screen recording — the 10-90% rise of
  /// each edge against its depth, over four separate scroll passes:
  ///
  /// ```
  /// depth   100pt  90   84   69   54   33   20    9
  /// rise    0.3pt  2.1  3.0  3.7  4.0  4.0  4.3  4.0
  /// ```
  ///
  /// A Gaussian's 10-90 rise is 2.563 sigma, so the plateau's 4.0-4.5pt is
  /// sigma 1.6-1.8 — and the baseline confirms itself, an edge below the
  /// effect measuring 0.3pt, i.e. pixel-sharp. The recording is H.264, which
  /// softens edges, so 1.8 is an upper bound.
  ///
  /// The 24pt radius this used to cite is Apple's figure for the *bar
  /// material*, which is a different effect: a full-strength material behind a
  /// bar, not the variable blur that fades into a page. Carrying it over put
  /// the sigma about three times too high, which is what "our blur is stronger
  /// than the system's, side by side" was.
  static const double _sigma = 1.8;

  /// Holds the effect at full strength over the first sliver of the span
  /// before it starts to fade. This is what the first recreation lacked: its wash
  /// began decaying at the very first pixel, so covering the bar area at all meant being
  /// heavy everywhere — the grey band. Held, then released, it can be lighter
  /// overall and still read stronger where it matters. Kept short: the flat
  /// band reads as a boundary against the curve below it, and the taller the
  /// effect rect the more of a plain painted stripe a third of it becomes.
  ///
  /// After the plateau both descend on Haze's smootherstep, which dies with
  /// zero slope — the cosine it replaced still carried a readable radius at
  /// 90% of the span and dropped it over the last few points, splitting a
  /// list row into a blurred top half and a crisp bottom one.
  ///
  /// 0.35 is measured, not picked. Sampling a column of a screen recording of
  /// the system effect over a flat mid-grey band (inline title, 47pt inset):
  /// the wash is FLAT from 0 to 47pt, then falls to nothing at 133pt — so the
  /// plateau is 47/133 of the span, and it ends exactly where the status bar
  /// does. The falloff over what is left matches smootherstep to within a few
  /// percent at every sample, which is why [_falloff] is the bare 1.0. The
  /// span itself, 133pt against a bar ending at 91 (47 + 44), is what
  /// `_effectOverhang = 44` already encodes.
  ///
  /// One caveat: the recording only ever shows the inline bar, so whether the
  /// plateau is really 0.35 of the span or a fixed 47pt (the inset) is not
  /// decidable from it. The two agree here and diverge once a large title or
  /// a search row makes the span taller.
  static const double _plateau = 0.35;

  /// The blur's own plateau — LONGER than the scrim's, over a shorter span.
  ///
  /// From the same rise-against-depth table as [_sigma]: the blur holds full
  /// strength to about 55pt and is gone by 105, while the scrim holds to 47
  /// and runs to 133. So 55/133 = 0.41 here against 0.35 for the scrim, and
  /// the blur dying first falls out of Haze's `blurCurve` of 2 — at 105pt that
  /// leaves a sigma of 0.1pt, which is nothing.
  ///
  /// A blur's plateau cannot be read off a still the way a flat band of wash
  /// can; it took tracking edges across frames. Which is exactly why the two
  /// are separate knobs — inheriting the scrim's measurement was a guess
  /// wearing a measurement's clothes.
  static const double _blurPlateau = 0.41;

  /// 1 = the bare smootherstep. Raising it tightens the decay toward the
  /// plateau; the system's fade is the long, patient version.
  static const double _falloff = 1.0;

  /// Peak scale on the wash, at the edge.
  ///
  /// 1, because the alpha is no longer ours to pick: with
  /// [Haze.tintAdaptivity] at 1 the shader derives it from the backdrop, on
  /// the law measured off the system effect (see `haze.frag`). This only
  /// scales that result, and [intensity] is what actually moves it.
  ///
  /// The wash carries more of the effect than the blur does here, and
  /// deliberately: it is the half that reaches the native controls. A
  /// `BackdropFilter` cannot touch a platform view, so under the bar the wash
  /// is what makes a switch or a glass button recede — the blur only ever
  /// softens the Flutter content around them.
  static const double _tintOpacity = 1.0;

  /// Full adaptivity: the scrim covers a white page far less than a mid-grey
  /// one, which is the system's behaviour and cannot be had from a flat alpha
  /// — no single (colour, alpha) pair fits both measurements.
  static const double _tintAdaptivity = 1.0;

  @override
  Widget build(BuildContext context) {
    final tint = CupertinoDynamicColor.resolve(
      color ?? CupertinoColors.systemBackground,
      context,
    );
    // `hard` is not a denser fade, it is the absence of one: the system's hard
    // style cuts content off at the bar with a defined boundary — an opaque
    // background, the way Flutter's own `AppBar` sits on a `Scaffold`. No
    // blur, no falloff: an opaque box already covers whatever passes under
    // it.
    if (style == CupertinoScrollEdgeEffectStyle.hard) {
      return IgnorePointer(child: ColoredBox(color: tint));
    }
    // A backdrop filter only ever filters its own render target, and over a
    // platform view Flutter paints into an overlay surface the embedder clears
    // to transparent — so the blur below reaches every pixel of this page
    // EXCEPT the native controls, which would come back up crisp through it.
    // The answer is not here but in the bar that hosts this: it publishes its
    // own rectangle, and a control inside it is drawn from a bitmap instead of
    // being left to come back up crisp. See [BarSnapshotSurface].
    return IgnorePointer(
      child: Haze(
        edge: edge == CupertinoScrollEdgeEffectEdge.top
            ? HazeEdge.top
            : HazeEdge.bottom,
        sigma: _sigma * intensity,
        falloff: _falloff,
        plateau: _plateau,
        blurPlateau: _blurPlateau,
        tint: tint,
        tintOpacity: _tintOpacity * intensity,
        tintAdaptivity: _tintAdaptivity,
      ),
    );
  }
}
