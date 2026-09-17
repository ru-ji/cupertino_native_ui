import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'native_view_capture.dart';

/// Shared `MethodChannel` and intrinsic-size plumbing for widgets hosting a
/// native `UiKitView`.
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
    // A ready photo for route transitions, taken before one starts.
    if (hidesDuringRouteTransition) _keepBitmapFresh();
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
  /// The native view also pushes its size after each layout; a few attempts
  /// cover a layout that happened before the channel existed.
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

  /// Keeps an up-to-date bitmap of this control on hand, for the route
  /// transition that swaps it in (see [wrapForTransition]).
  ///
  /// Taken as soon as the view can be photographed — a view that has never
  /// rendered refuses, so it retries every 100ms until the first success —
  /// then retaken only when the control itself changes.
  void _keepBitmapFresh() {
    if (_warmImage != null) return;
    _captureTimer ??= Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _refreshWarmBitmap(),
    );
    _refreshWarmBitmap();
  }

  /// Takes the bitmap. A refusal is not an error — the view has simply not
  /// rendered yet, and [_keepBitmapFresh] asks again.
  Future<void> _refreshWarmBitmap() async {
    final channel = this.channel;
    if (channel == null || !mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || box.size.isEmpty) {
      return;
    }
    (ui.Image, Rect)? capture;
    try {
      capture = await captureNativeView(channel);
    } on MissingPluginException {
      // No `snapshot` handler for this view type: stop retrying.
      _captureTimer?.cancel();
      _captureTimer = null;
      return;
    } catch (_) {
      return;
    }
    if (capture == null) return;
    if (!mounted) {
      capture.$1.dispose();
      return;
    }
    _captureTimer?.cancel();
    _captureTimer = null;
    // Kept on hand so a route transition can swap it in on its first frame,
    // with no channel round trip in between.
    _warmImage?.dispose();
    _warmImage = capture.$1.clone();
    _warmDest = capture.$2;
    capture.$1.dispose();
  }

  /// Runs until the first capture succeeds, then stops.
  Timer? _captureTimer;

  /// The latest photo of this control, and its pixels-per-point.
  ui.Image? _warmImage;
  Rect _warmDest = Rect.zero;

  @override
  void dispose() {
    _captureTimer?.cancel();
    for (final animation in _watchedRouteAnimations) {
      animation.removeStatusListener(_handleRouteAnimationStatus);
    }
    _watchedRouteAnimations = const [];
    _routeTransitioning = false;
    _transitionImage?.dispose();
    _transitionImage = null;
    _warmImage?.dispose();
    _warmImage = null;
    super.dispose();
  }

  /// Sends updated config to the native view via [method].
  ///
  /// Size is not re-requested: the native side pushes its intrinsic size after
  /// every layout pass (see `NativeHostingView.scheduleMeasurement`), so a
  /// config push needs no round trip of its own. Pass
  /// `refreshIntrinsicSize: true` only for the rare change the layout pass
  /// cannot see.
  void updateNativeView(
    String method,
    Map<String, dynamic> args, {
    bool refreshIntrinsicSize = false,
  }) {
    final future = channel?.invokeMethod(method, args);
    if (refreshIntrinsicSize) {
      future?.then((_) => requestIntrinsicSize());
    }
    // The held photo predates this change: retake it, so a transition that
    // starts now shows the control as it is.
    if (_warmImage != null) {
      future?.then((_) => _refreshWarmBitmap());
    }
  }

  // Route-transition snapshots: a native view lags the Flutter page during a
  // transition, so it can be replaced by a photo of itself while the route
  // animates (see [hidesDuringRouteTransition]).

  /// Whether this widget is replaced by a photo while its route animates.
  /// Off by default.
  bool get hidesDuringRouteTransition => false;

  /// The route animations whose status is being watched.
  List<Animation<double>> _watchedRouteAnimations = const [];

  /// True while any watched animation is in flight.
  bool _routeTransitioning = false;

  /// The photograph standing in for the live view, and its pixels-per-point.
  ui.Image? _transitionImage;
  Rect _transitionDest = Rect.zero;

  /// A capture in flight, so a second one is not launched on top of it.
  bool _transitionCaptureInFlight = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (!hidesDuringRouteTransition) return;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return;
    final route = ModalRoute.of(context);
    final next = <Animation<double>>[
      ?route?.animation,
      ?route?.secondaryAnimation,
    ];
    if (listEquals(next, _watchedRouteAnimations)) return;
    for (final animation in _watchedRouteAnimations) {
      animation.removeStatusListener(_handleRouteAnimationStatus);
    }
    _watchedRouteAnimations = next;
    for (final animation in _watchedRouteAnimations) {
      animation.addStatusListener(_handleRouteAnimationStatus);
    }
    // A widget mounted mid-transition (a page built during the push, a row
    // that scrolled in lazily) must join the transition it was born into.
    if (_watchedRouteAnimations.any((a) => a.isAnimating)) {
      _enterRouteTransition();
    } else if (_routeTransitioning &&
        _watchedRouteAnimations.every(
          (a) => a.status == AnimationStatus.completed,
        )) {
      _exitRouteTransition();
    }
  }

  void _handleRouteAnimationStatus(AnimationStatus status) {
    switch (status) {
      case AnimationStatus.forward:
      case AnimationStatus.reverse:
        _enterRouteTransition();
      case AnimationStatus.completed:
      case AnimationStatus.dismissed:
        _exitRouteTransition();
    }
  }

  void _enterRouteTransition() {
    if (_routeTransitioning) return;
    _routeTransitioning = true;
    final warm = _warmImage;
    if (warm != null && mounted && _transitionImage == null) {
      // Same frame as the status change: the first frame of the slide
      // already paints the photo, never the lagging live view.
      setState(() {
        _transitionImage = warm.clone();
        _transitionDest = _warmDest;
      });
      return;
    }
    _captureRouteSnapshot(attempt: 0);
  }

  /// Photographs the live view and swaps it in, retrying briefly while it has
  /// not rendered yet. If no capture lands, the live view stays.
  Future<void> _captureRouteSnapshot({required int attempt}) async {
    final ch = channel;
    if (!_routeTransitioning || !mounted || ch == null) return;
    if (_transitionImage != null || _transitionCaptureInFlight) return;
    _transitionCaptureInFlight = true;
    try {
      final capture = await captureNativeView(ch);
      if (!mounted || !_routeTransitioning) {
        capture?.$1.dispose();
        return;
      }
      if (capture != null) {
        final box = context.findRenderObject() as RenderBox?;
        if (box == null || !box.hasSize || box.size.isEmpty) {
          capture.$1.dispose();
          return;
        }
        setState(() {
          _transitionImage = capture.$1;
          _transitionDest = capture.$2;
        });
        return;
      }
    } on MissingPluginException {
      // No `snapshot` handler: nothing to draw in the view's place, so the
      // live view stays. One round trip and done.
      return;
    } catch (_) {
      // Treat like a refusal.
    } finally {
      _transitionCaptureInFlight = false;
    }
    if (attempt < 2 && mounted && _routeTransitioning) {
      Future<void>.delayed(Duration(milliseconds: 48 * (attempt + 1)), () {
        if (!_transitionCaptureInFlight) {
          _captureRouteSnapshot(attempt: attempt + 1);
        }
      });
    }
  }

  void _exitRouteTransition() {
    if (!_routeTransitioning) return;
    _routeTransitioning = false;
    final image = _transitionImage;
    _transitionImage = null;
    if (image == null) return;
    // After the frame that stops painting it: a painter still holding it
    // this frame would draw a disposed image.
    SchedulerBinding.instance.addPostFrameCallback((_) => image.dispose());
    if (mounted) setState(() {});
  }

  /// Wraps [platformView] so it is replaced by its own photo while the route
  /// around it animates. Wrap the sized box, not just the [UiKitView].
  Widget wrapForTransition(Widget platformView) {
    if (!hidesDuringRouteTransition) return platformView;
    if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) {
      return platformView;
    }
    final image = _transitionImage;
    // ONE shape, bitmap or not. Returning the bare view at rest and a Stack
    // during the transition moves the UiKitView in the element tree, which
    // destroys and recreates the native view — the blink on every transition.
    final dest = _transitionDest;
    return Stack(
      fit: StackFit.passthrough,
      clipBehavior: Clip.none,
      children: [
        Opacity(
          opacity: image == null ? 1 : 0,
          child: IgnorePointer(ignoring: image != null, child: platformView),
        ),
        // On the rectangle the platform side measured: the capture reaches past
        // the view.
        if (image != null)
          Positioned(
            left: dest.left,
            top: dest.top,
            width: dest.width,
            height: dest.height,
            child: RawImage(
              image: image,
              fit: BoxFit.fill,
              filterQuality: FilterQuality.medium,
            ),
          ),
      ],
    );
  }

  /// Lays a `w`x`h` control out in a `w`x`h` slot but gives its native view
  /// [room] points more on every side, so its rim and shadow are not cropped.
  Widget withPaintRoom(
    Widget platformView,
    double w,
    double h, {
    double room = 16,
  }) {
    return SizedBox(
      width: w,
      height: h,
      child: OverflowBox(
        minWidth: w + room * 2,
        maxWidth: w + room * 2,
        minHeight: h + room * 2,
        maxHeight: h + room * 2,
        child: platformView,
      ),
    );
  }

  /// [withPaintRoom] for a control that fills whatever box it is given (a
  /// text field). The native side must inset its content by the same [room].
  Widget withPaintRoomFilling(Widget platformView, {double room = 16}) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.biggest;
        // UiKitView needs a bounded box anyway; unbounded is a layout error
        // either way, so leave it to surface as one.
        if (!size.isFinite) return platformView;
        return OverflowBox(
          minWidth: size.width + room * 2,
          maxWidth: size.width + room * 2,
          minHeight: size.height + room * 2,
          maxHeight: size.height + room * 2,
          child: platformView,
        );
      },
    );
  }
}
