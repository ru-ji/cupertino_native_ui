import 'dart:async';
import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart' show kLongPressTimeout;
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'callbacks.dart';

import 'internal/native_platform_view_mixin.dart';
import 'models/cupertino_native_menu_item.dart';
import 'internal/native_log.dart';

/// Wraps Flutter content in a native iOS context menu: a long-press lifts the
/// content and shows a menu built from [actions], the same model
/// ([CupertinoNativeMenuItem]) as [CupertinoNativeMenu].
///
/// ```dart
/// CupertinoNativeContextMenu(
///   actions: [
///     CupertinoNativeMenuAction(title: 'Share', systemImage: 'square.and.arrow.up', actionId: 'share'),
///     CupertinoNativeMenuAction(title: 'Delete', systemImage: 'trash', isDestructive: true, actionId: 'delete'),
///   ],
///   onAction: (id, _) {},
///   child: const PhotoCard(),
/// )
/// ```
///
/// Pass [preview] to lift a different widget while the menu is open (a static
/// snapshot: animations inside it won't play).
class CupertinoNativeContextMenu extends StatefulWidget {
  const CupertinoNativeContextMenu({
    super.key,
    required this.child,
    required this.actions,
    this.preview,
    this.onAction,
    this.onOpenChanged,
    this.childInteractive = false,
    this.previewCornerRadius = 0,
  });

  /// Flutter content the context menu wraps.
  final Widget child;

  /// Native menu entries (actions, sections, submenus, toggles).
  final List<CupertinoNativeMenuItem> actions;

  /// Replacement for the lifted preview while the menu is open. Defaults to a
  /// snapshot of [child].
  final Widget? preview;

  /// Called with the tapped item's `actionId` (and the new value for toggles).
  final CupertinoNativeMenuActionCallback? onAction;

  /// Reports the menu opening/closing: e.g. to dim or swap [child] on the
  /// Flutter side while the menu is up. Fires `false` the instant the
  /// dismissal starts, not when its animation ends.
  final ValueChanged<bool>? onOpenChanged;

  /// Corner radius of [child], so the lifted preview keeps its shape. 0 for a
  /// square child.
  final double previewCornerRadius;

  /// Whether [child] receives touches. Defaults to false so every touch,
  /// including the long-press, reaches the native interaction; set true when
  /// the child has its own buttons (the menu then only opens where the child
  /// doesn't claim the touch).
  final bool childInteractive;

  @override
  State<CupertinoNativeContextMenu> createState() =>
      _CupertinoNativeContextMenuState();
}

