import 'dart:async';
import 'dart:math' show max;

import 'package:flutter/foundation.dart' show VoidCallback;
import 'package:flutter/gestures.dart';

/// A platform-view gesture recognizer that lets a vertical drag reach the
/// scrollable underneath.
///
/// Unlike [EagerGestureRecognizer], it waits the way UIKit does inside a scroll
/// view: a touch that moves sideways belongs to the control, one that runs
/// vertically past the slop belongs to the page — even after the finger rested
/// (see [onLost]).
///
/// Not for a control that needs vertical drags of its own — a wheel picker
/// keeps [EagerGestureRecognizer]. A view that holds one among other rows (a
/// list with a wheel in a row) names where it is with [claims].
class ScrollFriendlyPlatformViewRecognizer
    extends OneSequenceGestureRecognizer {
  ScrollFriendlyPlatformViewRecognizer({
    this.claims,
    this.claimAfter,
    this.onLost,
    super.debugOwner,
  });

  /// Whether a touch landing here, in the view's own coordinates, is the
  /// view's whatever way it then moves — on a wheel, a vertical drag spins it.
  final bool Function(Offset localPosition)? claims;

  /// How long a still finger takes to become the view's for good, for a view
  /// whose hold opens something — a pull-down menu, a context menu. Null: a
  /// held finger stays the page's to scroll however long it rests, as in a
  /// `UIScrollView` and in a Flutter list.
  final Duration? claimAfter;

  /// The native view already had the touch ([holdTimeout]) and the page took
  /// it: the view must let go natively — its `cancelTouches`.
  final VoidCallback? onLost;

  /// When a still finger reaches the native view, without the arena deciding:
  /// UIKit's own `delaysContentTouches` window, so a row highlights and a
  /// switch presses as fast as in a native scroll view.
  static const Duration holdTimeout = Duration(milliseconds: 150);

  /// The width of the strip a `CupertinoPageRoute`'s back swipe starts in —
  /// Flutter's `_kBackGestureWidth`, widened to the safe area like Flutter's.
  static const double _backGestureWidth = 20;

  Offset? _start;
  Timer? _hold;
  Timer? _claim;

  /// Decided, by this recognizer or by the arena.
  bool _resolved = false;

  /// Decided for the view.
  bool _accepted = false;

  /// The native view has the touch already, the arena still open.
  bool _released = false;

  /// Ran vertically: the page's, if the page wants it.
  bool _yielded = false;

  bool _down = false;

  /// The touch landed in the back-swipe strip: a drag there is not the
  /// view's, as no Flutter widget under it would claim it — a tap still is.
  bool _onBackEdge = false;

  @override
  String get debugDescription => 'scroll-friendly platform view';

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    _start = event.position;
    _resolved = _accepted = _released = _yielded = false;
    _down = true;
    if (claims?.call(event.localPosition) ?? false) {
      _finish(GestureDisposition.accepted);
      return;
    }
    _onBackEdge = _inBackStrip(event);
    final pointer = event.pointer;
    _hold = Timer(holdTimeout, () => _release(pointer));
    if (claimAfter case final after?) {
      _claim = Timer(after, () => _finish(GestureDisposition.accepted));
    }
    // Otherwise deliberately NOT resolved here. Everything this class exists for
    // happens in the frames between the touch landing and the finger moving.
  }

  /// Hands the touch to the native view the way the arena's win would — the
  /// team captain is the `UiKitView`'s own recognizer, whose accept releases
  /// it on the native side — but leaves the arena open, so a scroll can still
  /// take it back.
  void _release(int pointer) {
    if (_resolved || _yielded) return;
    _released = true;
    team?.captain?.acceptGesture(pointer);
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerUpEvent || event is PointerCancelEvent) _down = false;
    _decide(event);
    // Decided or not, a lifted finger is no longer tracked.
    stopTrackingIfPointerNoLongerDown(event);
  }

  void _decide(PointerEvent event) {
    if (_resolved || _yielded) return;
    final start = _start;
    if (start == null) return;

    if (event is PointerMoveEvent) {
      final delta = event.position - start;
      // A vertical run past the slop is a scroll: left to the Scrollable, not
      // given up — on a page that does not scroll, the view keeps it.
      if (delta.dy.abs() > kTouchSlop && delta.dy.abs() > delta.dx.abs()) {
        _yielded = true;
        _stopTimers();
        return;
      }
      // From the edge, sideways is the back swipe's: left to the arena.
      if (_onBackEdge) return;
      // Anything else that has travelled — a sideways drag on a slider or a
      // segmented control — belongs to the control.
      if (delta.distance > kTouchSlop) _finish(GestureDisposition.accepted);
      return;
    }

    // Lifted without travelling: a tap, which is the control's.
    if (event is PointerUpEvent) _finish(GestureDisposition.accepted);
    if (event is PointerCancelEvent) _finish(GestureDisposition.rejected);
  }

  /// Nobody else wanted it, so the control gets it — the common case for a
  /// press-and-hold on a button with no scrollable in the way.
  @override
  void didStopTrackingLastPointer(int pointer) {
    if (!_resolved && !_yielded) _finish(GestureDisposition.accepted);
  }

  // ponytail: left edge only — an RTL app's strip is on the right; pass the
  // text direction in if one ships.
  static bool _inBackStrip(PointerDownEvent event) {
    final view = GestureBinding.instance.platformDispatcher.view(
      id: event.viewId,
    );
    final inset = view == null
        ? 0.0
        : view.padding.left / view.devicePixelRatio;
    return event.position.dx < max(inset, _backGestureWidth);
  }

  void _finish(GestureDisposition disposition) {
    if (_resolved) return;
    _resolved = true;
    // Before resolving: a team that wins rejects its members, this one too.
    _accepted = disposition == GestureDisposition.accepted;
    _stopTimers();
    resolve(disposition);
  }

  void _stopTimers() {
    _hold?.cancel();
    _claim?.cancel();
    _hold = _claim = null;
  }

  /// Called when the page (or the back swipe) won, and also when this view's
  /// own team won — the team rejects every member but its captain.
  @override
  void rejectGesture(int pointer) {
    final lost = _down && _released && !_accepted;
    _resolved = true;
    _stopTimers();
    stopTrackingPointer(pointer);
    if (lost) onLost?.call();
  }

  @override
  void dispose() {
    _stopTimers();
    super.dispose();
  }
}

