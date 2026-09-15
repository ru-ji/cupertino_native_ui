import 'dart:ui' show Color;

import 'package:flutter/widgets.dart' show IconData;

import 'cupertino_symbols.dart';

/// A native icon that can be rendered on iOS either from an
/// [SF Symbol](https://developer.apple.com/sf-symbols/) or from a Flutter
/// [IconData] (any icon package — CupertinoIcons, MaterialIcons, FontAwesome,
/// a custom font, …).
///
/// - Use [CupertinoNativeIcon.symbol] for a typo-safe [CupertinoSymbols] value.
/// - Use [CupertinoNativeIcon.named] for any raw SF Symbol string not covered
///   by the [CupertinoSymbols] enum.
/// - Use [CupertinoNativeIcon.flutter] to render a Flutter [IconData] glyph
///   natively; the icon's font is loaded from the app bundle at runtime.
///
/// Exactly one of [sfSymbol] or [codePoint] is non-null.
class CupertinoNativeIcon {
  /// The SF Symbol name (e.g. `star.fill`), or null when this is a Flutter icon.
  final String? sfSymbol;

  /// Rendering mode for SF Symbols. Ignored for Flutter icons.
  final CupertinoSymbolRenderingMode? renderingMode;

  /// The Flutter glyph code point, or null when this is an SF Symbol.
  final int? codePoint;

  /// The effective font family for a Flutter icon, resolved the same way
  /// Flutter's `Icon` widget does — including the `packages/<pkg>/` prefix when
  /// the font ships in a package. This string is what appears in the app's
  /// `FontManifest.json`, which the native side uses to locate the font.
  final String? fontFamily;

  /// The original font package name (informational; [fontFamily] already
  /// encodes it). Null for icons that aren't in a package.
  final String? fontPackage;

  /// Point size. Null uses the host control's default sizing.
  final double? size;

  /// Icon color/tint. Null inherits the control's foreground/tint.
  final Color? color;

  const CupertinoNativeIcon._({
    this.sfSymbol,
    this.renderingMode,
    this.codePoint,
    this.fontFamily,
    this.fontPackage,
    this.size,
    this.color,
  });

  /// A copy whose [size] falls back to [fallback] when unset.
  CupertinoNativeIcon withDefaultSize(double fallback) => size != null
      ? this
      : CupertinoNativeIcon._(
          sfSymbol: sfSymbol,
          renderingMode: renderingMode,
          codePoint: codePoint,
          fontFamily: fontFamily,
          fontPackage: fontPackage,
          size: fallback,
          color: color,
        );

  /// A typo-safe SF Symbol from the [CupertinoSymbols] enum.
  CupertinoNativeIcon.symbol(
    CupertinoSymbols symbol, {
    double? size,
    Color? color,
    CupertinoSymbolRenderingMode? renderingMode,
  }) : this._(
         sfSymbol: symbol.value,
         renderingMode: renderingMode,
         size: size,
         color: color,
       );

  /// A raw SF Symbol name, for symbols not covered by [CupertinoSymbols].
  const CupertinoNativeIcon.named(
    String sfSymbolName, {
    double? size,
    Color? color,
    CupertinoSymbolRenderingMode? renderingMode,
  }) : this._(
         sfSymbol: sfSymbolName,
         renderingMode: renderingMode,
         size: size,
         color: color,
       );

  /// A Flutter [IconData] (from any icon package) rendered natively.
  ///
  /// The glyph's font must be bundled with the app (it is whenever the icon is
  /// referenced from Dart, e.g. via `Icon(...)`, or when
  /// `uses-material-design: true` for Material icons).
  factory CupertinoNativeIcon.flutter(
    IconData icon, {
    double? size,
    Color? color,
  }) {
    final family = icon.fontPackage != null
        ? 'packages/${icon.fontPackage}/${icon.fontFamily}'
        : icon.fontFamily;
    return CupertinoNativeIcon._(
      codePoint: icon.codePoint,
      fontFamily: family,
      fontPackage: icon.fontPackage,
      size: size,
      color: color,
    );
  }

  Map<String, dynamic> toMap() {
    return {
      'sfSymbol': sfSymbol,
      'renderingMode': renderingMode?.name,
      'codePoint': codePoint,
      'fontFamily': fontFamily,
      'fontPackage': fontPackage,
      'size': size,
      'color': color?.toARGB32(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CupertinoNativeIcon &&
        other.sfSymbol == sfSymbol &&
        other.renderingMode == renderingMode &&
        other.codePoint == codePoint &&
        other.fontFamily == fontFamily &&
        other.fontPackage == fontPackage &&
        other.size == size &&
        other.color == color;
  }

  @override
  int get hashCode => Object.hash(
    sfSymbol,
    renderingMode,
    codePoint,
    fontFamily,
    fontPackage,
    size,
    color,
  );
}
