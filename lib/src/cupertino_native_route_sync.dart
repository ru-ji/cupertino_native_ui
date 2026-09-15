/// Keeps a [CupertinoNativePageScaffold]'s native NavigationStack in step with
/// whatever router the app already uses — GoRouter, auto_route, Beamer, or a
/// plain imperative [Navigator].
///
/// Scaffold bodies run in their own engines, so the app's router cannot drive
/// them directly: it is mirrored onto the native stack, and native back
/// navigation is reported back so the router can catch up.
library;

import 'cupertino_native_page_scaffold.dart';

/// One step towards a target stack. A `UINavigationController` can only push
/// one page or pop its top at a time, so a stack change is expressed as a
/// sequence of these.
sealed class CupertinoNativeStackOp {
  const CupertinoNativeStackOp();
}

/// Push [route] onto the native stack.
class CupertinoNativePushOp extends CupertinoNativeStackOp {
  final String route;
  const CupertinoNativePushOp(this.route);

  @override
  bool operator ==(Object other) =>
      other is CupertinoNativePushOp && other.route == route;

  @override
  int get hashCode => route.hashCode;

  @override
  String toString() => 'push($route)';
}

/// Pop the top of the native stack.
class CupertinoNativePopOp extends CupertinoNativeStackOp {
  const CupertinoNativePopOp();

  @override
  bool operator ==(Object other) => other is CupertinoNativePopOp;

  @override
  int get hashCode => 0;

  @override
  String toString() => 'pop()';
}

/// The ops that turn [current] into [desired].
///
/// Both lists start with the root route. The shared prefix is left alone —
/// that is what makes a native push animate as a push rather than rebuilding
/// the whole stack — then everything above it is popped, then the remainder of
/// [desired] is pushed.
///
/// The root is never popped: a scaffold always shows something. If [desired]
/// is empty or its root differs from [current]'s, the current root is kept and
/// only the pages above it are reconciled — swapping the root is a tab change,
/// not a stack operation.
List<CupertinoNativeStackOp> diffNativeStack(
  List<String> current,
  List<String> desired,
) {
  if (current.isEmpty) {
    return [for (final route in desired.skip(1)) CupertinoNativePushOp(route)];
  }
  // Keep the existing root; only pages above it are reconcilable here.
  final target = desired.isEmpty
      ? <String>[current.first]
      : <String>[current.first, ...desired.skip(1)];

  var shared = 0;
  while (shared < current.length &&
      shared < target.length &&
      current[shared] == target[shared]) {
    shared++;
  }

  return [
    for (var i = shared; i < current.length; i++) const CupertinoNativePopOp(),
    for (var i = shared; i < target.length; i++)
      CupertinoNativePushOp(target[i]),
  ];
}

/// Splits a router location into a native stack: `/library/album/track`
/// becomes `['library', 'album', 'track']`.
///
/// This is only the default convention. If your locations do not nest that
/// way, map them yourself and hand the result to
/// [CupertinoNativeRouteSync.syncTo] — the sync speaks stacks, not URLs, so it
/// never has to agree with your router about path syntax.
List<String> routesFromLocation(String location) {
  final path = Uri.parse(location).path;
  return [
    for (final segment in path.split('/'))
      if (segment.isNotEmpty) segment,
  ];
}

/// The inverse of [routesFromLocation].
String locationFromRoutes(List<String> routes) =>
    routes.isEmpty ? '/' : '/${routes.join('/')}';

/// Mirrors an app router onto a [CupertinoNativePageScaffold]'s native stack.
///
/// Wire it to a scaffold's [CupertinoNativePageScaffoldController] and feed it
/// from both directions:
///
/// ```dart
/// final controller = CupertinoNativePageScaffoldController();
/// late final sync = CupertinoNativeRouteSync(
///   controller: controller,
///   // Native back button / back-swipe happened — tell the router.
///   onNativeStackChanged: (routes) => context.go(locationFromRoutes(routes)),
/// );
///
/// CupertinoNativePageScaffold(
///   controller: controller,
///   body: 'library',
///   onRouteChanged: sync.reportNativeStack,   // native -> Dart
///   // ...
/// )
///
/// // Router moved — push/pop natively to match.
/// sync.syncTo(routesFromLocation(GoRouterState.of(context).uri.path));
/// ```
///
/// The two directions cannot fight: while [syncTo] is applying its ops, the
/// stack reports it produces are recognised as echoes and not forwarded to
/// [onNativeStackChanged].
class CupertinoNativeRouteSync {
  CupertinoNativeRouteSync({
    required this.controller,
    this.onNativeStackChanged,
    CupertinoNativePageScaffoldPage Function(String route)? pageBuilder,
  }) : pageBuilder =
           pageBuilder ??
           ((route) => CupertinoNativePageScaffoldPage(route: route));

  final CupertinoNativePageScaffoldController controller;

  /// Called when the *native* stack changed on its own — the back button, the
  /// interactive back-swipe, or a body calling
  /// [CupertinoNativePageScaffold.push]. Drive your router from here.
  ///
  /// Not called for changes this object made itself via [syncTo].
  final void Function(List<String> routes)? onNativeStackChanged;

  /// Builds the page config for a route being pushed — use it to give pushed
  /// pages their navigation bars. Defaults to a bare
  /// [CupertinoNativePageScaffoldPage] with no app bar.
  final CupertinoNativePageScaffoldPage Function(String route) pageBuilder;

  /// The last stack the native side reported. Starts empty; the scaffold
  /// reports its root as soon as it is created.
  List<String> get nativeStack => List.unmodifiable(_nativeStack);
  List<String> _nativeStack = const [];

  /// True while [syncTo] is driving the native stack, so the resulting
  /// [reportNativeStack] calls are known to be echoes of our own ops rather
  /// than user-initiated navigation.
  bool _applying = false;

  /// Feed this to [CupertinoNativePageScaffold.onRouteChanged].
  void reportNativeStack(List<String> routes) {
    _nativeStack = List.of(routes);
    if (_applying) return;
    onNativeStackChanged?.call(nativeStack);
  }

  /// Drives the native stack to [desired], pushing and popping as needed.
  ///
  /// Call it whenever your router's location changes. It is a no-op when the
  /// stack already matches, so calling it from a `build` method or a router
  /// listener is safe.
  Future<void> syncTo(List<String> desired) async {
    final ops = diffNativeStack(_nativeStack, desired);
    if (ops.isEmpty) return;

    _applying = true;
    try {
      for (final op in ops) {
        switch (op) {
          case CupertinoNativePopOp():
            await controller.pop();
          case CupertinoNativePushOp(:final route):
            await controller.push(pageBuilder(route));
        }
      }
    } finally {
      _applying = false;
    }
  }

  /// Convenience for the imperative [Navigator] style: push one page.
  Future<void> push(String route) => controller.push(pageBuilder(route));

  /// Convenience for the imperative [Navigator] style: pop the top page.
  Future<void> pop() => controller.pop();
}
