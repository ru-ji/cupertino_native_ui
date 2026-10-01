import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'keyboard_avoidance.dart';
import 'native_platform_view_mixin.dart';
import 'scroll_friendly_recognizer.dart';

/// A control that stands for a [NativeControl] — what lets the lowering put
/// it straight into a SwiftUI surface (a list row, a native body).
abstract interface class NativeControlProvider {
  NativeControl get nativeControl;
}

/// The platform view behind the single-value controls (stepper, color
/// picker, gauge, multi-date picker, text editor): one native view type, the
/// SwiftUI control picked by [kind]. See `NativeControlView.swift`.
///
/// ponytail: no Flutter fallback off iOS (renders nothing); add one per
/// control if the package ever targets Android.
class NativeControl extends StatefulWidget {
  const NativeControl({
    super.key,
    required this.kind,
    required this.props,
    this.onChanged,
    this.enabled = true,
    this.hug = false,
    this.height,
    this.fallbackHeight = 44,
    this.gestures,
  });

  final String kind;
  final Map<String, Object?> props;
  final ValueChanged<Object?>? onChanged;
  final bool enabled;

  /// Size to the control (centred) instead of filling the width.
  final bool hug;

  /// A fixed height; otherwise the control's own.
  final double? height;

  /// Height until the native measurement lands.
  final double fallbackHeight;
  final Set<Factory<OneSequenceGestureRecognizer>>? gestures;

  @override
  State<NativeControl> createState() => _NativeControlState();
}

class _NativeControlState extends State<NativeControl>
    with NativePlatformViewStateMixin, WidgetsBindingObserver {
  String? _sent;

  /// The native text editor holds the keyboard (reported over `onFocus`).
  bool _focused = false;
  double _lastBottomInset = 0;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// Lifts the focused editor above the keyboard on each rising inset tick,
  /// the way [CupertinoNativeTextField] does — see its `didChangeMetrics`.
  @override
  void didChangeMetrics() {
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    if (view == null) return;
    final bottomInset = view.viewInsets.bottom;
    final rising = bottomInset > _lastBottomInset;
    _lastBottomInset = bottomInset;
    if (rising && _focused) _revealAboveKeyboard();
  }

  void _revealAboveKeyboard({bool animate = false}) {
    if (!mounted || !_focused) return;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    revealAboveKeyboard(context, box, animate: animate);
  }

  // The app's brightness, not the device's.
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Map<String, Object?> _map() => {
    ...widget.props,
    'kind': widget.kind,
    'hug': widget.hug,
    'enabled': widget.enabled,
    'isDark': _isDark,
  };

  void _push() {
    final map = _map();
    final json = jsonEncode(map);
    if (_sent == null || json == _sent) return;
    _sent = json;
    updateNativeView('update', map, refreshIntrinsicSize: false);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _push();
  }

  @override
  void didUpdateWidget(covariant NativeControl oldWidget) {
    super.didUpdateWidget(oldWidget);
    _push();
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return const SizedBox.shrink();
    }
    final params = _map();
    _sent ??= jsonEncode(params);
    final view = wrapForTransition(
      UiKitView(
        viewType: 'com.example.cupertino_widgets/cupertino_native_control',
        layoutDirection: TextDirection.ltr,
        creationParams: params,
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: (id) {
          setUpChannel(
            id,
            'cupertino_widgets/control_$id',
            onMethodCall: (call) async {
              if (call.method == 'onChanged') {
                widget.onChanged?.call(call.arguments);
              } else if (call.method == 'onFocus') {
                _focused = call.arguments == true;
                // Keyboard already up (focus moved from another field): no
                // rising tick will come.
                if (_focused) {
                  WidgetsBinding.instance.addPostFrameCallback(
                    (_) => _revealAboveKeyboard(animate: keyboardIsUp(context)),
                  );
                }
              }
            },
          );
          requestIntrinsicSize();
        },
        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        gestureRecognizers: widget.gestures ?? scrollFriendlyGestures,
      ),
    );
    final height = widget.height ?? intrinsicHeight ?? widget.fallbackHeight;
    if (widget.hug) {
      return SizedBox(width: intrinsicWidth ?? 94, height: height, child: view);
    }
    return SizedBox(height: height, child: view);
  }
}