/// Where a native view's own scrolling stands, as the native side reports it
/// (the text editor's `onScrollState`).
class NestedScrollState {
  const NestedScrollState({
    this.scrolls = false,
    this.atTop = true,
    this.atBottom = true,
    this.moving = false,
  });

  /// The content overflows: the view scrolls it itself.
  final bool scrolls;

  /// At rest against the top / the bottom of its content.
  final bool atTop;
  final bool atBottom;

  /// Dragged, decelerating or bouncing.
  final bool moving;

  static NestedScrollState fromMap(Object? map) {
    final m = (map as Map?) ?? const {};
    return NestedScrollState(
      scrolls: m['scrolls'] == true,
      atTop: m['atTop'] != false,
      atBottom: m['atBottom'] != false,
      moving: m['moving'] == true,
    );
  }
}

/// A platform-view recognizer for a view that scrolls its own content inside
/// a scrolling page — a text view in a form — handing each drag to the view
/// or to the page the way UIKit does, from where the view's scrolling stands
/// when the finger lands:
///
/// * still moving (dragged, decelerating, bouncing), or anywhere between its
///   edges: the view takes the drag;
/// * at rest against an edge: a vertical drag past that edge goes to the
///   page, any other drag to the view.
///
/// A drag once given is kept until the finger lifts, even when the content
/// reaches its edge on the way: the hand-off only ever happens on a new touch.
class NestedScrollPlatformViewRecognizer extends OneSequenceGestureRecognizer {
  NestedScrollPlatformViewRecognizer({required this.state, super.debugOwner});

  /// Read when the finger lands.
  final NestedScrollState Function() state;

  static const Duration _holdTimeout = Duration(milliseconds: 150);

  Offset? _start;
  NestedScrollState _landed = const NestedScrollState();
  bool _resolved = false;
  Timer? _hold;

  @override
  String get debugDescription => 'nested-scroll platform view';

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    _start = event.position;
    _resolved = false;
    _landed = state();
    if (_landed.moving || (!_landed.atTop && !_landed.atBottom)) {
      _finish(GestureDisposition.accepted);
      return;
    }
    _hold = Timer(_holdTimeout, () => _finish(GestureDisposition.accepted));
  }

  @override
  void handleEvent(PointerEvent event) {
    _decide(event);
    // Decided or not, a lifted finger is no longer tracked.
    stopTrackingIfPointerNoLongerDown(event);
  }

  void _decide(PointerEvent event) {
    if (_resolved) return;
    final start = _start;
    if (start == null) return;
    if (event is PointerMoveEvent) {
      final delta = event.position - start;
      if (delta.dy.abs() > kTouchSlop && delta.dy.abs() > delta.dx.abs()) {
        // Finger down at the top, or up at the bottom: past the edge.
        final pastEdge =
            (_landed.atTop && delta.dy > 0) ||
            (_landed.atBottom && delta.dy < 0);
        _finish(
          pastEdge ? GestureDisposition.rejected : GestureDisposition.accepted,
        );
        return;
      }
      if (delta.distance > kTouchSlop) _finish(GestureDisposition.accepted);
      return;
    }
    if (event is PointerUpEvent) _finish(GestureDisposition.accepted);
    if (event is PointerCancelEvent) _finish(GestureDisposition.rejected);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    if (!_resolved) _finish(GestureDisposition.accepted);
  }

  void _finish(GestureDisposition disposition) {
    if (_resolved) return;
    _resolved = true;
    _hold?.cancel();
    _hold = null;
    resolve(disposition);
  }

  @override
  void rejectGesture(int pointer) {
    _resolved = true;
    _hold?.cancel();
    _hold = null;
    stopTrackingPointer(pointer);
  }

  @override
  void dispose() {
    _hold?.cancel();
    super.dispose();
  }
}
