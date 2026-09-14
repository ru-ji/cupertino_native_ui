import 'dart:async';

import 'package:flutter/cupertino.dart' show OverlayVisibilityMode;
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'cupertino_native_glass_container.dart'
    show CupertinoGlass, CupertinoGlassVariant;
import 'internal/native_platform_view_mixin.dart';
import 'internal/text_field_wire.dart';
import 'search_row_visibility.dart';
import 'models/cupertino_native_icon.dart';

/// Disambiguates a quick drag (scroll the ancestor `Scrollable`, like a plain
/// Flutter `TextField` allows) from a press-and-hold (enter native text
/// selection, with its handles/magnifier) on the same touch that starts on
/// the field.
///
/// A blanket-eager recognizer would let selection-dragging work but also
/// swallow every scroll attempt that starts on top of the field. This instead
/// waits briefly: if the pointer moves past a small slop before the hold
/// timeout, it rejects so an ancestor scroll recognizer can claim the
/// gesture; if the pointer stays roughly still past the timeout (or is
/// released quickly, as a plain tap), it accepts so the native `UITextField`
/// gets the full gesture (selection, handle-dragging, or tap-to-focus/caret).
class _NativeTextFieldGestureRecognizer extends OneSequenceGestureRecognizer {
  _NativeTextFieldGestureRecognizer({required this.isSelectionActive});

  /// Whether the native field currently shows a non-empty selection (reported
  /// by the platform side). Selection handles are on screen during that
  /// window, and grabbing one is an immediate drag — indistinguishable from a
  /// scroll by the slop/timeout heuristic — so every touch is claimed for the
  /// native field instead. Scrolling from elsewhere on the page still works.
  final bool Function() isSelectionActive;

  static const Duration _holdTimeout = Duration(milliseconds: 300);
  static const double _slop = 12.0;

  Offset? _downPosition;
  Timer? _timer;

  @override
  void addAllowedPointer(PointerDownEvent event) {
    startTrackingPointer(event.pointer, event.transform);
    if (isSelectionActive()) {
      resolve(GestureDisposition.accepted);
      return;
    }
    _downPosition = event.position;
    _timer = Timer(_holdTimeout, () => resolve(GestureDisposition.accepted));
  }

  @override
  void handleEvent(PointerEvent event) {
    if (event is PointerMoveEvent) {
      final start = _downPosition;
      if (start != null && (event.position - start).distance > _slop) {
        _timer?.cancel();
        resolve(GestureDisposition.rejected);
      }
    } else if (event is PointerUpEvent) {
      _timer?.cancel();
      // Released quickly without much movement: a plain tap, let it through
      // so focus/caret placement still reaches the native field.
      resolve(GestureDisposition.accepted);
    } else if (event is PointerCancelEvent) {
      _timer?.cancel();
    }
    if (event is PointerUpEvent || event is PointerCancelEvent) {
      stopTrackingPointer(event.pointer);
    }
  }

  @override
  void acceptGesture(int pointer) {
    _timer?.cancel();
  }

  @override
  void rejectGesture(int pointer) {
    _timer?.cancel();
    stopTrackingPointer(pointer);
  }

  @override
  void didStopTrackingLastPointer(int pointer) {
    _timer?.cancel();
    _downPosition = null;
  }

  @override
  String get debugDescription => 'CupertinoNativeTextField selection gesture';
}

/// A native single-line iOS text field backed by `UITextField`, exposing
/// customization comparable to Flutter's [TextField]/`CupertinoTextField`.
///
/// Provide a [controller] for two-way text sync, or just use [onChanged]. The
/// field fills the available width by default (like Flutter's `TextField`);
/// pass [width]/[height] to size it explicitly.
///
/// iOS only — a plain Flutter [EditableText]-free fallback renders elsewhere.
/// Multi-line input (via `UITextView`) is not covered yet.
class CupertinoNativeTextField extends StatefulWidget {
  final TextEditingController? controller;

  /// An optional Flutter [FocusNode]. It is bridged to the native field's
  /// first-responder state: focusing/unfocusing the node shows/hides the
  /// keyboard, and tapping the field focuses the node. Because of this bridge,
  /// `FocusScope.of(context).unfocus()` dismisses the native keyboard. When
  /// null, an internal node is created so `unfocus()` still works.
  final FocusNode? focusNode;
  final String? placeholder;
  final TextInputType keyboardType;
  final TextInputAction? textInputAction;
  final bool obscureText;
  final bool autocorrect;
  final bool enableSuggestions;
  final TextCapitalization textCapitalization;
  final TextAlign textAlign;
  final int? maxLength;
  final bool enabled;
  final bool readOnly;
  final bool autofocus;

