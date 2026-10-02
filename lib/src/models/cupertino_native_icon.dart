import 'dart:ui' show Color, FontWeight;

import 'cupertino_symbols.dart';
import '../internal/native_color.dart';

/// A native SF Symbol, described for the native side (a button, a bar, a list
/// row, a menu).
///
/// - [CupertinoNativeIcon.symbol] takes a typo-safe [CupertinoSymbols] value.
/// - [CupertinoNativeIcon.named] takes any raw SF Symbol name the
///   [CupertinoSymbols] enum does not cover.
///
/// To show a symbol in the Flutter tree instead, use `CupertinoSymbolImage`.
class CupertinoNativeIcon {
  /// The SF Symbol name, e.g. `star.fill`.
  final String sfSymbol;

  /// Rendering mode.
  final CupertinoSymbolRenderingMode? renderingMode;

  /// Point size. Null uses the host control's default sizing.
  final double? size;

  /// Icon color/tint. Null inherits the control's foreground/tint.
  final Color? color;

  /// Stroke weight. Null keeps the control's own (regular).
  final FontWeight? weight;

  /// A typo-safe SF Symbol from the [CupertinoSymbols] enum.
  CupertinoNativeIcon.symbol(
    CupertinoSymbols symbol, {
    this.size,
    this.color,
    this.weight,
    this.renderingMode,
  }) : sfSymbol = symbol.value;

  /// A raw SF Symbol name, for symbols not covered by [CupertinoSymbols].
  const CupertinoNativeIcon.named(
    this.sfSymbol, {
    this.size,
    this.color,
    this.weight,
    this.renderingMode,
  });

  /// A copy whose [size] falls back to [fallback] when unset.
  CupertinoNativeIcon withDefaultSize(double fallback) => size != null
      ? this
      : CupertinoNativeIcon.named(
          sfSymbol,
          renderingMode: renderingMode,
          size: fallback,
          color: color,
          weight: weight,
        );

  Map<String, dynamic> toMap({bool isDark = false}) {
    return {
      'sfSymbol': sfSymbol,
      'renderingMode': renderingMode?.name,
      'size': size,
      'color': nativeArgb(color, isDark: isDark),
      'weight': weight == null ? null : _weightName(weight!),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CupertinoNativeIcon &&
        other.sfSymbol == sfSymbol &&
        other.renderingMode == renderingMode &&
        other.size == size &&
        other.color == color &&
        other.weight == weight;
  }

  @override
  int get hashCode => Object.hash(sfSymbol, renderingMode, size, color, weight);

  static String _weightName(FontWeight w) => switch (w.value) {
    <= 300 => 'light',
    >= 700 => 'bold',
    >= 600 => 'semibold',
    >= 500 => 'medium',
    _ => 'regular',
  };
}
