import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'internal/native_platform_view_mixin.dart';
import 'models/cupertino_native_icon.dart';
import 'internal/native_color.dart';
import 'internal/bar_slot.dart';
import 'internal/glass_leaves.dart';
import 'internal/ios_version.dart';

/// The shape of a [CupertinoNativeGlassContainer].
enum CupertinoGlassShape { capsule, circle, roundedRect }

/// Which Liquid Glass material variant to render (SwiftUI `Glass` /
/// `UIGlassEffect.Style`): [regular] is the standard adaptive glass,
/// [clear] is the more transparent variant for media-rich backdrops.
enum CupertinoGlassVariant { regular, clear }

/// The `Glass` a control renders on, one for one with SwiftUI's variants
/// (iOS 26). Always `.interactive()`: the glass answers touches with the
/// system shimmer. Tint it with the control's own `glassTint`.
enum CupertinoNativeGlass {
  /// `Glass.regular`: the standard adaptive glass.
  regular,

  /// `Glass.clear`: the more transparent variant, for media-rich backdrops.
  clear,

  /// `Glass.identity`: the effect applied with no glass, the control as if
  /// it had none, keeping the same layout.
  identity,
}

/// A container backed by the iOS 26 **Liquid Glass** material
/// (SwiftUI's `.glassEffect`). The glass is a real native view that refracts
/// whatever is rendered behind it.
///
/// Content goes on the glass two ways:
///
/// * **[child]**: an ordinary Flutter widget, laid out by your own engine
///   and sizing the glass. Its texts and SF Symbols are drawn by SwiftUI
///   inside the material, so they adapt to the backdrop; the rest is Flutter
///   over it.
/// * **[icon]**: a native SF Symbol, drawn by SwiftUI inside the material.
///
/// ```dart
/// CupertinoNativeGlassContainer(
///   shape: CupertinoGlassShape.capsule,
///   padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
///   child: Row(mainAxisSize: MainAxisSize.min, children: [...]),
/// )
/// ```
///
/// With neither, it is glass and nothing else.
///
/// **Availability:** the refractive effect requires iOS 26+. On iOS 15–25 the
/// native side renders a static `ultraThinMaterial` approximation so layouts
/// don't break; on other platforms a translucent [DecoratedBox] is used. Query
/// [isSupported] to branch your UI on the real effect.
class CupertinoNativeGlassContainer extends StatefulWidget {
  const CupertinoNativeGlassContainer({
    super.key,
    this.child,
    this.shape = CupertinoGlassShape.roundedRect,
    this.cornerRadius = 26,
    this.variant = CupertinoGlassVariant.regular,
    this.tint,
    this.interactive = false,
    this.onPressed,
    this.icon,
    this.padding = EdgeInsets.zero,
    this.width,
    this.height,
    this.animateChanges = false,
  });

  /// An ordinary Flutter widget, laid out by the engine you are already in.
  /// It sizes the container (plus [padding]).
  ///
  /// Its plain [Text]s and still symbols (`CupertinoSymbolImage`,
  /// `CupertinoNativeSymbol` without an effect) are drawn by SwiftUI *inside*
  /// the glass, in the frames Flutter laid them out in, so their colour adapts
  /// to what is behind the glass as a native label's does. That holds through
  /// [Row], [Column], [Wrap], [Padding], [Align], [Center], [SizedBox],
  /// [Expanded] and [Flexible]. Anything else, and any Text inside it, is
  /// Flutter, *over* the material.
  ///
  /// A Text keeps an explicit `style.color`; without one it takes the
  /// adaptive native foreground. A Text in a font of the app's own, or with a
  /// decoration or shadows, stays Flutter.
  final Widget? child;

  final CupertinoGlassShape shape;

  /// Corner radius for [CupertinoGlassShape.roundedRect]
  /// (continuous corners, default 26 to match iOS 26 cards).
  final double cornerRadius;

  /// Glass material variant: regular (default) or the more transparent
  /// clear glass (iOS 26).
  final CupertinoGlassVariant variant;

  /// Optional tint mixed into the glass material.
  final Color? tint;

  /// When true the glass reacts to touches with the system shimmer (iOS 26).
  final bool interactive;

  /// Called when the glass is tapped (native tap gesture on the glass
  /// surface). Set this to use the container as a liquid-glass button:
  /// combine with [interactive] for the touch shimmer.
  final VoidCallback? onPressed;

  /// SF Symbol (or Flutter glyph) rendered natively, centered in the glass:
  /// the easy way to make an icon-only glass button.
  final CupertinoNativeIcon? icon;

  /// Inset between the glass bounds and its content.
  final EdgeInsetsGeometry padding;

  /// Whether config changes (tint, variant, shape, corner radius) animate
  /// Animate [width]/[height] from Dart instead.
  final bool animateChanges;

