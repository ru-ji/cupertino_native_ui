import 'package:flutter/widgets.dart';

/// Marks a navigation bar's leading and trailing slots, so a
/// [CupertinoNativeButton] inside one draws as a bar button rather than a
/// free-standing one:
///
/// * its symbol is medium, at the large scale of the body size;
/// * on iOS 26 its title is medium too; in the iOS 15–18 bar it is regular,
///   and semibold for a `glassProminent` button: UIKit's Done style;
/// * in the iOS 15–18 bar, an icon-only button hugs its glyph, as a
///   `UIBarButtonItem` does, instead of centring it in a 44pt square that
///   would push it off the bar's 8pt / 16pt insets.
///
/// The weights were measured on Settings and Notes, iOS 26 and iOS 18,
/// against SF Symbols and SF Pro rendered at each weight. A label that sets
/// its own weight keeps it.
///
/// It also carries the brightness of the content under the bar, measured
/// under the scroll edge effect's wash: a bar button takes its appearance
/// from it, as the system's bar items take theirs from the content under
/// their edge effect, not from the wash right behind them.
class BarSlot extends InheritedWidget {
  const BarSlot({super.key, this.brightness, required super.child});

  /// The content under the bar; null until measured, and then the app's
  /// theme stands in.
  final Brightness? brightness;

  static bool isIn(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BarSlot>() != null;

  /// [brightness] of the enclosing slot, or null outside one.
  static Brightness? brightnessOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<BarSlot>()?.brightness;

  @override
  bool updateShouldNotify(BarSlot oldWidget) =>
      brightness != oldWidget.brightness;
}
