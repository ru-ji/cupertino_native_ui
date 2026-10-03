import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'models/cupertino_symbols.dart';
import 'internal/native_color.dart';

import 'package:flutter/material.dart' show Theme;

/// How large the symbol is drawn for its point size, like SwiftUI's
/// `imageScale`.
enum CupertinoSymbolScale { small, medium, large }

/// An SF Symbol drawn as **Flutter pixels**, not a platform view.
///
/// Every other icon in the package rides inside a native control. This one is
/// for Flutter-drawn UI: the symbol is rasterized natively (`UIImage(systemName:)`)
/// and handed back as an image, so it composites in Flutter's own layer tree.
/// That matters wherever the icon sits under a `BackdropFilter` (a
/// [CupertinoScrollEdgeEffect], a blurred bar) since a platform view is
/// composited outside that tree and would leave an unblurred hole.
///
/// Renders nothing until the first frame after the native call returns, and
/// nothing at all off iOS or for an unknown symbol name. Results are cached
/// process-wide by name/size/color/weight, so repeats in a list are free.
class CupertinoSymbolImage extends StatefulWidget {
  const CupertinoSymbolImage(
    this.name, {
    super.key,
    this.size = 17,
    this.color,
    this.weight = FontWeight.normal,
    this.scale = CupertinoSymbolScale.medium,
  });

  /// A typo-safe symbol from the [CupertinoSymbols] enum.
  CupertinoSymbolImage.symbol(
    CupertinoSymbols symbol, {
    Key? key,
    double size = 17,
    Color? color,
    FontWeight weight = FontWeight.normal,
    CupertinoSymbolScale scale = CupertinoSymbolScale.medium,
  }) : this(
         symbol.value,
         key: key,
         size: size,
         color: color,
         weight: weight,
         scale: scale,
       );

  /// Raw SF Symbol name, e.g. `slider.horizontal.3`.
  final String name;

  /// Point size, as passed to `UIImage.SymbolConfiguration`. The rendered
  /// image is taller/wider than this, a symbol's bounding box includes the
  /// font's ascent, which is why the widget sizes itself to the image.
  final double size;

  final Color? color;

  /// Mapped onto the five `UIImage.SymbolWeight` values the API accepts.
  final FontWeight weight;

  /// `UIImage.SymbolScale`. UIKit draws a bar button's symbol at
  /// [CupertinoSymbolScale.large], which is bigger than the plain point size.
  final CupertinoSymbolScale scale;

  @override
  State<CupertinoSymbolImage> createState() => _CupertinoSymbolImageState();
}

class _CupertinoSymbolImageState extends State<CupertinoSymbolImage> {
  static const _channel = MethodChannel(
    'com.example.cupertino_native_ui/alert',
  );

  /// Rendered PNGs, keyed by the full request. Futures (not bytes) so that N
  /// simultaneous rows asking for the same symbol share one platform call.
  static final Map<String, Future<Uint8List?>> _cache = {};

  Future<Uint8List?>? _bytes;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _load();
  }

  @override
  void didUpdateWidget(CupertinoSymbolImage old) {
    super.didUpdateWidget(old);
    if (old.name != widget.name ||
        old.size != widget.size ||
        old.color != widget.color ||
        old.weight != widget.weight ||
        old.scale != widget.scale) {
      _load();
    }
  }

  // No setState: both callers (didChangeDependencies, didUpdateWidget) are
  // already followed by a build.
  void _load() {
    // Rasterize at the device pixel ratio so the glyph is sharp: the PNG
    // carries no scale factor, so [Image.memory] is told the ratio too.
    final scale = MediaQuery.devicePixelRatioOf(context);
    final color = nativeArgb(
      widget.color,
      isDark: Theme.of(context).brightness == Brightness.dark,
    );
    final key =
        '${widget.name}|${widget.size}|$color|'
        '${widget.weight.value}|${widget.scale.name}|$scale';
    _bytes = _cache[key] ??= _channel
        .invokeMethod<Uint8List>('renderSymbol', {
          'name': widget.name,
          'size': widget.size,
          'color': color,
          'weight': _weightName(widget.weight),
          'symbolScale': widget.scale.name,
          'scale': scale,
        })
        // An unknown symbol name (or a non-iOS host) is a missing icon, not a
        // crash: the widget stays empty. Logged, not swallowed: a silent
        // catch here is indistinguishable from "the symbol just didn't draw".
        .catchError((Object e) {
          debugPrint('CupertinoSymbolImage: "${widget.name}" failed: $e');
          return null;
        });
  }

  static String _weightName(FontWeight weight) {
    if (weight.value <= FontWeight.w300.value) return 'light';
    if (weight.value >= FontWeight.w700.value) return 'bold';
    if (weight.value >= FontWeight.w600.value) return 'semibold';
    if (weight.value >= FontWeight.w500.value) return 'medium';
    return 'regular';
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Uint8List?>(
      future: _bytes,
      builder: (context, snapshot) {
        final bytes = snapshot.data;
        if (bytes == null) return SizedBox.square(dimension: widget.size);
        return Image.memory(
          bytes,
          scale: MediaQuery.devicePixelRatioOf(context),
          filterQuality: FilterQuality.medium,
        );
      },
    );
  }
}
