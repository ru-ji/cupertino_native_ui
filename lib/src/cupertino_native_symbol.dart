import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'internal/native_platform_view_mixin.dart';
import 'models/cupertino_symbols.dart';

/// Which `.symbolEffect` animates the symbol.
///
/// The discrete ones fire once per [CupertinoNativeSymbol.trigger] bump; the
/// indefinite ones run for as long as [CupertinoNativeSymbol.repeating] is
/// true. Most can do either — [bounce] is discrete only.
enum CupertinoNativeSymbolEffect {
  /// A quick downward nudge. Discrete.
  bounce,

  /// Opacity breathing in place.
  pulse,

  /// Layers light up one after another — the Wi-Fi / cellular animation.
  /// Only means anything on a symbol drawn in several layers.
  variableColor,

  /// A side-to-side shake, for "wrong" or "look here".
  wiggle,

  /// Spins the parts of the symbol meant to spin.
  rotate,

  /// A slow scale in and out.
  breathe,
}

/// An SF Symbol that can animate — SwiftUI's `.symbolEffect`.
///
/// This is the one icon in the package that has to be a platform view: the
/// effects animate the *view*, so rasterizing the symbol the way
/// [CupertinoSymbolImage] does would freeze them. Use [CupertinoSymbolImage]
/// for a still icon (it composites in Flutter's layer tree and so survives a
/// [CupertinoScrollEdgeEffect]); use this one when it has to move.
///
/// Discrete effects fire when [trigger] changes — bump it on each event:
///
/// ```dart
/// CupertinoNativeSymbol.symbol(
///   CupertinoSymbols.bell,
///   effect: CupertinoNativeSymbolEffect.bounce,
///   trigger: _notificationCount,
/// )
/// ```
///
/// Indefinite ones run while [repeating] is true:
///
/// ```dart
/// CupertinoNativeSymbol('wifi',
///     effect: CupertinoNativeSymbolEffect.variableColor, repeating: true)
/// ```
///
/// With [replaceOnChange], changing [name] morphs one symbol into the next
/// (`.contentTransition(.symbolEffect(.replace))`) — the play/pause swap.
class CupertinoNativeSymbol extends StatefulWidget {
  const CupertinoNativeSymbol(
    this.name, {
    super.key,
    this.size = 17,
    this.color,
    this.weight = FontWeight.normal,
    this.renderingMode,
    this.effect,
    this.trigger = 0,
    this.repeating = false,
    this.replaceOnChange = false,
  });

  /// A typo-safe symbol from the [CupertinoSymbols] enum.
  CupertinoNativeSymbol.symbol(
    CupertinoSymbols symbol, {
    Key? key,
    double size = 17,
    Color? color,
    FontWeight weight = FontWeight.normal,
    CupertinoNativeSymbolRenderingMode? renderingMode,
    CupertinoNativeSymbolEffect? effect,
    int trigger = 0,
    bool repeating = false,
    bool replaceOnChange = false,
  }) : this(
         symbol.value,
         key: key,
         size: size,
         color: color,
         weight: weight,
         renderingMode: renderingMode,
         effect: effect,
         trigger: trigger,
         repeating: repeating,
         replaceOnChange: replaceOnChange,
       );

  /// Raw SF Symbol name, e.g. `bell.badge`.
  final String name;
  final double size;
  final Color? color;
  final FontWeight weight;

  /// How a multi-layer symbol is coloured.
  final CupertinoNativeSymbolRenderingMode? renderingMode;

  /// The animation. Null draws a still symbol.
  final CupertinoNativeSymbolEffect? effect;

  /// Bump to fire a discrete [effect]. Ignored while [repeating].
  final int trigger;

  /// Run [effect] continuously instead of once per [trigger].
  /// [CupertinoNativeSymbolEffect.bounce] ignores this — it is discrete only.
  final bool repeating;

  /// Morph between symbols when [name] changes, instead of cutting.
  final bool replaceOnChange;

  @override
  State<CupertinoNativeSymbol> createState() => _CupertinoNativeSymbolState();
}

/// SwiftUI's `SymbolRenderingMode`.
enum CupertinoNativeSymbolRenderingMode {
  monochrome,
  hierarchical,
  palette,
  multicolor,
}

class _CupertinoNativeSymbolState extends State<CupertinoNativeSymbol>
    with NativePlatformViewStateMixin {
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  bool? _lastIsDark;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_lastIsDark != null && _lastIsDark != _isDark) {
      updateNativeView('updateSymbol', _toMap(), refreshIntrinsicSize: false);
    }
    _lastIsDark = _isDark;
  }

  @override
  void didUpdateWidget(covariant CupertinoNativeSymbol oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.name != widget.name ||
        oldWidget.size != widget.size ||
        oldWidget.color != widget.color ||
        oldWidget.weight != widget.weight ||
        oldWidget.renderingMode != widget.renderingMode ||
        oldWidget.effect != widget.effect ||
        oldWidget.trigger != widget.trigger ||
        oldWidget.repeating != widget.repeating ||
        oldWidget.replaceOnChange != widget.replaceOnChange) {
      // Size only changes with the symbol itself, and re-measuring on every
      // trigger bump would round-trip once per animation.
      updateNativeView(
        'updateSymbol',
        _toMap(),
        refreshIntrinsicSize:
            oldWidget.name != widget.name || oldWidget.size != widget.size,
      );
    }
  }

  Map<String, dynamic> _toMap() => {
    'name': widget.name,
    'size': widget.size,
    // The native side maps 0 = w100 ... 8 = w900.
    'weight': (widget.weight.value ~/ 100) - 1,
    'color': widget.color?.toARGB32(),
    'renderingMode': widget.renderingMode?.name,
    'effect': widget.effect?.name,
    'trigger': widget.trigger,
    'repeating': widget.repeating,
    'replaceOnChange': widget.replaceOnChange,
    'isDark': _isDark,
  };

  void _onPlatformViewCreated(int id) {
    setUpChannel(id, 'cupertino_widgets/symbol_$id');
    requestIntrinsicSize();
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return SizedBox(width: widget.size, height: widget.size);
    }
    return SizedBox(
      width: intrinsicWidth ?? widget.size * 1.3,
      height: intrinsicHeight ?? widget.size * 1.3,
      child: wrapForTransition(
        UiKitView(
          viewType: 'com.example.cupertino_widgets/cupertino_native_symbol',
          layoutDirection: TextDirection.ltr,
          creationParams: _toMap(),
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
        ),
      ),
    );
  }
}
