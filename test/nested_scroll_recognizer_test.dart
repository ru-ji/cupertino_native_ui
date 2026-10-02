import 'package:cupertino_widgets/src/internal/scroll_friendly_recognizer.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter_test/flutter_test.dart';

/// Who wins the arena between a text editor whose text scrolls and the page
/// around it, for the cases UIKit decides: in between, at an edge, moving.
void main() {
  late NestedScrollState state;
  late NestedScrollPlatformViewRecognizer view;
  late VerticalDragGestureRecognizer page;
  late List<String> won;

  setUp(() {
    won = [];
    view = NestedScrollPlatformViewRecognizer(state: () => state);
    page = VerticalDragGestureRecognizer()..onStart = (_) => won.add('page');
  });

  tearDown(() {
    view.dispose();
    page.dispose();
  });

  void send(PointerEvent event) {
    if (event is PointerDownEvent) {
      view.addPointer(event);
      page.addPointer(event);
      GestureBinding.instance.gestureArena.close(event.pointer);
      return;
    }
    GestureBinding.instance.pointerRouter.route(event);
  }

  /// A vertical drag; positive [dy] is the finger moving down.
  Future<void> drag(WidgetTester tester, double dy) async {
    send(const PointerDownEvent(position: Offset(50, 200)));
    send(PointerMoveEvent(position: Offset(50, 200 + dy)));
    // A frame before the lift, as in a real drag: the arena resolves then.
    await tester.pump();
    send(PointerUpEvent(position: Offset(50, 200 + dy)));
    await tester.pump();
  }

  const scrolls = NestedScrollState(
    scrolls: true,
    atTop: false,
    atBottom: false,
  );
  const atTop = NestedScrollState(scrolls: true, atTop: true, atBottom: false);
  const atBottom = NestedScrollState(
    scrolls: true,
    atTop: false,
    atBottom: true,
  );

  testWidgets('in between, the text keeps both directions', (tester) async {
    state = scrolls;
    await drag(tester, kTouchSlop * 3);
    await drag(tester, -kTouchSlop * 3);
    expect(won, isEmpty);
  });

  testWidgets('at the top, pulling down scrolls the page', (tester) async {
    state = atTop;
    await drag(tester, kTouchSlop * 3);
    expect(won, ['page']);
  });

  testWidgets('at the top, pushing up scrolls the text', (tester) async {
    state = atTop;
    await drag(tester, -kTouchSlop * 3);
    expect(won, isEmpty);
  });

  testWidgets('at the bottom, pushing up scrolls the page', (tester) async {
    state = atBottom;
    await drag(tester, -kTouchSlop * 3);
    expect(won, ['page']);
  });

  testWidgets('still bouncing at an edge, the text keeps it', (tester) async {
    state = const NestedScrollState(
      scrolls: true,
      atTop: true,
      atBottom: false,
      moving: true,
    );
    await drag(tester, kTouchSlop * 3);
    expect(won, isEmpty);
  });
}
