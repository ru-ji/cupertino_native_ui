import 'package:flutter/widgets.dart';

import '../cupertino_native_activity_indicator.dart';
import '../cupertino_native_body.dart';
import '../cupertino_native_button.dart';
import '../cupertino_native_checkbox.dart';
import 'native_control.dart';
import 'native_log.dart';
import '../cupertino_native_date_picker.dart';
import '../cupertino_native_flutter_view.dart';
import '../cupertino_native_glass_container.dart';
import '../cupertino_native_menu.dart';
import '../cupertino_native_photos_picker.dart';
import '../cupertino_native_picker.dart';
import '../cupertino_native_slider.dart';
import '../cupertino_native_sliding_segmented_control.dart';
import '../cupertino_native_switch.dart';
import '../cupertino_native_symbol.dart';
import '../cupertino_native_text_field.dart';
import '../models/cupertino_native_button_extra_options.dart';

/// Turns package widgets written inline into native descriptions, plus the
/// callbacks to fire when they report: the lowering every surface that
/// hosts content built by SwiftUI uses (a keyboard toolbar, a native list
/// row's trailing, and the basis of `nativeBody`).
///
/// Those surfaces are built by SwiftUI in a window Flutter cannot draw, so
/// the widgets are **read, not mounted**: the package's own views are
/// transcribed straight into SwiftUI, exactly like
/// `CupertinoNativePageScaffold.nativeBody`, while real Flutter content goes
/// through a [CupertinoNativeFlutterView], which is an island in its own
/// engine and the only way Flutter itself can appear there.
///
/// The transcription is recursive: a [Row], a [Column] or a
/// [CupertinoNativeGlassContainer] can hold further items, and every level is
/// lowered the same way. SwiftUI views stay SwiftUI, only Flutter islands
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

    // A childless SizedBox is a fixed gap. One *with* a child is a sizing
    // box, and lowering it as a gap silently dropped the child: a 200pt
    // square where a field was meant to be.
    case SizedBox(:final child?):
      return lowerWidgetNode(child, id, callbacks);

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
        // A circle only rounds a square, icon-only label: with a title
        // SwiftUI still clips the label to the circle ("Sh…").
        borderShape:
            widget.borderShape == CupertinoNativeButtonBorderShape.circle &&
                !label.iconOnly
            ? CupertinoNativeButtonBorderShape.automatic
            : widget.borderShape,
        color: widget.color,
        // A null `onPressed` is a disabled button, the way it is everywhere
        // else in Flutter: greyed out rather than silently inert.
        enabled: onPressed != null,
      );

    case CupertinoNativeMenu():
      final onAction = widget.onAction;
      if (onAction != null) {
        callbacks[id] = (value) {
          final event = value as Map<Object?, Object?>? ?? const {};
          onAction(event['id'] as String? ?? '', event['value']);
        };
      }
      return CupertinoNativeBody.menu(
        id: id,
        title: widget.title,
        systemImage: widget.systemImage,
        items: [for (final item in widget.items) item.toMap()],
        style: widget.style,
        borderShape: widget.borderShape,
        labelStyle: widget.labelStyle,
        controlSize: widget.controlSize,
        color: widget.activeColor,
        fontSize: widget.textStyle?.fontSize,
        fontWeight: widget.textStyle?.fontWeight == null
            ? null
            : widget.textStyle!.fontWeight!.value ~/ 100 - 1,
        textColor: widget.textStyle?.color,
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

    case CupertinoNativeCheckbox():
      final onChanged = widget.onChanged;
      if (onChanged != null) {
        callbacks[id] = (value) => onChanged(value as bool? ?? false);
      }
      return CupertinoNativeBody.checkbox(
        id: id,
        value: widget.value,
        label: widget.label,
        color: widget.activeColor,
        enabled: onChanged != null,
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
      if (onChanged != null) {
        callbacks[id] = (value) => onChanged((value as num?)?.toDouble() ?? 0);
      }
      double valueOf(Object? v) => (v as num?)?.toDouble() ?? widget.value;
      if (widget.onChangeStart case final start?) {
        callbacks['$id.start'] = (v) => start(valueOf(v));
      }
      if (widget.onChangeEnd case final end?) {
        callbacks['$id.end'] = (v) => end(valueOf(v));
      }
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
        neutralValue: widget.neutralValue,
        showTicks: widget.showTicks,
        minimumIcon: widget.minimumIcon,
        maximumIcon: widget.maximumIcon,
      );

    case CupertinoNativePhotosPicker():
      callbacks[id] = (value) =>
          widget.onChanged(CupertinoNativePickedMedia.listFrom(value));
      return CupertinoNativeBody.photosPicker(id: id, picker: widget);

    case final NativeControlProvider provider:
      final control = provider.nativeControl;
      if (control.onChanged case final onChanged? when control.enabled) {
        callbacks[id] = onChanged;
      }
      return CupertinoNativeBody.control(
        id: id,
        control: widget,
        enabled: control.enabled,
      );

    case CupertinoNativeTextField():
      // The bar travels with the field: the native side owns it and puts it
      // on the transcribed field's own UITextField. Its nodes stay unencoded,
      // so they resolve their colours with the brightness the field is sent
      // with, not a guess made here.
      final toolbar = widget.toolbarActions.isEmpty
          ? null
          : LoweredToolbar(widget.toolbarActions, isDark: false);
      if (toolbar != null) {
        for (final entry in toolbar.callbacks.entries) {
          callbacks['$id.toolbar.${entry.key}'] = entry.value;
        }
      }
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
        keyboardType: widget.keyboardType,
        textInputAction: widget.textInputAction,
        textContentType: widget.textContentType,
        textCapitalization: widget.textCapitalization,
        autocorrect: widget.autocorrect,
        textAlign: widget.textAlign,
        maxLength: widget.maxLength,
        clearButtonMode: widget.clearButtonMode,
        glass: widget.glass,
        glassTint: widget.glassTint,
        cornerRadius: widget.cornerRadius,
        prefix: widget.prefix,
        suffix: widget.suffix,
        keyboardToolbar: toolbar?.bodies ?? const [],
      );

    case CupertinoNativeSlidingSegmentedControl():
      final keys = widget.children.keys.toList();
      // Read through a dynamic receiver: the widget is matched raw here (T is
      // dynamic), so a typed field read would check the callback against
      // `void Function(dynamic)` and reject a closure declared with T's real
      // type (covariant generic field access).
      final dynamic onValueChanged = (widget as dynamic).onValueChanged;
      final selected = widget.groupValue == null
          ? -1
          : keys.indexOf(widget.groupValue as Object);
      callbacks[id] = (value) {
        final index = (value as num?)?.toInt() ?? 0;
        if (index >= 0 && index < keys.length) {
          // The callback is a ValueChanged<T>; the original key, not the
          // index, is what it expects.
          Function.apply(onValueChanged as Function, [keys[index]]);
        }
      };
      return CupertinoNativeBody.segmented(
        id: id,
        items: [
          for (final child in widget.children.values) ButtonLabel(child).title,
        ],
        // -1 when nothing is selected: no segment shows as picked, as with
        // the standalone control.
        selectedIndex: selected,
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
        style: widget.style.name,
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
      // The insets ride on the child's node: dropping them here is what made
      // a `Padding` around a toolbar item do nothing.
      return lowerWidgetNode(
        child,
        id,
        callbacks,
      )?.withPadding(widget.padding.resolve(TextDirection.ltr));

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
        'read rather than mounted. Use the package\'s own controls: '
        'CupertinoNativeButton, CupertinoNativeSwitch, CupertinoNativeCheckbox, '
        'CupertinoNativeMenu, CupertinoNativeSlider, CupertinoNativeStepper, '
        'CupertinoNativeColorPicker, CupertinoNativeGauge, '
        'CupertinoNativeMultiDatePicker, CupertinoNativeTextEditor, CupertinoNativePicker, '
        'CupertinoNativeSegmentedControl, CupertinoNativeDatePicker, '
        'CupertinoNativeActivityIndicator, CupertinoNativeSymbol, '
        'CupertinoNativeTextField, CupertinoNativeGlassContainer, Text, '
        'Spacer, Row or Column, or CupertinoNativeFlutterView(route) to host '
        'your own Flutter there, which costs an engine.',
      );
      // The assert stops a debug build; release drops the widget, which only
      // the package's own diagnostics mention.
      nativeLog(
        () =>
            'dropped ${widget.runtimeType}. This surface is '
            'rendered by SwiftUI and cannot mount Flutter widgets. Wrap it in '
            'CupertinoNativeFlutterView(route) to keep it.',
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
/// [CupertinoNativeGlassContainer.icon] becomes a symbol and its `child` is
/// lowered in place, so a container
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
  // ponytail: a native body draws SF Symbols only; a custom icon is dropped
  // here until body nodes take one.
  final icon = widget.icon;
  if (icon?.sfSymbol case final name?) {
    children.add(
      CupertinoNativeBody.symbol(
        name,
        size: icon!.size ?? 17,
        color: icon.color,
      ),
    );
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
    // Always: the id is also the node's SwiftUI identity, so dropping it with
    // onPressed made a new view (and cut a press) whenever onPressed toggled.
    // Whether a tap reports is `pressable`'s call.
    id: id,
    children: children,
    shape: widget.shape,
    cornerRadius: widget.cornerRadius,
    variant: widget.variant,
    tint: widget.tint,
    interactive: widget.interactive,
    pressable: onPressed != null,
    padding: widget.padding.resolve(TextDirection.ltr),
    width: widget.width,
    height: widget.height,
  );
}

/// The widgets of a `CupertinoNativeTextField.toolbarActions` list, lowered:
/// the keyboard bar's content.
class LoweredToolbar {
  LoweredToolbar(List<Widget> items, {required bool isDark}) {
    for (var i = 0; i < items.length; i++) {
      final node = lowerWidgetNode(items[i], 'item$i', callbacks);
      if (node == null) continue;
      bodies.add(node);
      nodes.add(node.toMap(isDark: isDark));
    }
  }

  /// The items as nodes, for a bar nested in a node that is encoded later.
  final List<CupertinoNativeBody> bodies = [];

  /// The items encoded for [isDark].
  final List<Map<String, dynamic>> nodes = [];

  /// id → what to call when that item reports.
  final Map<String, void Function(Object? value)> callbacks = {};

  void dispatch(String id, Object? value) => callbacks[id]?.call(value);
}

/// One lowered widget for a single slot: a native list row's `trailing`.
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
