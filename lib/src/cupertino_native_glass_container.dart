import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'internal/native_platform_view_mixin.dart';
import 'models/cupertino_native_icon.dart';
import 'internal/scroll_friendly_recognizer.dart';

/// The shape of a [CupertinoNativeGlassContainer].
enum CupertinoGlassShape { capsule, circle, roundedRect }

/// Which Liquid Glass material variant to render (SwiftUI `Glass` /
/// `UIGlassEffect.Style`): [regular] is the standard adaptive glass,
/// [clear] is the more transparent variant for media-rich backdrops.
/// Ignored below iOS 26, where the material fallback has no variants.
enum CupertinoGlassVariant { regular, clear }

/// Liquid Glass settings for a control that renders *on* glass rather than
/// being a glass container itself — currently [CupertinoNativeTextField.glass].
///
/// Passing one enables the effect; leaving it null renders the plain control.
/// The field names match [CupertinoNativeGlassContainer]'s, so the same
/// vocabulary describes glass wherever it appears.
///
/// ```dart
/// CupertinoNativeTextField(
///   placeholder: 'Search',
///   glass: CupertinoGlass(cornerRadius: 22),
/// )
/// ```
class CupertinoGlass {
  /// Corner radius of the glass shape (continuous corners).
  final double cornerRadius;

  /// Standard adaptive glass, or the more transparent clear variant (iOS 26).
  final CupertinoGlassVariant variant;

  /// Whether the glass reacts to touches with the system shimmer (iOS 26).
  final bool interactive;

  /// Optional tint mixed into the glass material.
  final Color? tint;

  const CupertinoGlass({
    this.cornerRadius = 16,
    this.variant = CupertinoGlassVariant.regular,
    this.interactive = true,
    this.tint,
  });

  @override
  bool operator ==(Object other) =>
      other is CupertinoGlass &&
      other.cornerRadius == cornerRadius &&
      other.variant == variant &&
      other.interactive == interactive &&
      other.tint == tint;

  @override
  int get hashCode => Object.hash(cornerRadius, variant, interactive, tint);
}

/// A container backed by the iOS 26 **Liquid Glass** material
/// (SwiftUI's `.glassEffect`). The glass is a real native view that refracts
/// whatever is rendered behind it.
///
/// Content goes *inside* the glass — a native [icon], or a Flutter [route]
/// hosted as a SwiftUI view that `glassEffect` wraps. It is live Flutter:
/// `setState`, Riverpod, animations, all of it runs normally in there.
///
/// ```dart
/// CupertinoNativeGlassContainer(
///   shape: CupertinoGlassShape.capsule,
///   route: 'now_playing',
/// )
/// ```
///
/// With neither, it is glass and nothing else — size it and stack whatever you
/// like over it in Flutter.
///
/// **Availability:** the refractive effect requires iOS 26+. On iOS 15–25 the
/// native side renders a static `ultraThinMaterial` approximation so layouts
/// don't break; on other platforms a translucent [DecoratedBox] is used. Query
/// [isSupported] to branch your UI on the real effect.
class CupertinoNativeGlassContainer extends StatefulWidget {
  const CupertinoNativeGlassContainer({
    super.key,
    this.route,
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

  /// A body route whose Flutter content is hosted *inside* the glass.
  /// Registered like a [CupertinoNativePageScaffold] body in `maybeRun`, and
  /// run in its own isolate.
  final String? route;

  final CupertinoGlassShape shape;

  /// Corner radius for [CupertinoGlassShape.roundedRect]
  /// (continuous corners, default 26 to match iOS 26 cards).
  final double cornerRadius;

  /// Glass material variant — regular (default) or the more transparent
  /// clear glass (iOS 26).
  final CupertinoGlassVariant variant;

  /// Optional tint mixed into the glass material.
  final Color? tint;

  /// When true the glass reacts to touches with the system shimmer (iOS 26).
  final bool interactive;

  /// Called when the glass is tapped (native tap gesture on the glass
  /// surface). Set this to use the container as a liquid-glass button —
  /// combine with [interactive] for the touch shimmer.
  final VoidCallback? onPressed;

  /// SF Symbol (or Flutter glyph) rendered natively, centered in the glass —
  /// the easy way to make an icon-only glass button.
  final CupertinoNativeIcon? icon;

  /// Inset between the glass bounds and its content.
  final EdgeInsetsGeometry padding;

  /// Whether config changes — tint, variant, shape, corner radius — animate
  /// Animate [width]/[height] from Dart instead.
  final bool animateChanges;

  /// Explicit size. Left null the glass finds its own: a native [icon] or a
  /// [route] body is measured by SwiftUI, and with neither the glass fills the
  /// space offered, the way a `Container` with no child does. An empty glass
  /// in an unbounded space has nothing to fill and falls back to a standard
  /// 44pt control, so it is visible rather than collapsed.
  final double? width;
  final double? height;

  /// Whether the running device renders real Liquid Glass (iOS 26+).
  static Future<bool> get isSupported async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return false;
    const channel = MethodChannel('com.example.cupertino_widgets/alert');
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
      'tint': widget.tint?.toARGB32(),
      'interactive': widget.interactive,
      'pressable': widget.onPressed != null,
      'icon': widget.icon?.toMap(),
      // No width/height: the platform view's frame is already the Flutter box.
      'paddingLeft': _padding.left,
      'paddingTop': _padding.top,
      'paddingRight': _padding.right,
      'paddingBottom': _padding.bottom,
      'route': widget.route,
      'animated': widget.animateChanges,
      'expand': !_hugsContent,
      'isDark': _isDark,
    };
  }

