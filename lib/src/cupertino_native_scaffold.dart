import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'callbacks.dart';

import 'cupertino_native_app_bar.dart';
import 'cupertino_native_tab_bar.dart';
import 'cupertino_widgets_settings.dart';
import 'internal/native_platform_view_mixin.dart';

/// A page pushed onto a [CupertinoNativeScaffold]'s native NavigationStack.
/// [route] must match a builder registered in [CupertinoNativeScaffold.run];
/// [appBar] configures the destination's navigation bar (title, items).
class CupertinoNativeScaffoldPage {
  final String route;
  final CupertinoNativeAppBar? appBar;

  const CupertinoNativeScaffoldPage({required this.route, this.appBar});

  Map<String, dynamic> toMap() {
    return {'route': route, 'appBar': appBar?.toMap()};
  }
}

/// Snapshot of a searchable scaffold page's native search field, delivered to
/// the body isolate via [CupertinoNativeScaffold.searchState].
///
/// - [query]: the current text in the search field.
/// - [isActive]: whether the user is interacting with the field (SwiftUI's
///   `isSearching`). Use it to swap your body content for suggestions/results.
/// - [isSubmitted]: true for the single notification fired when the user hits
///   the keyboard's search/return key.
class CupertinoNativeSearchState {
  final String query;
  final bool isActive;
  final bool isSubmitted;

  const CupertinoNativeSearchState({
    this.query = '',
    this.isActive = false,
    this.isSubmitted = false,
  });

  @override
  bool operator ==(Object other) =>
      other is CupertinoNativeSearchState &&
      other.query == query &&
      other.isActive == isActive &&
      other.isSubmitted == isSubmitted;

  @override
  int get hashCode => Object.hash(query, isActive, isSubmitted);

  @override
  String toString() =>
      'CupertinoNativeSearchState(query: $query, isActive: $isActive, '
      'isSubmitted: $isSubmitted)';
}

/// Drives a [CupertinoNativeScaffold]'s navigation from the host isolate
/// (the widget tree that created the scaffold). Inside body isolates use the
/// static [CupertinoNativeScaffold.push]/[CupertinoNativeScaffold.pop].
class CupertinoNativeScaffoldController {
  MethodChannel? _channel;

  Future<void> push(CupertinoNativeScaffoldPage page) async {
    await _channel?.invokeMethod('push', page.toMap());
  }

  /// Pushes [route] with no navigation bar of its own — the string-only form
  /// of [push], for when you don't need to configure the destination's bar.
  Future<void> pushNamed(String route) =>
      push(CupertinoNativeScaffoldPage(route: route));

  Future<void> pop() async {
    await _channel?.invokeMethod('pop');
  }
}

/// A pure SwiftUI scaffold: native NavigationStack (+ optional TabView) whose
/// pages are Flutter bodies embedded in native ScrollViews.
///
/// Native behaviors preserved: large-title collapse on scroll, tab bar
/// minimize (iOS 26), `.search` tab role (iOS 18+), system push/pop
/// transitions with toolbar morphing, and interactive back-swipe.
///
/// Navigation between scaffold pages happens on the NATIVE stack via
/// [CupertinoNativeScaffoldController.push] (host isolate) or the static
/// [push] (body isolates) — not Flutter's Navigator. Each body runs in its
/// own FlutterEngine. Register the route builders by calling [maybeRun] at
/// the top of your `main()` (no entry point needed). Requires iOS 16+.
class CupertinoNativeScaffold extends StatefulWidget {
  /// Root body route when no [tabBar] is given. With a [tabBar], each tab's
  /// `id` doubles as its body route.
  final String? body;

  /// Root navigation-bar config (also applied to each tab's root page).
  final CupertinoNativeAppBar? appBar;

  /// Optional native tab bar; enables tabbed mode.
  final CupertinoNativeTabBar? tabBar;

