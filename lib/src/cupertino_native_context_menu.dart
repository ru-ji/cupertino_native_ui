import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'callbacks.dart';

import 'internal/native_platform_view_mixin.dart';
import 'models/cupertino_native_menu_item.dart';
import 'internal/scroll_friendly_recognizer.dart';

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
    this.blurBackground = false,
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

  /// Reports the menu opening/closing — e.g. to dim or swap [child] on the
  /// Flutter side while the menu is up. Fires `false` the instant the
  /// dismissal starts, not when its animation ends.
  final ValueChanged<bool>? onOpenChanged;

  /// Blurs the whole app behind the menu while it is open, natively over the
  /// app window.
  final bool blurBackground;

  /// Corner radius of [child], so the lifted preview keeps its shape. 0 for a
  /// square child.
  final double previewCornerRadius;

  /// Whether [child] receives touches. Defaults to false so every touch —
  /// including the long-press — reaches the native interaction; set true when
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

  /// Safety net for [_menuOpen]: the child is hidden while the menu is up and
  /// restored when the native dismiss animation completes. If that completion
  /// is ever missed the child would stay invisible for good, so a timer
  /// restores it regardless.
  Timer? _restoreTimer;

  bool? _lastIsDark;

  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-push config if the app toggled light/dark at runtime.
    if (_lastIsDark != null && _lastIsDark != _isDark) {
      updateNativeView(
        'updateContextMenu',
        _toMap(),
        refreshIntrinsicSize: false,
      );
    }
    _lastIsDark = _isDark;
  }

  void _scheduleChildRestore() {
    _restoreTimer?.cancel();
    _restoreTimer = Timer(const Duration(milliseconds: 700), _restoreChild);
  }

  void _restoreChild() {
    _restoreTimer?.cancel();
    _restoreTimer = null;
    if (mounted && _menuOpen) setState(() => _menuOpen = false);
  }

  @override
  void dispose() {
    _restoreTimer?.cancel();
    super.dispose();
  }

  Map<String, dynamic> _toMap() {
    return {
      'previewCornerRadius': widget.previewCornerRadius,
      'items': widget.actions.map((e) => e.toMap()).toList(),
      'blurBackground': widget.blurBackground,
      'isDark': _isDark,
    };
  }

  @override
  void didUpdateWidget(covariant CupertinoNativeContextMenu oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.actions != widget.actions ||
        oldWidget.blurBackground != widget.blurBackground ||
        oldWidget.previewCornerRadius != widget.previewCornerRadius) {
      updateNativeView(
        'updateContextMenu',
        _toMap(),
        refreshIntrinsicSize: false,
      );
    }
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
      'cupertino_widgets/context_menu_$id',
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
  // ponytail: static snapshot, retaken when the widget changes — re-capture
  // on a timer if live/animated content ever needs to lift accurately.
  void _captureAfterFrame(GlobalKey key, String method) {
    WidgetsBinding.instance.addPostFrameCallback((_) async {
      if (!mounted || channel == null || _menuOpen) return;
      final render = key.currentContext?.findRenderObject();
      if (render is! RenderRepaintBoundary) return;
      final dpr = MediaQuery.devicePixelRatioOf(context);
      try {
        final image = await render.toImage(pixelRatio: dpr);
        final size = '${image.width}x${image.height}';
        final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
        image.dispose();
        if (bytes == null) {
          debugPrint('[ctxmenu] $method: encode returned null');
          return;
        }
        await channel?.invokeMethod(method, {
          'bytes': bytes.buffer.asUint8List(),
          'scale': dpr,
        });
        debugPrint('[ctxmenu] $method sent: $size px, ${bytes.lengthInBytes}B');
      } catch (e) {
        // Boundary not painted yet; the next update re-captures.
        debugPrint('[ctxmenu] $method FAILED: $e');
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) return widget.child;

    return Stack(
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
                child: RepaintBoundary(key: _previewKey, child: widget.preview),
              ),
            ),
          ),
        Positioned.fill(
          child: RepaintBoundary(
            child: UiKitView(
              viewType:
                  'com.example.cupertino_widgets/cupertino_native_context_menu',
              layoutDirection: TextDirection.ltr,
              creationParams: _toMap(),
              creationParamsCodec: const StandardMessageCodec(),
              // The long-press must reach the native interaction immediately;
              // inside scrollables Flutter's gesture arena would otherwise
              // delay and cancel it (same pattern as the glass container).
              hitTestBehavior: PlatformViewHitTestBehavior.opaque,
              gestureRecognizers: scrollFriendlyGestures,
              onPlatformViewCreated: _onPlatformViewCreated,
            ),
          ),
        ),
        IgnorePointer(
          ignoring: !widget.childInteractive || _menuOpen,
          child: Opacity(
            opacity: _menuOpen ? 0 : 1,
            // Boundary so the child can be rendered to the image the system
            // lifts — every layer of it, text included.
            child: RepaintBoundary(key: _childKey, child: widget.child),
          ),
        ),
      ],
    );
  }
}
