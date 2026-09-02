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
/// native controls, which keep drawing crisp through the bar. Flutter cannot
/// sample a `UIView` — those pixels never exist inside its render targets —
/// so the control has to do its own half, and to do that it needs to know
/// where the effect is.
///
/// This is the same division of labour as [CupertinoSearchRowVisibility]:
/// `Opacity` cannot fade a platform view either, so the native field is told
/// the number and fades itself.
///
/// A no-op off iOS, and free when the effect is at zero strength.
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
    required this.intensity,
    required this.plateau,
    required this.child,
  });

  /// Which end of the region the effect is densest at.
  final bool atTop;

  /// 0 (nothing) to 1 (full), as published by the effect itself.
  final double intensity;

  /// Fraction of the span held at full strength before the fade begins — the
  /// native ramp has to match the Flutter one or the two halves of the same
  /// effect disagree about where the content should be gone.
  final double plateau;

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
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || box.size.isEmpty) return;
    final origin = box.localToGlobal(Offset.zero);
    final region = <String, dynamic>{
      'left': origin.dx,
      'top': origin.dy,
      'width': box.size.width,
      'height': box.size.height,
      'atTop': widget.atTop,
      'intensity': widget.intensity,
      'plateau': widget.plateau,
    };
    if (mapEquals(region, _sent)) return;
    _push(region);
  }

  void _push(Map<String, dynamic>? region) {
    _sent = region;
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
