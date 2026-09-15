import 'package:cupertino_widgets/cupertino_widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('diffNativeStack', () {
    test('no change produces no ops', () {
      expect(diffNativeStack(['home'], ['home']), isEmpty);
      expect(diffNativeStack(['home', 'a'], ['home', 'a']), isEmpty);
    });

    test('pushing keeps the shared prefix so the push animates', () {
      expect(diffNativeStack(['home'], ['home', 'a']), [
        const CupertinoNativePushOp('a'),
      ]);
      expect(diffNativeStack(['home', 'a'], ['home', 'a', 'b']), [
        const CupertinoNativePushOp('b'),
      ]);
    });

    test('popping back to the root', () {
      expect(diffNativeStack(['home', 'a', 'b'], ['home']), [
        const CupertinoNativePopOp(),
        const CupertinoNativePopOp(),
      ]);
    });

    test('diverging stacks pop to the fork then push', () {
      expect(diffNativeStack(['home', 'a', 'b'], ['home', 'a', 'c']), [
        const CupertinoNativePopOp(),
        const CupertinoNativePushOp('c'),
      ]);
    });

    test('the root is never popped', () {
      // A different desired root is a tab change, not a stack op: keep ours.
      final ops = diffNativeStack(['home', 'a'], ['settings']);
      expect(ops, [const CupertinoNativePopOp()]);
      expect(ops.whereType<CupertinoNativePushOp>(), isEmpty);

      expect(diffNativeStack(['home'], []), isEmpty);
    });

    test('an empty current stack only pushes above the root', () {
      expect(diffNativeStack([], ['home', 'a']), [
        const CupertinoNativePushOp('a'),
      ]);
    });
  });

  group('location mapping', () {
    test('round-trips', () {
      expect(routesFromLocation('/library/album'), ['library', 'album']);
      expect(locationFromRoutes(['library', 'album']), '/library/album');
      expect(routesFromLocation('/'), isEmpty);
      expect(locationFromRoutes([]), '/');
    });

    test('ignores query strings and repeated slashes', () {
      expect(routesFromLocation('/a//b?q=1'), ['a', 'b']);
    });
  });

  group('CupertinoNativeRouteSync', () {
    test('forwards native-initiated stack changes to the router', () {
      final captured = <List<String>>[];
      final sync = CupertinoNativeRouteSync(
        controller: CupertinoNativePageScaffoldController(),
        onNativeStackChanged: captured.add,
      );

      sync.reportNativeStack(['home']);
      sync.reportNativeStack(['home', 'details']);

      expect(captured, [
        ['home'],
        ['home', 'details'],
      ]);
      expect(sync.nativeStack, ['home', 'details']);
    });

    test('does not echo its own pushes back to the router', () async {
      final captured = <List<String>>[];
      // No scaffold is attached, so the controller's channel is null and the
      // ops are no-ops — enough to exercise the echo guard.
      final sync = CupertinoNativeRouteSync(
        controller: CupertinoNativePageScaffoldController(),
        onNativeStackChanged: captured.add,
      );
      sync.reportNativeStack(['home']);
      captured.clear();

      // Native reports the new stack while syncTo is still applying: that is
      // our own push coming back, not the user navigating.
      final pending = sync.syncTo(['home', 'details']);
      sync.reportNativeStack(['home', 'details']);
      await pending;

      expect(captured, isEmpty);

      // Once applying has finished, real user navigation flows again.
      sync.reportNativeStack(['home']);
      expect(captured, [
        ['home'],
      ]);
    });

    test('syncTo is a no-op when the stack already matches', () async {
      final sync = CupertinoNativeRouteSync(
        controller: CupertinoNativePageScaffoldController(),
      );
      sync.reportNativeStack(['home', 'details']);
      // Safe to call repeatedly from a build method or router listener.
      await sync.syncTo(['home', 'details']);
      expect(sync.nativeStack, ['home', 'details']);
    });
  });
}
