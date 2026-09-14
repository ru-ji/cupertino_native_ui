import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/material.dart';

import 'internal/native_platform_view_mixin.dart';
import 'internal/scroll_friendly_recognizer.dart';

class CupertinoNativeSwitch extends StatefulWidget {
  final bool value;
  final ValueChanged<bool>? onChanged;
  final String? label;
  final Color? activeColor;
  final TextStyle? textStyle;
  final double? width;
  final double? height;

  const CupertinoNativeSwitch({
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
  State<CupertinoNativeSwitch> createState() => _CupertinoNativeSwitchState();
}

class _CupertinoNativeSwitchState extends State<CupertinoNativeSwitch>
    with NativePlatformViewStateMixin {
  bool? _lastIsDark;

  // Follows the app's own theme brightness, not the device's — a light app
  // forced on a dark-mode phone should still get a light switch.
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-push config if the app toggled light/dark at runtime.
    if (_lastIsDark != null && _lastIsDark != _isDark) {
      updateNativeView('updateToggle', _toMap(), refreshIntrinsicSize: false);
    }
    _lastIsDark = _isDark;
  }

  @override
  void didUpdateWidget(covariant CupertinoNativeSwitch oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value ||
        oldWidget.label != widget.label ||
        oldWidget.activeColor != widget.activeColor ||
        oldWidget.textStyle != widget.textStyle) {
      updateNativeView('updateToggle', _toMap());
    }
  }

  Map<String, dynamic> _toMap() {
    return {
      'value': widget.value,
      'label': widget.label,
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
      'cupertino_widgets/toggle_$id',
      onMethodCall: _handleMethodCall,
    );
    requestIntrinsicSize();
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onChanged') {
      final bool newValue = call.arguments;
      widget.onChanged?.call(newValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final platformView = wrapForTransition(
        UiKitView(
          // Must match FlutterCupertinoPlugin.swift's registration. The widget
          // was renamed Toggle -> Switch on the Dart side only; this id is the
          // native contract and deliberately keeps the old spelling.
          viewType: 'com.example.cupertino_widgets/cupertino_native_toggle',
          layoutDirection: TextDirection.ltr,
          creationParams: _toMap(),
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
          // Claim drags immediately so press-and-slide reaches the native
          // switch instead of being taken by Flutter's gesture arena.
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
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

      // A labeled switch is a full-width list row: the native side already
      // fills the box, so only the height needs stating.
      if (widget.label != null) {
        return SizedBox(height: intrinsicHeight ?? 44.0, child: platformView);
      }

      // Native measurement, with a default for the frame or two before it
      // lands. 68x32 is iOS 26's reported 61x28 plus the margin the native
      // side adds for what the control paints outside its layout bounds (see
      // NativeToggleView.paintOverflow) — not the 51x31 UIKit drew for years,
      // which was 20% short in width. A box that under-shoots does not shrink
      // the control, it lets it draw outside: the switch is centred in
      // whatever box it is given, so the excess spilled, and on a row flush
      // to the screen edge it spilled off-screen.
      return SizedBox(
        width: intrinsicWidth ?? 68.0,
        height: intrinsicHeight ?? 32.0,
        child: platformView,
      );
    }

    // Fallback for non-iOS. Material ancestor so Switch works even in
    // Cupertino-only apps.
    return Material(
      type: MaterialType.transparency,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.label != null) Text(widget.label!),
          Switch(
            value: widget.value,
            onChanged: widget.onChanged,
            activeThumbColor: widget.activeColor,
          ),
        ],
      ),
    );
  }
}
