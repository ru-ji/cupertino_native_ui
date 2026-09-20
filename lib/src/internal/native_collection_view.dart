import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../callbacks.dart';

import '../models/cupertino_native_list_tile.dart';
import '../models/cupertino_native_list_section.dart';
import 'native_platform_view_mixin.dart';
import 'keyboard_avoidance.dart';
import 'widget_lowering.dart';

/// Shared platform-view implementation behind `CupertinoNativeList` and
/// `CupertinoNativeForm`. Both render a native SwiftUI `List`/`Form` of
/// [CupertinoNativeListSection]s; they differ only in the [variant] string
/// (and default styling) sent to the native side.
class NativeCollectionView extends StatefulWidget {
  /// "list" or "form".
  final String variant;

  /// List style name: automatic | plain | grouped | insetGrouped | sidebar.
  final String style;

  final List<CupertinoNativeListSection> sections;

  /// Fixed height. When null the view self-sizes to its content.
  final double? height;

  /// Let the native list own its scrolling. Defaults to false so the content
  /// self-sizes and the surrounding Flutter scroll view scrolls instead.
  final bool scrollable;

  final Color? activeColor;

  /// Corner radius of the inset-grouped section cards. Null uses the native
  /// default (10). Tune this to match your iOS version's Settings app.
  final double? cornerRadius;

  final CupertinoNativeListTileCallback? onRowTap;
  final CupertinoNativeListToggleCallback? onToggle;

  const NativeCollectionView({
    super.key,
    required this.variant,
    required this.style,
    required this.sections,
    this.height,
    this.scrollable = false,
    this.activeColor,
    this.cornerRadius,
    this.onRowTap,
    this.onToggle,
  });

  @override
  State<NativeCollectionView> createState() => _NativeCollectionViewState();
}

