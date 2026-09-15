import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'internal/native_platform_view_mixin.dart';

/// iOS's spinning activity indicator, rendered by SwiftUI. Same shape as
/// Flutter's [CupertinoActivityIndicator].
class CupertinoNativeActivityIndicator extends StatelessWidget {
  const CupertinoNativeActivityIndicator({
    super.key,
    this.color,
    this.animating = true,
    this.radius = 10,
  }) : assert(radius > 0);

  final Color? color;

  /// False draws nothing: the native spinner has no paused state.
  final bool animating;

  /// Half the indicator's extent. 10 is the system size.
  final double radius;

  @override
  Widget build(BuildContext context) {
    if (!animating) return SizedBox.square(dimension: radius * 2);
    final indicator = _NativeProgress(circular: true, color: color);
    return radius == 10
        ? indicator
        : SizedBox.square(
            dimension: radius * 2,
            child: FittedBox(child: indicator),
          );
  }
}

/// iOS's progress bar, rendered by SwiftUI. Same shape as Flutter's
/// [CupertinoLinearActivityIndicator].
class CupertinoNativeLinearActivityIndicator extends StatelessWidget {
  const CupertinoNativeLinearActivityIndicator({
    super.key,
    required this.progress,
    this.height = 4.5,
    this.color,
  }) : assert(progress >= 0 && progress <= 1),
       assert(height > 0);

  /// 0 to 1.
  final double progress;
  final double height;
  final Color? color;

  @override
  Widget build(BuildContext context) => SizedBox(
    height: height,
    child: _NativeProgress(circular: false, value: progress, color: color),
  );
}

class _NativeProgress extends StatefulWidget {
  const _NativeProgress({required this.circular, this.value, this.color});

  final bool circular;
  final double? value;
  final Color? color;

  @override
  State<_NativeProgress> createState() => _NativeProgressState();
}

class _NativeProgressState extends State<_NativeProgress>
    with NativePlatformViewStateMixin {
  bool? _lastIsDark;

  // Follows the app's own theme brightness, not the device's.
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Map<String, dynamic> _toMap() => {
    'value': widget.value,
    'total': 1.0,
    'label': null,
    // Native style index: 0 automatic, 1 linear, 2 circular.
    'style': widget.circular ? 2 : 1,
    'color': widget.color?.toARGB32(),
    'isDark': _isDark,
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_lastIsDark != null && _lastIsDark != _isDark) {
      updateNativeView('updateProgress', _toMap(), refreshIntrinsicSize: false);
    }
    _lastIsDark = _isDark;
  }

  @override
  void didUpdateWidget(_NativeProgress oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.value != oldWidget.value ||
        widget.circular != oldWidget.circular ||
        widget.color != oldWidget.color) {
      updateNativeView('updateProgress', _toMap());
    }
  }

  Future<void> _onPlatformViewCreated(int id) async {
    setUpChannel(id, 'cupertino_widgets/progress_$id');
    requestIntrinsicSize();
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) return const SizedBox();
    // Circular states both axes (SwiftUI's ~20pt); linear fills the width
    // offered. The constants stand in until the native measurement lands.
    return SizedBox(
      width: widget.circular ? (intrinsicWidth ?? 20) : null,
      height: widget.circular ? (intrinsicHeight ?? 20) : null,
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
}