  /// Follows the app's own theme brightness, not the device's — a light app
  /// forced on a dark-mode phone should still get light glass.
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // The theme is the one config source that no property diff can see: the
    // widget's own fields did not move, the inherited brightness did.
    final config = _toMap();
    if (mapEquals(_sentConfig, config)) return;
    _sentConfig = config;
    updateNativeView('updateGlass', config, refreshIntrinsicSize: _hugsContent);
  }

  /// [padding] resolved to concrete insets, for the native side.
  /// An icon gets 12pt by default, so it measures like a 44pt control.
  EdgeInsets get _padding {
    final padding = widget.padding.resolve(TextDirection.ltr);
    final bare =
        widget.icon != null && _hugsContent && padding == EdgeInsets.zero;
    return bare ? const EdgeInsets.all(12) : padding;
  }

  /// Whether a native [icon] is the only thing sizing this container — the one
  /// case where the glass hugs its own content, exactly as the button does
  /// without `expand`. An explicit size, or nothing at all, means the glass
  /// fills the box Flutter builds instead.
  bool get _hugsContent =>
      _hasNativeContent && widget.width == null && widget.height == null;

  /// Content the native side can measure — a symbol or a hosted body.
  bool get _hasNativeContent => widget.icon != null || widget.route != null;

  /// What the native side was last told, so a rebuild that changes nothing it
  /// can see costs nothing. A `TweenAnimationBuilder` driving width/height
  /// rebuilds this widget every frame and none of those frames reach here.
  Map<String, dynamic>? _sentConfig;

  @override
  void didUpdateWidget(covariant CupertinoNativeGlassContainer oldWidget) {
    super.didUpdateWidget(oldWidget);
    final config = _toMap();
    if (mapEquals(_sentConfig, config)) return;
    _sentConfig = config;
    // The intrinsic-size round trip is only for a container that hugs its own
    // content; asking for it on every update would put a retry loop behind
    // every config change.
    updateNativeView('updateGlass', config, refreshIntrinsicSize: _hugsContent);
  }

  Future<void> _onPlatformViewCreated(int id) async {
    setUpChannel(
      id,
      'cupertino_widgets/liquid_glass_$id',
      onMethodCall: _handleMethodCall,
    );
    // Only native content gives the hosted view something to measure; with
    // nothing, SwiftUI answers zero — retried round trips for an answer this
    // widget would discard.
    _sentConfig = _toMap();
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

  @override
  Widget build(BuildContext context) {
    final Widget content;
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // Touches must reach the native view immediately for the interactive
      // shimmer / tap gesture — inside scrollables Flutter's gesture arena
      // would otherwise delay and cancel them.
      final wantsTouches = widget.interactive || widget.onPressed != null;
      final glass = wrapForTransition(
        UiKitView(
          viewType:
              'com.example.cupertino_widgets/cupertino_native_liquid_glass',
          layoutDirection: TextDirection.ltr,
          creationParams: _toMap(),
          creationParamsCodec: const StandardMessageCodec(),
          hitTestBehavior: wantsTouches
              ? PlatformViewHitTestBehavior.opaque
              : PlatformViewHitTestBehavior.transparent,
          gestureRecognizers: wantsTouches ? scrollFriendlyGestures : const {},
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
    // 2. Native content: SwiftUI measured the glyph (or the hosted body) and
    //    the material around it, so take that — the same `getIntrinsicSize`
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