  final CupertinoNativeScaffoldController? controller;
  final CupertinoNativeBarActionCallback? onBarAction;
  final ValueChanged<String>? onTabChanged;

  /// iOS 26 scroll edge effect style for the native scroll views.
  final CupertinoScrollEdgeEffectStyle scrollEdgeEffect;

  /// Background color for the scaffold. Defaults to
  /// [Theme.of(context).scaffoldBackgroundColor].
  final Color? backgroundColor;

  /// Primary/accent color used for interactive elements (buttons, toggles,
  /// etc.). Defaults to [Theme.of(context).colorScheme.primary].
  final Color? activeColor;

  /// Reports the current tab's native stack (root route first) whenever a
  /// push/pop happens — including native back button and back-swipe.
  final CupertinoNativeRouteChangedCallback? onRouteChanged;

  /// Fires on every keystroke in a page's [CupertinoNativeAppBar.search] field.
  /// [route] is the searchable page's root route.
  final CupertinoNativeSearchCallback? onSearchChanged;

  /// Fires when the user submits the search (keyboard search/return key).
  final CupertinoNativeSearchCallback? onSearchSubmitted;

  /// Fires when a search field becomes active/inactive (SwiftUI `isSearching`).
  final CupertinoNativeSearchActiveCallback? onSearchActiveChanged;

  const CupertinoNativeScaffold({
    super.key,
    this.body,
    this.appBar,
    this.tabBar,
    this.controller,
    this.onBarAction,
    this.onTabChanged,
    this.scrollEdgeEffect = CupertinoScrollEdgeEffectStyle.automatic,
    this.backgroundColor,
    this.activeColor,
    this.showLoadingIndicator,
    this.onRouteChanged,
    this.onSearchChanged,
    this.onSearchSubmitted,
    this.onSearchActiveChanged,
  }) : assert(
         tabBar != null || body != null,
         'Provide a tabBar (tab ids double as body routes) or a body route',
       );

  /// Whether a native spinner shows while a body engine boots and renders
  /// its first frame. Defaults to the global
  /// [CupertinoWidgetsSettings.showLoadingIndicator] (off).
  final bool? showLoadingIndicator;

  /// Well-known channel the native side attaches to every body engine.
  static const MethodChannel _bodyChannel = MethodChannel(
    'cupertino_widgets/scaffold_body',
  );

  /// Route prefix used by body engines so that [maybeRun] can intercept and
  /// `main()` with `cn-scaffold://<route>` as the initial route.
  static const String _routePrefix = 'cn-scaffold://';

  static final ValueNotifier<CupertinoNativeSearchState> _searchState =
      ValueNotifier(const CupertinoNativeSearchState());

  /// The enclosing scaffold page's live search state. Only meaningful inside
  /// body isolates whose [CupertinoNativeAppBar] declares a
  /// [CupertinoNativeSearchField]. Drive your body with a
  /// [ValueListenableBuilder] on this to render search suggestions, results
  /// and a loading indicator below the native search bar.
  static ValueListenable<CupertinoNativeSearchState> get searchState =>
      _searchState;

  /// The host app's brightness, pushed into each body engine so a body's
  /// Flutter content matches the app (not the device). Null until seeded.
  /// Used by [_DynamicEnvWrapper]; seeded from the `?dark=` route param and
  /// updated by the `setBrightness` body-channel call.
  static final ValueNotifier<bool?> _bodyIsDark = ValueNotifier<bool?>(null);

  /// Strips and applies a `?dark=0|1` suffix from a body route, returning the
  /// bare route name. Safe to call with a route that has no query.
  static String _consumeBrightnessQuery(String route) {
    final q = route.indexOf('?');
    if (q < 0) return route;
    final query = route.substring(q + 1);
    final dark = Uri.splitQueryString(query)['dark'];
    if (dark != null) _bodyIsDark.value = dark == '1';
    return route.substring(0, q);
  }

