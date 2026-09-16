import 'package:flutter/material.dart';

/// The experiment: real Flutter widgets hosted inside the keyboard's own
/// toolbar, where Flutter is otherwise unreachable.
///
/// It runs in its own FlutterEngine — the same deal as a scaffold body — so
/// everything here is live Flutter: the icon is `FlutterLogo`, the counter is
/// `setState`. If this renders inside the keyboard accessory, a `UIWindow`
/// other than the app's is no obstacle to hosting Flutter; if it does not,
/// that is the answer.
class KeyboardIslandBody extends StatefulWidget {
  const KeyboardIslandBody({super.key});

  @override
  State<KeyboardIslandBody> createState() => _KeyboardIslandBodyState();
}

class _KeyboardIslandBodyState extends State<KeyboardIslandBody> {
  int _taps = 0;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 44,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const FlutterLogo(size: 24),
          const SizedBox(width: 8),
          const Text('Flutter, in the keyboard'),
          const SizedBox(width: 12),
          GestureDetector(
            onTap: () => setState(() => _taps++),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                color: Colors.blue.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(999),
              ),
              child: Text('tapped $_taps'),
            ),
          ),
        ],
      ),
    );
  }
}
