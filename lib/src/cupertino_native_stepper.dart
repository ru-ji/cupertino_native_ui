import 'package:flutter/widgets.dart';

import 'internal/native_control.dart';

/// A native SwiftUI `Stepper` — the − / + pair of the Settings app.
///
/// ```dart
/// CupertinoNativeStepper(
///   label: 'Guests: $_guests',
///   value: _guests.toDouble(),
///   min: 1,
///   max: 10,
///   onChanged: (v) => setState(() => _guests = v.round()),
/// )
/// ```
class CupertinoNativeStepper extends StatelessWidget
    implements NativeControlProvider {
  const CupertinoNativeStepper({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0,
    this.max = 100,
    this.step = 1,
    this.label,
    this.activeColor,
  });

  final double value;

  /// Null disables the stepper.
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final double step;

  /// Text leading the buttons; with it the stepper fills the row width, like
  /// a Settings row. Put the current value in it yourself.
  final String? label;
  final Color? activeColor;

  @override
  Widget build(BuildContext context) => nativeControl;

  @override
  NativeControl get nativeControl => NativeControl(
    kind: 'stepper',
    hug: label == null,
    props: {
      'value': value,
      'min': min,
      'max': max,
      'step': step,
      'label': label,
      'tint': activeColor?.toARGB32(),
    },
    enabled: onChanged != null,
    onChanged: (v) => onChanged?.call((v as num).toDouble()),
  );
}
