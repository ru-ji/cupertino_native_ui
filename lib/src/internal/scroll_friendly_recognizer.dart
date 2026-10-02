import 'dart:async';

import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart';

/// A platform-view gesture recognizer that lets a vertical drag reach the
/// scrollable underneath.
///
/// Unlike [EagerGestureRecognizer], it waits the way UIKit does inside a scroll
/// view: a touch that stays put or moves sideways belongs to the control, one
/// that runs vertically past the slop belongs to the page.
///
/// Not for a control that needs vertical drags of its own — a wheel picker
/// keeps [EagerGestureRecognizer]. A view that holds one among other rows (a
/// list with a wheel in a row) names where it is with [claims].
class ScrollFriendlyPlatformViewRecognizer
    extends OneSequenceGestureRecognizer {
  ScrollFriendlyPlatformViewRecognizer({this.claims, super.debugOwner});

  /// Whether a touch landing here, in the view's own coordinates, is the
  /// view's whatever way it then moves — on a wheel, a vertical drag spins it.
  final bool Function(Offset localPosition)? claims;

  /// A finger that has not moved by now is not scrolling. 150ms is UIKit's
  /// own `delaysContentTouches` window, so a switch or a context menu answers
  /// a held finger as fast as it does in a native scroll view; 300ms made the
  /// switch's press feedback and the context menu's lift visibly late.
  static const Duration _holdTimeout = Duration(milliseconds: 150);

  Offset? _start;
  bool _resolved = false;
  Timer? _hold;

  @override
  String get debugDescription => 'scroll-friendly platform view';

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    _start = event.position;
    _resolved = false;
    if (claims?.call(event.localPosition) ?? false) {
      _finish(GestureDisposition.accepted);
      return;
    }
    _hold = Timer(_holdTimeout, () => _finish(GestureDisposition.accepted));
    // Otherwise deliberately NOT resolved here. Everything this class exists for
    // happens in the frames between the touch landing and the finger moving.
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
      // A vertical run past the slop is a scroll: reject, so the Scrollable
      // takes it.
      if (delta.dy.abs() > kTouchSlop && delta.dy.abs() > delta.dx.abs()) {
        _finish(GestureDisposition.rejected);
        return;
      }
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

/// The set to hand a `UiKitView` for a control that does not drag vertically.
///
/// Typed with the recognizer's own class, not `OneSequenceGestureRecognizer`:
/// a `UiKitView` only swaps recognizers when the factories' *types* differ,
/// so two sets both typed `Factory<OneSequenceGestureRecognizer>` read as
/// equal and the second is never installed.
Set<Factory<OneSequenceGestureRecognizer>> get scrollFriendlyGestures =>
    <Factory<OneSequenceGestureRecognizer>>{
      Factory<ScrollFriendlyPlatformViewRecognizer>(
        ScrollFriendlyPlatformViewRecognizer.new,
      ),
    };

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
