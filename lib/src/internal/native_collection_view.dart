import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../callbacks.dart';

import '../models/cupertino_native_list_tile.dart';
import '../models/cupertino_native_list_section.dart';
import 'native_platform_view_mixin.dart';
import 'keyboard_avoidance.dart';
import 'widget_lowering.dart';
import 'native_color.dart';

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
  final bool editing;
  final Set<String> selection;
  final ValueChanged<Set<String>>? onSelectionChanged;
  final CupertinoNativeListSwipeCallback? onSwipeAction;
  final bool reorderable;
  final CupertinoNativeListReorderCallback? onReorder;

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
    this.editing = false,
    this.selection = const {},
    this.onSelectionChanged,
    this.onSwipeAction,
    this.reorderable = false,
    this.onReorder,
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

  /// Whether the last height came from an expandable row opening or
  /// closing. Matches `AdaptiveSystemListView.expandDuration`.
  bool _animateHeight = false;
  static const _expandDuration = Duration(milliseconds: 250);

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
          nativeArgb(widget.activeColor, isDark: _isDark) ??
          nativeArgb(theme.colorScheme.primary, isDark: _isDark)!,
      'sections': widget.sections.map(_sectionMap).toList(),
      'editing': widget.editing,
      'selection': widget.selection.toList(),
      'reorderable': widget.reorderable,
    };
  }

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    watchKeyboardMotion();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  /// True while a transcribed field inside this list holds focus.
  bool _fieldFocused = false;

  /// That field's vertical extent **in this platform view's own coordinates**,
  /// when it reported one. Null falls back to revealing the whole list.
  ///
  /// Box-local, and deliberately not the window rectangle the native side
  /// measured. The reveal runs on *every* rising metrics tick, and the page
  /// scrolls as it goes: a window-space row would be compared against a box
  /// that has already moved, so each tick would ask for slightly more travel
  /// than the last and the list would walk off the top of the screen, taking
  /// the field's window with it, which is what closes the keyboard. The row's
  /// offset *inside* the platform view is unaffected by the page scrolling, so
  /// converting once, when the report arrives, is stable for the whole
  /// animation.
  Rect? _focusedRow;

  /// The last keyboard inset seen, to react only while it grows.
  double _lastBottomInset = 0;

  /// iOS reports the inset repeatedly while the keyboard animates. The focus
  /// event itself arrives before the keyboard has any height at all, so
  /// revealing on focus alone scrolls by nothing: this is what actually
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

  /// A focus report's `y`/`height`, which are window coordinates, moved into
  /// the space [RenderBox.showOnScreen] expects: this platform view's own.
  /// See [_focusedRow] for why the conversion happens once, here.
  Rect? _rowInViewCoordinates(Map<Object?, Object?> report) {
    final y = (report['y'] as num?)?.toDouble();
    final height = (report['height'] as num?)?.toDouble();
    if (y == null || height == null) return null;
    final box = context.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return null;
    return rowInViewCoordinates(
      rowInWindow: Rect.fromLTWH(0, y, 0, height),
      viewInWindow: box.localToGlobal(Offset.zero) & box.size,
    );
  }

  /// One section, with each row's [CupertinoNativeListTile.trailing] lowered
  /// to the native nodes SwiftUI renders, and its callbacks kept.
  Map<String, dynamic> _sectionMap(CupertinoNativeListSection section) {
    return {
      ...section.toMap(isDark: _isDark),
      'rows': [for (final row in section.children) _rowMap(row)],
    };
  }

  Map<String, dynamic> _rowMap(CupertinoNativeListTile row) {
    final map = row.toMap(isDark: _isDark)
      ..['tappable'] = widget.onRowTap != null;
    if (row.children.isNotEmpty) {
      map['children'] = [for (final child in row.children) _rowMap(child)];
    }
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

  /// The creation params, captured on the first build and never rebuilt:
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
      'cupertino_native_ui/list_$id',
      onMethodCall: _handleMethodCall,
    );
    // The view was built from the creation params: push only what changed
    // while it was being created. Resending the same config rebuilt every
    // row a second time, on the main thread, in the middle of the push.
    _lastConfigJson = jsonEncode(_creationParams);
    _pushConfig();
    // No `requestIntrinsicSize()`: its answer forced a full layout of the
    // list, and the native view already reports its size after its first
    // layout pass, then its real height through `onContentSize`.
  }

  /// The wheels in the rows, in this view's coordinates, as the native side
  /// reports them: a drag that lands on one spins it, any other vertical drag
  /// scrolls the page.
  List<Rect> _wheels = const [];

  late final Set<Factory<OneSequenceGestureRecognizer>> _gestures =
      scrollFriendlyGestures(claims: (p) => _wheels.any((r) => r.contains(p)));

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
      case 'onSelectionChanged':
        final ids = (call.arguments['ids'] as List?)?.cast<String>();
        if (ids != null) widget.onSelectionChanged?.call(ids.toSet());
        break;
      case 'onSwipeAction':
        final rowId = call.arguments['rowId'] as String?;
        final actionId = call.arguments['actionId'] as String?;
        if (rowId != null && actionId != null) {
          widget.onSwipeAction?.call(rowId, actionId);
        }
        break;
      case 'onReorder':
        final args = call.arguments as Map;
        widget.onReorder?.call(
          args['section'] as int,
          args['from'] as int,
          args['to'] as int,
        );
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
            // `{focused, y, height}`: the row's own box, so the reveal can
            // move the row rather than the whole list. See
            // `FocusReportingField` on the native side.
            final report = value is Map ? value.cast<Object?, Object?>() : null;
            _fieldFocused = (report?['focused'] ?? value) == true;
            _focusedRow = report == null || !_fieldFocused
                ? null
                : _rowInViewCoordinates(report);
            if (_fieldFocused) _revealAboveKeyboard(postFrame: true);
          }
          _trailingCallbacks[rowId]?[nodeId]?.call(call.arguments['value']);
        }
        break;
      case 'onWheels':
        _wheels = [
          for (final r in (call.arguments as List).cast<List>())
            Rect.fromLTWH(
              (r[0] as num).toDouble(),
              (r[1] as num).toDouble(),
              (r[2] as num).toDouble(),
              (r[3] as num).toDouble(),
            ),
        ];
        break;
      case 'onContentSize':
        // Native pushes the measured content height as its layout settles
        // (rows render, fonts load), so the fixed platform-view box grows to
        // fit instead of clipping.
        final h = (call.arguments['height'] as num?)?.toDouble();
        if (h != null && h > 0 && mounted) {
          setState(() {
            intrinsicHeight = h;
            _animateHeight = call.arguments['animated'] == true;
          });
        }
        break;
    }
  }

  /// Scrolls the focused row clear of the keyboard: the row, not the list:
  /// revealing the whole box overshot a short section and undershot a long
  /// one. The row's rect comes from the native side with its focus report,
  /// already converted into this view's coordinates, see [_focusedRow].
  void _revealAboveKeyboard({bool postFrame = false}) {
    void run({bool animate = false}) {
      if (!mounted) return;
      final box = context.findRenderObject();
      if (box is! RenderBox || !box.hasSize) return;
      final row = _focusedRow;
      final target = row == null
          ? Offset.zero & box.size
          : Rect.fromLTWH(0, row.top, box.size.width, row.height);
      revealAboveKeyboard(context, box, rect: target, animate: animate);
    }

    if (postFrame) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => run(animate: mounted && keyboardIsUp(context)),
      );
    } else {
      run();
    }
  }

  /// The fields here are transcribed into the platform view, so Flutter holds
  /// no focus node for them; `endEditing` resigns whichever one is first
  /// responder inside it. Called as the route starts leaving, so the keyboard
  /// goes down with the transition, see [RouteKeyboardDismissal].
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
        viewType: 'com.example.cupertino_native_ui/cupertino_native_list',
        layoutDirection: TextDirection.ltr,
        // Memoized: every later change goes over `updateList`, not through a
        // map rebuilt on every build.
        creationParams: _creationParams ??= _toMap(),
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
        // With no recognizer of its own, the view only got a touch once
        // nothing else in Flutter wanted it: at the finger's lift, at best.
        // A tap still worked; a press-and-hold that turns into a drag (moving
        // a field's cursor, the magnifier, a selection) never reached the
        // native field. A hold or a sideways drag is the row's now; a
        // vertical drag still scrolls the page.
        gestureRecognizers: _gestures,
      ),
    );

    // Width fills the parent; height is fixed (given) or the measured content
    // height, with a generous placeholder until the native measurement arrives.
    final h = widget.height ?? intrinsicHeight ?? 400.0;
    // Only an expandable row opening or closing animates the height, with
    // the same duration and curve as the native row animation, so what is
    // under the list moves with the rows. Every other change (the first
    // measurement, rows pushed from Dart) lands at once.
    return TweenAnimationBuilder<double>(
      tween: Tween(end: h),
      duration: _animateHeight ? _expandDuration : Duration.zero,
      curve: Curves.easeInOut,
      builder: (context, height, child) =>
          SizedBox(height: height, child: child),
      child: platformView,
    );
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
