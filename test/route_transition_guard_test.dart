import 'package:cupertino_widgets/src/internal/native_platform_view_mixin.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';

class _Probe extends StatefulWidget {
  const _Probe({super.key});
  @override
  State<_Probe> createState() => _ProbeState();
}

class _ProbeState extends State<_Probe> with NativePlatformViewStateMixin {
  @override
  Widget build(BuildContext context) =>
      wrapForTransition(const SizedBox(width: 10, height: 10));
}

void main() {
  testWidgets('guards a covered page, never an arriving or leaving one', (
    tester,
  ) async {
    debugDefaultTargetPlatformOverride = TargetPlatform.iOS;
    final home = GlobalKey<_ProbeState>();
    final pushed = GlobalKey<_ProbeState>();
    final nav = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      CupertinoApp(
        navigatorKey: nav,
        home: _Probe(key: home),
      ),
    );
    expect(home.currentState!.debugGuardingRouteTransition, isFalse);

    nav.currentState!.push(
      CupertinoPageRoute<void>(builder: (_) => _Probe(key: pushed)),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Mid-push: the covered page is guarded, the arriving one is not.
    expect(home.currentState!.debugGuardingRouteTransition, isTrue);
    expect(pushed.currentState!.debugGuardingRouteTransition, isFalse);

    await tester.pumpAndSettle();
    // Still covered: keeps its photo for when it is uncovered.
    expect(home.currentState!.debugGuardingRouteTransition, isTrue);
    expect(pushed.currentState!.debugGuardingRouteTransition, isFalse);

    nav.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    // Mid-pop: the uncovered page shows its photo; the leaving one stays
    // live — photographing it as the pop starts held the main thread long
    // enough to lose a back swipe under the finger.
    expect(pushed.currentState!.debugGuardingRouteTransition, isFalse);
    expect(home.currentState!.debugGuardingRouteTransition, isTrue);

    await tester.pumpAndSettle();
    expect(home.currentState!.debugGuardingRouteTransition, isFalse);
    debugDefaultTargetPlatformOverride = null;
  });
}
