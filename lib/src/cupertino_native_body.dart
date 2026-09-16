import 'package:flutter/widgets.dart';

import 'cupertino_native_picker.dart';
import 'cupertino_native_symbol.dart';
import 'models/cupertino_native_button_style.dart';
import 'models/cupertino_native_button_extra_options.dart';
import 'models/cupertino_native_icon.dart';
import 'models/cupertino_native_list_section.dart';

/// A node of a [CupertinoNativePageScaffold]'s **native body** — a SwiftUI
/// view tree described from Dart.
///
/// The ordinary body is a route running in its own FlutterEngine, so a native
/// control inside it goes Flutter → SwiftUI → FlutterView → SwiftUI: a
/// platform view nested in a hierarchy that was already native. A native body
/// removes the middle: Dart sends this description, SwiftUI renders it, and
/// the result is the view hierarchy you would get writing the SwiftUI by hand.
///
/// ```dart
/// CupertinoNativePageScaffold(
///   navigationBar: const CupertinoNativeScaffoldNavigationBar(title: 'Profile'),
///   nativeBody: CupertinoNativeBody.column(
///     padding: const EdgeInsets.all(16),
///     spacing: 12,
///     children: [
///       CupertinoNativeBody.text('Account', style: CupertinoNativeTextStyle.title),
///       CupertinoNativeBody.textField(id: 'name', placeholder: 'Name'),
///       CupertinoNativeBody.toggle(id: 'notify', label: 'Notifications', value: _notify),
///       CupertinoNativeBody.button(id: 'save', title: 'Save', style: CupertinoNativeButtonStyle.glassProminent),
///     ],
///   ),
///   onBodyEvent: (id, value) => setState(() { ... }),
/// )
/// ```
///
/// These are **descriptions, not widgets**: they are serialized and sent, not
/// built. That is the trade — the body is no longer arbitrary Flutter, only
/// what this tree can express. You cannot have both a body you write in
/// Flutter and controls that render as SwiftUI directly.
///
/// Interactive nodes need an [id]; changes report through
/// `CupertinoNativePageScaffold.onBodyEvent` as `(id, value)`. A button
/// reports null, a field its text, a toggle a bool, a slider a double, a
/// picker an int index.
class CupertinoNativeBody {
  CupertinoNativeBody._({
    required this.type,
    this.id,
    this.children,
    this.spacing,
    this.alignment,
    this.padding,
    this.extent,
    this.expand,
    this.route,
    this.payload,
  });

  final String type;
  final String? id;
  final List<CupertinoNativeBody>? children;
  final double? spacing;
  final String? alignment;
  final EdgeInsets? padding;
  final double? extent;
  final bool? expand;
  final String? route;
  final Map<String, dynamic>? payload;

  /// A vertical stack.
  CupertinoNativeBody.column({
    required List<CupertinoNativeBody> children,
    double? spacing,
    CrossAxisAlignment alignment = CrossAxisAlignment.start,
    EdgeInsets? padding,
    bool? expand,
  }) : this._(
         type: 'column',
         children: children,
         spacing: spacing,
         alignment: alignment == CrossAxisAlignment.center
             ? 'center'
             : alignment == CrossAxisAlignment.end
             ? 'trailing'
             : 'leading',
         padding: padding,
         expand: expand,
       );

  /// A horizontal stack.
  CupertinoNativeBody.row({
    required List<CupertinoNativeBody> children,
    double? spacing,
    CrossAxisAlignment alignment = CrossAxisAlignment.center,
    EdgeInsets? padding,
    bool? expand,
  }) : this._(
         type: 'row',
         children: children,
         spacing: spacing,
         alignment: alignment == CrossAxisAlignment.start
             ? 'top'
             : alignment == CrossAxisAlignment.end
             ? 'bottom'
             : 'center',
         padding: padding,
         expand: expand,
       );

  /// A scrolling column. The scaffold already wraps the body in a scroll view,
  /// so this is for a nested one.
  CupertinoNativeBody.scroll({
    required List<CupertinoNativeBody> children,
    double? spacing,
    EdgeInsets? padding,
  }) : this._(
         type: 'scroll',
         children: children,
         spacing: spacing,
         padding: padding,
       );

