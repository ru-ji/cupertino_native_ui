import 'package:flutter/widgets.dart';

import '../cupertino_native_body.dart';
import '../cupertino_native_button.dart';
import '../cupertino_native_flutter_view.dart';
import '../cupertino_native_picker.dart';
import '../cupertino_native_symbol.dart';
import '../cupertino_native_switch.dart';

/// Turns the widgets written in `keyboardToolbar` into the native description
/// the toolbar is built from, plus the callbacks to fire when they report.
///
/// The keyboard bar is a `ToolbarItemGroup(placement: .keyboard)` in the
/// keyboard's own window, so its content is built by SwiftUI, not by Flutter.
/// The widgets you write there are therefore **read, not mounted**: this walks
/// them, copies what the native control needs, and keeps their callbacks.
///
/// That is why only the package's own controls and [Spacer] are accepted — a
/// widget the native side has no equivalent for could not be drawn.
class LoweredToolbar {
  LoweredToolbar(List<Widget> items, {required bool isDark}) {
    for (var i = 0; i < items.length; i++) {
      final id = 'item$i';
      final node = _lower(items[i], id);
      if (node != null) nodes.add(node.toMap(isDark: isDark));
    }
  }

  final List<Map<String, dynamic>> nodes = [];

  /// id → what to call when that item reports.
  final Map<String, void Function(Object? value)> callbacks = {};

  void dispatch(String id, Object? value) => callbacks[id]?.call(value);

  CupertinoNativeBody? _lower(Widget widget, String id) {
    switch (widget) {
      case Spacer():
        return CupertinoNativeBody.spacer();

      case SizedBox(:final width):
        return CupertinoNativeBody.spacer(extent: width);

      case CupertinoNativeButton():
        final label = ButtonLabel(widget.child);
        final onPressed = widget.onPressed;
        if (onPressed != null) callbacks[id] = (_) => onPressed();
        return CupertinoNativeBody.button(
          id: id,
          title: label.title.isEmpty ? null : label.title,
          icon: label.icon,
          style: widget.style,
          sizeStyle: widget.sizeStyle,
          borderShape: widget.borderShape,
          color: widget.color,
        );

      case CupertinoNativeSwitch():
        final onChanged = widget.onChanged;
        if (onChanged != null) {
          callbacks[id] = (value) => onChanged(value as bool? ?? false);
        }
        return CupertinoNativeBody.toggle(
          id: id,
          value: widget.value,
          label: widget.label,
          color: widget.activeTrackColor,
        );

      case CupertinoNativePicker():
        final onChanged = widget.onChanged;
        if (onChanged != null) {
          callbacks[id] = (value) => onChanged((value as num?)?.toInt() ?? 0);
        }
        return CupertinoNativeBody.picker(
          id: id,
          items: widget.items,
          selectedIndex: widget.selectedIndex,
          style: widget.style,
          label: widget.label,
          showLabel: widget.showLabel,
          color: widget.activeColor,
        );

      case CupertinoNativeSymbol():
        return CupertinoNativeBody.symbol(
          widget.name,
          size: widget.size,
          color: widget.color,
          effect: widget.effect,
          trigger: widget.trigger,
          repeating: widget.repeating,
        );

      case CupertinoNativeFlutterView(:final route):
        return CupertinoNativeBody.flutter(route);

      case Text(:final data?):
        return CupertinoNativeBody.text(data);

      case Padding(:final child?):
        return _lower(child, id);

      default:
        assert(
          false,
          'keyboardToolbar cannot hold a ${widget.runtimeType}. The bar is '
          'built by SwiftUI in the keyboard\'s own window, so its items are '
          'read rather than mounted. Use CupertinoNativeButton, '
          'CupertinoNativeSwitch, CupertinoNativePicker, '
          'CupertinoNativeSymbol, Text, Spacer — or '
          'CupertinoNativeBody.flutter(route) to host your own Flutter there, '
          'which costs an engine.',
        );
        return null;
    }
  }
}
