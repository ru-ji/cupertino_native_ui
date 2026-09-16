import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'internal/native_platform_view_mixin.dart';
import 'internal/scroll_friendly_recognizer.dart';
import 'models/cupertino_native_button_style.dart';
import 'models/cupertino_native_icon.dart';

/// SwiftUI's `PickerStyle`. The style is what makes this a different control,
/// so it is the constructor rather than a parameter.
enum CupertinoNativePickerStyle {
  /// The system default for the context.
  automatic,

  /// The spinning drum — `UIPickerView`.
  wheel,

  /// A button that opens the options as a native menu.
  menu,

  /// The segmented strip.
  segmented,

  /// The Liquid Glass row of icons, the selection travelling between them.
  /// Only reads correctly when every item carries an [icon].
  palette,

  /// The options listed in place, for a row of a native list.
  inline,

  /// A list row that pushes a picker page. Only inside a native
  /// `NavigationStack` — that means a `CupertinoNativePageScaffold` body.
  navigationLink,
}

/// One option of a [CupertinoNativePicker].
class CupertinoNativePickerItem {
  const CupertinoNativePickerItem({this.title, this.icon})
    : assert(
        title != null || icon != null,
        'A picker item needs a title, an icon, or both',
      );

  final String? title;
  final CupertinoNativeIcon? icon;

  Map<String, dynamic> toMap(int index) => {
    'title': title,
    'icon': icon?.toMap(),
    'id': index,
  };
}

/// A native SwiftUI `Picker`.
///
/// ```dart
/// CupertinoNativePicker.palette(
///   items: const [
///     CupertinoNativePickerItem(icon: CupertinoNativeIcon.named('list.bullet')),
///     CupertinoNativePickerItem(icon: CupertinoNativeIcon.named('square.grid.2x2')),
///   ],
///   selectedIndex: _layout,
///   onChanged: (i) => setState(() => _layout = i),
/// )
/// ```
///
/// [CupertinoNativePickerStyle.segmented] overlaps
/// `CupertinoNativeSlidingSegmentedControl`; prefer that one when the control
/// is a segmented control rather than a picker that happens to be segmented.
class CupertinoNativePicker extends StatefulWidget {
  const CupertinoNativePicker({
    super.key,
    required this.items,
    required this.selectedIndex,
    this.onChanged,
    this.style = CupertinoNativePickerStyle.automatic,
    this.label,
    this.showLabel = false,
    this.activeColor,
    this.sizeStyle,
    this.height,
  });

  /// The Liquid Glass icon row.
  const CupertinoNativePicker.palette({
    Key? key,
    required List<CupertinoNativePickerItem> items,
    required int selectedIndex,
    ValueChanged<int>? onChanged,
    String? label,
    Color? activeColor,
    CupertinoNativeControlSize? sizeStyle,
  }) : this(
         key: key,
         items: items,
         selectedIndex: selectedIndex,
         onChanged: onChanged,
         style: CupertinoNativePickerStyle.palette,
         label: label,
         activeColor: activeColor,
         sizeStyle: sizeStyle,
       );

  /// A button that opens the options as a native menu.
  const CupertinoNativePicker.menu({
    Key? key,
    required List<CupertinoNativePickerItem> items,
    required int selectedIndex,
    ValueChanged<int>? onChanged,
    String? label,
    Color? activeColor,
    CupertinoNativeControlSize? sizeStyle,
  }) : this(
         key: key,
         items: items,
         selectedIndex: selectedIndex,
         onChanged: onChanged,
         style: CupertinoNativePickerStyle.menu,
         label: label,
         activeColor: activeColor,
         sizeStyle: sizeStyle,
       );

  /// The spinning drum. Give it room — the wheel fills the box it is handed.
  const CupertinoNativePicker.wheel({
    Key? key,
    required List<CupertinoNativePickerItem> items,
    required int selectedIndex,
    ValueChanged<int>? onChanged,
    double height = 216,
  }) : this(
         key: key,
         items: items,
         selectedIndex: selectedIndex,
         onChanged: onChanged,
         style: CupertinoNativePickerStyle.wheel,
         height: height,
       );

  final List<CupertinoNativePickerItem> items;

  /// Index into [items]. Out-of-range values are clamped.
  final int selectedIndex;
  final ValueChanged<int>? onChanged;
  final CupertinoNativePickerStyle style;

  /// The picker's own label. Hidden unless [showLabel] — a picker in a list
  /// row shows it, a standalone control usually does not.
  final String? label;
  final bool showLabel;

  final Color? activeColor;
  final CupertinoNativeControlSize? sizeStyle;

  /// Fixed height. Null lets the native control report its own, except for
  /// [CupertinoNativePickerStyle.wheel], which has none of its own.
  final double? height;

  @override
  State<CupertinoNativePicker> createState() => _CupertinoNativePickerState();
}

class _CupertinoNativePickerState extends State<CupertinoNativePicker>
    with NativePlatformViewStateMixin {
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  bool? _lastIsDark;

  int get _selectedIndex => widget.items.isEmpty
      ? 0
      : widget.selectedIndex.clamp(0, widget.items.length - 1);

  bool get _fillsBox =>
      widget.style == CupertinoNativePickerStyle.wheel ||
      widget.style == CupertinoNativePickerStyle.segmented;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_lastIsDark != null && _lastIsDark != _isDark) {
      updateNativeView('updatePicker', _toMap(), refreshIntrinsicSize: false);
    }
    _lastIsDark = _isDark;
  }

  @override
  void didUpdateWidget(covariant CupertinoNativePicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.selectedIndex != widget.selectedIndex ||
        oldWidget.style != widget.style ||
        oldWidget.label != widget.label ||
        oldWidget.showLabel != widget.showLabel ||
        oldWidget.activeColor != widget.activeColor ||
        oldWidget.sizeStyle != widget.sizeStyle ||
        oldWidget.items.length != widget.items.length) {
      updateNativeView('updatePicker', _toMap());
    }
  }

  Map<String, dynamic> _toMap() {
    final theme = Theme.of(context);
    return {
      'label': widget.label,
      'labelHidden': !widget.showLabel,
      'items': [
        for (var i = 0; i < widget.items.length; i++) widget.items[i].toMap(i),
      ],
      'selectedIndex': _selectedIndex,
      'style': widget.style.name,
      'color': (widget.activeColor ?? theme.colorScheme.primary).toARGB32(),
      'controlSize': widget.sizeStyle?.name,
      'isDark': _isDark,
    };
  }

  void _onPlatformViewCreated(int id) {
    setUpChannel(
      id,
      'cupertino_widgets/picker_$id',
      onMethodCall: _handleMethodCall,
    );
    requestIntrinsicSize();
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'onChanged' && call.arguments is int) {
      widget.onChanged?.call(call.arguments as int);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return const SizedBox.shrink();
    }
    final platformView = wrapForTransition(
      UiKitView(
        viewType: 'com.example.cupertino_widgets/cupertino_native_picker',
        layoutDirection: TextDirection.ltr,
        creationParams: _toMap(),
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: _onPlatformViewCreated,
        // The wheel is a drag control: it has to win the gesture arena
        // against the scroll view it usually sits in.
        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        gestureRecognizers: scrollFriendlyGestures,
      ),
    );

    if (widget.height != null) {
      return SizedBox(height: widget.height, child: platformView);
    }
    if (_fillsBox) {
      return SizedBox(height: intrinsicHeight ?? 34.0, child: platformView);
    }
    return SizedBox(
      width: intrinsicWidth,
      height: intrinsicHeight ?? 34.0,
      child: platformView,
    );
  }
}
