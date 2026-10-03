import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'cupertino_native_glass_container.dart' show CupertinoNativeGlass;
import 'internal/native_control.dart';
import 'internal/widget_lowering.dart';

/// A native SwiftUI `TextEditor`: multi-line, scrolling text entry.
///
/// Controlled by [text]: echo [onChanged] back into it.
class CupertinoNativeTextEditor extends StatelessWidget
    implements NativeControlProvider {
  const CupertinoNativeTextEditor({
    super.key,
    required this.text,
    required this.onChanged,
    this.placeholder,
    this.fontSize,
    this.style,
    this.cursorColor,
    this.backgroundColor,
    this.cornerRadius,
    this.keyboardType = TextInputType.multiline,
    this.textCapitalization = TextCapitalization.sentences,
    this.textContentType,
    this.textAlign = TextAlign.start,
    this.autocorrect = true,
    this.maxLength,
    this.readOnly = false,
    this.glass,
    this.glassTint,
    this.placeholderPadding,
    this.padding,
    this.prefix,
    this.height = 120,
  });

  final String text;

  /// Null makes the editor read-only.
  final ValueChanged<String>? onChanged;
  final String? placeholder;

  /// Shorthand for `style.fontSize`; [style] wins when both are set.
  final double? fontSize;

  /// `fontSize`, `fontWeight` and `color` are forwarded natively.
  final TextStyle? style;
  final Color? cursorColor;

  /// Null is transparent (iOS 16+; the system background below).
  final Color? backgroundColor;
  final double? cornerRadius;
  final TextInputType keyboardType;
  final TextCapitalization textCapitalization;

  /// A `UITextContentType` raw value, as on [CupertinoNativeTextField].
  final String? textContentType;
  final TextAlign textAlign;
  final bool autocorrect;

  /// Longer input is cut, like [CupertinoNativeTextField.maxLength].
  final int? maxLength;

  /// Selectable and copyable, but not editable.
  final bool readOnly;

  /// `.glassEffect(glass.interactive())`, in a [cornerRadius] rounded shape
  /// (16 when null). iOS 26; null: no glass.
  final CupertinoNativeGlass? glass;

  /// `Glass.tint`: a colour mixed into the [glass].
  final Color? glassTint;

  /// Where the [placeholder] sits from the editor's top-left corner, before
  /// [padding]. The placeholder is drawn over the editor (SwiftUI's
  /// `TextEditor` has none), so it is aligned by hand with where typed text
  /// starts: 8 top / 5 left, the text view's own inset. Set it if the two do
  /// not line up.
  final EdgeInsets? placeholderPadding;

  /// Room between the editor's edge and its text, added to the text view's
  /// own inset. Above and below, it is inside the scrolling text, which
  /// scrolls through it up to the edge. The placeholder and the [prefix]
  /// move with it.
  final EdgeInsets? padding;

  /// Drawn before the text, on its first line: any widget the package
  /// transcribes natively (a `CupertinoNativeIcon`'s symbol image, a
  /// `CupertinoNativeButton`, a `Row` of them…), keeping its callbacks. Its
  /// measured width is added to the placeholder's left offset. Standalone
  /// editor only: an editor inside a native list or body draws none.
  final Widget? prefix;

  /// The editor scrolls inside this height.
  final double height;

  @override
  Widget build(BuildContext context) => nativeControl;

  @override
  NativeControl get nativeControl {
    final lowered = prefix == null ? null : LoweredTrailing(prefix!);
    return NativeControl(
      prefix: lowered?.node,
      onEvent: lowered?.dispatch,
      kind: 'textEditor',
      height: height,
      // A drag scrolls the text or the page as UIKit would decide, see
      // NestedScrollPlatformViewRecognizer.
      props: {
        'text': text,
        'height': height,
        'placeholder': placeholder,
        'fontSize': style?.fontSize ?? fontSize,
        'fontWeight': style?.fontWeight == null
            ? null
            : style!.fontWeight!.value ~/ 100 - 1,
        'textColor': style?.color,
        'cursorColor': cursorColor,
        'backgroundColor': backgroundColor,
        'cornerRadius': cornerRadius,
        // The names the text field sends: `TextInputType` has no enum `name`.
        'keyboardType': (keyboardType.toJson()['name'] as String)
            .split('.')
            .last,
        'textCapitalization': textCapitalization.name,
        'textContentType': textContentType,
        'textAlign': textAlign.name,
        'autocorrect': autocorrect,
        'maxLength': maxLength,
        'readOnly': readOnly,
        'glass': glass?.name,
        'glassTint': glassTint,
        'placeholderTop': placeholderPadding?.top,
        'placeholderLeading': placeholderPadding?.left,
        'padding': padding == null
            ? null
            : {
                'left': padding!.left,
                'top': padding!.top,
                'right': padding!.right,
                'bottom': padding!.bottom,
              },
      },
      enabled: onChanged != null,
      onChanged: (v) => onChanged?.call(v as String),
    );
  }
}
