import 'package:flutter/widgets.dart';

import 'internal/native_control.dart';

/// A native SwiftUI `MultiDatePicker` (iOS 16+): a calendar where several
/// days can be picked. Only the day of each [DateTime] matters.
class CupertinoNativeMultiDatePicker extends StatelessWidget
    implements NativeControlProvider {
  const CupertinoNativeMultiDatePicker({
    super.key,
    required this.dates,
    required this.onChanged,
    this.minimumDate,
    this.maximumDate,
    this.activeColor,
  });

  /// The picked days. Controlled: echo [onChanged] back into it.
  final Set<DateTime> dates;

  /// Called with every picked day (at local midnight). Null disables it.
  final ValueChanged<Set<DateTime>>? onChanged;

  /// First and last pickable days, both included.
  final DateTime? minimumDate;
  final DateTime? maximumDate;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) => nativeControl;

  @override
  NativeControl get nativeControl => NativeControl(
    kind: 'multiDatePicker',
    fallbackHeight: 380,
    props: {
      'dates': [for (final d in dates) d.millisecondsSinceEpoch.toDouble()],
      'minimumDate': minimumDate?.millisecondsSinceEpoch.toDouble(),
      'maximumDate': maximumDate?.millisecondsSinceEpoch.toDouble(),
      'tint': activeColor,
    },
    enabled: onChanged != null,
    onChanged: (v) => onChanged?.call({
      for (final ms in v as List)
        DateTime.fromMillisecondsSinceEpoch((ms as num).toInt()),
    }),
  );
}
