import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/rendering.dart' show PlatformViewHitTestBehavior;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:haze/haze.dart';

import 'cupertino_scroll_edge_effect.dart' show CupertinoScrollEdgeEffectEdge;

/// A progressive blur drawn by Core Animation, the way iOS 26's own scroll
/// edge effect draws it — and, with [adaptiveTint], its luminance-tracked wash.
/// [CupertinoScrollEdgeEffect] is built on it.
///
/// A Flutter backdrop filter only filters Flutter's own render target, and the
/// iOS embedder forwards nothing but uniform blurs to platform views. This is
/// a platform view itself: composited after everything painted before it, so
/// its backdrop is the Flutter surface AND the native views under it, live.
/// See `NativeEdgeBlurView.swift` for how it is built and why.
///
/// Paint it after the content it should blur and before the chrome on top of
/// it. The app must set `FLTDisablePartialRepaint` in its `Info.plist`: with
/// partial repaint, Flutter leaves the pixels under its own overlays uncleared,
/// and a stale copy of chrome drawn over this blur ghosts inside it.
///
/// Same curves as [Haze] (hold, smootherstep, geometric radius ramp), same
/// automatic fit of [sigma] to the height. Off iOS it falls back to [Haze].
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
    this.debugPaintRect = false,
  }) : assert(sigma >= 0),
       assert(intensity >= 0 && intensity <= 1);

  final CupertinoScrollEdgeEffectEdge edge;

  /// Peak blur at [edge], logical px. Fitted to the height like [Haze.sigma].
  final double sigma;

  /// Without [adaptiveTint], the wash colour; its alpha is the peak opacity at
  /// [edge]. With it, the colour of the bright wash — the page background —
  /// whose peak is the system's. Null for no fixed wash / a white bright one.
  final Color? tint;

  /// The system's adaptive wash instead of a fixed [tint]: the render server
  /// measures the luminance of what is under the bar, and the wash settles on
  /// one of three levels — the bright one over near-white content, a light
  /// dark one over mid content, a deeper one over dark content — cross-fading
  /// on a 0.5s critically damped spring, the timing measured off iOS 26's own
  /// effect.
  final bool adaptiveTint;

  /// 0 (nothing) to 1 (full): scales the blur and the wash together.
  final double intensity;

  /// Calibration factor on the native radius.
  final double radiusScale;

  /// With [adaptiveTint], called when the wash flips: [Brightness.light] over
  /// bright content (so chrome over it should be dark), [Brightness.dark] over
  /// darker content (light chrome) — the flip UIKit applies to its own bar
  /// items. Before the first measurement the app theme stands in.
  final ValueChanged<Brightness>? onBrightnessChanged;

  /// Outlines the native view in red: geometry and z-order check.
  final bool debugPaintRect;

  @override
  State<CupertinoNativeEdgeBlur> createState() =>
      _CupertinoNativeEdgeBlurState();
}

class _CupertinoNativeEdgeBlurState extends State<CupertinoNativeEdgeBlur> {
  MethodChannel? _channel;
  Map<String, Object?>? _sent;

  Map<String, Object?> _params(double span, bool isDark) => {
    'edge': widget.edge.name,
    'sigma': Haze.fitSigma(span, widget.sigma),
    'tint': widget.tint?.toARGB32(),
    'adaptive': widget.adaptiveTint,
    'intensity': widget.intensity,
    'radiusScale': widget.radiusScale,
    // The wash before the first luma measurement follows the app theme.
    'isDark': isDark,
    'debug': widget.debugPaintRect,
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
      return Haze(
        edge: widget.edge == CupertinoScrollEdgeEffectEdge.top
            ? HazeEdge.top
            : HazeEdge.bottom,
        sigma: widget.sigma * widget.intensity,
        tint: widget.tint,
      );
    }
    // The app's brightness, not the device's — the plugin's other views follow
    // `Theme.of` too.
    final isDark = Theme.of(context).brightness == Brightness.dark;
    return IgnorePointer(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final params = _params(constraints.maxHeight, isDark);
          // Creation params are read once; later changes go over the channel.
          _push(params);
          return UiKitView(
            viewType:
                'com.example.cupertino_widgets/cupertino_native_edge_blur',
            layoutDirection: TextDirection.ltr,
            creationParams: params,
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
              _sent = params;
            },
          );
        },
      ),
    );
  }
}