class _CupertinoNativeContextMenuState extends State<CupertinoNativeContextMenu>
    with NativePlatformViewStateMixin {
  final GlobalKey _previewKey = GlobalKey();
  final GlobalKey _childKey = GlobalKey();

  /// True while the native menu is lifted. The child is hidden meanwhile: the
  /// system lifts a snapshot of it, and UIKit can't hide Flutter's copy the
  /// way it hides the original of a lifted UIView. Cleared only once the
  /// dismiss animation lands, so the child doesn't pop back in mid-flight.
  bool _menuOpen = false;

  /// True from just after a press begins until it ends without a menu. UIKit
  /// scales the child's snapshot as the press highlight *under* Flutter's
  /// child, which would otherwise sit there unscaled; hiding the child lets
  /// the highlight be what the finger sees.
  bool _pressHidden = false;
  Timer? _pressTimer;

  /// A finger is on the child. `onPressBegan` crosses the channel, so it can
  /// land after the lift: hiding then would leave nothing to restore it.
  bool _pointerDown = false;

  void _pressBegan() {
    _pressTimer?.cancel();
    // At once: the highlight is the press's only feedback, and a tap that
    // ends before any menu restores the child on its lift (`_pressEnded`).
    if (mounted && _pointerDown && !_pressHidden) {
      setState(() => _pressHidden = true);
    }
  }

  /// The page took the touch back to scroll: UIKit drops its highlight, so
  /// the child shows again now, not when the finger lifts.
  @override
  void cancelNativeTouches() {
    super.cancelNativeTouches();
    _restoreChild();
  }

  void _pressEnded({required bool lifted}) {
    _pointerDown = false;
    _pressTimer?.cancel();
    // A lifted finger with no menu up was a tap or a hold let go early.
    if (lifted && !_menuOpen) {
      if (mounted && _pressHidden) setState(() => _pressHidden = false);
      return;
    }
    // UIKit cancels the touch as it lifts the menu, and `onOpenChanged` lands
    // a beat later: restore only if no menu came.
    _pressTimer = Timer(const Duration(milliseconds: 250), () {
      if (mounted && _pressHidden && !_menuOpen) {
        setState(() => _pressHidden = false);
      }
    });
  }

  /// Safety net for [_menuOpen]: the child is hidden while the menu is up and
  /// restored when the native dismiss animation completes. If that completion
  /// is ever missed the child would stay invisible for good, so a timer
  /// restores it regardless.
  Timer? _restoreTimer;

  /// Debounce timer per capture method. A parent that rebuilds every frame
  /// (an animation, a platform view pushing sizes) would otherwise encode a
  /// PNG every frame: the timer keeps getting pushed back, so the capture
  /// fires only once the rebuild storm has stopped.
  final Map<String, Timer> _captureDebounce = {};

  /// A capture in flight, by method; a second one is not launched on top.
  final Set<String> _pendingCaptures = {};

  bool? _lastIsDark;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-push config if the app toggled light/dark at runtime.
    if (_lastIsDark != null && _lastIsDark != _isDark) _pushMenu();
    _lastIsDark = _isDark;
  }

  /// The menu last sent. Compared as JSON: [CupertinoNativeContextMenu.actions]
  /// is usually a list literal, a new one on every parent rebuild, and each
  /// update re-creates the native menu.
  String? _sent;

  void _pushMenu() {
    final map = _toMap();
    final sent = jsonEncode(map);
    if (sent == _sent) return;
    _sent = sent;
    updateNativeView('updateContextMenu', map, refreshIntrinsicSize: false);
  }

  void _scheduleChildRestore() {
    _restoreTimer?.cancel();
    _restoreTimer = Timer(const Duration(milliseconds: 700), _restoreChild);
  }

  void _restoreChild() {
    _restoreTimer?.cancel();
    _restoreTimer = null;
    if (mounted && (_menuOpen || _pressHidden)) {
      setState(() => _menuOpen = _pressHidden = false);
    }
  }

  @override
  void dispose() {
    _pressTimer?.cancel();
    _restoreTimer?.cancel();
    for (final timer in _captureDebounce.values) {
      timer.cancel();
    }
    _captureDebounce.clear();
    super.dispose();
  }

  /// The creation params, also what [_pushMenu] compares the first update
  /// against.
  Map<String, dynamic> _creationParams() {
    final map = _toMap();
    _sent ??= jsonEncode(map);
    return map;
  }

  Map<String, dynamic> _toMap() {
    return {
      'previewCornerRadius': widget.previewCornerRadius,
      'items': widget.actions.map((e) => e.toMap()).toList(),
      'isDark': _isDark,
    };
  }

  @override
  void didUpdateWidget(covariant CupertinoNativeContextMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    _pushMenu();
    if (widget.child != oldWidget.child) {
      _captureAfterFrame(_childKey, 'setChildImage');
    }
    if (widget.preview == null && oldWidget.preview != null) {
      channel?.invokeMethod('setPreview', null);
    } else if (widget.preview != null) {
      _captureAfterFrame(_previewKey, 'setPreview');
    }
  }

  Future<void> _onPlatformViewCreated(int id) async {
    setUpChannel(
      id,
      'cupertino_native_ui/context_menu_$id',
      onMethodCall: _handleMethodCall,
    );
    _captureAfterFrame(_childKey, 'setChildImage');
    if (widget.preview != null) _captureAfterFrame(_previewKey, 'setPreview');
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onAction':
        final String? id = call.arguments['id'];
        if (id != null) widget.onAction?.call(id, call.arguments['value']);
      case 'onPressBegan':
        _pressBegan();
      case 'onOpenChanged':
        final bool? open = call.arguments['open'];
        if (open != null) {
          // Hiding the child only latches ON here; it is released by
          // onDismissComplete (or the safety timer).
          if (mounted && open && !_menuOpen) {
            setState(() => _menuOpen = true);
            _restoreTimer?.cancel();
          } else if (!open) {
            _scheduleChildRestore();
          }
          widget.onOpenChanged?.call(open);
        }
      case 'onDismissComplete':
        _restoreChild();
    }
  }

  /// Renders a [RepaintBoundary] to a PNG and pushes it to the native side.
  ///
  /// Flutter captures it itself: a native window snapshot drops content drawn
  /// into Flutter's Metal layer.
  ///
  /// Captured from the boundary's layer directly, not via
  /// [RenderRepaintBoundary.toImage]: that API asserts `!debugNeedsPaint`, and
  /// a boundary under a platform view can legitimately be dirty at
  /// post-frame time, and the assert then spams forever on every rebuild. The
  /// layer form never asserts and rasterizes the last-painted pixels, which
  /// is exactly what a menu lift wants anyway.
  ///
  /// Debounced (one capture per quiet period, per method) and skipped while
  /// this route is covered by another: a page hidden under a pushed scaffold
  /// must not keep encoding PNGs.
  // ponytail: static snapshot, retaken when the widget changes. Re-capture
  // on a timer if live/animated content ever needs to lift accurately.
  void _captureAfterFrame(GlobalKey key, String method) {
    _captureDebounce[method]?.cancel();
    _captureDebounce[method] = Timer(const Duration(milliseconds: 120), () {
      _captureDebounce.remove(method);
      if (!mounted || channel == null || _menuOpen) return;
      if (_pendingCaptures.contains(method)) return;
      _pendingCaptures.add(method);
      WidgetsBinding.instance.addPostFrameCallback((_) {
        _pendingCaptures.remove(method);
        if (!mounted || channel == null || _menuOpen) return;
        final route = ModalRoute.of(context);
        if (route != null && !route.isCurrent) return;
        _captureNow(key, method);
      });
    });
  }

  /// The PNG last pushed per method, so an unchanged capture is dropped
  /// before it reaches the channel.
  final Map<String, Uint8List> _lastSent = {};

  Future<void> _captureNow(GlobalKey key, String method) async {
    final render = key.currentContext?.findRenderObject();
    if (render is! RenderRepaintBoundary) return;
    final layer = render.debugLayer;
    if (layer is! OffsetLayer) return;
    final dpr = MediaQuery.devicePixelRatioOf(context);
    try {
      final image = await layer.toImage(
        Offset.zero & render.size,
        pixelRatio: dpr,
      );
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      if (bytes == null) {
        nativeLog(() => '[ctxmenu] $method: encode returned null');
        return;
      }
      // The capture is re-run on every rebuild (a non-const child is a new
      // widget each time) and almost always paints the same pixels. Comparing
      // the bytes costs a pass over a few hundred KB; sending them costs the
      // same over the method channel, plus a decode and a texture on the
      // native side.
      final png = bytes.buffer.asUint8List();
      if (listEquals(_lastSent[method], png)) return;
      _lastSent[method] = png;
      await channel?.invokeMethod(method, {'bytes': png, 'scale': dpr});
      nativeLog(() => '[ctxmenu] $method sent: ${bytes.lengthInBytes}B');
    } catch (e) {
      // Nothing to rasterize yet; the next update re-captures.
      nativeLog(() => '[ctxmenu] $method FAILED: $e');
    }
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) return widget.child;

    return Listener(
      onPointerDown: (_) => _pointerDown = true,
      onPointerUp: (_) => _pressEnded(lifted: true),
      onPointerCancel: (_) => _pressEnded(lifted: false),
      child: Stack(
        fit: StackFit.passthrough,
        // No clip: the preview overflows, and a composited clip would also cut
        // the native views painted before it.
        clipBehavior: Clip.none,
        children: [
          if (widget.preview != null)
            Positioned(
              left: 0,
              top: 0,
              child: IgnorePointer(
                // ponytail: painted in place but near-invisible so it can be
                // snapshotted; far off-screen its gradients rasterized blank.
                child: Opacity(
                  opacity: 0.001,
                  child: RepaintBoundary(
                    key: _previewKey,
                    child: widget.preview,
                  ),
                ),
              ),
            ),
          Positioned.fill(
            child: RepaintBoundary(
              child: UiKitView(
                viewType: 'com.example.cupertino_native_ui/cupertino_native_context_menu',
                layoutDirection: TextDirection.ltr,
                creationParams: _creationParams(),
                creationParamsCodec: const StandardMessageCodec(),
                // The long-press must reach the native interaction immediately;
                // inside scrollables Flutter's gesture arena would otherwise
                // delay and cancel it (same pattern as the glass container).
                hitTestBehavior: PlatformViewHitTestBehavior.opaque,
                gestureRecognizers: scrollFriendlyGestures(
                  // The menu presents on a long press; until then a
                  // scroll still takes the lift back.
                  claimAfter: kLongPressTimeout,
                ),
                onPlatformViewCreated: _onPlatformViewCreated,
              ),
            ),
          ),
          IgnorePointer(
            ignoring: !widget.childInteractive || _menuOpen,
            child: Opacity(
              opacity: _menuOpen || _pressHidden ? 0 : 1,
              // Boundary so the child can be rendered to the image the system
              // lifts: every layer of it, text included.
              child: RepaintBoundary(key: _childKey, child: widget.child),
            ),
          ),
        ],
      ),
    );
  }
}
