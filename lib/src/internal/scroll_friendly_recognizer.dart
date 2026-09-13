import 'dart:async';

import 'package:flutter/foundation.dart' show Factory;
import 'package:flutter/gestures.dart';

/// A platform-view gesture recognizer that lets a vertical drag reach the
/// scrollable underneath.
///
/// [EagerGestureRecognizer] wins the arena on the first event, before anyone
/// can tell a tap from a scroll. That is what a control wants — the touch
/// arrives instantly — and it costs two things:
///
///  * a drag started on a switch or a slider never scrolls the page, because
///    the control took the gesture before it was one;
///  * `Scrollable` gets its drag rejected while its hold is still up, which
///    trips `'_hold == null': is not true` on every such scroll in debug.
///
/// This waits instead, exactly as far as UIKit does inside a scroll view: a
/// touch that stays put, or moves mostly sideways, belongs to the control; one
/// that runs vertically past the slop belongs to the page. Nothing is claimed
/// until one of those is true, so the arena resolves the way the finger
/// actually moved.
///
/// Not for a control that needs vertical drags of its own — a wheel picker
/// keeps [EagerGestureRecognizer].
class ScrollFriendlyPlatformViewRecognizer
    extends OneSequenceGestureRecognizer {
  ScrollFriendlyPlatformViewRecognizer({super.debugOwner});

  /// A finger that has not moved by now is not scrolling. Long-pressing a
  /// control — the gesture a context menu is built on — never produces a move
  /// event at all, so without this it would wait for the lift and the native
  /// view would never see the press. 300ms is UIKit's own
  /// `delaysContentTouches` window, which is what this is reproducing.
  static const Duration _holdTimeout = Duration(milliseconds: 300);

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
    _hold = Timer(_holdTimeout, () => _finish(GestureDisposition.accepted));
    // Deliberately NOT resolved here. Everything this class exists for
    // happens in the frames between the touch landing and the finger moving.
  }

  @override
  void handleEvent(PointerEvent event) {
    if (_resolved) return;
    final start = _start;
    if (start == null) return;

    if (event is PointerMoveEvent) {
      final delta = event.position - start;
      // A vertical run past the slop is a scroll: hand it over. Rejecting is
      // what lets the Scrollable's own recognizer take the sequence, and it
      // is why the page moves when the finger started on a control.
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
Set<Factory<OneSequenceGestureRecognizer>> get scrollFriendlyGestures =>
    <Factory<OneSequenceGestureRecognizer>>{
      Factory<OneSequenceGestureRecognizer>(
        ScrollFriendlyPlatformViewRecognizer.new,
      ),
    };
