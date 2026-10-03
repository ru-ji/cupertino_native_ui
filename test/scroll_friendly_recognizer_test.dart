import 'package:cupertino_widgets/src/internal/native_platform_view_mixin.dart';
import 'package:cupertino_widgets/src/internal/scroll_friendly_recognizer.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The `UiKitView`'s own recognizer, captain of the view's team: its accept
/// is what hands the touch to the native view.
class _Captain extends GestureArenaMember {
  _Captain(this.log);

  final List<String> log;

  @override
  void acceptGesture(int pointer) => log.add('native has it');

  @override
  void rejectGesture(int pointer) {}
}

class _Probe extends StatefulWidget {
  const _Probe();

  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe>
    with NativePlatformViewStateMixin<_Probe> {
  @override
  Widget build(BuildContext context) => const SizedBox();
}

/// The whole point of the recognizer is who wins the arena, so the check is a
/// real arena with the recognizer the `Scrollable` would have put in it, and
/// the view's team as a `UiKitView` builds it.
void main() {
  late ScrollFriendlyPlatformViewRecognizer view;
  late VerticalDragGestureRecognizer drag;
  late List<String> won;

  ScrollFriendlyPlatformViewRecognizer inTeam(
    ScrollFriendlyPlatformViewRecognizer recognizer,
  ) => recognizer..team = (GestureArenaTeam()..captain = _Captain(won));

  setUp(() {
    won = [];
    view = inTeam(
      ScrollFriendlyPlatformViewRecognizer(
        onLost: () => won.add('native lets go'),
      ),
    );
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

  // A drag recognizer counts the delta, not the position.
  PointerMoveEvent down(double dy, {double dx = 0}) => PointerMoveEvent(
    position: Offset(50 + dx, 50 + dy),
    delta: Offset(dx, dy),
  );

  testWidgets('a vertical drag goes to the scrollable', (tester) async {
    send(const PointerDownEvent(position: Offset(50, 50)));
    send(down(kTouchSlop * 3));
    await tester.pump();
    expect(won, ['scroll']);
  });

  testWidgets('a finger that rested still scrolls, and the view lets go', (
    tester,
  ) async {
    send(const PointerDownEvent(position: Offset(50, 50)));
    await tester.pump(const Duration(seconds: 2));
    expect(won, ['native has it'], reason: 'a row highlights under it');
    send(down(kTouchSlop * 3));
    await tester.pump();
    expect(won, ['native has it', 'native lets go', 'scroll']);
  });

  testWidgets('a finger that rested and lifts is a tap', (tester) async {
    send(const PointerDownEvent(position: Offset(50, 50)));
    await tester.pump(const Duration(seconds: 2));
    send(const PointerUpEvent(position: Offset(50, 50)));
    await tester.pump();
    expect(won, ['native has it', 'native has it']);
  });

  testWidgets('a held finger is the view\'s for good after claimAfter', (
    tester,
  ) async {
    // A context menu: presented after a long press, the touch stays with it.
    view.dispose();
    view = inTeam(
      ScrollFriendlyPlatformViewRecognizer(claimAfter: kLongPressTimeout),
    );
    send(const PointerDownEvent(position: Offset(50, 50)));
    await tester.pump(kLongPressTimeout);
    send(down(kTouchSlop * 3));
    await tester.pump();
    expect(won, isNot(contains('scroll')));
  });

  testWidgets('a sideways drag stays with the control', (tester) async {
    send(const PointerDownEvent(position: Offset(50, 50)));
    send(const PointerMoveEvent(position: Offset(50 + kTouchSlop * 3, 50)));
    await tester.pump();
    expect(won, ['native has it'], reason: 'the control took it');
  });

  testWidgets('a tap stays with the control', (tester) async {
    send(const PointerDownEvent(position: Offset(50, 50)));
    send(const PointerUpEvent(position: Offset(50, 50)));
    await tester.pump();
    expect(won, ['native has it']);
  });

  testWidgets('a held finger on the back edge still swipes back', (
    tester,
  ) async {
    // The route's back swipe, which a Flutter widget there never beats.
    final back = HorizontalDragGestureRecognizer()
      ..onStart = (_) => won.add('back');
    addTearDown(back.dispose);
    const down = PointerDownEvent(position: Offset(10, 300));
    back.addPointer(down);
    send(down);
    await tester.pump(const Duration(milliseconds: 300));
    // Slightly diagonal, as a thumb swipes. A drag recognizer counts the
    // delta, not the position.
    send(
      const PointerMoveEvent(
        position: Offset(10 + kTouchSlop * 3, 310),
        delta: Offset(kTouchSlop * 3, 10),
      ),
    );
    await tester.pump();
    // The row highlighted under the resting finger, then let go.
    expect(won, ['native has it', 'native lets go', 'back']);
  });

  testWidgets('a vertical drag on a claimed spot stays with the view', (
    tester,
  ) async {
    // A wheel in a row: the touch lands on it, so the drag spins it.
    view.dispose();
    view = inTeam(
      ScrollFriendlyPlatformViewRecognizer(
        claims: (p) => const Rect.fromLTWH(0, 0, 100, 100).contains(p),
      ),
    );
    send(const PointerDownEvent(position: Offset(50, 50)));
    send(const PointerMoveEvent(position: Offset(50, 50 + kTouchSlop * 3)));
    await tester.pump();
    expect(won, ['native has it'], reason: 'the wheel took it');
  });

  testWidgets('the factory carries the recognizer type a UiKitView compares', (
    tester,
  ) async {
    // A UiKitView swaps recognizers only when the factory types differ: a
    // set typed Factory<OneSequenceGestureRecognizer> is never replaced.
    await tester.pumpWidget(const _Probe());
    final state = tester.state<_ProbeState>(find.byType(_Probe));
    expect(
      state.scrollFriendlyGestures().single.type,
      ScrollFriendlyPlatformViewRecognizer,
    );
  });
}
