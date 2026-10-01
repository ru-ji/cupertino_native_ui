import 'package:flutter/material.dart' show Theme;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'internal/native_platform_view_mixin.dart';
import 'models/cupertino_native_icon.dart';
import 'internal/scroll_friendly_recognizer.dart';

class CupertinoNativeSlider extends StatefulWidget {
  const CupertinoNativeSlider({
    super.key,
    required this.value,
    required this.onChanged,
    this.min = 0.0,
    this.max = 1.0,
    this.divisions,
    this.activeColor,
    this.thumbColor,
    this.onChangeStart,
    this.onChangeEnd,
    this.minimumIcon,
    this.maximumIcon,
    this.showTicks = false,
    this.neutralValue,
  }) : assert(min <= max),
       assert(value >= min && value <= max);

  final double value;
  final ValueChanged<double>? onChanged;
  final double min;
  final double max;
  final int? divisions;
  final Color? activeColor;
  final Color? thumbColor;

  /// Called with the value when the user starts dragging.
  final ValueChanged<double>? onChangeStart;

  /// Called with the value when the user lets go.
  final ValueChanged<double>? onChangeEnd;

  /// Icon at the minimum end of the track (SwiftUI `minimumValueLabel`),
  /// e.g. `speaker.fill`.
  final CupertinoNativeIcon? minimumIcon;

  /// Icon at the maximum end of the track (`maximumValueLabel`).
  final CupertinoNativeIcon? maximumIcon;

  /// A tick mark at every one of the [divisions] (iOS 26+; needs [divisions]).
  final bool showTicks;

  /// The value the filled track grows from, e.g. 0 in a -1...1 balance
  /// slider (iOS 26+).
  final double? neutralValue;

  @override
  State<CupertinoNativeSlider> createState() => _CupertinoNativeSliderState();
}

class _CupertinoNativeSliderState extends State<CupertinoNativeSlider>
    with NativePlatformViewStateMixin {
  bool? _lastIsDark;

  // Follows the app's own theme brightness, not the device's — a light app
  // forced on a dark-mode phone should still get a light slider.
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-push props if the app toggled light/dark at runtime.
    if (_lastIsDark != null && _lastIsDark != _isDark) {
      updateNativeView('updateProps', {
        'isDark': _isDark,
      }, refreshIntrinsicSize: false);
    }
    _lastIsDark = _isDark;
  }

  @override
  Widget build(BuildContext context) {
    const String viewType =
        'com.example.cupertino_widgets/cupertino_native_slider';
    final Map<String, dynamic> creationParams = _props();

    // The slider fills the width offered, so only its height needs stating:
    // SwiftUI's own, through the same `getIntrinsicSize` round trip the button
    // makes. 44 is the standard control height and stands in until that lands.
    return SizedBox(
      height: intrinsicHeight ?? 44,
      child: wrapForTransition(
        UiKitView(
          viewType: viewType,
          layoutDirection: TextDirection.ltr,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
          onPlatformViewCreated: _onPlatformViewCreated,
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
          gestureRecognizers: scrollFriendlyGestures,
        ),
      ),
    );
  }

  Map<String, dynamic> _props() => {
    'value': widget.value,
    'min': widget.min,
    'max': widget.max,
    'divisions': widget.divisions,
    'activeColor': widget.activeColor?.toARGB32(),
    'thumbColor': widget.thumbColor?.toARGB32(),
    'isEnabled': widget.onChanged != null,
    'isDark': _isDark,
    'minimumIcon': widget.minimumIcon?.toMap(),
    'maximumIcon': widget.maximumIcon?.toMap(),
    'showTicks': widget.showTicks,
    'neutralValue': widget.neutralValue,
  };

  Future<void> _onPlatformViewCreated(int id) async {
    setUpChannel(id, 'adaptive_slider_$id', onMethodCall: _handleMethodCall);
    requestIntrinsicSize();
  }

  Future<void> _handleMethodCall(MethodCall call) async {
    final value = (call.arguments as num?)?.toDouble();
    if (value == null) return;
    switch (call.method) {
      case 'onChanged':
        widget.onChanged?.call(value);
      case 'onChangeStart':
        widget.onChangeStart?.call(value);
      case 'onChangeEnd':
        widget.onChangeEnd?.call(value);
    }
  }

  @override
  void didUpdateWidget(CupertinoNativeSlider oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.value != widget.value ||
        oldWidget.min != widget.min ||
        oldWidget.max != widget.max ||
        oldWidget.divisions != widget.divisions ||
        oldWidget.activeColor != widget.activeColor ||
        oldWidget.thumbColor != widget.thumbColor ||
        oldWidget.minimumIcon != widget.minimumIcon ||
        oldWidget.maximumIcon != widget.maximumIcon ||
        oldWidget.showTicks != widget.showTicks ||
        oldWidget.neutralValue != widget.neutralValue ||
        (oldWidget.onChanged == null) != (widget.onChanged == null)) {
      updateNativeView('updateProps', _props(), refreshIntrinsicSize: false);
    }
  }
}
