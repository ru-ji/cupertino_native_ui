import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'edge_effect_coverage.dart';

/// Shared `MethodChannel` + intrinsic-size machinery for widgets that host a
/// native `UiKitView`. Every `CupertinoNative*` widget re-implemented this
/// identically; this mixin is the single copy.
///
/// Each widget still owns its own `_toMap()` (field set differs per widget),
/// its own `didUpdateWidget` diff (field list differs), and its own `build()`
/// (layout/fallback behavior differs per widget) - only the channel wiring
/// and intrinsic-size request/response plumbing is shared here.
mixin NativePlatformViewStateMixin<T extends StatefulWidget> on State<T> {
  MethodChannel? channel;
  double? intrinsicWidth;
  double? intrinsicHeight;

  /// Creates the method channel for this platform view instance and wires up
  /// [onMethodCall] to handle callbacks invoked from the native side.
  void setUpChannel(
    int id,
    String channelName, {
    Future<dynamic> Function(MethodCall call)? onMethodCall,
  }) {
    channel = MethodChannel(channelName);
    // Bar chrome does not dissolve into the bar's own edge effect: the
    // buttons are painted OVER it. The mask on the native side is geometric
    // and cannot tell a leading button from a row that has scrolled up to the
    // same place, so the widget tree — which knows — says so here.
    _edgeEffectViewId = id;
    if (CupertinoEdgeEffectExempt.of(context)) {
      CupertinoEdgeEffectCoverage.setExempt(id, true);
    }
    // Always handled here, whether or not the widget wants calls of its own:
    // `intrinsicSize` is pushed by the native view the moment its container
    // lays out, and every widget wants that.
    channel?.setMethodCallHandler((call) async {
      if (call.method == 'intrinsicSize') {
        _adoptIntrinsicSize(call.arguments as Map?);
        return null;
      }
      return onMethodCall?.call(call);
    });
  }

  /// Takes a size the native side measured, ignoring anything degenerate —
  /// a view that has not been laid out reports zero rather than a guess.
  void _adoptIntrinsicSize(Map? size) {
    final width = (size?['width'] as num?)?.toDouble();
    final height = (size?['height'] as num?)?.toDouble();
    if (width == null || height == null || width <= 0 || height <= 0) return;
    if (width == intrinsicWidth && height == intrinsicHeight) return;
    if (!mounted) return;
    setState(() {
      intrinsicWidth = width;
      intrinsicHeight = height;
    });
  }

  /// Asks the native view for its intrinsic content size and rebuilds with it
  /// once available. Safe to call before the channel is ready or after unmount.
  ///
  /// Only for the window this cannot cover: the native view publishes its size
  /// from its own layout pass, but a layout that happened before this channel
  /// existed published into nothing. A couple of attempts close that race.
  ///
  /// It used to be the whole mechanism, and it was twelve attempts spread over
  /// 1.2s — a dozen method calls per view because Dart had no way of knowing
  /// when SwiftUI had settled, and a view laid out late (during a route
  /// transition, inside a lazily-built list) could still finish past the last
  /// attempt and keep a wrong size for good. The view knows when it settles;
  /// asking it repeatedly was always the wrong way round.
  Future<void> requestIntrinsicSize({int attempts = 3}) async {
    for (var attempt = 0; attempt < attempts; attempt++) {
      if (!mounted || channel == null) return;
      try {
        final result = await channel!.invokeMethod<Map>('getIntrinsicSize');
        final w = (result?['width'] as num?)?.toDouble();
        final h = (result?['height'] as num?)?.toDouble();
        if (w != null && h != null && w > 0 && h > 0) {
          if (!mounted) return;
          setState(() {
            intrinsicWidth = w;
            intrinsicHeight = h;
          });
          return;
        }
      } catch (_) {
        // View may not be ready yet - ignore and try again.
      }
      await Future<void>.delayed(Duration(milliseconds: 16 * (attempt + 1)));
    }
  }

  /// The platform view id, kept so the edge-effect exemption can be dropped
  /// when this view goes away and the id is handed to the next one.
  int? _edgeEffectViewId;

  /// Releases the exemption this view claimed. Mixed into a `State`, so the
  /// widget's own `dispose` runs this by calling `super.dispose()`.
  @override
  void dispose() {
    final id = _edgeEffectViewId;
    if (id != null) CupertinoEdgeEffectCoverage.setExempt(id, false);
    super.dispose();
  }

  /// Sends updated config to the native view via [method].
  ///
  /// [refreshIntrinsicSize] is now only a safety net: a config change that
  /// resizes the control makes it lay out again, and that layout publishes the
  /// new size on its own.
  void updateNativeView(
    String method,
    Map<String, dynamic> args, {
    bool refreshIntrinsicSize = true,
  }) {
    final future = channel?.invokeMethod(method, args);
    if (refreshIntrinsicSize) {
      future?.then((_) => requestIntrinsicSize());
    }
  }
}
