import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../callbacks.dart';

import '../models/cupertino_native_list_row.dart';
import '../models/cupertino_native_list_section.dart';
import 'native_platform_view_mixin.dart';

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

  /// Fixed height. When null the view self-sizes to its content (requires
  /// iOS 16+; falls back to a scrolling region below that).
  final double? height;

  /// Let the native list own its scrolling. Defaults to false so the content
  /// self-sizes and the surrounding Flutter scroll view scrolls instead.
  final bool scrollable;

  final Color? activeColor;

  /// Corner radius of the inset-grouped section cards. Null uses the native
  /// default (10). Tune this to match your iOS version's Settings app.
  final double? cornerRadius;

  final CupertinoNativeListRowCallback? onRowTap;
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
    with NativePlatformViewStateMixin {
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
      'sections': widget.sections.map((s) => s.toMap()).toList(),
    };
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // Re-push config if the app toggled light/dark at runtime.
    if (_lastIsDark != null && _lastIsDark != _isDark) {
      updateNativeView('updateList', _toMap());
    }
    _lastIsDark = _isDark;
  }

  @override
  void didUpdateWidget(covariant NativeCollectionView oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Configs are nested maps of primitives; a JSON compare is a simple deep
    // equality check.
    if (jsonEncode(_mapOf(oldWidget)) != jsonEncode(_toMap())) {
      updateNativeView('updateList', _toMap());
    }
  }

  Map<String, dynamic> _mapOf(NativeCollectionView w) {
    return {
      'variant': w.variant,
      'style': w.style,
      'scrollable': w.scrollable,
      'tint': w.activeColor?.toARGB32(),
      'sections': w.sections.map((s) => s.toMap()).toList(),
    };
  }

  Future<void> _onPlatformViewCreated(int id) async {
    setUpChannel(
      id,
      'cupertino_widgets/list_$id',
      onMethodCall: _handleMethodCall,
    );
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

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return _fallback(context);
    }

    final platformView = wrapForTransition(UiKitView(
      viewType: 'com.example.cupertino_widgets/cupertino_native_list',
      layoutDirection: TextDirection.ltr,
      creationParams: _toMap(),
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _onPlatformViewCreated,
    ));

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
      for (final row in section.rows) {
        children.add(
          ListTile(
            title: Text(row.title),
            subtitle: row.subtitle != null ? Text(row.subtitle!) : null,
            trailing: row.type == CupertinoNativeListRowType.toggle
                ? Switch(
                    value: row.toggleValue,
                    onChanged: (v) => widget.onToggle?.call(row.id, v),
                  )
                : (row.value != null ? Text(row.value!) : null),
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