  /// Text style. `fontSize`, `fontWeight`, and `color` are forwarded natively.
  final TextStyle? style;
  final Color? cursorColor;

  /// When the built-in clear (×) button appears — the same
  /// [OverlayVisibilityMode] `CupertinoTextField.clearButtonMode` takes,
  /// forwarded to UIKit's `UITextField.ViewMode`.
  final OverlayVisibilityMode clearButtonMode;

  /// Background color. Defaults to transparent (iOS default).
  final Color? backgroundColor;

  /// Corner radius of that background, drawn natively. Ignored when [glass]
  /// is set (the glass carries its own radius). A radius also gives the text
  /// the same 16pt horizontal inset the glass variant uses, so it doesn't hug
  /// the capsule's edge.
  final double? cornerRadius;

  /// Renders the field on a **Liquid Glass** background (iOS 26 `UIGlassEffect`;
  /// an ultra-thin material stands in on earlier versions). The text gets a
  /// 16pt horizontal inset inside the glass.
  ///
  /// Null (the default) renders the plain field.
  final CupertinoGlass? glass;

  /// Leading SF Symbol inside the field (native `UITextField.leftView`).
  /// SF Symbols only — Flutter widgets can't be embedded in a native control;
  /// compose with a Flutter `Row`/`Stack` for arbitrary widgets.
  final CupertinoNativeIcon? prefixIcon;

  /// Trailing SF Symbol inside the field (native `UITextField.rightView`).
  final CupertinoNativeIcon? suffixIcon;

  /// Where the (single) line of text sits within the field's height — useful
  /// with an explicit [height]. UITextField is single-line; multi-line input
  /// would use UITextView and is not covered yet.
  ///
  /// Takes the same [TextAlignVertical] as [TextField.textAlignVertical].
  /// `UIControl.contentVerticalAlignment` only has three positions, so the
  /// continuous [TextAlignVertical.y] is snapped: negative → top, positive →
  /// bottom, zero → center.
  final TextAlignVertical verticalAlignment;

  /// iOS autofill/content type hint (e.g. `'password'`, `'username'`,
  /// `'emailAddress'`, `'oneTimeCode'`, `'name'`, `'telephoneNumber'`,
  /// `'fullStreetAddress'`, `'URL'`). Passed through to `UITextContentType`.
  final String? textContentType;

  final ValueChanged<String>? onChanged;
  final ValueChanged<String>? onSubmitted;
  final VoidCallback? onEditingComplete;

  /// Called when the field gains focus (e.g. the user taps it).
  final VoidCallback? onTap;

  /// Called when a pointer taps outside the field. A common use is dismissing
  /// the keyboard: `onTapOutside: (_) => FocusScope.of(context).unfocus()`.
  final TapRegionCallback? onTapOutside;

  /// Explicit size. When null, the field fills the available width and uses its
  /// intrinsic height.
  final double? width;
  final double? height;

  /// Adopts the parent's height instead of [height]/the intrinsic one, so the
  /// native view physically resizes with its host. Used by
  /// `CupertinoSliverAppBar.search`, whose collapsing slot squeezes the
  /// capsule proportionally to the scroll. [height] remains the fallback when
  /// the parent's height is unbounded.
  final bool fillHeight;

  const CupertinoNativeTextField({
    super.key,
    this.controller,
    this.focusNode,
    this.placeholder,
    this.keyboardType = TextInputType.text,
    this.textInputAction,
    this.obscureText = false,
    this.autocorrect = true,
    this.enableSuggestions = true,
    this.textCapitalization = TextCapitalization.none,
    this.textAlign = TextAlign.start,
    this.maxLength,
    this.enabled = true,
    this.readOnly = false,
    this.autofocus = false,
    this.style,
    this.cursorColor,
    this.clearButtonMode = OverlayVisibilityMode.never,
    this.backgroundColor,
    this.cornerRadius,
    this.glass,
    this.prefixIcon,
    this.suffixIcon,
    this.verticalAlignment = TextAlignVertical.center,
    this.textContentType,
    this.onChanged,
    this.onSubmitted,
    this.onEditingComplete,
    this.onTap,
    this.onTapOutside,
    this.width,
    this.height,
    this.fillHeight = false,
  });

