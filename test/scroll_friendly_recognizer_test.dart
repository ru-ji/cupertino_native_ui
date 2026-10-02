import 'package:cupertino_widgets/src/internal/scroll_friendly_recognizer.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/painting.dart' show Rect;
import 'package:flutter_test/flutter_test.dart';

/// The whole point of the recognizer is who wins the arena, so the check is a
/// real arena with the recognizer the `Scrollable` would have put in it.
void main() {
  late ScrollFriendlyPlatformViewRecognizer view;
  late VerticalDragGestureRecognizer drag;
  late List<String> won;

  setUp(() {
    won = [];
    view = ScrollFriendlyPlatformViewRecognizer();
    drag = VerticalDragGestureRecognizer()..onStart = (_) => won.add('scroll');
  });

  tearDown(() {
    view.dispose();
    drag.dispose();
  });

  void send(PointerEvent event) {
    if (event is PointerDownEvent) {
      view.addPointer(event);
      drag.addPointer(event);
      GestureBinding.instance.gestureArena.close(event.pointer);
      return;
    }
    GestureBinding.instance.pointerRouter.route(event);
  }

  testWidgets('a vertical drag goes to the scrollable', (tester) async {
    send(const PointerDownEvent(position: Offset(50, 50)));
    send(const PointerMoveEvent(position: Offset(50, 50 + kTouchSlop * 3)));
    await tester.pump();
    expect(won, ['scroll']);
  });

  testWidgets('a sideways drag stays with the control', (tester) async {
    send(const PointerDownEvent(position: Offset(50, 50)));
    send(const PointerMoveEvent(position: Offset(50 + kTouchSlop * 3, 50)));
    await tester.pump();
    expect(won, isEmpty, reason: 'the control took it, not the scrollable');
  });

  testWidgets('a tap stays with the control', (tester) async {
    send(const PointerDownEvent(position: Offset(50, 50)));
    send(const PointerUpEvent(position: Offset(50, 50)));
    await tester.pump();
    expect(won, isEmpty);
  });

  testWidgets('a vertical drag on a claimed spot stays with the view', (
    tester,
  ) async {
    // A wheel in a row: the touch lands on it, so the drag spins it.
    view.dispose();
    view = ScrollFriendlyPlatformViewRecognizer(
      claims: (p) => const Rect.fromLTWH(0, 0, 100, 100).contains(p),
    );
    send(const PointerDownEvent(position: Offset(50, 50)));
    send(const PointerMoveEvent(position: Offset(50, 50 + kTouchSlop * 3)));
    await tester.pump();
    expect(won, isEmpty, reason: 'the wheel took it, not the scrollable');
  });

  test('the factory carries the recognizer type a UiKitView compares', () {
    // A UiKitView swaps recognizers only when the factory types differ: a
    // set typed Factory<OneSequenceGestureRecognizer> is never replaced.
    expect(
      scrollFriendlyGestures.single.type,
      ScrollFriendlyPlatformViewRecognizer,
    );
  });
}
