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
        theme: ThemeData(
          colorSchemeSeed: const Color(0xFF007AFF),
          useMaterial3: true,
          brightness: Brightness.light,
        ),
        darkTheme: ThemeData(
          colorSchemeSeed: const Color(0xFF007AFF),
          useMaterial3: true,
          brightness: Brightness.dark,
        ),
        themeMode: mode,
        home: const HomePage(),
      ),
    );
  }
}
