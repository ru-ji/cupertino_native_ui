import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'internal/native_platform_view_mixin.dart';
import 'models/cupertino_native_button_style.dart';
import 'models/cupertino_native_button_extra_options.dart';
import 'models/cupertino_native_icon.dart';

// The deprecated [CupertinoNativeButton.systemImage] has to keep working until
// it is removed, so this file necessarily reads it.
// ignore_for_file: deprecated_member_use_from_same_package

class CupertinoNativeButton extends StatefulWidget {
  final String title;

  /// The button's icon. Accepts an SF Symbol ([CupertinoNativeIcon.symbol] /
  /// [CupertinoNativeIcon.named]) or a Flutter [IconData]
  /// ([CupertinoNativeIcon.flutter]). Takes precedence over [systemImage].
  final CupertinoNativeIcon? icon;

  /// Convenience for a raw SF Symbol name. Ignored when [icon] is set. Prefer
  /// [icon] for typed symbols or Flutter icons.
  @Deprecated(
    'Use icon: CupertinoNativeIcon.symbol(...) or .named(...) instead',
  )
  final String? systemImage;
  final CupertinoNativeButtonStyle style;
  final CupertinoNativeControlSize controlSize;
  final CupertinoNativeButtonBorderShape borderShape;
  final CupertinoNativeButtonLabelStyle labelStyle;
  final bool expand;
  final VoidCallback? onPressed;

  /// Explicit point size, sizing the SwiftUI control itself and not just the
  /// Flutter box around it. Left null the control is sized by [controlSize] —
  /// except that a button with no title to lay out falls back to the standard
  /// 44pt square, which is what a bar button is.
  final double? width;
  final double? height;
  final Color? activeColor;
  final TextStyle? textStyle;

  const CupertinoNativeButton({
    super.key,
    this.title = '',
    this.icon,
    @Deprecated(
      'Use icon: CupertinoNativeIcon.symbol(...) or .named(...) instead',
    )
    this.systemImage,
    this.style = CupertinoNativeButtonStyle.automatic,
    this.controlSize = CupertinoNativeControlSize.regular,
    this.borderShape = CupertinoNativeButtonBorderShape.automatic,
    this.labelStyle = CupertinoNativeButtonLabelStyle.titleAndIcon,
    this.expand = false,
    this.onPressed,
    this.width,
    this.height,
    this.activeColor,
    this.textStyle,
  });

  @override
  State<CupertinoNativeButton> createState() => _CupertinoNativeButtonState();
}