  /// Flexible space, or a fixed gap when [extent] is given.
  CupertinoNativeBody.spacer({double? extent})
    : this._(type: 'spacer', extent: extent);

  /// A hairline separator.
  CupertinoNativeBody.divider() : this._(type: 'divider');

  /// A `Text`.
  CupertinoNativeBody.text(
    String value, {
    CupertinoNativeTextStyle? style,
    double? fontSize,
    FontWeight? fontWeight,
    Color? color,
    TextAlign? align,
    EdgeInsets? padding,
  }) : this._(
         type: 'text',
         padding: padding,
         payload: {
           'text': {
             'value': value,
             'style': style?.name,
             'fontSize': fontSize,
             'fontWeight': fontWeight == null
                 ? null
                 : (fontWeight.value ~/ 100) - 1,
             'color': color,
             'align': align == TextAlign.center
                 ? 'center'
                 : align == TextAlign.right || align == TextAlign.end
                 ? 'trailing'
                 : 'leading',
           },
         },
       );

  /// A `Button`, reporting a tap as `(id, null)`.
  CupertinoNativeBody.button({
    required String id,
    String? title,
    CupertinoNativeIcon? icon,
    CupertinoNativeButtonStyle style = CupertinoNativeButtonStyle.plain,
    CupertinoNativeControlSize sizeStyle = CupertinoNativeControlSize.regular,
    CupertinoNativeButtonBorderShape borderShape =
        CupertinoNativeButtonBorderShape.automatic,
    Color? color,
    bool expand = false,
    EdgeInsets? padding,
  }) : this._(
         type: 'button',
         id: id,
         padding: padding,
         payload: {
           'button': {
             'title': title ?? '',
             'icon': icon,
             'style': style,
             'controlSize': sizeStyle,
             'borderShape': borderShape,
             'labelStyle': (title == null || title.isEmpty) && icon != null
                 ? 'iconOnly'
                 : icon == null
                 ? 'titleOnly'
                 : 'titleAndIcon',
             'expand': expand,
             'color': color,
           },
         },
       );

  /// A `TextField`, reporting each edit as `(id, String)`. Focus and submit
  /// arrive as `('<id>.focused', bool)` and `('<id>.submitted', String)`.
  CupertinoNativeBody.textField({
    required String id,
    String? value,
    String? placeholder,
    bool obscureText = false,
    bool enabled = true,
    EdgeInsets? padding,
  }) : this._(
         type: 'textField',
         id: id,
         padding: padding,
         payload: {
           'textField': {
             'text': value ?? '',
             'placeholder': placeholder,
             'obscureText': obscureText,
             'enabled': enabled,
           },
         },
       );

  /// A `Toggle`, reporting `(id, bool)`.
  CupertinoNativeBody.toggle({
    required String id,
    required bool value,
    String? label,
    Color? color,
    EdgeInsets? padding,
  }) : this._(
         type: 'toggle',
         id: id,
         padding: padding,
         payload: {
           'toggle': {'label': label, 'value': value, 'color': color},
         },
       );

  /// A `Slider`, reporting `(id, double)` on every step of the drag.
  CupertinoNativeBody.slider({
    required String id,
    required double value,
    double min = 0,
    double max = 1,
    double? step,
    Color? color,
    bool enabled = true,
    EdgeInsets? padding,
  }) : this._(
         type: 'slider',
         id: id,
         padding: padding,
         payload: {
           'slider': {
             'value': value,
             'min': min,
             'max': max,
             'step': step,
             'color': color,
             'enabled': enabled,
           },
         },
       );

  /// A `Picker`, reporting `(id, int)`.
  CupertinoNativeBody.picker({
    required String id,
    required List<CupertinoNativePickerItem> items,
    required int selectedIndex,
    CupertinoNativePickerStyle style = CupertinoNativePickerStyle.automatic,
    String? label,
    bool showLabel = false,
    Color? color,
    EdgeInsets? padding,
  }) : this._(
         type: 'picker',
         id: id,
         padding: padding,
         payload: {
           'picker': {
             'items': items,
             'selectedIndex': selectedIndex,
             'style': style,
             'label': label,
             'labelHidden': !showLabel,
             'color': color,
           },
         },
       );

