import 'package:flutter/widgets.dart';

import 'internal/native_control.dart';

/// SwiftUI's gauge styles.
enum CupertinoNativeGaugeStyle {
  /// A plain linear bar with its labels.
  automatic,

  /// A linear bar filled up to the value.
  linearCapacity,

  /// The widget-style ring with the value in the middle.
  circular,

  /// A ring filled up to the value.
  circularCapacity,
}

/// A native SwiftUI `Gauge` (iOS 16+; a progress bar on iOS 15) — a value
/// within a range, the battery or storage meter look.
class CupertinoNativeGauge extends StatelessWidget
    implements NativeControlProvider {
  const CupertinoNativeGauge({
    super.key,
    required this.value,
    this.min = 0,
    this.max = 1,
    this.label,
    this.currentValueLabel,
    this.minimumValueLabel,
    this.maximumValueLabel,
    this.style = CupertinoNativeGaugeStyle.automatic,
    this.color,
  });

  final double value;
  final double min;
  final double max;
  final String? label;

  /// Shown inside a circular gauge, beside a linear one.
  final String? currentValueLabel;
  final String? minimumValueLabel;
  final String? maximumValueLabel;
  final CupertinoNativeGaugeStyle style;
  final Color? color;

  bool get _circular =>
      style == CupertinoNativeGaugeStyle.circular ||
      style == CupertinoNativeGaugeStyle.circularCapacity;

  @override
  Widget build(BuildContext context) => nativeControl;

  @override
  NativeControl get nativeControl => NativeControl(
    kind: 'gauge',
    hug: _circular,
    props: {
      'value': value,
      'min': min,
      'max': max,
      'label': label,
      'currentValueLabel': currentValueLabel,
      'minimumValueLabel': minimumValueLabel,
      'maximumValueLabel': maximumValueLabel,
      'gaugeStyle': style.name,
      'tint': color,
    },
  );
}
