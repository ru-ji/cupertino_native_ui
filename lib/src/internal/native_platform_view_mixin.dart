import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart' show SchedulerBinding;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'bar_snapshots.dart';
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
    _exempt = CupertinoEdgeEffectExempt.of(context);
    if (_exempt) CupertinoEdgeEffectCoverage.setExempt(id, true);
    // Exempt or not: the bar's own buttons need a ready photo for route
    // transitions even though they never pass under the effect.
    _keepBitmapFresh();
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

  /// Takes a bitmap of this control the moment it starts passing under a
  /// scroll edge effect, and hands it to the bar to draw.
  ///
  /// A `BackdropFilter` cannot reach a platform view, so the pixels are moved
  /// to where it can: the bar draws the covered band of this bitmap in its own
  /// layer, under the shader, and only once it holds one is the live view cut
  /// on the same line. See [barSnapshots].
  ///
  /// Frozen, and that is the point rather than a limitation: a control halfway
  /// under a bar is not one anybody is operating. The capture is refreshed the
  /// next time it comes back out and goes under again.
  /// Keeps an up-to-date bitmap of this control on hand, always.
  ///
  /// Not when it approaches a bar — **always**, from the moment it can be
  /// photographed until it goes away. Taking it on approach was the mistake
  /// that produced every blink: a control announced early is usually still
  /// off-screen, and an off-screen view has never rendered, which is the one
  /// state `drawHierarchy` refuses. The picture then only existed after the
  /// crossing had already happened.
  ///
  /// So the trigger is not proximity, it is EXISTENCE. Try as soon as the view
  /// is created; keep trying while it refuses, which covers the whole of a
  /// route transition and the frames before the first render; stop at the
  /// first success. From then on it is retaken only when the control itself
  /// changes — a switch flipped, a tint changed, a character typed — because
  /// that is the only thing that can make the picture wrong.
  ///
  /// By the time any bar is involved there is nothing left to decide: the band
  /// inside the bar's rectangle is drawn from the bitmap, the live view is cut
  /// on the same line, and neither waits on the other.
  void _keepBitmapFresh() {
    if (_warmImage != null) return;
    _captureTimer ??= Timer.periodic(
      const Duration(milliseconds: 100),
      (_) => _captureIntoBar(),
    );
    _captureIntoBar();
  }

  /// Takes the bitmap and registers it. A refusal is not an error — the view
  /// has simply not rendered yet, and [_keepBitmapFresh] asks again.
  Future<void> _captureIntoBar() async {
    final id = _edgeEffectViewId;
    final channel = this.channel;
    if (id == null || channel == null || !mounted) return;
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize || box.size.isEmpty) {
      // TEMPORARY diagnostic. Delete with the Swift-side probes.
      return;
    }
    (ui.Image, Rect)? capture;
    try {
      capture = await captureNativeView(channel);
    } on MissingPluginException {
      // This view type has no `snapshot` handler and never will — a context
      // menu, say. Retrying it every 100ms for the life of the page is a
      // channel round trip a second, forever, for an answer that cannot
      // change.
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
    if (_exempt) {
      capture.$1.dispose();
      return;
    }
    // The bar places the bitmap against this State's box; the native view
    // sits [withPaintRoom] further out.
    barSnapshots.add(
      id,
      BarSnapshotEntry(
        capture.$1,
        box,
        capture.$2.shift(Offset(-_paintRoom, -_paintRoom)),
      ),
    );
    // The platform side may cut this view from now on: there is something to
    // put in the band's place.
    unawaited(setEdgeCut(id, true));
  }

  /// Runs until the first capture succeeds, then stops.
  Timer? _captureTimer;

  /// The latest photo of this control, and its pixels-per-point.
  ui.Image? _warmImage;
  Rect _warmDest = Rect.zero;

  /// How far the native view reaches past this widget's box. See
  /// [withPaintRoom].
  double _paintRoom = 0;

  /// Bar chrome: painted over the edge effect, never cut by it.
  bool _exempt = false;

  /// The platform view id, kept so the edge-effect exemption can be dropped
  /// when this view goes away and the id is handed to the next one.
  int? _edgeEffectViewId;

  /// Releases the exemption this view claimed. Mixed into a `State`, so the
  /// widget's own `dispose` runs this by calling `super.dispose()`.
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
    final id = _edgeEffectViewId;
    if (id != null) {
      CupertinoEdgeEffectCoverage.setExempt(id, false);
      barSnapshots.remove(id);
    }
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
    // The bitmap held for this control is a photograph, and the control just
    // changed underneath it. Left alone, a switch flipped on its way to the
    // bar would show its old state above the cut and its new one below.
    // The bitmap is a photograph and the control just changed underneath it.
    if (_warmImage != null) {
      future?.then((_) => _captureIntoBar());
    }
  }

  // ---------------------------------------------------------------------------
  // Route-transition snapshots.
  //
  // A platform view is a real UIView composited by UIKit ABOVE the Flutter
  // surface, moved by the embedder one beat behind the Flutter animation it
  // belongs to. During a route transition that shows: the bar's native
  // buttons keep painting above the incoming page, and every native control
  // lags the page that is carrying it. Flutter cannot composite the UIView
  // itself, so the control is temporarily replaced by a photograph of it —
  // ordinary Flutter pixels that slide, fade and clip exactly like the page
  // they sit on. The official docs spell out the same technique: snapshot the
  // native view and render it as a texture while the animation runs.
  //
  // The widget's own route and its secondary animation are both watched
  // (push animates the pushed route, Cupertino's parallax animates the
  // secondary of the covered one), so a widget hides whichever side of a
  // transition it happens to be on — no observer for the app to install.
  // ---------------------------------------------------------------------------

  /// Whether this widget melts away into a bitmap while its route animates.
  ///
  /// False for a full-screen host (the scaffold): it IS the page being
  /// transitioned, not a control riding on one, and a bitmap of it would
  /// freeze the whole page while the route above it slides.
  bool get hidesDuringRouteTransition => true;

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
            (a) => a.status == AnimationStatus.completed)) {
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

  /// Photographs the live view and swaps it in. A refusal to capture is not
  /// an error — the view has not rendered yet (a page being pushed for the
  /// first time) — and a couple of short retries cover the frames it needs.
  /// If none lands, the live view simply stays: hiding it with nothing to
  /// draw in its place would leave a hole, which is worse than the one-frame
  /// lag this whole path exists to remove.
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

  /// Wraps [platformView] so it is replaced by its own photograph while the
  /// route around it animates. Wrap the sized box, not just the [UiKitView]:
  /// the bitmap fills whatever the live view would have filled.
  ///
  /// The live view is hidden with opacity, the one mutation hybrid
  /// composition is guaranteed to carry, and only once the bitmap exists —
  /// there is never a frame with a hole in it.
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
        // On the rectangle the platform side measured, not the box: the
        // capture reaches past the view by the cut's outset.
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

  /// Lays a `w`x`h` control out in a `w`x`h` slot, but gives its native view
  /// [room] points more on every side, the control centred in it.
  ///
  /// iOS cannot capture what a view paints outside its own bounds, and a
  /// glass circle, its rim and its shadow all do: boxed to the control's
  /// exact size, the photo comes back with the circle cropped to a grey
  /// square. Only for controls that hug and centre their content natively —
  /// one pinned to fill its box would just draw bigger.
  Widget withPaintRoom(Widget platformView, double w, double h,
      {double room = 16}) {
    _paintRoom = room;
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
}