  static bool _bodyHandlersInstalled = false;

  /// Registers the body engine's handler for native → Dart callbacks (search
  /// state, ...). Idempotent; called from [maybeRun]/[run].
  static void _ensureBodyHandlers() {
    if (_bodyHandlersInstalled) return;
    _bodyHandlersInstalled = true;
    // maybeRun/run execute at the very top of main(), before runApp — so the
    // binary messenger isn't up yet. Setting a channel handler (or invoking a
    // method) before the binding is initialized throws and aborts the body's
    // main(), leaving the body blank. Initialize the binding first.
    WidgetsFlutterBinding.ensureInitialized();
    _bodyChannel.setMethodCallHandler((call) async {
      if (call.method == 'onScaffoldSearch') {
        final args = call.arguments as Map?;
        _searchState.value = CupertinoNativeSearchState(
          query: args?['query'] as String? ?? '',
          isActive: args?['isActive'] as bool? ?? false,
          isSubmitted: args?['isSubmitted'] as bool? ?? false,
        );
      } else if (call.method == 'setBrightness') {
        final isDark = (call.arguments as Map?)?['isDark'] as bool?;
        if (isDark != null) _bodyIsDark.value = isDark;
      }
      return null;
    });
    // Pull the app's brightness once on startup so the body matches the app
    // from the first frame (falls back to device brightness until it arrives).
    _bodyChannel
        .invokeMethod<bool>('getBrightness')
        .then((isDark) {
          if (isDark != null) _bodyIsDark.value = isDark;
        })
        .catchError((_) {});
  }

