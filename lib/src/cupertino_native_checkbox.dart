import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'internal/native_platform_view_mixin.dart';
import 'internal/native_color.dart';

/// A checkbox rendered by SwiftUI.
///
/// iOS has no system checkbox, so this is the selection symbol Reminders and
/// Mail use: `circle` when off, `checkmark.circle.fill` in the [activeColor]
/// (system accent by default) when on. Taps report through [onChanged]; pass
/// null (or omit it) for a disabled box, Flutter-style.
///
/// [label] turns the control into a full-width list row (text leading, box
/// trailing), like the labeled [CupertinoNativeSwitch].
class CupertinoNativeCheckbox extends StatefulWidget {
  final bool value;

  /// Called with the new value when the user taps the box. Null disables the
  /// control — the box stays visible but dimmed and inert.
  final ValueChanged<bool>? onChanged;

  final String? label;

  /// The checked fill. Null uses the system accent color.
  final Color? activeColor;

  /// The [label]'s style.
  final TextStyle? textStyle;

  /// Explicit box size; otherwise the native 44x44 touch target is used.
  final double? width;
  final double? height;

  const CupertinoNativeCheckbox({
    super.key,
    required this.value,
    this.onChanged,
    this.label,
    this.activeColor,
    this.textStyle,
    this.width,
    this.height,
  });

  @override
  State<CupertinoNativeCheckbox> createState() =>
      _CupertinoNativeCheckboxState();
}

class _CupertinoNativeCheckboxState extends State<CupertinoNativeCheckbox>
    with NativePlatformViewStateMixin {
  bool? _lastIsDark;

  // Follows the app's own theme brightness, not the device's — a light app
  // forced on a dark-mode phone should still get a light checkbox.
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-push config if the app toggled light/dark at runtime.
    if (_lastIsDark != null && _lastIsDark != _isDark) {
      updateNativeView('updateCheckbox', _toMap(), refreshIntrinsicSize: false);
    }
    _lastIsDark = _isDark;
  }

  @override
  void didUpdateWidget(covariant CupertinoNativeCheckbox oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value ||
        oldWidget.onChanged != widget.onChanged ||
        oldWidget.label != widget.label ||
        oldWidget.activeColor != widget.activeColor ||
        oldWidget.textStyle != widget.textStyle) {
      updateNativeView('updateCheckbox', _toMap());
    }
  }

  Map<String, dynamic> _toMap() {
    return {
      'value': widget.value,
      'enabled': widget.onChanged != null,
      'label': widget.label,
      'color': nativeArgb(widget.activeColor, isDark: _isDark),
      'fontSize': widget.textStyle?.fontSize,
      'fontWeight': widget.textStyle?.fontWeight == null
          ? null
          : widget.textStyle!.fontWeight!.value ~/ 100 - 1,
      'textColor': nativeArgb(widget.textStyle?.color, isDark: _isDark),
      'isDark': _isDark,
    };
  }

  Future<void> _onPlatformViewCreated(int id) async {
    setUpChannel(
      id,
      'cupertino_widgets/checkbox_$id',
      onMethodCall: _handleMethodCall,
    );
    requestIntrinsicSize();
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onChanged') {
      widget.onChanged?.call(call.arguments as bool);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final platformView = wrapForTransition(
        UiKitView(
          viewType: 'com.example.cupertino_widgets/cupertino_native_checkbox',
          layoutDirection: TextDirection.ltr,
          creationParams: _toMap(),
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
          // The whole box (including its 44pt touch target) takes taps, and
          // press-and-release belongs to the control, not to a scroll.
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
          gestureRecognizers: scrollFriendlyGestures(),
        ),
      );

      if (widget.width != null || widget.height != null) {
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: platformView,
        );
      }

      // A labeled checkbox is a full-width list row: the native side fills
      // the box, so only the height needs stating.
      if (widget.label != null) {
        return SizedBox(height: intrinsicHeight ?? 44.0, child: platformView);
      }

      // The native 44x44 touch target, with a default for the frames before
      // the measurement lands.
      return SizedBox(
        width: intrinsicWidth ?? 44.0,
        height: intrinsicHeight ?? 44.0,
        child: platformView,
      );
    }

    // Fallback for non-iOS. Material ancestor so Checkbox works even in
    // Cupertino-only apps.
    return Material(
      type: MaterialType.transparency,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.label != null) Text(widget.label!),
          Checkbox(
            value: widget.value,
            onChanged: widget.onChanged == null
                ? null
                : (value) => widget.onChanged!(value ?? false),
            activeColor: widget.activeColor,
          ),
        ],
      ),
    );
  }
}
