import 'package:flutter/widgets.dart';

/// Marks a navigation bar's leading and trailing slots, so a
/// [CupertinoNativeButton] inside one draws as a bar button rather than a
/// free-standing one:
///
/// * its symbol is medium, at the large scale of the body size;
/// * on iOS 26 its title is medium too; in the iOS 15–18 bar it is regular,
///   and semibold for a `glassProminent` button — UIKit's Done style;
/// * in the iOS 15–18 bar, an icon-only button hugs its glyph, as a
///   `UIBarButtonItem` does, instead of centring it in a 44pt square that
///   would push it off the bar's 8pt / 16pt insets.
///
/// The weights were measured on Settings and Notes, iOS 26 and iOS 18,
/// against SF Symbols and SF Pro rendered at each weight. A label that sets
/// its own weight keeps it.
class BarSlot extends InheritedWidget {
  const BarSlot({super.key, required super.child});

  static bool isIn(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BarSlot>() != null;

  @override
  bool updateShouldNotify(BarSlot oldWidget) => false;
}
