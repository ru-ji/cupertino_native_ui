import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';

import 'internal/native_platform_view_mixin.dart';
import 'internal/scroll_friendly_recognizer.dart';

/// A native iOS 26 radio button rendered by SwiftUI — a circular selection
/// control that fills with [activeColor] and shows a white centre dot when
/// selected.
///
/// iOS has no system radio, so the native side draws this one: unselected it
/// is a quaternary circle with a separator ring, selected it takes the
/// [activeColor] (system accent by default) with a dot that springs in.
///
/// Radio buttons are group controls: keep your own group state in Dart and
/// give each option its own `value` + `onChanged` (selecting one deselects
/// the others in your callback), the same shape Flutter's `Radio` uses.
/// Pass null for [onChanged] (or omit it) for a disabled button.
///
/// [label] turns the control into a full-width list row (text leading,
/// button trailing), like the labeled [CupertinoNativeSwitch].
class CupertinoNativeRadio extends StatefulWidget {
  final bool value;

  /// Called with `true` when the button is tapped. Null disables the control.
  final ValueChanged<bool>? onChanged;

  final String? label;

  /// The selected fill. Null uses the system accent color.
  final Color? activeColor;

  /// The [label]'s style.
  final TextStyle? textStyle;

  /// Explicit button size; otherwise the native 44x44 touch target is used.
  final double? width;
  final double? height;

  const CupertinoNativeRadio({
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
  State<CupertinoNativeRadio> createState() => _CupertinoNativeRadioState();
}

class _CupertinoNativeRadioState extends State<CupertinoNativeRadio>
    with NativePlatformViewStateMixin {
  bool? _lastIsDark;

  // Follows the app's own theme brightness, not the device's — a light app
  // forced on a dark-mode phone should still get a light radio.
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-push config if the app toggled light/dark at runtime.
    if (_lastIsDark != null && _lastIsDark != _isDark) {
      updateNativeView('updateRadio', _toMap(), refreshIntrinsicSize: false);
    }
    _lastIsDark = _isDark;
  }

  @override
  void didUpdateWidget(covariant CupertinoNativeRadio oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value ||
        oldWidget.onChanged != widget.onChanged ||
        oldWidget.label != widget.label ||
        oldWidget.activeColor != widget.activeColor ||
        oldWidget.textStyle != widget.textStyle) {
      updateNativeView('updateRadio', _toMap());
    }
  }

  Map<String, dynamic> _toMap() {
    return {
      'value': widget.value,
      'enabled': widget.onChanged != null,
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
      'cupertino_widgets/radio_$id',
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
          viewType: 'com.example.cupertino_widgets/cupertino_native_radio',
          layoutDirection: TextDirection.ltr,
          creationParams: _toMap(),
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
          // The whole button (including its 44pt touch target) takes taps,
          // and press-and-release belongs to the control, not to a scroll.
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
          gestureRecognizers: scrollFriendlyGestures,
        ),
      );

      if (widget.width != null || widget.height != null) {
        return SizedBox(
          width: widget.width,
          height: widget.height,
          child: platformView,
        );
      }

      // A labeled radio is a full-width list row: the native side fills the
      // box, so only the height needs stating.
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

    // Fallback for non-iOS. Material ancestor so Radio works even in
    // Cupertino-only apps.
    return Material(
      type: MaterialType.transparency,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (widget.label != null) Text(widget.label!),
          Opacity(
            opacity: widget.onChanged == null ? 0.35 : 1,
            child: IgnorePointer(
              ignoring: widget.onChanged == null,
              child: RadioGroup<bool>(
                groupValue: widget.value,
                onChanged: (value) =>
                    widget.onChanged?.call(value ?? widget.value),
                child: Radio<bool>(
                  value: widget.value,
                  activeColor: widget.activeColor,
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
