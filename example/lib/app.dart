import 'package:flutter/cupertino.dart' show CupertinoColors;
import 'package:flutter/material.dart';

import 'pages/home_page.dart';

/// Root app. This stays a [MaterialApp] on purpose: the plugin's platform
/// views read `Theme.of(context)` to sync light/dark with the native side,
/// and Material's iOS defaults give Cupertino page transitions. Every visible
/// screen, however, is built from Cupertino + native widgets.
class MyApp extends StatelessWidget {
  const MyApp({super.key});

  /// App-wide theme mode — toggled by the home app bar's brightness action.
  /// Starts on the device setting.
  static final ValueNotifier<ThemeMode> themeMode = ValueNotifier<ThemeMode>(
    ThemeMode.system,
  );

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeMode,
      builder: (context, mode, _) => MaterialApp(
        title: 'Cupertino Widgets',
        debugShowCheckedModeBanner: false,
        // Pages default to the system background a CupertinoPageScaffold
        // starts from: the one colour on which the scroll edge effect adapts
        // to its content, as the system's does on a page without a
        // `.background`.
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF007AFF),
          useMaterial3: true,
          brightness: Brightness.light,
          scaffoldBackgroundColor: CupertinoColors.systemBackground.color,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: const Color(0xFF007AFF),
          useMaterial3: true,
          brightness: Brightness.dark,
          scaffoldBackgroundColor: CupertinoColors.systemBackground.darkColor,
        ),
        themeMode: mode,
        // No cross-fade: native views take the theme's brightness, which a
        // lerping theme flips at its midpoint — so they snapped mid-fade
        // while the Flutter background was still grey.
        themeAnimationDuration: Duration.zero,
        // Every page is a CupertinoPageScaffold, which is not a Material —
        // so a bare `Text` fell back to Flutter's debug style, the yellow
        // underline. One transparent Material at the root gives every page a
        // text style to inherit, and paints nothing.
        builder: (context, child) =>
            Material(type: MaterialType.transparency, child: child!),
        home: const HomePage(),
      ),
    );
  }
}