  /// Explicit size. Left null the glass finds its own: a native [icon] is
  /// measured by SwiftUI, and without one the glass fills the space offered, the way a `Container` with no child does. An empty glass
  /// in an unbounded space has nothing to fill and falls back to a standard
  /// 44pt control, so it is visible rather than collapsed.
  final double? width;
  final double? height;

  /// Whether the running device renders real Liquid Glass (iOS 26+).
  static Future<bool> get isSupported async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return false;
    const channel = MethodChannel('com.example.cupertino_native_ui/alert');
    try {
      return await channel.invokeMethod<bool>('isLiquidGlassSupported') ??
          false;
    } on PlatformException {
      return false;
    } on MissingPluginException {
      return false;
    }
  }

  @override
  State<CupertinoNativeGlassContainer> createState() =>
      _CupertinoNativeGlassContainerState();
}

class _CupertinoNativeGlassContainerState
    extends State<CupertinoNativeGlassContainer>
    with NativePlatformViewStateMixin {
  Map<String, dynamic> _toMap() {
    return {
      'shape': widget.shape.name,
      'cornerRadius': widget.cornerRadius,
      'variant': widget.variant.name,
      'tint': nativeArgb(widget.tint, isDark: _isDark),
      'interactive': widget.interactive,
      'pressable': widget.onPressed != null,
      'icon': widget.icon?.toMap(isDark: _isDark),
      // No width/height: the platform view's frame is already the Flutter box.
      'paddingLeft': _padding.left,
      'paddingTop': _padding.top,
      'paddingRight': _padding.right,
      'paddingBottom': _padding.bottom,
      'animated': widget.animateChanges,
      'expand': !_hugsContent,
      // The app's, for the window; a bar's content only for this view.
      'isDark': Theme.of(context).brightness == Brightness.dark,
      'appearanceDark': switch (BarSlot.brightnessOf(context)) {
        null => null,
        final b => b == Brightness.dark,
      },
      'leaves': _leaves.current,
    };
  }

  /// The [CupertinoNativeGlassContainer.child]'s texts and symbols, drawn by
  /// SwiftUI inside the glass. See [GlassLeaves].
  late final _leaves = GlassLeaves((_) {
    if (mounted) _sendConfig();
  });

  void _sendConfig() {
    final config = _toMap();
    // Compared as JSON: the icon travels as a nested map, a new one on every
    // build, so a shallow compare never matched and every rebuild was sent.
    final json = _encode(config);
    if (json == _sentConfig) return;
    _sentConfig = json;
    // The intrinsic-size round trip is only for a container that hugs its own
    // content; asking for it on every update would put a retry loop behind
    // every config change.
    updateNativeView('updateGlass', config, refreshIntrinsicSize: _hugsContent);
  }

  /// Follows the app's own theme brightness, not the device's: a light app
  /// forced on a dark-mode phone should still get light glass.
  /// In a bar, the content under it (see [BarSlot]); elsewhere the app's.
  bool get _isDark =>
      (BarSlot.brightnessOf(context) ?? Theme.of(context).brightness) ==
      Brightness.dark;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The theme is the one config source that no property diff can see: the
    // widget's own fields did not move, the inherited brightness did.
    _sendConfig();
  }

  /// [padding] resolved to concrete insets, for the native side.
  /// An icon gets 12pt by default, so it measures like a 44pt control.
  EdgeInsets get _padding {
    final padding = widget.padding.resolve(TextDirection.ltr);
    final bare =
        widget.icon != null && _hugsContent && padding == EdgeInsets.zero;
    return bare ? const EdgeInsets.all(12) : padding;
  }

  /// Whether a native [icon] is the only thing sizing this container: the one
  /// case where the glass hugs its own content, exactly as the button does
  /// without `expand`. An explicit size, or nothing at all, means the glass
  /// fills the box Flutter builds instead.
  bool get _hugsContent =>
      _hasNativeContent && widget.width == null && widget.height == null;

  /// Content the native side can measure: a symbol.
  bool get _hasNativeContent => widget.icon != null;

  /// What the native side was last told, so a rebuild that changes nothing it
  /// can see costs nothing. A `TweenAnimationBuilder` driving width/height
  /// rebuilds this widget every frame and none of those frames reach here.
  String? _sentConfig;

  /// A user's `cornerRadius: double.infinity` is not JSON; as a string it
  /// still compares.
  static String _encode(Object? config) =>
      jsonEncode(config, toEncodable: (o) => o.toString());

  /// What the platform view was created with: its first build's config.
  Map<String, dynamic>? _createdWith;

  @override
  void didUpdateWidget(covariant CupertinoNativeGlassContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sendConfig();
  }

  Future<void> _onPlatformViewCreated(int id) async {
    setUpChannel(
      id,
      'cupertino_native_ui/liquid_glass_$id',
      onMethodCall: _handleMethodCall,
    );
    // Only native content gives the hosted view something to measure; with
    // nothing, SwiftUI answers zero: retried round trips for an answer this
    // widget would discard.
    _sentConfig = _encode(_createdWith);
    // The leaves are measured after the first frame, so usually after the
    // view was created without them.
    _sendConfig();
    if (_hugsContent) requestIntrinsicSize();
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'pressed') {
      widget.onPressed?.call();
    }
  }

  /// The size a glass container falls back to when it has none of its own: the
  /// standard iOS touch target, which is also what a glass toolbar button
  /// measures. Used until the native measurement lands, and for good where
  /// there is nothing at all to measure.
  static const double _defaultExtent = 44;

  /// A bar button's height on iOS 26, shared glass or not.
  static const double _barHeight = 44;

  @override
  Widget build(BuildContext context) {
    final Widget content;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // Touches must reach the native view immediately for the interactive
      // shimmer / tap gesture: inside scrollables Flutter's gesture arena
      // would otherwise delay and cancel them.
      final wantsTouches = widget.interactive || widget.onPressed != null;
      final glass = wrapForTransition(
        UiKitView(
          viewType:
              'com.example.cupertino_native_ui/cupertino_native_liquid_glass',
          layoutDirection: TextDirection.ltr,
          creationParams: _createdWith ??= _toMap(),
          creationParamsCodec: const StandardMessageCodec(),
          hitTestBehavior: wantsTouches
              ? PlatformViewHitTestBehavior.opaque
              : PlatformViewHitTestBehavior.transparent,
          gestureRecognizers: wantsTouches
              ? scrollFriendlyGestures()
              : const {},
          onPlatformViewCreated: _onPlatformViewCreated,
        ),
      );
      content = glass;
    } else {
      // Non-iOS fallback: a translucent rounded box.
      Widget box = DecoratedBox(
        decoration: BoxDecoration(
          color: (widget.tint ?? const Color(0xFF787880)).withValues(
            alpha: 0.2,
          ),
          borderRadius: widget.shape == CupertinoGlassShape.circle
              ? null
              : BorderRadius.circular(
                  widget.shape == CupertinoGlassShape.capsule
                      ? 999
                      : widget.cornerRadius,
                ),
          shape: widget.shape == CupertinoGlassShape.circle
              ? BoxShape.circle
              : BoxShape.rectangle,
        ),
        child: Padding(padding: widget.padding, child: const SizedBox.shrink()),
      );
      if (widget.onPressed != null) {
        box = GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: widget.onPressed,
          child: box,
        );
      }
      content = box;
    }

    // A Flutter child rides over the glass and gives it its size: the stack
    // is as big as the padded child, and the glass fills it.
    if (widget.child != null) {
      // Buttons sharing a glass in the iOS 26 bar: the system's capsule is
      // 44pt high, whatever is in it, the height of a bar button. Only the
      // horizontal padding is kept.
      final inBar = isIOS26OrLater && BarSlot.isIn(context);
      final resolved = widget.padding.resolve(Directionality.of(context));
      final padding = inBar
          ? EdgeInsets.only(left: resolved.left, right: resolved.right)
          : widget.padding;
      final height = widget.height ?? (inBar ? _barHeight : null);
      final stacked = _leaves.host(
        Stack(
          // Centred in the bar's 44pt; elsewhere the child sizes the stack.
          alignment: inBar ? Alignment.center : AlignmentDirectional.topStart,
          children: [
            Positioned.fill(child: content),
            Padding(
              padding: padding,
              child: defaultTargetPlatform == TargetPlatform.iOS
                  ? _leaves.split(widget.child!, isDark: _isDark)
                  : widget.child,
            ),
          ],
        ),
      );
      if (widget.width != null || height != null) {
        return SizedBox(width: widget.width, height: height, child: stacked);
      }
      return stacked;
    }

    // Three ways to a size, in order of authority.
    //
    // 1. What the caller asked for.
    if (widget.width != null || widget.height != null) {
      return SizedBox(
        width: widget.width,
        height: widget.height,
        child: content,
      );
    }
    // 2. Native content: SwiftUI measured the glyph and
    //    the material around it, so take that, the same `getIntrinsicSize`
    //    round trip the button makes, with the same default until it lands.
    if (_hasNativeContent) {
      return SizedBox(
        width: intrinsicWidth ?? _defaultExtent,
        height: intrinsicHeight ?? _defaultExtent,
        child: content,
      );
    }
    // 3. Empty: fill the space offered, or a standard 44pt control when it is
    //    unbounded.
    return LimitedBox(
      maxWidth: _defaultExtent,
      maxHeight: _defaultExtent,
      child: content,
    );
  }
}
