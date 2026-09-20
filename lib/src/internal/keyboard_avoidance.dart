import 'package:flutter/widgets.dart';

/// Dismisses the keyboard *while* the route leaves, not after it has left.
///
/// A native UIKit/SwiftUI screen resigns the first responder in
/// `viewWillDisappear`, so the keyboard slides down over the same frames as
/// the push or pop — and follows an interactive back swipe finger-for-finger.
/// A Flutter platform view does neither on its own: the field stays mounted
/// for the whole transition and only gives up the responder when it is
/// disposed, which is why the keyboard appears to wait for the transition to
/// finish before collapsing.
///
/// Mixing this in hooks the two signals that mark "this route is going away
/// now": the route's own animation reversing (a pop), its secondary animation
/// running forward (a push covering it), and the navigator's user-gesture flag
/// (the back swipe, whose animation value is driven by the finger and so never
/// changes status).
mixin RouteKeyboardDismissal<T extends StatefulWidget> on State<T> {
  ModalRoute<dynamic>? _route;
  ValueNotifier<bool>? _userGesture;

  /// Resign whatever this widget has focused. Called once per departure.
  void dismissKeyboardForRoute();

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final route = ModalRoute.of(context);
    if (route == _route) return;
    _detach();
    _route = route;
    route?.animation?.addStatusListener(_onStatus);
    route?.secondaryAnimation?.addStatusListener(_onSecondaryStatus);
    _userGesture = Navigator.maybeOf(context)?.userGestureInProgressNotifier
      ?..addListener(_onUserGesture);
  }

  @override
  void dispose() {
    _detach();
    super.dispose();
  }

  void _detach() {
    _route?.animation?.removeStatusListener(_onStatus);
    _route?.secondaryAnimation?.removeStatusListener(_onSecondaryStatus);
    _userGesture?.removeListener(_onUserGesture);
    _userGesture = null;
  }

  void _onStatus(AnimationStatus status) {
    if (status == AnimationStatus.reverse) dismissKeyboardForRoute();
  }

  void _onSecondaryStatus(AnimationStatus status) {
    if (status == AnimationStatus.forward) dismissKeyboardForRoute();
  }

  /// The back swipe moves the route's animation by hand, so its status never
  /// reports the departure; the navigator's flag is the only edge there.
  void _onUserGesture() {
    if (_userGesture?.value == true && (_route?.isCurrent ?? false)) {
      dismissKeyboardForRoute();
    }
  }
}

/// How much of the keyboard actually covers the scroll viewport [context] sits
/// in — the padding a reveal has to add, and **not** the same thing as the
/// view inset.
///
/// The inset is the keyboard's height against the *window*. A reveal that pads
/// by it assumes the viewport still reaches the bottom of the screen, which is
/// only true for a page that does not resize for the keyboard. When something
/// upstream already shrinks the viewport — a `Scaffold` consuming the inset, a
/// native scroll view doing its own avoidance — the field has been lifted
/// clear once already, and padding by the full inset lifts it a second time.
/// That is the page scrolling away from a field that was perfectly visible.
///
/// Measuring the overlap instead makes the reveal self-cancelling: a viewport
/// that already ends above the keyboard returns 0 and the reveal falls back to
/// its plain "is this box visible" test.
double keyboardCoverOfViewport(BuildContext context) {
  final inset = MediaQuery.viewInsetsOf(context).bottom;
  if (inset <= 0) return 0;
  final viewport = Scrollable.maybeOf(context)?.context.findRenderObject();
  if (viewport is! RenderBox || !viewport.hasSize) return inset;
  final viewportBottom = viewport
      .localToGlobal(Offset(0, viewport.size.height))
      .dy;
  final keyboardTop = MediaQuery.sizeOf(context).height - inset;
  return (viewportBottom - keyboardTop).clamp(0.0, inset);
}
