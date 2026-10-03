import 'package:flutter/cupertino.dart';

/// A colour as the native side reads it: ARGB, with a [CupertinoDynamicColor]
/// resolved for the app's brightness. `toARGB32()` on one ships its light
/// variant whatever the theme: `CupertinoColors.label` came out black on a
/// dark page.
int? nativeArgb(Color? color, {required bool isDark}) => switch (color) {
  null => null,
  final CupertinoDynamicColor c => (isDark ? c.darkColor : c.color).toARGB32(),
  final c => c.toARGB32(),
};