class _CupertinoNativeButtonState extends State<CupertinoNativeButton>
    with NativePlatformViewStateMixin {
  /// The icon actually sent to native: [CupertinoNativeButton.icon] wins,
  /// falling back to [CupertinoNativeButton.systemImage] as a raw SF Symbol.
  CupertinoNativeIcon? get _effectiveIcon =>
      widget.icon ??
      (widget.systemImage != null
          ? CupertinoNativeIcon.named(widget.systemImage!)
          : null);

  bool? _lastIsDark;

  // Follows the app's own theme brightness, not the device's — a light app
  // forced on a dark-mode phone should still get a light control.
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-push config if the app toggled light/dark at runtime.
    if (_lastIsDark != null && _lastIsDark != _isDark) {
      updateNativeView('updateButton', _toMap(), refreshIntrinsicSize: false);
    }
    _lastIsDark = _isDark;
  }

  @override
  void didUpdateWidget(covariant CupertinoNativeButton oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.title != widget.title ||
        oldWidget.icon != widget.icon ||
        oldWidget.systemImage != widget.systemImage ||
        oldWidget.style != widget.style ||
        oldWidget.controlSize != widget.controlSize ||
        oldWidget.borderShape != widget.borderShape ||
        oldWidget.labelStyle != widget.labelStyle ||
        oldWidget.expand != widget.expand ||
        oldWidget.activeColor != widget.activeColor ||
        oldWidget.textStyle != widget.textStyle ||
        oldWidget.width != widget.width ||
        oldWidget.height != widget.height) {
      updateNativeView('updateButton', _toMap());
    }
  }

  Map<String, dynamic> _toMap() {
    return {
      'title': widget.title,
      'icon': _effectiveIcon?.toMap(),
      'style': widget.style.name,
      'controlSize': widget.controlSize.name,
      'borderShape': widget.borderShape.name,
      'labelStyle': widget.labelStyle.name,
      'expand': widget.expand,
      'color': widget.activeColor?.toARGB32(),
      'fontSize': widget.textStyle?.fontSize,
      'fontWeight': widget.textStyle?.fontWeight?.value,
      'textColor': widget.textStyle?.color?.toARGB32(),
      'isDark': _isDark,
      // Sized natively too, not just boxed: a SwiftUI button is `fixedSize`,
      // so a Flutter SizedBox alone leaves it drawing at its own metrics and
      // spilling out of (or rattling inside) the box.
      'width': _width,
      'height': _height,
    };
  }

  Future<void> _onPlatformViewCreated(int id) async {
    setUpChannel(
      id,
      'cupertino_widgets/button_$id',
      onMethodCall: _handleMethodCall,
    );
    // Request intrinsic size after a short delay to let the view settle
    requestIntrinsicSize();
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onPressed') {
      widget.onPressed?.call();
    }
  }

  /// Apple's control heights per `ControlSize`, on iOS. Used only until the
  /// native measurement lands — SwiftUI is the authority on the real metrics,
  /// this is what the box measures for the frame or two before it answers.
  /// A default that under-shoots clips the button, so these are the real
  /// numbers rather than the one-size-fits-all 34 that used to stand here.
  static const _heights = <CupertinoNativeControlSize, double>{
    CupertinoNativeControlSize.mini: 28,
    CupertinoNativeControlSize.small: 32,
    CupertinoNativeControlSize.regular: 34,
    CupertinoNativeControlSize.large: 44,
    CupertinoNativeControlSize.extraLarge: 50,
  };

  /// No title to draw: the button is a square glyph target, the way a bar
  /// button is.
  bool get _isIconOnly =>
      widget.labelStyle == CupertinoNativeButtonLabelStyle.iconOnly ||
      (widget.title.isEmpty && _effectiveIcon != null);

  /// The standard iOS touch target, and the size of a navigation-bar button.
  static const double _standardExtent = 44;

  /// What the control is actually sized to. An explicit value wins; failing
  /// that an icon-only button is a 44pt square — the one case where there is
  /// no text whose length has to decide the width, so a number can. A button
  /// with a title is left to [controlSize]: forcing 44 on it would clip the
  /// title, which no default should do.
  double? get _width =>
      widget.width ?? (_isIconOnly && !widget.expand ? _standardExtent : null);
  double? get _height =>
      widget.height ?? (_isIconOnly && !widget.expand ? _standardExtent : null);

  double get _defaultHeight {
    final height = _heights[widget.controlSize]!;
    return _isIconOnly && height < 44 ? 44 : height;
  }

  /// Square when icon-only; a title's worth of width otherwise.
  double get _defaultWidth => _isIconOnly ? _defaultHeight : 80;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final platformView = wrapForTransition(
        UiKitView(
          viewType: 'com.example.cupertino_widgets/cupertino_native_button',
          layoutDirection: TextDirection.ltr,
          creationParams: _toMap(),
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
        ),
      );

      if (_width != null && _height != null) {
        return withPaintRoom(platformView, _width!, _height!);
      }
      if (_width != null || _height != null) {
        return SizedBox(width: _width, height: _height, child: platformView);
      }

      // expand: true — the native button already fills the box, so only the
      // height needs stating; the width constraint passes straight through.
      if (widget.expand) {
        return SizedBox(
          height: intrinsicHeight ?? _defaultHeight,
          child: platformView,
        );
      }

      return withPaintRoom(
        platformView,
        intrinsicWidth ?? _defaultWidth,
        intrinsicHeight ?? _defaultHeight,
      );
    }

    // Fallback for non-iOS
    return GestureDetector(
      onTap: widget.onPressed,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        color: const Color(0xFF007AFF),
        child: Text(
          widget.title,
          style: const TextStyle(color: Color(0xFFFFFFFF)),
        ),
      ),
    );
  }
}
