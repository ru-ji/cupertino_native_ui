import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/rendering.dart' show PlatformViewHitTestBehavior;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'cupertino_scroll_edge_effect.dart' show CupertinoScrollEdgeEffectEdge;

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
    'sigma': (span * (1 - 0.41) * 0.4 / 3).clamp(0.0, widget.sigma),
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
      return const SizedBox.shrink();
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
