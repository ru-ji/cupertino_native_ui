import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Icon, Theme;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'internal/native_platform_view_mixin.dart';
import 'models/cupertino_native_button_style.dart';
import 'models/cupertino_native_button_extra_options.dart';
import 'cupertino_symbol_image.dart';
import 'models/cupertino_native_icon.dart';

/// iOS's button, rendered by SwiftUI. Shaped like Flutter's [CupertinoButton]:
/// the label is [child], and the style comes from the constructor —
/// [CupertinoNativeButton.filled], [.tinted], [.glass], [.glassProminent].
///
/// The native control draws the label itself, so [child] is read rather than
/// built: a [Text] (title and style), a [CupertinoSymbolImage] (SF Symbol), an
/// [Icon] (Flutter glyph), or a [Row] of one icon and one [Text].
class CupertinoNativeButton extends StatefulWidget {
  const CupertinoNativeButton({
    super.key,
    required this.child,
    required this.onPressed,
    this.sizeStyle = CupertinoNativeControlSize.regular,
    this.color,
    this.borderShape = CupertinoNativeButtonBorderShape.automatic,
    this.expand = false,
    this.width,
    this.height,
  }) : style = CupertinoNativeButtonStyle.plain;

  const CupertinoNativeButton.filled({
    super.key,
    required this.child,
    required this.onPressed,
    this.sizeStyle = CupertinoNativeControlSize.regular,
    this.color,
    this.borderShape = CupertinoNativeButtonBorderShape.automatic,
    this.expand = false,
    this.width,
    this.height,
  }) : style = CupertinoNativeButtonStyle.filled;

  const CupertinoNativeButton.tinted({
    super.key,
    required this.child,
    required this.onPressed,
    this.sizeStyle = CupertinoNativeControlSize.regular,
    this.color,
    this.borderShape = CupertinoNativeButtonBorderShape.automatic,
    this.expand = false,
    this.width,
    this.height,
  }) : style = CupertinoNativeButtonStyle.tinted;

  /// iOS 26 Liquid Glass.
  const CupertinoNativeButton.glass({
    super.key,
    required this.child,
    required this.onPressed,
    this.sizeStyle = CupertinoNativeControlSize.regular,
    this.color,
    this.borderShape = CupertinoNativeButtonBorderShape.automatic,
    this.expand = false,
    this.width,
    this.height,
  }) : style = CupertinoNativeButtonStyle.glass;

  /// iOS 26 prominent (tinted) Liquid Glass.
  const CupertinoNativeButton.glassProminent({
    super.key,
    required this.child,
    required this.onPressed,
    this.sizeStyle = CupertinoNativeControlSize.regular,
    this.color,
    this.borderShape = CupertinoNativeButtonBorderShape.automatic,
    this.expand = false,
    this.width,
    this.height,
  }) : style = CupertinoNativeButtonStyle.glassProminent;

  /// A [Text], [CupertinoSymbolImage], [Icon], or a [Row] of an icon and a
  /// [Text].
  final Widget child;
  final VoidCallback? onPressed;
  final CupertinoNativeButtonStyle style;

  /// SwiftUI `ControlSize`: height, padding and font.
  final CupertinoNativeControlSize sizeStyle;

  /// Tint of the button.
  final Color? color;
  final CupertinoNativeButtonBorderShape borderShape;

  /// Fill the width offered.
  final bool expand;

  /// Explicit point size, sizing the SwiftUI control itself and not just the
  /// Flutter box around it. Left null the control is sized by [sizeStyle] —
  /// except that an icon-only button falls back to the standard 44pt square,
  /// which is what a bar button is.
  final double? width;
  final double? height;

  @override
  State<CupertinoNativeButton> createState() => _CupertinoNativeButtonState();
}