  /// Pays body-engine start-up costs ahead of time.
  ///
  /// The scaffold runs each body in its own FlutterEngine. Called with no
  /// arguments, this spawns a hidden warm-up engine so the engine group's
  /// first-spawn cost (snapshot load, isolate-group creation) is paid early.
  ///
  /// Pass [routes] to go further: one engine per route is **fully booted** —
  /// `main()` runs, the route's builder executes, `runApp` is called — and
  /// parked. The first scaffold or sheet that opens that route attaches the
  /// parked engine instead of booting one, so its Flutter content appears
  /// immediately:
  ///
  /// ```dart
  /// runApp(const MyApp());
  /// CupertinoNativeScaffold.prewarm(routes: ['home']);
  /// ```
  ///
  /// Each parked engine holds its isolate in memory (~a few MB), so prewarm
  /// the routes users actually hit first, not the whole table. Note: debug
  /// builds JIT-compile Dart on top of all this — judge real latency in
  /// `--release`.
  static Future<void> prewarm({List<String> routes = const []}) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    final isDark =
        ui.PlatformDispatcher.instance.platformBrightness == ui.Brightness.dark;
    try {
      await const MethodChannel('com.example.cupertino_widgets/alert')
          .invokeMethod<void>('prewarmScaffold', {
            'routes': routes,
            'isDark': isDark,
          });
    } on PlatformException {
      // Plugin unavailable (e.g. iOS < 15) — nothing to warm.
    }
  }

  /// Call as the FIRST line of `main()`:
  /// `if (CupertinoNativeScaffold.maybeRun(routes)) return;`
  ///
  /// Returns true when this isolate is a scaffold body engine, in which case
  /// the matching route builder has been run and `main()` must not continue
  /// to `runApp`. Returns false in the regular app isolate.
  static bool maybeRun(Map<String, Widget Function()> builders) {
    final route = ui.PlatformDispatcher.instance.defaultRouteName;
    if (!route.startsWith(_routePrefix)) return false;
    // Route is `cn-scaffold://<name>?dark=0|1`; consume the brightness suffix.
    final name = _consumeBrightnessQuery(route.substring(_routePrefix.length));
    // The hidden engine spawned by [prewarm]: render nothing and keep the
    // engine group warm.
    if (name == '_warmup') {
      runApp(const SizedBox.shrink());
      return true;
    }
    final builder = builders[name];
    final child = builder != null ? builder() : Text('Unknown route: $name');
    _ensureBodyHandlers();
    runApp(_DynamicEnvWrapper(child: _withExplicitWidth(child)));
    return true;
  }

  /// Call this inside your `@pragma('vm:entry-point')` function. It reads the
  /// route from the engine's initial route and runs the matching builder.
  static void run(Map<String, Widget Function()> builders) {
    final route = _consumeBrightnessQuery(
      ui.PlatformDispatcher.instance.defaultRouteName,
    );
    final builder = builders[route];

    // Wrap the body in basic inherited widgets only (no Scaffold/MaterialApp,
    // which expand to infinity) so the SwiftUI side can size it to its
    // natural height and let the native ScrollView own scrolling.
    final child = builder != null ? builder() : const Text('Unknown route');

    _ensureBodyHandlers();
    runApp(_DynamicEnvWrapper(child: _withExplicitWidth(child)));
  }

  /// The auto-resizable engine lays the root out with UNBOUNDED constraints
  /// and requires the top-level widget to pick explicit dimensions (the
  /// native view then adopts that size). Width = the screen; height comes
  /// from the content.
  static Widget _withExplicitWidth(Widget child) {
    final dispatcher = ui.PlatformDispatcher.instance;
    double width = 0;
    if (dispatcher.displays.isNotEmpty) {
      final display = dispatcher.displays.first;
      if (display.size.width > 0) {
        width = display.size.width / display.devicePixelRatio;
      }
    }
    if (width <= 0 && dispatcher.views.isNotEmpty) {
      final view = dispatcher.views.first;
      if (view.physicalSize.width > 0) {
        width = view.physicalSize.width / view.devicePixelRatio;
      }
    }
    if (width <= 0) width = 400; // last resort
    return SizedBox(width: width, child: child);
  }

  /// Pushes a page onto the enclosing scaffold's native stack. Only usable
  /// inside body isolates (widgets built via [run]).
  static Future<void> push(CupertinoNativeScaffoldPage page) {
    return _bodyChannel.invokeMethod('push', page.toMap());
  }

  /// Pushes [route] with no navigation bar of its own — the string-only form
  /// of [push]. Only usable inside body isolates.
  static Future<void> pushNamed(String route) =>
      push(CupertinoNativeScaffoldPage(route: route));

  /// Pops the enclosing scaffold's native stack. Only usable inside body
  /// isolates; the system back button and back-swipe also pop natively.
  static Future<void> pop() {
    return _bodyChannel.invokeMethod('pop');
  }

  /// Updates the root navigation bar's title. Only usable inside body isolates.
  static Future<void> setTitle(String title) {
    return _bodyChannel.invokeMethod('setTitle', {'title': title});
  }

  @override
  State<CupertinoNativeScaffold> createState() =>
      _CupertinoNativeScaffoldState();
}

/// Keeps body isolates in sync with platform brightness/locale changes,
/// since they run without a MaterialApp.
class _DynamicEnvWrapper extends StatefulWidget {
  final Widget child;
  const _DynamicEnvWrapper({required this.child});

  @override
  State<_DynamicEnvWrapper> createState() => _DynamicEnvWrapperState();
}

