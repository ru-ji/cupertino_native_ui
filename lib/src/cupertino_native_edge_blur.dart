import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/rendering.dart' show PlatformViewHitTestBehavior;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'cupertino_scroll_edge_effect.dart' show CupertinoScrollEdgeEffectEdge;
import 'internal/bar_holes.dart';
import 'internal/native_color.dart';

/// A progressive blur drawn by Core Animation, the way iOS 26's own scroll
/// edge effect draws it — and, with [adaptiveTint], its luminance-tracked wash.
/// [CupertinoScrollEdgeEffect] is built on it.
///
/// Paint it after the content it should blur and before the chrome on top of
/// it. The app must set `FLTDisablePartialRepaint` in its `Info.plist`: with
/// partial repaint, Flutter leaves the pixels under its own overlays uncleared,
/// and a stale copy of chrome drawn over this blur ghosts inside it.
///
/// Hold, smootherstep and a geometric radius ramp, with [sigma] fitted to the
/// height. iOS only: elsewhere it draws nothing.
class CupertinoNativeEdgeBlur extends StatefulWidget {
  const CupertinoNativeEdgeBlur({
    super.key,
    this.edge = CupertinoScrollEdgeEffectEdge.top,
    this.sigma = 12,
    this.tint,
    this.adaptiveTint = false,
    this.intensity = 1,
    this.radiusScale = 1,
    this.onBrightnessChanged,
    this.hard = false,
    this.debugPaintRect = false,
  }) : assert(sigma >= 0),
       assert(intensity >= 0 && intensity <= 1);

  final CupertinoScrollEdgeEffectEdge edge;

  /// Peak blur at [edge], logical px. Capped so the fade is at least 3 sigma wide.
  final double sigma;

  /// Without [adaptiveTint], the wash colour (its alpha is the peak opacity).
  /// With it, the colour of the bright wash; null for white.
  final Color? tint;

  /// The system's adaptive wash instead of a fixed [tint]: it follows the
  /// luminance of the content under the bar, on a 0.5s spring.
  final bool adaptiveTint;

  /// 0 (nothing) to 1 (full): scales the blur and the wash together.
  final double intensity;

  /// Calibration factor on the native radius.
  final double radiusScale;

  /// Called when the content under the effect turns bright or dark:
  /// [Brightness.light] over bright content (so chrome over it should be
  /// light glass with dark labels), [Brightness.dark] over darker content —
  /// the flip UIKit applies to its own bar items. Measured under the wash, so
  /// it works with a fixed [tint] too. Before the first measurement the app
  /// theme stands in.
  final ValueChanged<Brightness>? onBrightnessChanged;

  /// One even blur at [sigma] over the whole view, under a flat [tint] that
  /// ends in a hard line — the `.hard` scroll edge effect. No ramp, no
  /// adaptation, nothing cut out of it.
  final bool hard;

  /// Outlines the native view in red: geometry and z-order check.
  final bool debugPaintRect;

  @override
  State<CupertinoNativeEdgeBlur> createState() =>
      _CupertinoNativeEdgeBlurState();
}

class _CupertinoNativeEdgeBlurState extends State<CupertinoNativeEdgeBlur> {
  MethodChannel? _channel;
  Map<String, Object?>? _sent;

  /// What the view was created with — its first build's — and the latest.
  /// The tint can change before the view exists (the page under the effect
  /// is found after the first frame).
  Map<String, Object?>? _createdWith;
  Map<String, Object?>? _latest;

  /// A bar's native items, cut out of the wash so their glass sees the
  /// content under the bar (see [BarHoles]). Null outside a bar.
  BarHoles? _holes;

  RenderBox? _box() =>
      mounted ? context.findRenderObject() as RenderBox? : null;

  void _onHoles() {
    if (mounted) setState(() {});
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final holes = BarHolesScope.maybeOf(context);
    if (holes == _holes) return;
    _holes?.removeListener(_onHoles);
    _holes = holes
      ?..origin = _box
      ..addListener(_onHoles);
  }

  @override
  void dispose() {
    _holes?.removeListener(_onHoles);
    if (_holes?.origin == _box) _holes?.origin = null;
    super.dispose();
  }

  Map<String, Object?> _params(double span, bool isDark) => {
    'edge': widget.edge.name,
    'sigma': widget.hard
        ? widget.sigma
        : (span * (1 - 0.41) * 0.4 / 3).clamp(0.0, widget.sigma),
    'tint': nativeArgb(widget.tint, isDark: isDark),
    'adaptive': widget.adaptiveTint,
    'tracksLuma': widget.onBrightnessChanged != null,
    'intensity': widget.intensity,
    'radiusScale': widget.radiusScale,
    // The wash before the first luma measurement follows the app theme.
    'isDark': isDark,
    'debug': widget.debugPaintRect,
    // Replaced only when they change, so the identity check in [_push] holds.
    'holes': widget.hard ? const <double>[] : _holes?.rects ?? const <double>[],
    'hard': widget.hard,
  };

  void _push(Map<String, Object?> params) {
    final channel = _channel;
    if (channel == null || mapEquals(params, _sent)) return;
    _sent = params;
    channel.invokeMethod<void>('update', params);
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return const SizedBox.shrink();
    }
    // The app's brightness, not the device's — the plugin's other views follow
    // `Theme.of` too.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final params = _latest = _params(constraints.maxHeight, isDark);
          // Creation params are read once; later changes go over the channel.
          _push(params);
          return UiKitView(
            viewType:
                'com.example.cupertino_widgets/cupertino_native_edge_blur',
            layoutDirection: TextDirection.ltr,
            creationParams: _createdWith ??= params,
            creationParamsCodec: const StandardMessageCodec(),
            // Never takes a touch: everything under it stays operable.
            hitTestBehavior: PlatformViewHitTestBehavior.transparent,
            onPlatformViewCreated: (id) {
              _channel = MethodChannel('cupertino_widgets/edge_blur_$id')
                ..setMethodCallHandler((call) async {
                  if (call.method != 'lumaChanged') return;
                  final light = (call.arguments as Map?)?['light'] == true;
                  widget.onBrightnessChanged?.call(
                    light ? Brightness.light : Brightness.dark,
                  );
                });
              _sent = _createdWith;
              _push(_latest!);
            },
          );
        },
      ),
    );
  }
}