class _NativeCollectionViewState extends State<NativeCollectionView>
    with
        NativePlatformViewStateMixin,
        WidgetsBindingObserver,
        RouteKeyboardDismissal {
  bool? _lastIsDark;

  // Match the app's own theme brightness, NOT the device brightness: a light
  // app on a dark-mode device should still render a light (systemGrouped
  // background) list, not a black backdrop.
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Map<String, dynamic> _toMap() {
    final theme = Theme.of(context);
    return {
      'variant': widget.variant,
      'style': widget.style,
      'scrollable': widget.scrollable,
      'isDark': _isDark,
      'cornerRadius': widget.cornerRadius,
      'tint':
          widget.activeColor?.toARGB32() ??
          theme.colorScheme.primary.toARGB32(),
      'sections': widget.sections.map(_sectionMap).toList(),
    };
  }

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

  /// True while a transcribed field inside this list holds focus.
  bool _fieldFocused = false;

  /// That field's vertical extent in window coordinates, when it reported
  /// one. Null falls back to revealing the whole list.
  Rect? _focusedRow;

  /// The last keyboard inset seen, to react only while it grows.
  double _lastBottomInset = 0;

  /// iOS reports the inset repeatedly while the keyboard animates. The focus
  /// event itself arrives before the keyboard has any height at all, so
  /// revealing on focus alone scrolls by nothing — this is what actually
  /// moves the list.
  @override
  void didChangeMetrics() {
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    if (view == null) return;
    final bottomInset = view.viewInsets.bottom;
    final rising = bottomInset > _lastBottomInset;
    _lastBottomInset = bottomInset;
    if (rising && _fieldFocused) _revealAboveKeyboard();
  }

  /// One section, with each row's [CupertinoNativeListTile.trailing] lowered
  /// to the native nodes SwiftUI renders — and its callbacks kept.
  Map<String, dynamic> _sectionMap(CupertinoNativeListSection section) {
    return {
      ...section.toMap(),
      'rows': [for (final row in section.children) _rowMap(row)],
    };
  }

  Map<String, dynamic> _rowMap(CupertinoNativeListTile row) {
    final map = row.toMap();
    final trailing = row.trailing;
    if (trailing == null) return map;
    final lowered = LoweredTrailing(trailing);
    _trailingCallbacks[row.id] = lowered.callbacks;
    map['trailing'] = [
      if (lowered.node != null) lowered.node!.toMap(isDark: _isDark),
    ];
    return map;
  }

  /// rowId → (nodeId → callback), for the lowered trailing controls.
  final Map<String, Map<String, void Function(Object? value)>>
  _trailingCallbacks = {};

  /// The config last pushed over the channel, encoded. Only set for pushes
  /// that actually went out.
  String? _lastConfigJson;

  /// The creation params, captured on the first build and never rebuilt —
  /// `UiKitView` only reads them at creation.
  Map<String, dynamic>? _creationParams;

  void _pushConfig() {
    final map = _toMap();
    final json = jsonEncode(map);
    if (json == _lastConfigJson) return;
    updateNativeView('updateList', map);
    if (channel != null) _lastConfigJson = json;
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-push config if the app toggled light/dark at runtime.
    if (_lastIsDark != null && _lastIsDark != _isDark) {
      _pushConfig();
    }
    _lastIsDark = _isDark;
  }

  @override
  void didUpdateWidget(covariant NativeCollectionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    _pushConfig();
  }

  Future<void> _onPlatformViewCreated(int id) async {
    setUpChannel(
      id,
      'cupertino_widgets/list_$id',
      onMethodCall: _handleMethodCall,
    );
    // The creation params were built on the first frame; push the live config
    // once so nothing that changed mid-creation is lost.
    final map = _toMap();
    _lastConfigJson = jsonEncode(map);
    updateNativeView('updateList', map);
    // Give the native view a layout pass so it can measure content height.
    requestIntrinsicSize();
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onRowTap':
        final id = call.arguments['id'] as String?;
        if (id != null) widget.onRowTap?.call(id);
        break;
      case 'onToggle':
        final id = call.arguments['id'] as String?;
        final value = call.arguments['value'] as bool?;
        if (id != null && value != null) widget.onToggle?.call(id, value);
        break;
      case 'onTrailingEvent':
        // A lowered trailing control changed: (rowId, nodeId, value).
        final rowId = call.arguments['rowId'] as String?;
        final nodeId = call.arguments['nodeId'] as String?;
        if (rowId != null && nodeId != null) {
          // A transcribed field lives inside this platform view, so Flutter
          // never sees its focus and never scrolls it clear of the keyboard.
          // The native side reports it as `<nodeId>.focused`.
          if (nodeId.endsWith('.focused')) {
            final value = call.arguments['value'];
            // `{focused, y, height}` — the row's own box in window
            // coordinates, so the reveal can move the row rather than the
            // whole list. See `FocusReportingField` on the native side.
            final report = value is Map ? value : null;
            _fieldFocused = (report?['focused'] ?? value) == true;
            _focusedRow = report == null || !_fieldFocused
                ? null
                : Rect.fromLTWH(
                    0,
                    (report['y'] as num).toDouble(),
                    0,
                    (report['height'] as num).toDouble(),
                  );
            if (_fieldFocused) _revealAboveKeyboard(postFrame: true);
          }
          _trailingCallbacks[rowId]?[nodeId]?.call(call.arguments['value']);
        }
        break;
      case 'onContentSize':
        // Native pushes the measured content height as its layout settles
        // (rows render, fonts load), so the fixed platform-view box grows to
        // fit instead of clipping.
        final h = (call.arguments['height'] as num?)?.toDouble();
        if (h != null && h > 0 && mounted) {
          setState(() => intrinsicHeight = h);
        }
        break;
    }
  }

  /// Scrolls the focused row clear of the keyboard — the row, not the list:
  /// revealing the whole box overshot a short section and undershot a long
  /// one. The row's rect comes from the native side with its focus report.
  void _revealAboveKeyboard({bool postFrame = false}) {
    void run() {
      if (!mounted) return;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      // Only the part of the keyboard that really covers this viewport, the
      // way the standalone field's reveal does it — see
      // [keyboardCoverOfViewport].
      // No early return on a zero cover: the row may still be plainly
      // off-screen, and `showOnScreen` is the thing that decides.
      final inset = keyboardCoverOfViewport(context);
      // No duration: the engine already delivers the inset once per vsync of
      // the keyboard's own animation, so an instant move on each tick *is*
      // the animation — and it is the keyboard's curve, not a second one
      // running alongside it at a different speed.
      final row = _focusedRow;
      final target = row == null
          ? Offset.zero & box.size
          : Rect.fromLTWH(
              0,
              row.top - box.localToGlobal(Offset.zero).dy,
              box.size.width,
              row.height,
            );
      box.showOnScreen(
        rect: EdgeInsets.only(bottom: inset + 20).inflateRect(target),
      );
    }

    if (postFrame) {
      WidgetsBinding.instance.addPostFrameCallback((_) => run());
    } else {
      run();
    }
  }

  /// The fields here are transcribed into the platform view, so Flutter holds
  /// no focus node for them; `endEditing` resigns whichever one is first
  /// responder inside it. Called as the route starts leaving, so the keyboard
  /// goes down with the transition — see [RouteKeyboardDismissal].
  @override
  void dismissKeyboardForRoute() {
    if (_fieldFocused) channel?.invokeMethod('endEditing');
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return _fallback(context);
    }

    final platformView = wrapForTransition(
      UiKitView(
        viewType: 'com.example.cupertino_widgets/cupertino_native_list',
        layoutDirection: TextDirection.ltr,
        // Memoized: every later change goes over `updateList`, not through a
        // map rebuilt on every build.
        creationParams: _creationParams ??= _toMap(),
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
      ),
    );

    // Width fills the parent; height is fixed (given) or the measured content
    // height, with a generous placeholder until the native measurement arrives.
    final h = widget.height ?? intrinsicHeight ?? 400.0;
    return SizedBox(height: h, child: platformView);
  }

  /// Plain-Flutter fallback for non-iOS platforms.
  Widget _fallback(BuildContext context) {
    final children = <Widget>[];
    for (final section in widget.sections) {
      if (section.header != null) {
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 4),
            child: Text(
              section.header!.toUpperCase(),
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        );
      }
      for (final row in section.children) {
        children.add(
          ListTile(
            title: Text(row.title),
            subtitle: row.subtitle != null ? Text(row.subtitle!) : null,
            trailing: row.type == CupertinoNativeListTileType.toggle
                ? Switch(
                    value: row.toggleValue,
                    onChanged: (v) => widget.onToggle?.call(row.id, v),
                  )
                : (row.additionalInfo != null
                      ? Text(row.additionalInfo!)
                      : null),
            onTap: () => widget.onRowTap?.call(row.id),
          ),
        );
      }
      if (section.footer != null) {
        children.add(
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: Text(
              section.footer!,
              style: const TextStyle(fontSize: 12, color: Colors.grey),
            ),
          ),
        );
      }
    }
    // Material ancestor so ListTile/Switch work even in Cupertino-only apps.
    return Material(
      type: MaterialType.transparency,
      child: Column(mainAxisSize: MainAxisSize.min, children: children),
    );
  }
}
