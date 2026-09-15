import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'internal/native_platform_view_mixin.dart';
import 'internal/scroll_friendly_recognizer.dart';

/// iOS's segmented control, rendered by SwiftUI. Same shape as Flutter's
/// [CupertinoSlidingSegmentedControl]: [children] maps each value to its
/// segment label — a [Text], whose string is what the native control shows.
class CupertinoNativeSlidingSegmentedControl<T extends Object>
    extends StatefulWidget {
  CupertinoNativeSlidingSegmentedControl({
    super.key,
    required this.children,
    required this.onValueChanged,
    this.groupValue,
    this.thumbColor,
    this.width,
    this.height,
  }) : _menu = false,
       assert(children.length >= 2),
       assert(
         children.values.every((w) => w is Text && w.data != null),
         'Each segment must be a Text with a string: the native control '
         'draws labels, not arbitrary widgets.',
       );

  const CupertinoNativeSlidingSegmentedControl._menu({
    super.key,
    required this.children,
    required this.onValueChanged,
    this.groupValue,
    this.thumbColor,
    this.width,
    this.height,
  }) : _menu = true;

  final bool _menu;

  final Map<T, Widget> children;
  final T? groupValue;
  final ValueChanged<T?> onValueChanged;

  /// Tint of the selected segment.
  final Color? thumbColor;
  final double? width;
  final double? height;

  @override
  State<CupertinoNativeSlidingSegmentedControl<T>> createState() =>
      _CupertinoNativeSegmentedControlState<T>();
}

class _CupertinoNativeSegmentedControlState<T extends Object>
    extends State<CupertinoNativeSlidingSegmentedControl<T>>
    with NativePlatformViewStateMixin {
  List<T> get _keys => widget.children.keys.toList();
  List<String> get _labels =>
      widget.children.values.map((w) => (w as Text).data!).toList();

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
  void didUpdateWidget(
    covariant CupertinoNativeSlidingSegmentedControl<T> oldWidget,
  ) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.children.keys.toList(), _keys) ||
        !listEquals(
          oldWidget.children.values.map((w) => (w as Text).data).toList(),
          _labels,
        ) ||
        oldWidget.groupValue != widget.groupValue ||
        oldWidget.thumbColor != widget.thumbColor) {
      updateNativeView('updateSegmentedControl', _toMap());
    }
  }

  Map<String, dynamic> _toMap() {
    return {
      'items': _labels,
      'style': widget._menu ? 'menu' : 'segmented',
      'selectedIndex': widget.groupValue == null
          ? -1
          : _keys.indexOf(widget.groupValue as T),
      'color': widget.thumbColor?.toARGB32(),
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
      final int index = call.arguments;
      if (index >= 0 && index < _keys.length) {
        widget.onValueChanged(_keys[index]);
      }
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
        children: List.generate(_keys.length, (index) {
          final isSelected = widget.groupValue == _keys[index];
          return GestureDetector(
            onTap: () => widget.onValueChanged(_keys[index]),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              color: isSelected
                  ? (widget.thumbColor ?? const Color(0xFF007AFF))
                  : null,
              child: Center(
                child: Text(
                  _labels[index],
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

/// iOS's menu picker, rendered by SwiftUI: a button showing the selected
/// value that opens a native menu of the options. Same API as
/// [CupertinoNativeSlidingSegmentedControl].
class CupertinoNativePicker<T extends Object>
    extends CupertinoNativeSlidingSegmentedControl<T> {
  const CupertinoNativePicker({
    super.key,
    required super.children,
    required super.onValueChanged,
    super.groupValue,
    super.thumbColor,
    super.width,
    super.height,
  }) : super._menu();
}
