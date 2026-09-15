import 'package:flutter/cupertino.dart' show CupertinoDatePickerMode;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'internal/native_platform_view_mixin.dart';

/// The **compact** system date picker: renders as the tappable gray pill used
/// throughout iOS Settings/Calendar, and pops the native calendar or time
/// wheel over the app when tapped — overlay, dimming and animations are all
/// UIKit's.
///
/// ```dart
/// CupertinoNativeDatePicker(
///   initialDateTime: _start,
///   mode: CupertinoDatePickerMode.dateAndTime,
///   onDateTimeChanged: (d) => setState(() => _start = d),
/// )
/// ```
class CupertinoNativeDatePicker extends StatefulWidget {
  const CupertinoNativeDatePicker({
    super.key,
    required this.onDateTimeChanged,
    this.initialDateTime,
    this.mode = CupertinoDatePickerMode.dateAndTime,
    this.minimumDate,
    this.maximumDate,
    this.activeColor,
    this.width,
    this.height,
  });

  /// The shown date. Unlike Flutter's wheel, this picker follows it after
  /// creation too, so it can be driven from state. Defaults to now.
  final DateTime? initialDateTime;
  final ValueChanged<DateTime> onDateTimeChanged;

  /// [CupertinoDatePickerMode.monthYear] has no native compact equivalent and
  /// shows as [CupertinoDatePickerMode.date].
  final CupertinoDatePickerMode mode;
  final DateTime? minimumDate;
  final DateTime? maximumDate;

  /// Accent color of the popped-open calendar / selected values.
  final Color? activeColor;

  final double? width;
  final double? height;

  @override
  State<CupertinoNativeDatePicker> createState() =>
      _CupertinoNativeDatePickerState();
}

class _CupertinoNativeDatePickerState extends State<CupertinoNativeDatePicker>
    with NativePlatformViewStateMixin {
  bool? _lastIsDark;

  // Follows the app's own theme brightness, not the device's — a light app
  // forced on a dark-mode device should still get a light picker.
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  late final DateTime _createdAt = DateTime.now();
  DateTime get _value => widget.initialDateTime ?? _createdAt;

  Map<String, dynamic> _toMap() {
    return {
      'value': _value.millisecondsSinceEpoch,
      'mode': widget.mode == CupertinoDatePickerMode.monthYear
          ? CupertinoDatePickerMode.date.name
          : widget.mode.name,
      'minimumDate': widget.minimumDate?.millisecondsSinceEpoch,
      'maximumDate': widget.maximumDate?.millisecondsSinceEpoch,
      'tint': widget.activeColor?.toARGB32(),
      'isDark': _isDark,
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-push config if the app toggled light/dark at runtime.
    if (_lastIsDark != null && _lastIsDark != _isDark) {
      updateNativeView(
        'updateDatePicker',
        _toMap(),
        refreshIntrinsicSize: false,
      );
    }
    _lastIsDark = _isDark;
  }

  @override
  void didUpdateWidget(covariant CupertinoNativeDatePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.initialDateTime != widget.initialDateTime ||
        oldWidget.mode != widget.mode ||
        oldWidget.minimumDate != widget.minimumDate ||
        oldWidget.maximumDate != widget.maximumDate ||
        oldWidget.activeColor != widget.activeColor) {
      updateNativeView(
        'updateDatePicker',
        _toMap(),
        refreshIntrinsicSize: false,
      );
    }
  }

  Future<void> _onPlatformViewCreated(int id) async {
    setUpChannel(
      id,
      'cupertino_widgets/date_picker_$id',
      onMethodCall: _handleMethodCall,
    );
    requestIntrinsicSize();
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onChanged') {
      final ms = call.arguments as int;
      widget.onDateTimeChanged(DateTime.fromMillisecondsSinceEpoch(ms));
    }
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      // Non-iOS fallback: a plain value pill reporting no edits.
      return Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: const Color(0x1E787880),
          borderRadius: BorderRadius.circular(8),
        ),
        child: Text('$_value'),
      );
    }

    final platformView = wrapForTransition(
      UiKitView(
        viewType: 'com.example.cupertino_widgets/cupertino_native_date_picker',
        layoutDirection: TextDirection.ltr,
        creationParams: _toMap(),
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
        // Taps must reach the native pill immediately so the system popover
        // opens on first touch, even inside scrollables.
        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        gestureRecognizers: {
          Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
        },
      ),
    );

    return SizedBox(
      width: widget.width ?? intrinsicWidth ?? 148,
      height: widget.height ?? intrinsicHeight ?? 36,
      child: platformView,
    );
  }
}
