import 'package:flutter/widgets.dart';

import '../cupertino_native_activity_indicator.dart';
import '../cupertino_native_body.dart';
import '../cupertino_native_button.dart';
import '../cupertino_native_date_picker.dart';
import '../cupertino_native_flutter_view.dart';
import '../cupertino_native_glass_container.dart';
import '../cupertino_native_picker.dart';
import '../cupertino_native_slider.dart';
import '../cupertino_native_sliding_segmented_control.dart';
import '../cupertino_native_switch.dart';
import '../cupertino_native_symbol.dart';
import '../cupertino_native_text_field.dart';

/// Turns package widgets written inline into native descriptions, plus the
/// callbacks to fire when they report — the lowering every surface that
/// hosts content built by SwiftUI uses (a keyboard toolbar, a native list
/// row's trailing, and the basis of `nativeBody`).
///
/// Those surfaces are built by SwiftUI in a window Flutter cannot draw, so
/// the widgets are **read, not mounted**: the package's own views are
/// transcribed straight into SwiftUI — exactly like
/// `CupertinoNativePageScaffold.nativeBody` — while real Flutter content goes
/// through a [CupertinoNativeFlutterView], which is an island in its own
/// engine and the only way Flutter itself can appear there.
///
/// The transcription is recursive: a [Row], a [Column] or a
/// [CupertinoNativeGlassContainer] can hold further items, and every level is
/// lowered the same way — SwiftUI views stay SwiftUI, only Flutter islands
/// cost an engine. That is why only the package's own controls, [Text],
/// [Spacer], [SizedBox] and [CupertinoNativeFlutterView] are accepted: a
/// widget the native side has no equivalent for could not be drawn.

/// Recursively lowers one widget to a [CupertinoNativeBody] node, registering
/// every interactive node's callback in [callbacks] under its node id.
///
/// `id` is a path: a surface's top-level items are `item0`, `item1`… and a
/// container's children are `<parent>.<index>`, so ids stay unique however
/// deep the nesting goes and every interactive node answers under the id it
/// was lowered with.
CupertinoNativeBody? lowerWidgetNode(
  Widget widget,
  String id,
  Map<String, void Function(Object? value)> callbacks,
) {
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

    case CupertinoNativeSlider():
      final onChanged = widget.onChanged;
      if (onChanged != null) callbacks[id] = (value) => onChanged((value as num?)?.toDouble() ?? 0);
      return CupertinoNativeBody.slider(
        id: id,
        value: widget.value,
        min: widget.min,
        max: widget.max,
        step: widget.divisions == null || widget.divisions! <= 0
            ? null
            : (widget.max - widget.min) / widget.divisions!,
        color: widget.activeColor,
        enabled: onChanged != null,
      );

    case CupertinoNativeTextField():
      final onChanged = widget.onChanged;
      if (onChanged != null) {
        callbacks[id] = (value) {
          final text = value as String? ?? '';
          widget.controller?.text = text;
          onChanged(text);
        };
      }
      return CupertinoNativeBody.textField(
        id: id,
        value: widget.controller?.text ?? '',
        placeholder: widget.placeholder,
        obscureText: widget.obscureText,
        enabled: widget.enabled,
      );

    case CupertinoNativeSlidingSegmentedControl():
      final keys = widget.children.keys.toList();
      final selected = widget.groupValue == null
          ? -1
          : keys.indexOf(widget.groupValue as Object);
      callbacks[id] = (value) {
        final index = (value as num?)?.toInt() ?? 0;
        if (index >= 0 && index < keys.length) {
          // The callback is a ValueChanged<T>; the original key, not the
          // index, is what it expects.
          (widget.onValueChanged as dynamic)(keys[index]);
        }
      };
      return CupertinoNativeBody.segmented(
        id: id,
        items: [
          for (final child in widget.children.values) ButtonLabel(child).title,
        ],
        selectedIndex: selected < 0 ? 0 : selected,
        style: widget.isMenu ? 'menu' : 'segmented',
        color: widget.thumbColor,
      );

    case CupertinoNativeDatePicker():
      callbacks[id] = (value) => widget.onDateTimeChanged(
        DateTime.fromMillisecondsSinceEpoch((value as num?)?.toInt() ?? 0),
      );
      return CupertinoNativeBody.datePicker(
        id: id,
        value: widget.initialDateTime,
        minimumDate: widget.minimumDate,
        maximumDate: widget.maximumDate,
        mode: widget.mode.name,
        tint: widget.activeColor,
      );

    case CupertinoNativeActivityIndicator():
      return CupertinoNativeBody.progress(style: 2, color: widget.color);

    case CupertinoNativeLinearActivityIndicator():
      return CupertinoNativeBody.progress(
        value: widget.progress,
        style: 1,
        color: widget.color,
      );

    case Padding(:final child?):
      return lowerWidgetNode(child, id, callbacks);

    case Row():
      return CupertinoNativeBody.row(
        children: lowerWidgetChildren(widget.children, id, callbacks),
      );

    case Column():
      return CupertinoNativeBody.column(
        children: lowerWidgetChildren(widget.children, id, callbacks),
      );

    case CupertinoNativeGlassContainer():
      return lowerGlassContainer(widget, id, callbacks);

    default:
      assert(
        false,
        'This content cannot hold a ${widget.runtimeType}. The surface is '
        'built by SwiftUI in a window Flutter cannot draw, so its items are '
        'read rather than mounted. Use the package\'s own controls — '
        'CupertinoNativeButton, CupertinoNativeSwitch, CupertinoNativeSlider, '
        'CupertinoNativePicker, CupertinoNativeSegmentedControl, '
        'CupertinoNativeDatePicker, CupertinoNativeActivityIndicator, '
        'CupertinoNativeSymbol, CupertinoNativeTextField, '
        'CupertinoNativeGlassContainer, Text, Spacer, Row or Column — or '
        'CupertinoNativeFlutterView(route) to host your own Flutter there, '
        'which costs an engine.',
      );
      return null;
  }
}