/// What the native control is told to draw, read off [CupertinoNativeButton.child].
/// Reads the title, icon and text style out of a button's `child`.
///
/// Internal rather than private: the keyboard toolbar lowers a
/// `CupertinoNativeButton` written inline into a native description, and needs
/// the same reading of its label.
class ButtonLabel {
  ButtonLabel(Widget child) {
    void read(Widget w) {
      switch (w) {
        case Text(:final data?, :final style):
          title = data;
          textStyle = style;
        case CupertinoSymbolImage(:final name, :final size, :final color):
          icon = CupertinoNativeIcon.named(name, size: size, color: color);
        case Icon(icon: final data?, :final size, :final color):
          icon = CupertinoNativeIcon.flutter(data, size: size, color: color);
        case Row(:final children) || Wrap(:final children):
          children.forEach(read);
        case Padding(:final child?) || Center(:final child?):
          read(child);
        default:
          assert(
            false,
            'CupertinoNativeButton.child must be a Text, CupertinoSymbolImage, '
            'Icon or a Row of them, not ${w.runtimeType}: the native control '
            'draws its own label.',
          );
      }
    }

    read(child);
  }

  String title = '';
  TextStyle? textStyle;
  CupertinoNativeIcon? icon;

  bool get iconOnly => title.isEmpty && icon != null;
}

class _CupertinoNativeButtonState extends State<CupertinoNativeButton>
    with NativePlatformViewStateMixin {
  ButtonLabel get _label => ButtonLabel(widget.child);

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
    final old = ButtonLabel(oldWidget.child);
    final label = _label;
    if (old.title != label.title ||
        old.icon != label.icon ||
        old.textStyle != label.textStyle ||
        oldWidget.style != widget.style ||
        oldWidget.sizeStyle != widget.sizeStyle ||
        oldWidget.borderShape != widget.borderShape ||
        oldWidget.expand != widget.expand ||
        oldWidget.color != widget.color ||
        oldWidget.width != widget.width ||
        oldWidget.height != widget.height) {
      updateNativeView('updateButton', _toMap());
    }
  }

  Map<String, dynamic> _toMap() {
    final label = _label;
    return {
      'title': label.title,
      'icon': label.icon?.toMap(),
      'style': widget.style.name,
      'controlSize': widget.sizeStyle.name,
      'borderShape': widget.borderShape.name,
      'labelStyle': label.iconOnly
          ? CupertinoNativeButtonLabelStyle.iconOnly.name
          : label.icon == null
          ? CupertinoNativeButtonLabelStyle.titleOnly.name
          : CupertinoNativeButtonLabelStyle.titleAndIcon.name,
      'expand': widget.expand,
      'color': widget.color?.toARGB32(),
      'fontSize': label.textStyle?.fontSize,
      'fontWeight': label.textStyle?.fontWeight?.value,
      'textColor': label.textStyle?.color?.toARGB32(),
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
    requestIntrinsicSize();
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onPressed') {
      widget.onPressed?.call();
    }
  }

  /// Apple's control heights per `ControlSize`, used until the native
  /// measurement lands.
  static const _heights = <CupertinoNativeControlSize, double>{
    CupertinoNativeControlSize.mini: 28,
    CupertinoNativeControlSize.small: 32,
    CupertinoNativeControlSize.regular: 34,
    CupertinoNativeControlSize.large: 44,
    CupertinoNativeControlSize.extraLarge: 50,
  };

  /// No title to draw: the button is a square glyph target, the way a bar
  /// button is.
  bool get _isIconOnly => _label.iconOnly;

  /// The standard iOS touch target, and the size of a navigation-bar button.
  static const double _standardExtent = 44;

  /// An explicit value wins; otherwise an icon-only button is a 44pt square.
  double? get _width =>
      widget.width ?? (_isIconOnly && !widget.expand ? _standardExtent : null);
  double? get _height =>
      widget.height ?? (_isIconOnly && !widget.expand ? _standardExtent : null);

  double get _defaultHeight {
    final height = _heights[widget.sizeStyle]!;
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
        child: DefaultTextStyle(
          style: const TextStyle(color: Color(0xFFFFFFFF)),
          child: widget.child,
        ),
      ),
    );
  }
}
