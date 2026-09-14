import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'internal/native_platform_view_mixin.dart';
import 'internal/scroll_friendly_recognizer.dart';

class CupertinoNativeSegmentedControl extends StatefulWidget {
  final List<String> children;
  final int groupValue;
  final ValueChanged<int>? onChanged;
  final Color? activeColor;
  final double? width;
  final double? height;

  const CupertinoNativeSegmentedControl({
    super.key,
    required this.children,
    required this.groupValue,
    this.onChanged,
    this.activeColor,
    this.width,
    this.height,
  });

  @override
  State<CupertinoNativeSegmentedControl> createState() =>
      _CupertinoNativeSegmentedControlState();
}

class _CupertinoNativeSegmentedControlState
    extends State<CupertinoNativeSegmentedControl>
    with NativePlatformViewStateMixin {
  bool? _lastIsDark;

  // Follows the app's own theme brightness, not the device's — a light app
  // forced on a dark-mode phone should still get a light control.
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-push config if the app toggled light/dark at runtime.
    if (_lastIsDark != null && _lastIsDark != _isDark) {
      updateNativeView(
        'updateSegmentedControl',
        _toMap(),
        refreshIntrinsicSize: false,
      );
    }
    _lastIsDark = _isDark;
  }

  @override
  void didUpdateWidget(covariant CupertinoNativeSegmentedControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.children, widget.children) ||
        oldWidget.groupValue != widget.groupValue ||
        oldWidget.activeColor != widget.activeColor) {
      updateNativeView('updateSegmentedControl', _toMap());
    }
  }

  Map<String, dynamic> _toMap() {
    return {
      'items': widget.children,
      'selectedIndex': widget.groupValue,
      'color': widget.activeColor?.toARGB32(),
      'isDark': _isDark,
    };
  }

  Future<void> _onPlatformViewCreated(int id) async {
    setUpChannel(
      id,
      'cupertino_widgets/segmented_$id',
      onMethodCall: _handleMethodCall,
    );
    requestIntrinsicSize();
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onValueChanged') {
      final int newValue = call.arguments;
      widget.onChanged?.call(newValue);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final platformView = wrapForTransition(
        UiKitView(
          viewType: 'com.example.cupertino_widgets/cupertino_native_segmented',
          layoutDirection: TextDirection.ltr,
          creationParams: _toMap(),
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
          // Claim drags immediately so press-and-slide across segments reaches
          // the native control instead of being taken by Flutter's gesture arena.
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

      // Use intrinsic size from native view, with defaults until size is received
      // Default: full width x 32 height for segmented control
      return SizedBox(
        width: intrinsicWidth ?? 200,
        height: intrinsicHeight ?? 32,
        child: platformView,
      );
    }

    // Fallback for non-iOS
    return SizedBox(
      height: 40,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: List.generate(widget.children.length, (index) {
          final isSelected = widget.groupValue == index;
          return GestureDetector(
            onTap: () => widget.onChanged?.call(index),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              color: isSelected
                  ? (widget.activeColor ?? const Color(0xFF007AFF))
                  : null,
              child: Center(
                child: Text(
                  widget.children[index],
                  style: TextStyle(
                    color: isSelected
                        ? const Color(0xFFFFFFFF)
                        : const Color(0xFF000000),
                  ),
                ),
              ),
            ),
          );
        }),
      ),
    );
  }
}