class _DynamicEnvWrapperState extends State<_DynamicEnvWrapper>
    with WidgetsBindingObserver {
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    CupertinoNativeScaffold._bodyIsDark.addListener(_onBrightnessChanged);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    CupertinoNativeScaffold._bodyIsDark.removeListener(_onBrightnessChanged);
    super.dispose();
  }

  void _onBrightnessChanged() {
    if (mounted) setState(() {}); // Host app toggled light/dark.
  }

  @override
  void didChangePlatformBrightness() {
    setState(() {}); // Trigger rebuild on theme change
  }

  @override
  void didChangeLocales(List<Locale>? locales) {
    setState(() {}); // Trigger rebuild on locale change
  }

  @override
  Widget build(BuildContext context) {
    final platformDispatcher = ui.PlatformDispatcher.instance;
    // Prefer the host app's brightness (pushed from the scaffold) so a body's
    // Flutter content matches the app; fall back to the device brightness.
    final override = CupertinoNativeScaffold._bodyIsDark.value;
    final brightness = override != null
        ? (override ? ui.Brightness.dark : ui.Brightness.light)
        : platformDispatcher.platformBrightness;
    final locale = platformDispatcher.locales.isNotEmpty
        ? platformDispatcher.locales.first
        : const Locale('en', 'US');

    // Body isolates run without a WidgetsApp, so no MediaQuery exists —
    // and without one, every CupertinoDynamicColor.resolveFrom falls back
    // to LIGHT regardless of the app/device brightness. Provide one with
    // the effective brightness so dynamic colors resolve correctly.
    return MediaQuery(
      data: MediaQueryData.fromView(View.of(context))
          .copyWith(platformBrightness: brightness),
      child: Directionality(
        textDirection: TextDirection.ltr,
        child: Localizations(
          locale: locale,
          delegates: const <LocalizationsDelegate<dynamic>>[
            DefaultWidgetsLocalizations.delegate,
            DefaultMaterialLocalizations.delegate,
          ],
          child: Theme(
            data: brightness == ui.Brightness.dark
                ? ThemeData.dark()
                : ThemeData.light(),
            // Ensure the main widget takes the full width but its natural height.
            // Material provides the default text styles so text isn't white-on-white.
            child: Material(
              type: MaterialType.transparency,
              child: widget.child,
            ),
          ),
        ),
      ),
    );
  }
}