  /// An inset-grouped list. Row taps report `(id, rowId)`; a row's toggle
  /// reports `('<id>.<rowId>', bool)`.
  CupertinoNativeBody.list({
    required String id,
    required List<CupertinoNativeListSection> sections,
    EdgeInsets? padding,
  }) : this._(
         type: 'list',
         id: id,
         padding: padding,
         payload: {
           'list': {'sections': sections},
         },
       );

  /// An SF Symbol, optionally animated.
  CupertinoNativeBody.symbol(
    String name, {
    double size = 17,
    Color? color,
    CupertinoNativeSymbolEffect? effect,
    int trigger = 0,
    bool repeating = false,
    EdgeInsets? padding,
  }) : this._(
         type: 'symbol',
         padding: padding,
         payload: {
           'symbol': {
             'name': name,
             'size': size,
             'color': color,
             'effect': effect,
             'trigger': trigger,
             'repeating': repeating,
           },
         },
       );

  /// A **Flutter island** inside the native tree: real Flutter widgets, in
  /// their own engine, hosted where SwiftUI puts them — including inside a
  /// keyboard toolbar, where Flutter otherwise cannot draw.
  ///
  /// [route] is registered in `maybeRun` like a scaffold body, for the same
  /// reason: the island runs in its own isolate, so it is named, not passed.
  ///
  /// This is the expensive node. One island is one isolate, booted the first
  /// time it appears and kept for the process's lifetime. A row of buttons
  /// costs nothing; an island costs what a scaffold body costs. Use it where
  /// the content genuinely has to be your Flutter, not to avoid writing three
  /// `.button`s.
  CupertinoNativeBody.flutter(String route, {EdgeInsets? padding})
    : this._(type: 'flutter', route: route, padding: padding);

  /// Serialized form consumed by `BodyNodeConfig` on the Swift side.
  ///
  /// [isDark] is threaded down the tree: every leaf config carries the app's
  /// brightness, the same as when the control is a standalone platform view.
  Map<String, dynamic> toMap({required bool isDark}) {
    return {
      'type': type,
      'id': id,
      'spacing': spacing,
      'alignment': alignment,
      'extent': extent,
      'expand': expand,
      'route': route,
      'isDark': isDark,
      if (padding != null)
        'padding': {
          'top': padding!.top,
          'leading': padding!.left,
          'bottom': padding!.bottom,
          'trailing': padding!.right,
        },
      if (children != null)
        'children': [
          for (final child in children!) child.toMap(isDark: isDark),
        ],
      ..._encodePayload(isDark),
    };
  }

  /// Payloads are stored with live Dart objects (colors, icons, enums) so the
  /// constructors can stay `const`; they are lowered to channel types here.
  Map<String, dynamic> _encodePayload(bool isDark) {
    final payload = this.payload;
    if (payload == null) return const {};
    return {
      for (final entry in payload.entries)
        entry.key: {
          ...(entry.value as Map<String, dynamic>).map(
            (key, value) => MapEntry(key, _lower(value, isDark)),
          ),
          // Every leaf config carries it; the ones that don't read it ignore it.
          'isDark': isDark,
        },
    };
  }

  static Object? _lower(Object? value, bool isDark) {
    if (value is Color) return value.toARGB32();
    if (value is FontWeight) return (value.value ~/ 100) - 1;
    if (value is CupertinoNativeIcon) return value.toMap();
    if (value is CupertinoNativeListSection) return value.toMap();
    if (value is CupertinoNativePickerItem) return value.toMap(0);
    if (value is Enum) return value.name;
    if (value is List) {
      return [
        for (var i = 0; i < value.length; i++)
          value[i] is CupertinoNativePickerItem
              ? (value[i] as CupertinoNativePickerItem).toMap(i)
              : _lower(value[i], isDark),
      ];
    }
    return value;
  }
}

/// SwiftUI's built-in text styles, for [CupertinoNativeBody.text].
enum CupertinoNativeTextStyle {
  largeTitle,
  title,
  title2,
  title3,
  headline,
  subheadline,
  body,
  callout,
  footnote,
  caption,
}
