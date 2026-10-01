import 'package:flutter/widgets.dart';

import 'internal/native_control.dart';

/// A native SwiftUI `ColorPicker`: a colour well that opens the system colour
/// picker.
class CupertinoNativeColorPicker extends StatelessWidget
    implements NativeControlProvider {
  const CupertinoNativeColorPicker({
    super.key,
    required this.color,
    required this.onChanged,
    this.label,
    this.supportsOpacity = true,
  });

  final Color color;

  /// Null disables the picker.
  final ValueChanged<Color>? onChanged;

  /// Text leading the well; with it the picker fills the row width.
  final String? label;

  /// Whether the system picker offers an opacity slider.
  final bool supportsOpacity;

  @override
  Widget build(BuildContext context) => nativeControl;

  @override
  NativeControl get nativeControl => NativeControl(
    kind: 'colorPicker',
    hug: label == null,
    props: {
      'color': color.toARGB32(),
      'label': label,
      'supportsOpacity': supportsOpacity,
    },
    enabled: onChanged != null,
    onChanged: (v) => onChanged?.call(Color(v as int)),
  );
}
