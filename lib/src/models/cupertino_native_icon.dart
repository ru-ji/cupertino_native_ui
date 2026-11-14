import 'dart:ui' show Color, FontWeight;

import 'package:flutter/widgets.dart' show IconData;

import 'cupertino_symbols.dart';
import '../internal/native_color.dart';

/// A native icon, described for the native side (a button, a bar, a list
/// row, a menu).
///
/// - [CupertinoNativeIcon.symbol] takes a typo-safe [CupertinoSymbols] value.
/// - [CupertinoNativeIcon.named] takes any raw SF Symbol name the
///   [CupertinoSymbols] enum does not cover.
/// - [CupertinoNativeIcon.iconData] takes a glyph of an icon font:
///   `CupertinoIcons`, Material `Icons`, or one of the app's own.
/// - [CupertinoNativeIcon.asset] takes one of the app's image assets.
///
/// The last two are drawn as templates, tinted like a symbol. To show a
/// symbol in the Flutter tree instead, use `CupertinoSymbolImage`.
/// The shape of a [CupertinoNativeIcon] tile.
enum CupertinoNativeIconTileShape { circle, roundedSquare }

class CupertinoNativeIcon {
  /// The SF Symbol name, e.g. `star.fill`. Null for a custom icon.
  final String? sfSymbol;

  /// The icon font glyph, for [CupertinoNativeIcon.iconData].
  final IconData? iconData;

  /// The asset key as Flutter bundles it (`packages/<package>/<name>` for a
  /// package's asset), for [CupertinoNativeIcon.asset].
  final String? asset;

  /// Rendering mode. SF Symbols only.
  final CupertinoSymbolRenderingMode? renderingMode;

  /// Point size. Null uses the host control's default sizing.
  final double? size;

  /// Icon color/tint. Null inherits the control's foreground/tint.
  final Color? color;

  /// Stroke weight. Null keeps the control's own (regular). SF Symbols only.
  final FontWeight? weight;

  /// Fill of a tile drawn behind the icon, like Settings' coloured squares or
  /// Reminders' round list icon. Null draws no tile. The glyph turns white
  /// unless [color] is set.
  final Color? tile;

  final CupertinoNativeIconTileShape tileShape;

  /// Side of the tile in points (Settings uses 30).
  final double tileSize;

  /// The Settings-style fill: [tile] lightened at the top, plain at the bottom.
  final bool tileGradient;

  /// Draw an [asset] as is, filling the tile, instead of tinting it as a
  /// glyph: an app icon, a card thumbnail.
  final bool original;

  const CupertinoNativeIcon._({
    this.sfSymbol,
    this.iconData,
    this.asset,
    this.renderingMode,
    this.size,
    this.color,
    this.weight,
    this.tile,
    this.tileShape = CupertinoNativeIconTileShape.roundedSquare,
    this.tileSize = 30,
    this.tileGradient = false,
    this.original = false,
  });

  /// A typo-safe SF Symbol from the [CupertinoSymbols] enum.
  CupertinoNativeIcon.symbol(
    CupertinoSymbols symbol, {
    this.size,
    this.color,
    this.weight,
    this.renderingMode,
    this.tile,
    this.tileShape = CupertinoNativeIconTileShape.roundedSquare,
    this.tileSize = 30,
    this.tileGradient = false,
  }) : sfSymbol = symbol.value,
       iconData = null,
       asset = null,
       original = false;

  /// A raw SF Symbol name, for symbols not covered by [CupertinoSymbols].
  const CupertinoNativeIcon.named(
    String this.sfSymbol, {
    this.size,
    this.color,
    this.weight,
    this.renderingMode,
    this.tile,
    this.tileShape = CupertinoNativeIconTileShape.roundedSquare,
    this.tileSize = 30,
    this.tileGradient = false,
  }) : iconData = null,
       asset = null,
       original = false;

  /// A glyph of an icon font, e.g. `CupertinoIcons.heart` or `Icons.home`.
  /// The font must be bundled with the app, as it is for an [IconData] the
  /// app's own code uses.
  const CupertinoNativeIcon.iconData(
    IconData this.iconData, {
    this.size,
    this.color,
    this.tile,
    this.tileShape = CupertinoNativeIconTileShape.roundedSquare,
    this.tileSize = 30,
    this.tileGradient = false,
  }) : sfSymbol = null,
       asset = null,
       original = false,
       weight = null,
       renderingMode = null;

  /// One of the app's image assets, declared in its `pubspec.yaml`, with its
  /// `2.0x` / `3.0x` variants picked for the screen. A transparent PNG drawn
  /// as a template: its opaque pixels in the control's tint, or in [color].
  const CupertinoNativeIcon.asset(
    String name, {
    String? package,
    this.size,
    this.color,
    this.tile,
    this.tileShape = CupertinoNativeIconTileShape.roundedSquare,
    this.tileSize = 30,
    this.tileGradient = false,
    this.original = false,
  }) : asset = package == null ? name : 'packages/$package/$name',
       sfSymbol = null,
       iconData = null,
       weight = null,
       renderingMode = null;

  /// A copy whose [size] falls back to [fallback] when unset.
  CupertinoNativeIcon withDefaultSize(double fallback) =>
      size != null ? this : _copy(size: fallback);

  /// A copy whose [weight] falls back to [fallback] when unset.
  CupertinoNativeIcon withDefaultWeight(FontWeight fallback) =>
      weight != null ? this : _copy(weight: fallback);

  CupertinoNativeIcon _copy({double? size, FontWeight? weight}) =>
      CupertinoNativeIcon._(
        sfSymbol: sfSymbol,
        iconData: iconData,
        asset: asset,
        renderingMode: renderingMode,
        size: size ?? this.size,
        color: color,
        weight: weight ?? this.weight,
        tile: tile,
        tileShape: tileShape,
        tileSize: tileSize,
        tileGradient: tileGradient,
        original: original,
      );

  Map<String, dynamic> toMap({bool isDark = false}) {
    return {
      'sfSymbol': sfSymbol,
      'renderingMode': renderingMode?.name,
      'size': size,
      'color': nativeArgb(color, isDark: isDark),
      'weight': weight == null ? null : _weightName(weight!),
      'glyph': iconData?.codePoint,
      'fontFamily': iconData?.fontFamily,
      'fontPackage': iconData?.fontPackage,
      'asset': asset,
      'tile': nativeArgb(tile, isDark: isDark),
      'tileShape': tileShape.name,
      'tileSize': tileSize,
      'tileGradient': tileGradient,
      'original': original,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CupertinoNativeIcon &&
        other.sfSymbol == sfSymbol &&
        other.iconData == iconData &&
        other.asset == asset &&
        other.renderingMode == renderingMode &&
        other.size == size &&
        other.color == color &&
        other.weight == weight &&
        other.tile == tile &&
        other.tileShape == tileShape &&
        other.tileSize == tileSize &&
        other.tileGradient == tileGradient &&
        other.original == original;
  }

  @override
  int get hashCode => Object.hash(
    sfSymbol,
    iconData,
    asset,
    renderingMode,
    size,
    color,
    weight,
    tile,
    tileShape,
    tileSize,
    tileGradient,
    original,
  );

  static String _weightName(FontWeight w) => switch (w.value) {
    <= 300 => 'light',
    >= 700 => 'bold',
    >= 600 => 'semibold',
    >= 500 => 'medium',
    _ => 'regular',
  };
}