  @override
  State<CupertinoNativeTextField> createState() =>
      _CupertinoNativeTextFieldState();
}

class _CupertinoNativeTextFieldState extends State<CupertinoNativeTextField>
    with NativePlatformViewStateMixin, WidgetsBindingObserver {
  /// Whether the native field is showing a non-empty selection (and thus its
  /// draggable handles). Kept current by the `onSelectionActive` callback.
  bool _selectionActive = false;

  /// The APP's brightness (its Material theme), propagated to the native text
  /// field so its text color matches the app — not the device, which may be in
  /// a different mode. Re-synced dynamically when the app theme changes.
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;
  bool? _lastIsDark;

  /// Claims a press-and-hold for native text selection while ceding a quick
  /// drag to an ancestor `Scrollable`; while [_selectionActive], claims every
  /// touch so handle drags reach the native field — see
  /// [_NativeTextFieldGestureRecognizer].
  late final Set<Factory<OneSequenceGestureRecognizer>> _gestureRecognizers =
      <Factory<OneSequenceGestureRecognizer>>{
        Factory<OneSequenceGestureRecognizer>(
          () => _NativeTextFieldGestureRecognizer(
            isSelectionActive: () => _selectionActive,
          ),
        ),
      };

  /// The text native currently holds — used to break the controller<->native
  /// sync feedback loop.
  String _lastNativeText = '';

  /// The effective focus node: the caller's, or an internal one so that
  /// `FocusScope.unfocus()` and `onTapOutside` dismissal still work.
  late FocusNode _focusNode;
  bool _ownsFocusNode = false;

  @override
  void initState() {
    super.initState();
    _lastNativeText = widget.controller?.text ?? '';
    widget.controller?.addListener(_onControllerChanged);
    _focusNode = widget.focusNode ?? _createInternalFocusNode();
    WidgetsBinding.instance.addObserver(this);
  }

  /// Bottom view inset (physical px) seen at the previous metrics tick, to
  /// detect whether the keyboard is currently rising.
  double _lastBottomInset = 0;

  /// Keyboard insets changed. iOS reports this repeatedly while the keyboard
  /// animates (not just once at the end) — reacting on each *rising* tick with
  /// an instant minimal jump tracks the keyboard's real motion progressively.
  /// Falling/settled insets are deliberately ignored so keyboard dismissal and
  /// post-settle blips (autocorrect bar, emoji switch) never move the scroll.
  @override
  void didChangeMetrics() {
    final view = WidgetsBinding.instance.platformDispatcher.implicitView;
    if (view == null) return;
    final bottomInset = view.viewInsets.bottom;
    final rising = bottomInset > _lastBottomInset;
    _lastBottomInset = bottomInset;
    if (rising && _focusNode.hasFocus) _revealAboveKeyboard();
  }

  /// Scrolls the minimum needed to keep the field above the keyboard.
  /// `keepVisibleAtEnd` only ever scrolls when the field sits beyond the
  /// bottom edge of the (keyboard-shrunken) viewport — when the field is
  /// already visible it is a strict no-op, so this never repositions or
  /// fights a scroll the user did themselves. The jump is instant
  /// (`duration` zero, Flutter's default): each metrics tick already reflects
  /// the keyboard's current height, so animating would lag the next tick.
  void _revealAboveKeyboard() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !_focusNode.hasFocus) return;
      Scrollable.ensureVisible(
        context,
        alignmentPolicy: ScrollPositionAlignmentPolicy.keepVisibleAtEnd,
      );
    });
  }

  FocusNode _createInternalFocusNode() {
    _ownsFocusNode = true;
    return FocusNode(debugLabel: 'CupertinoNativeTextField');
  }

  @override
  void didUpdateWidget(covariant CupertinoNativeTextField oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller != widget.controller) {
      oldWidget.controller?.removeListener(_onControllerChanged);
      widget.controller?.addListener(_onControllerChanged);
      _lastNativeText = widget.controller?.text ?? '';
    }
    if (oldWidget.focusNode != widget.focusNode) {
      if (_ownsFocusNode) {
        _focusNode.dispose();
        _ownsFocusNode = false;
      }
      _focusNode = widget.focusNode ?? _createInternalFocusNode();
    }
    if (_configChanged(oldWidget)) {
      updateNativeView('updateTextField', _toMap());
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBrightness();
    _syncSearchRowVisibility();
  }

  void _syncBrightness() {
    final isDark = _isDark;
    if (_lastIsDark == isDark) return;
    _lastIsDark = isDark;
    channel?.invokeMethod('setBrightness', {'isDark': isDark});
  }

  /// The enclosing [CupertinoSliverAppBar]'s search-row visibility, when this
  /// field is hosted as its `searchField`. Flutter's `Opacity` can't fade a
  /// platform view's pixels, so the fade is forwarded to the native side.
  ValueListenable<double>? _searchRowVisibility;

  /// Last opacity actually sent, quantized — the scroll drives the value every
  /// frame and the channel shouldn't be spammed with sub-perceptual deltas.
  double? _lastSentOpacity;

  void _syncSearchRowVisibility() {
    final visibility = CupertinoSearchRowVisibility.maybeOf(context);
    if (identical(visibility, _searchRowVisibility)) return;
    _searchRowVisibility?.removeListener(_onSearchRowVisibilityChanged);
    _searchRowVisibility = visibility;
    visibility?.addListener(_onSearchRowVisibilityChanged);
  }

  void _onSearchRowVisibilityChanged() {
    final value = _searchRowVisibility?.value ?? 1.0;
    final quantized = (value * 20).roundToDouble() / 20;
    if (quantized == _lastSentOpacity) return;
    _lastSentOpacity = quantized;
    channel?.invokeMethod('setContentOpacity', {'opacity': quantized});
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    widget.controller?.removeListener(_onControllerChanged);
    _searchRowVisibility?.removeListener(_onSearchRowVisibilityChanged);
    if (_ownsFocusNode) _focusNode.dispose();
    super.dispose();
  }

  /// Flutter focus changed (e.g. `FocusScope.unfocus()`); mirror it to the
  /// native first responder. Native responder ops are idempotent, so this
  /// won't loop with the native `onFocusChange` callback.
  void _onFlutterFocusChange(bool hasFocus) {
    channel?.invokeMethod(hasFocus ? 'focus' : 'unfocus');
  }

  bool _configChanged(CupertinoNativeTextField o) {
    return o.placeholder != widget.placeholder ||
        o.keyboardType != widget.keyboardType ||
        o.textInputAction != widget.textInputAction ||
        o.obscureText != widget.obscureText ||
        o.autocorrect != widget.autocorrect ||
        o.enableSuggestions != widget.enableSuggestions ||
        o.textCapitalization != widget.textCapitalization ||
        o.textAlign != widget.textAlign ||
        o.maxLength != widget.maxLength ||
        o.enabled != widget.enabled ||
        o.readOnly != widget.readOnly ||
        o.style != widget.style ||
        o.cursorColor != widget.cursorColor ||
        o.clearButtonMode != widget.clearButtonMode ||
        o.textContentType != widget.textContentType ||
        o.backgroundColor != widget.backgroundColor ||
        o.cornerRadius != widget.cornerRadius ||
        o.glass != widget.glass ||
        o.prefixIcon != widget.prefixIcon ||
        o.suffixIcon != widget.suffixIcon ||
        o.verticalAlignment != widget.verticalAlignment;
  }

  /// Push programmatic controller edits to native (guarded against the echo
  /// that native change notifications would otherwise cause).
  void _onControllerChanged() {
    final text = widget.controller?.text ?? '';
    if (text != _lastNativeText) {
      _lastNativeText = text;
      channel?.invokeMethod('setText', {'text': text});
    }
  }

  Map<String, dynamic> _toMap() {
    return {
      'text': widget.controller?.text ?? '',
      'placeholder': widget.placeholder,
      'keyboardType': _keyboardTypeName(widget.keyboardType),
      'textInputAction': widget.textInputAction?.name,
      'obscureText': widget.obscureText,
      'autocorrect': widget.autocorrect,
      'enableSuggestions': widget.enableSuggestions,
      'textCapitalization': widget.textCapitalization.name,
      'textAlign': widget.textAlign.name,
      'maxLength': widget.maxLength,
      'enabled': widget.enabled,
      'readOnly': widget.readOnly,
      'autofocus': widget.autofocus,
      'fontSize': widget.style?.fontSize,
      'fontWeight': widget.style?.fontWeight?.value,
      'textColor': widget.style?.color?.toARGB32(),
      'cursorColor': widget.cursorColor?.toARGB32(),
      'clearButtonMode': clearButtonModeName(widget.clearButtonMode),
      'textContentType': widget.textContentType,
      'isDark': _isDark,
      'backgroundColor': widget.backgroundColor?.toARGB32(),
      'cornerRadius': widget.cornerRadius,
      'glass': widget.glass != null,
      'glassCornerRadius': widget.glass?.cornerRadius ?? 16,
      'glassVariant':
          (widget.glass?.variant ?? CupertinoGlassVariant.regular).name,
      'glassInteractive': widget.glass?.interactive ?? true,
      'glassTint': widget.glass?.tint?.toARGB32(),
      'prefixIcon': widget.prefixIcon?.toMap(),
      'suffixIcon': widget.suffixIcon?.toMap(),
      'verticalAlignment': verticalAlignmentName(widget.verticalAlignment),
    };
  }

  static String _keyboardTypeName(TextInputType type) {
    // TextInputType isn't an enum; its JSON name is like "TextInputType.email".
    final name = type.toJson()['name'];
    if (name is String) return name.split('.').last;
    return 'text';
  }

  Future<void> _onPlatformViewCreated(int id) async {
    setUpChannel(
      id,
      'cupertino_widgets/textfield_$id',
      onMethodCall: _handleMethodCall,
    );
    requestIntrinsicSize();
    // The view may be created mid-collapse (or already collapsed); align the
    // native content opacity with the current row visibility right away.
    if (_searchRowVisibility != null) _onSearchRowVisibilityChanged();
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    switch (call.method) {
      case 'onChanged':
        final text = (call.arguments['text'] as String?) ?? '';
        _lastNativeText = text;
        final controller = widget.controller;
        if (controller != null && controller.text != text) {
          controller.value = TextEditingValue(
            text: text,
            selection: TextSelection.collapsed(offset: text.length),
          );
        }
        widget.onChanged?.call(text);
        break;
      case 'onSubmitted':
        widget.onSubmitted?.call((call.arguments['text'] as String?) ?? '');
        break;
      case 'onEditingComplete':
        widget.onEditingComplete?.call();
        break;
      case 'onSelectionActive':
        _selectionActive = (call.arguments['active'] as bool?) ?? false;
        break;
      case 'onFocusChange':
        final focused = (call.arguments['focused'] as bool?) ?? false;
        if (focused) {
          if (!_focusNode.hasFocus) _focusNode.requestFocus();
          widget.onTap?.call();
          _revealAboveKeyboard();
        } else if (_focusNode.hasFocus) {
          _focusNode.unfocus();
        }
        break;
    }
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform == TargetPlatform.iOS) {
      final platformView = withPaintRoomFilling(wrapForTransition(UiKitView(
        viewType: 'com.example.cupertino_widgets/cupertino_native_text_field',
        layoutDirection: TextDirection.ltr,
        creationParams: _toMap(),
        creationParamsCodec: const StandardMessageCodec(),
        gestureRecognizers: _gestureRecognizers,
        onPlatformViewCreated: _onPlatformViewCreated,
      )));

      final Widget sized;
      if (widget.fillHeight) {
        // Adopt the parent's (possibly animating) box outright — the app bar's
        // collapsing search slot — so the native view really resizes with it.
        sized = widget.width == null
            ? platformView
            : SizedBox(width: widget.width, child: platformView);
      } else if (widget.width != null || widget.height != null) {
        sized = SizedBox(
          width: widget.width,
          height: widget.height ?? intrinsicHeight ?? 52,
          child: platformView,
        );
      } else {
        // Fills the width offered, like Flutter's TextField; intrinsic height.
        sized = SizedBox(height: intrinsicHeight ?? 52, child: platformView);
      }

      Widget content = sized;
      if (widget.onTapOutside != null) {
        content = TapRegion(onTapOutside: widget.onTapOutside, child: content);
      }
      // Host the focus node so `FocusScope.unfocus()` reaches the native field.
      return Focus(
        focusNode: _focusNode,
        onFocusChange: _onFlutterFocusChange,
        child: content,
      );
    }

    // Fallback for non-iOS: a plain Flutter EditableText-less placeholder.
    return SizedBox(
      width: widget.width,
      height: widget.height ?? 36,
      child: Align(
        alignment: Alignment.centerLeft,
        child: Text(
          widget.controller?.text.isNotEmpty == true
              ? widget.controller!.text
              : (widget.placeholder ?? ''),
        ),
      ),
    );
  }
}
