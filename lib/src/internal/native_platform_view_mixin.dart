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
    debugPrint(
      'EXPAND-DEBUG ${DateTime.now().millisecondsSinceEpoch} intrinsicSize '
      'h=$height was=$intrinsicHeight ($runtimeType)',
    );
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

  @override
  void dispose() {
    _unwatchRoute();
    _routeTransitioning = false;
    _transitionImage?.dispose();
    _transitionImage = null;
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
  }

  // Route-transition snapshots. A platform view is positioned on the platform
  // thread, a step behind the Flutter layer it belongs to, so while its route
  // animates it hangs at the wrong offset. For that time it is drawn as a photo
  // of itself: Flutter pixels, which move in step with the page.
  //
  // The photo is taken when the transition starts, never ahead of time. A glass
  // samples what is behind it, and a bar's search field changes size and
  // material as the page scrolls, so a photo taken earlier shows the control as
  // it was. The one this replaced was taken as soon as the view could be
  // photographed (during the push that brought the page in, while the view
  // still lagged) and kept: glass came back dark or boxed in, and the search
  // field flat and 16pt off, the paint room it gained after the photo.

  /// Whether this widget is replaced by a photo while its route animates.
  bool get hidesDuringRouteTransition => true;

  ModalRoute<dynamic>? _route;
  Animation<double>? _routeAnimation;
  Animation<double>? _routeSecondaryAnimation;

  /// This route has finished arriving once. Until then a moving own animation
  /// is its first push, whose views have never rendered and so cannot be
  /// photographed; after, it is this page leaving (a pop, a back swipe).
  bool _routeSettled = false;

  /// True while the photo stands in for the live view.
  bool _routeTransitioning = false;

  @visibleForTesting
  bool get debugGuardingRouteTransition => _routeTransitioning;

  /// The photograph standing in for the live view, and where it goes.
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
    if (route?.animation == _routeAnimation &&
        route?.secondaryAnimation == _routeSecondaryAnimation) {
      return;
    }
    _unwatchRoute();
    _route = route;
    _routeSettled = false;
    _routeAnimation = route?.animation?..addStatusListener(_onRouteStatus);
    _routeSecondaryAnimation = route?.secondaryAnimation
      ?..addStatusListener(_onRouteStatus);
    _updateRouteGuard();
  }

  void _unwatchRoute() {
    _routeAnimation?.removeStatusListener(_onRouteStatus);
    _routeSecondaryAnimation?.removeStatusListener(_onRouteStatus);
    _route = null;
    _routeAnimation = null;
    _routeSecondaryAnimation = null;
  }

  void _onRouteStatus(AnimationStatus _) => _updateRouteGuard();

  /// Guards while another page covers this one (from the moment it starts
  /// sliding over until it has slid back off), and while this page leaves.
  /// The photo taken as a page is covered is still right when it is uncovered:
  /// nothing on it moved in between.
  void _updateRouteGuard() {
    final own = _routeAnimation;
    final secondary = _routeSecondaryAnimation;
    // Not on the offstage pass: a pushed route is first built with its
    // animation pinned at 1.0, for Hero measurement, before it has arrived.
    if (own != null && own.isCompleted && !(_route?.offstage ?? false)) {
      _routeSettled = true;
    }
    final guard =
        (secondary != null && !secondary.isDismissed) ||
        (_routeSettled && own != null && !own.isCompleted);
    if (!guard) {
      _exitRouteTransition();
      return;
    }
    _routeTransitioning = true;
    // Also when already guarding without a photo (a capture that was declined
    // while the page was covered): the page is about to be seen again.
    if (_transitionImage == null) _captureRouteSnapshot(attempt: 0);
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
