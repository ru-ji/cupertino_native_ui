import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Publishes a scroll edge effect's rectangle and strength to the native side,
/// so the SwiftUI views passing under it can melt away with it.
///
/// [CupertinoScrollEdgeEffect] is a `BackdropFilter`, and a backdrop filter
/// only ever filters its own render target. Painted over a platform view it
/// lands in an overlay surface the embedder clears to transparent each frame,
/// so it filters nothing: the blur reaches every pixel of the page except the
/// native controls, which would keep drawing crisp through the bar. Flutter
/// cannot sample a `UIView` — those pixels never exist inside its render
/// targets.
///
/// So the pixels move to where the shader is. The platform side answers this
/// rectangle by telling each control when it enters it; the control hands over
/// a bitmap of itself, the bar draws the covered band of it beneath the shader
/// (`BarSnapshotSurface`), and only then is the live view cut on the same
/// line. See `barSnapshots` for the whole path.
///
/// A no-op off iOS, and free when the effect is at zero strength.
///
/// The rectangles currently published, in global coordinates, keyed the same
/// way the platform side keys them. Read by `BarSnapshotSurface`, which must
/// bound what it draws by exactly what the platform side cuts on.
final Map<int, Rect> publishedEdgeRegions = {};

class CupertinoEdgeEffectCoverage extends StatefulWidget {
  /// Marks one platform view as sitting ABOVE the effect rather than passing
  /// under it, so the native mask skips it.
  ///
  /// The mask is geometric — it cannot tell a bar's leading button from a
  /// list row that has scrolled up behind that button — so the widget tree
  /// answers instead, through [CupertinoEdgeEffectExempt].
  static void setExempt(int viewId, bool exempt) {
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    _channel.invokeMethod<void>('setEdgeEffectExempt', {
      'viewId': viewId,
      'exempt': exempt,
    });
  }

  static const _channel = MethodChannel('com.example.cupertino_widgets/alert');

  const CupertinoEdgeEffectCoverage({
    super.key,
    required this.atTop,
    this.strength = 1,
    required this.child,
  });

  /// Which end of the region the effect is densest at.
  final bool atTop;

  /// How strongly the effect this covers is currently running, 0..1.
  ///
  /// At 0 nothing is published and nothing is cut. This is not an
  /// optimisation: a bar whose effect ramps up from zero — the collapsing app
  /// bar does, on the scroll that triggers the collapse — spends real time at
  /// zero with content already behind it, and cutting a control there
  /// replaces it with a bitmap while there is no effect to justify the
  /// swap. Any difference between the bitmap and the live view then shows as
  /// a bare patch. On a dark page the patch matches the page and nobody sees
  /// it; on a light one it is a white block.
  final double strength;

  final Widget child;

  @override
  State<CupertinoEdgeEffectCoverage> createState() =>
      _CupertinoEdgeEffectCoverageState();
}

class _CupertinoEdgeEffectCoverageState
    extends State<CupertinoEdgeEffectCoverage> {
  MethodChannel get _channel => CupertinoEdgeEffectCoverage._channel;

  /// Identifies this effect for as long as it lives; the native side keys its
  /// regions by it so two bars (a top one and a tab bar) do not overwrite
  /// each other.
  late final int _id = identityHashCode(this);

  /// Last payload sent, so a rebuild that moved nothing sends nothing. A
  /// pinned bar's rectangle is fixed while the page scrolls under it — the
  /// per-frame half of this job belongs to the native side, which is where
  /// the movement actually is.
  Map<String, dynamic>? _sent;

  bool get _enabled => !kIsWeb && defaultTargetPlatform == TargetPlatform.iOS;

  @override
  void initState() {
    super.initState();
    if (_enabled) _scheduleReport();
  }

  @override
  void didUpdateWidget(covariant CupertinoEdgeEffectCoverage old) {
    super.didUpdateWidget(old);
    if (_enabled) _scheduleReport();
  }

  @override
  void dispose() {
    if (_enabled && _sent != null) _push(null);
    super.dispose();
  }

  /// After layout, not during it: the rectangle is read off the render object,
  /// which has no geometry until the frame it is laid out in.
  void _scheduleReport() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _report();
    });
  }

  void _report() {
    if (widget.strength <= 0) {
      if (_sent != null) _push(null);
      return;
    }
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || box.size.isEmpty) return;
    final origin = box.localToGlobal(Offset.zero);
    // Snapped to a whole device pixel before it is published, because this
    // number becomes a line in two different rasterisers — a `CALayer` mask
    // frame over there, a canvas clip over here. Rounded independently they
    // land on either side of the same pixel, and that pixel is a hairline that
    // flickers with the scroll. Rounded once, here, they cannot disagree.
    final dpr = MediaQuery.devicePixelRatioOf(context);
    double snap(double v) => (v * dpr).roundToDouble() / dpr;
    final region = <String, dynamic>{
      'left': snap(origin.dx),
      'top': snap(origin.dy),
      'width': snap(box.size.width),
      'height': snap(box.size.height),
      'atTop': widget.atTop,
    };
    if (mapEquals(region, _sent)) return;
    _push(region);
  }

  void _push(Map<String, dynamic>? region) {
    _sent = region;
    // The same rectangle the platform side cuts on, kept for the surface that
    // draws the bitmaps. Both halves of that illusion have to be bounded by
    // ONE number; computing it twice — here and again from the bar's layout —
    // is how a band of bare background ends up straight across a control.
    if (region == null) {
      publishedEdgeRegions.remove(_id);
    } else {
      publishedEdgeRegions[_id] = Rect.fromLTWH(
        region['left'] as double,
        region['top'] as double,
        region['width'] as double,
        region['height'] as double,
      );
    }
    _channel.invokeMethod<void>('setEdgeEffectRegion', {
      'id': _id,
      'region': region,
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

/// Marks a subtree as bar chrome: everything native inside it is painted over
/// the scroll edge effect, not under it, so it must not dissolve into it.
///
/// The leading and trailing buttons of an app bar are the case this exists
/// for. They sit inside the effect's rectangle — that is the whole point of a
/// bar — while the content that has to melt away is at the same coordinates
/// one layer down. Only the widget tree can tell the two apart.
class CupertinoEdgeEffectExempt extends InheritedWidget {
  const CupertinoEdgeEffectExempt({super.key, required super.child});

  static bool of(BuildContext context) =>
      context.getInheritedWidgetOfExactType<CupertinoEdgeEffectExempt>() !=
      null;

  @override
  bool updateShouldNotify(covariant CupertinoEdgeEffectExempt oldWidget) =>
      false;
}
