import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'callbacks.dart';
import 'internal/native_platform_view_mixin.dart';
import 'internal/scroll_friendly_recognizer.dart';
import 'models/cupertino_native_button_extra_options.dart';
import 'models/cupertino_native_menu_item.dart';
import 'models/cupertino_native_button_style.dart';

class CupertinoNativeMenu extends StatefulWidget {
  final String title;
  final String? systemImage;
  final CupertinoNativeButtonStyle style;

  /// Outline of the button that opens the menu. With a glass [style] this is
  /// all that separates a capsule from a circle.
  final CupertinoNativeButtonBorderShape borderShape;

  /// Which halves of the anchor the button shows. A circular
  /// [borderShape] needs [CupertinoNativeButtonLabelStyle.iconOnly] — an anchor
  /// still carrying its title is laid out as a capsule whatever shape is asked
  /// for — so pair the two for the icon-only glass circle the bar uses.
  final CupertinoNativeButtonLabelStyle labelStyle;

  /// The anchor's metrics — height, padding and font — rather than an explicit
  /// size.
  final CupertinoNativeControlSize controlSize;
  final Color? activeColor;
  final TextStyle? textStyle;
  final List<CupertinoNativeMenuItem> items;
  final CupertinoNativeMenuActionCallback? onAction;
  final double? width;
  final double? height;

  const CupertinoNativeMenu({
    super.key,
    required this.items,
    this.title = 'Options',
    this.systemImage,
    this.style = CupertinoNativeButtonStyle.automatic,
    this.borderShape = CupertinoNativeButtonBorderShape.automatic,
    this.labelStyle = CupertinoNativeButtonLabelStyle.titleAndIcon,
    this.controlSize = CupertinoNativeControlSize.regular,
    this.activeColor,
    this.textStyle,
    this.onAction,
    this.width,
    this.height,
  });

  @override
  State<CupertinoNativeMenu> createState() => _CupertinoNativeMenuState();
}

class _CupertinoNativeMenuState extends State<CupertinoNativeMenu>
    with NativePlatformViewStateMixin {
  bool? _lastIsDark;

  // Follows the app's own theme brightness, not the device's — a light app
  // forced on a dark-mode device should still get a light menu.
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-push config if the app toggled light/dark at runtime.
    if (_lastIsDark != null && _lastIsDark != _isDark) {
      updateNativeView('updateMenu', _toMap());
    }
    _lastIsDark = _isDark;
  }

  String? _sent;

  @override
  void didUpdateWidget(covariant CupertinoNativeMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Item lists are usually rebuilt each frame, so compare what would be sent:
    // an update re-creates the native menu.
    final sent = jsonEncode(_toMap());
    if (sent == _sent) return;
    _sent = sent;
    updateNativeView('updateMenu', _toMap());
  }

  Map<String, dynamic> _toMap() {
    return {
      'title': widget.title,
      'systemImage': widget.systemImage,
      'items': widget.items.map((e) => e.toMap()).toList(),
      'style': widget.style.name,
      'borderShape': widget.borderShape.name,
      'labelStyle': widget.labelStyle.name,
      'controlSize': widget.controlSize.name,
      'color': widget.activeColor?.toARGB32(),
      'fontSize': widget.textStyle?.fontSize,
      'fontWeight': widget.textStyle?.fontWeight?.value,
      'textColor': widget.textStyle?.color?.toARGB32(),
      'isDark': _isDark,
    };
  }

  Future<void> _onPlatformViewCreated(int id) async {
    setUpChannel(
      id,
      'cupertino_widgets/menu_$id',
      onMethodCall: _handleMethodCall,
    );
    requestIntrinsicSize();
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onAction') {
      final String id = call.arguments['id'];
      final dynamic value = call.arguments['value'];
      widget.onAction?.call(id, value);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final platformView = wrapForTransition(
        UiKitView(
          viewType: 'com.example.cupertino_widgets/cupertino_native_menu',
          layoutDirection: TextDirection.ltr,
          creationParams: _toMap(),
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
          // The system menu takes over the touch; without a recognizer claiming
          // it, Flutter never sees it end and every later touch stays blocked.
          gestureRecognizers: scrollFriendlyGestures,
        ),
      );

      // If explicit width/height provided, use them
      if (widget.width != null || widget.height != null) {
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: platformView,
        );
      }

      // Use intrinsic size from native view, with defaults until size is received
      // Default: 100x44 for menu button
      return SizedBox(
        width: intrinsicWidth ?? 100,
        height: intrinsicHeight ?? 44,
        child: platformView,
      );
    }

    return SizedBox(
      height: widget.height ?? 44,
      width: widget.width ?? 100,
      child: const Center(child: Text("iOS Only")),
    );
  }
}