/// One container's children, lowered under its own path.
List<CupertinoNativeBody> lowerWidgetChildren(
  List<Widget> widgets,
  String parentId,
  Map<String, void Function(Object? value)> callbacks,
) {
  final children = <CupertinoNativeBody>[];
  for (var i = 0; i < widgets.length; i++) {
    final node = lowerWidgetNode(widgets[i], '$parentId.$i', callbacks);
    if (node != null) children.add(node);
  }
  return children;
}

/// A liquid glass container, transcribed to a native `glass` node: its
/// [CupertinoNativeGlassContainer.icon] becomes a symbol, its `route` a
/// Flutter island, and its `child` is lowered in place — so a container
/// inside a container works at any depth. A `onPressed` makes the glass
/// itself a button, reporting `(id, null)`.
CupertinoNativeBody lowerGlassContainer(
  CupertinoNativeGlassContainer widget,
  String id,
  Map<String, void Function(Object? value)> callbacks,
) {
  final onPressed = widget.onPressed;
  if (onPressed != null) callbacks[id] = (_) => onPressed();

  final children = <CupertinoNativeBody>[];
  final icon = widget.icon;
  if (icon != null) {
    assert(
      icon.sfSymbol != null,
      'This content cannot transcribe a Flutter glyph icon; use an SF '
      'Symbol, or CupertinoNativeFlutterView for the whole content.',
    );
    children.add(
      CupertinoNativeBody.symbol(
        icon.sfSymbol!,
        size: icon.size ?? 17,
        color: icon.color,
      ),
    );
  }
  if (widget.route != null) {
    children.add(CupertinoNativeBody.flutter(widget.route!));
  }
  if (widget.child != null) {
    final lowered = lowerWidgetNode(
      widget.child!,
      '$id.${children.length}',
      callbacks,
    );
    if (lowered != null) children.add(lowered);
  }

  return CupertinoNativeBody.glass(
    id: onPressed != null ? id : null,
    children: children,
    shape: widget.shape,
    cornerRadius: widget.cornerRadius,
    variant: widget.variant,
    tint: widget.tint,
    interactive: widget.interactive,
    pressable: onPressed != null,
    padding: widget.padding.resolve(TextDirection.ltr),
  );
}

/// The widgets of a `CupertinoNativeTextField.toolbarActions` list, lowered —
/// the keyboard bar's content.
class LoweredToolbar {
  LoweredToolbar(List<Widget> items, {required bool isDark}) {
    for (var i = 0; i < items.length; i++) {
      final node = lowerWidgetNode(items[i], 'item$i', callbacks);
      if (node != null) nodes.add(node.toMap(isDark: isDark));
    }
  }

  final List<Map<String, dynamic>> nodes = [];

  /// id → what to call when that item reports.
  final Map<String, void Function(Object? value)> callbacks = {};

  void dispatch(String id, Object? value) => callbacks[id]?.call(value);
}

/// One lowered widget for a single slot — a native list row's `trailing`.
/// The widget itself may be a container (Row, glass…) whose children lower
/// recursively under it.
class LoweredTrailing {
  LoweredTrailing(Widget widget) {
    node = lowerWidgetNode(widget, 'item0', callbacks);
  }

  CupertinoNativeBody? node;

  /// id → what to call when that node reports.
  final Map<String, void Function(Object? value)> callbacks = {};

  void dispatch(String id, Object? value) => callbacks[id]?.call(value);
}
