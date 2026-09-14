import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'internal/native_platform_view_mixin.dart';

enum CupertinoNativeProgressStyle { automatic, linear, circular }

class CupertinoNativeProgressIndicator extends StatefulWidget {
  const CupertinoNativeProgressIndicator({
    super.key,
    this.value,
    this.total = 1.0,
    this.label,
    this.style = CupertinoNativeProgressStyle.automatic,
    this.activeColor,
  });

  /// The progress value.
  /// If null, loops indefinitely (indeterminate).
  /// If provided, displays progress from 0.0 to [total].
  final double? value;

  /// The total value corresponding to 100% progress. Defaults to 1.0.
  final double total;

  /// An optional label to display with the progress.
  final String? label;

  /// The style of the progress view.
  final CupertinoNativeProgressStyle style;

  /// The tint color of the progress view.
  final Color? activeColor;

  @override
  State<CupertinoNativeProgressIndicator> createState() =>
      _CupertinoNativeProgressIndicatorState();
}

class _CupertinoNativeProgressIndicatorState
    extends State<CupertinoNativeProgressIndicator>
    with NativePlatformViewStateMixin {
  bool? _lastIsDark;

  // Follows the app's own theme brightness, not the device's — a light app
  // forced on a dark-mode phone should still get a light indicator.
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-push config if the app toggled light/dark at runtime.
    if (_lastIsDark != null && _lastIsDark != _isDark) {
      updateNativeView('updateProgress', _toMap(), refreshIntrinsicSize: false);
    }
    _lastIsDark = _isDark;
  }

  Map<String, dynamic> _toMap() {
    return {
      'value': widget.value,
      'total': widget.total,
      'label': widget.label,
      'style': widget.style.index,
      'color': widget.activeColor?.toARGB32(),
      'isDark': _isDark,
    };
  }

  Future<void> _onPlatformViewCreated(int id) async {
    setUpChannel(id, 'cupertino_widgets/progress_$id');
    requestIntrinsicSize();
  }

  @override
  void didUpdateWidget(CupertinoNativeProgressIndicator oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value ||
        widget.total != oldWidget.total ||
        widget.label != oldWidget.label ||
        widget.style != oldWidget.style ||
        widget.activeColor != oldWidget.activeColor) {
      updateNativeView('updateProgress', _toMap());
    }
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      // Circular: SwiftUI's own size, ~20x20. Linear: stretches across the
      // width offered and reports its height (4pt of track, more with a
      // label). Both come from `getIntrinsicSize` like the button's; the
      // numbers below stand in only until that measurement lands.
      // Circular states both axes; linear fills the width offered and states
      // only its height. Either way the numbers are SwiftUI's, through the
      // same `getIntrinsicSize` round trip the button makes — the constants
      // stand in until the measurement lands.
      final circular = widget.style == CupertinoNativeProgressStyle.circular;
      return SizedBox(
        width: circular ? (intrinsicWidth ?? 20) : null,
        height: circular
            ? (intrinsicHeight ?? 20)
            : (intrinsicHeight ?? (widget.label != null ? 44 : 4)),
        child: wrapForTransition(
          UiKitView(
            viewType: 'com.example.cupertino_widgets/cupertino_native_progress',
            layoutDirection: TextDirection.ltr,
            creationParams: _toMap(),
            creationParamsCodec: const StandardMessageCodec(),
            onPlatformViewCreated: _onPlatformViewCreated,
          ),
        ),
      );
    }

    // Fallback or Android impl could go here (e.g. CircularProgressIndicator)
    return const SizedBox();
  }
}
