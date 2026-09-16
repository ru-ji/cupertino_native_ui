import 'package:flutter/widgets.dart';

/// Your own Flutter, hosted inside a native surface that Flutter cannot
/// otherwise reach — the keyboard toolbar, a glass container, a native body.
///
/// It runs in its own FlutterEngine, so it is named by [route] rather than
/// passed as a widget: engines are isolates, and a widget written here lives
/// in this isolate's heap where the hosting one cannot reach it. Register the
/// route in `CupertinoNativePageScaffold.maybeRun`, like a scaffold body.
///
/// ```dart
/// keyboardToolbar: [
///   const CupertinoNativeFlutterView('editorBar'),
///   const Spacer(),
///   CupertinoNativeButton(onPressed: done, child: const Text('Done')),
/// ]
/// ```
///
/// **This is the expensive item.** One view is one isolate, booted the first
/// time it appears and kept for the process's lifetime. A row of
/// [CupertinoNativeButton]s costs nothing; this costs what a scaffold body
/// costs. Use it where the content genuinely has to be your Flutter.
class CupertinoNativeFlutterView extends StatelessWidget {
  const CupertinoNativeFlutterView(this.route, {super.key});

  /// A body route registered in `maybeRun`.
  final String route;

  @override
  Widget build(BuildContext context) {
    // Never mounted where it is written: the surfaces that accept it read the
    // route off the widget and host the engine themselves.
    return const SizedBox.shrink();
  }
}