class _CupertinoNativeScaffoldState extends State<CupertinoNativeScaffold>
    with NativePlatformViewStateMixin {
  /// Number of routes on the current native stack (root route + pushed pages).
  /// When > 1, a page is pushed on the native NavigationStack and the Flutter
  /// route's iOS swipe-back gesture is suppressed so it doesn't compete with
  /// the native back-swipe.
  int _nativeStackDepth = 1;

  /// The scaffold IS the page: it must never be swapped for a photograph
  /// while a route animates above it — the whole page would freeze mid-slide.
  @override
  bool get hidesDuringRouteTransition => false;

  /// The APP's brightness (its Material theme), propagated to the native
  /// SwiftUI views so they match the app — e.g. light content when the app is
  /// light even if the device is in dark mode. Re-synced dynamically when the
  /// app theme changes (see [didChangeDependencies]/[_syncBrightness]).
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  bool? _lastIsDark;

  Map<String, dynamic> _toMap() {
    final theme = Theme.of(context);
    return {
      'body': widget.body,
      'appBar': widget.appBar?.toMap(),
      'tabBar': widget.tabBar?.toMap(),
      'scrollEdgeEffect': widget.scrollEdgeEffect.name,
      'isDark': _isDark,
      'backgroundColor':
          widget.backgroundColor?.toARGB32() ??
          theme.scaffoldBackgroundColor.toARGB32(),
      'primaryColor':
          widget.activeColor?.toARGB32() ??
          theme.colorScheme.primary.toARGB32(),
      'showLoadingIndicator':
          widget.showLoadingIndicator ??
          CupertinoWidgetsSettings.showLoadingIndicator,
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBrightness();
    _watchRoute();
  }

  /// The route whose animations are watched for [_refreshLayoutMargins].
  ModalRoute<Object?>? _route;

  void _watchRoute() {
    final route = ModalRoute.of(context);
    if (identical(route, _route)) return;
    _unwatchRoute();
    _route = route;
    route?.animation?.addStatusListener(_onRouteStatus);
    route?.secondaryAnimation?.addStatusListener(_onRouteStatus);
  }

  void _unwatchRoute() {
    _route?.animation?.removeStatusListener(_onRouteStatus);
    _route?.secondaryAnimation?.removeStatusListener(_onRouteStatus);
  }

  /// UIKit derives the large title's inset from where the native view sits
  /// on screen, and during a route slide it sits off screen: it gets zero and
  /// keeps it. Once the slide settles, have it derive the margins again.
  void _onRouteStatus(AnimationStatus status) {
    if (status.isAnimating) return;
    channel?.invokeMethod('refreshLayoutMargins');
  }

  @override
  void dispose() {
    _unwatchRoute();
    super.dispose();
  }

  void _syncBrightness() {
    final isDark = _isDark;
    if (_lastIsDark == isDark) return;
    // Don't commit _lastIsDark until the channel is ready; otherwise the
    // first didChangeDependencies (before _onPlatformViewCreated) eats the
    // value and the real send never happens.
    if (channel == null) return;
    _lastIsDark = isDark;
    channel!.invokeMethod('setBrightness', {'isDark': isDark});
  }

  @override
  void didUpdateWidget(covariant CupertinoNativeScaffold oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldMap = {
      'body': oldWidget.body,
      'appBar': oldWidget.appBar?.toMap(),
      'tabBar': oldWidget.tabBar?.toMap(),
      'scrollEdgeEffect': oldWidget.scrollEdgeEffect.name,
    };
    // Configs are nested maps of primitives; JSON comparison is a simple
    // deep-equality check.
    if (jsonEncode(oldMap) != jsonEncode(_toMap())) {
      updateNativeView('updateScaffold', _toMap(), refreshIntrinsicSize: false);
    }
  }

  Future<void> _onPlatformViewCreated(int id) async {
    setUpChannel(
      id,
      'cupertino_widgets/scaffold_$id',
      onMethodCall: _handleMethodCall,
    );
    widget.controller?._channel = channel;
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onBarAction':
        final String? route = call.arguments['route'];
        final String? id = call.arguments['id'];
        if (route != null && id != null) {
          widget.onBarAction?.call(route, id);
        }
        break;
      case 'onTabChanged':
        final String? selection = call.arguments['selection'];
        if (selection != null) {
          widget.onTabChanged?.call(selection);
        }
        break;
      case 'onRouteChanged':
        final List<dynamic>? routes = call.arguments['routes'];
        if (routes != null) {
          final depth = routes.length;
          if (depth != _nativeStackDepth) {
            setState(() => _nativeStackDepth = depth);
          }
          widget.onRouteChanged?.call(routes.cast<String>());
        }
        break;
      case 'onSearchChanged':
        {
          final String? route = call.arguments['route'];
          final String? query = call.arguments['query'];
          if (route != null && query != null) {
            widget.onSearchChanged?.call(route, query);
          }
        }
        break;
      case 'onSearchSubmitted':
        {
          final String? route = call.arguments['route'];
          final String? query = call.arguments['query'];
          if (route != null && query != null) {
            widget.onSearchSubmitted?.call(route, query);
          }
        }
        break;
      case 'onSearchActiveChanged':
        {
          final String? route = call.arguments['route'];
          final bool? active = call.arguments['active'];
          if (route != null && active != null) {
            widget.onSearchActiveChanged?.call(route, active);
          }
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return const Center(child: Text('CupertinoNativeScaffold is iOS only'));
    }

    final platformView = UiKitView(
      viewType: 'com.example.cupertino_widgets/cupertino_native_scaffold',
      layoutDirection: TextDirection.ltr,
      creationParams: _toMap(),
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _onPlatformViewCreated,
    );

    // When a page is pushed on the native NavigationStack, suppress the
    // Flutter route's iOS back-swipe gesture so it doesn't compete with the
    // native one. At the root level, let the Flutter back-swipe proceed so the
    // user can pop the scaffold page itself.
    return PopScope(canPop: _nativeStackDepth <= 1, child: platformView);
  }
}
