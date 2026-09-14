import 'package:flutter/cupertino.dart' show CupertinoTheme;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'internal/native_platform_view_mixin.dart';
import 'models/cupertino_native_icon.dart';
import 'internal/scroll_friendly_recognizer.dart';

/// The shape of one glass in a [CupertinoNativeGlassGroup].
enum CupertinoGlassGroupShape { circle, capsule, roundedRect }

/// One glass in a group: an icon, a title, or both.
///
/// Configuration rather than a widget, and that is the trade the group makes.
/// A [CupertinoNativeGlassContainer] takes any Flutter child because it is its
/// own platform view with the child composited over it. A group's items are
/// laid out by SwiftUI inside a single host, which is precisely what lets them
/// share one `GlassEffectContainer` — so they have to be things SwiftUI can
/// build: a native icon and a label.
@immutable
class CupertinoNativeGlassGroupItem {
  const CupertinoNativeGlassGroupItem({
    required this.actionId,
    this.icon,
    this.title,
    this.shape = CupertinoGlassGroupShape.circle,
    this.width,
    this.height = 44,
    this.enabled = true,
  }) : assert(
         icon != null || title != null,
         'A glass with neither an icon nor a title has nothing to be shaped '
         'around.',
       );

  /// Handed back to [CupertinoNativeGlassGroup.onAction] on tap.
  ///
  /// It is also the item's identity for the morph: SwiftUI interpolates each
  /// glass from one layout to the next by this id, so keep it stable across
  /// rebuilds or an item will fade instead of travelling.
  final String actionId;

  final CupertinoNativeIcon? icon;
  final String? title;
  final CupertinoGlassGroupShape shape;

  /// Defaults to a square (icon only) or to the label's own width.
  final double? width;
  final double height;
  final bool enabled;

  Map<String, dynamic> toMap() => {
    'actionId': actionId,
    'icon': icon?.toMap(),
    'title': title,
    'shape': shape.name,
    'width': width,
    'height': height,
    'enabled': enabled,
  };
}

/// Several liquid-glass controls in ONE platform view, so they behave as one
/// piece of glass: brought close, they stretch towards each other and merge,
/// then separate again — the effect a row of separate glass buttons cannot
/// have.
///
/// It cannot be had any other way. `GlassEffectContainer` merges glasses that
/// live in the same SwiftUI tree, and every `CupertinoNativeGlassContainer` is
/// its own platform view — a separate tree, a separate hosting controller, a
/// separate layer. No amount of positioning from Dart makes two of them aware
/// of one another. Grouping is not an optimisation here; it is the only
/// arrangement in which the effect exists.
///
/// The second thing it buys is quieter but useful: one host is one layer, so
/// the items cannot overlap or be composited out of order the way neighbouring
/// platform views can.
///
/// ```dart
/// CupertinoNativeGlassGroup(
///   spacing: 4, // small enough that the glasses reach for each other
///   items: [
///     CupertinoNativeGlassGroupItem(
///       actionId: 'back',
///       icon: CupertinoNativeIcon.symbol(CupertinoSymbols.chevronBackward),
///     ),
///     CupertinoNativeGlassGroupItem(
///       actionId: 'forward',
///       icon: CupertinoNativeIcon.symbol(CupertinoSymbols.chevronForward),
///     ),
///   ],
///   onAction: (id) => debugPrint(id),
/// )
/// ```
///
/// Falls back to a plain material row below iOS 26, and to nothing at all
/// below iOS 16.
class CupertinoNativeGlassGroup extends StatefulWidget {
  const CupertinoNativeGlassGroup({
    super.key,
    required this.items,
    this.onAction,
    this.spacing = 8,
    this.vertical = false,
    this.tint,
    this.clear = false,
    this.interactive = true,
    this.cornerRadius = 16,
  });

  final List<CupertinoNativeGlassGroupItem> items;

  /// Called with the tapped item's [CupertinoNativeGlassGroupItem.actionId].
  final ValueChanged<String>? onAction;

  /// Distance between the glasses — and, at the same time, how close they have
  /// to be before they merge. In SwiftUI it is one number
  /// (`GlassEffectContainer(spacing:)`), so it is one here: animate it and the
  /// group flows apart and back together.
  final double spacing;

  final bool vertical;

  /// Tint mixed into every glass in the group.
  final Color? tint;

  /// The `clear` variant instead of `regular`.
  final bool clear;

  /// Touch shimmer on each glass.
  final bool interactive;

  /// Radius for items shaped [CupertinoGlassGroupShape.roundedRect].
  final double cornerRadius;

  @override
  State<CupertinoNativeGlassGroup> createState() =>
      _CupertinoNativeGlassGroupState();
}

class _CupertinoNativeGlassGroupState extends State<CupertinoNativeGlassGroup>
    with NativePlatformViewStateMixin {
  bool _isDark = false;

  Map<String, dynamic> _toMap() => {
    'items': widget.items.map((e) => e.toMap()).toList(),
    'spacing': widget.spacing,
    'variant': widget.clear ? 'clear' : 'regular',
    'tint': widget.tint?.toARGB32(),
    'interactive': widget.interactive,
    'vertical': widget.vertical,
    'cornerRadius': widget.cornerRadius,
    'isDark': _isDark,
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final dark = CupertinoTheme.brightnessOf(context) == Brightness.dark;
    if (dark != _isDark) {
      _isDark = dark;
      updateNativeView('setConfig', _toMap());
    }
  }

  @override
  void didUpdateWidget(covariant CupertinoNativeGlassGroup old) {
    super.didUpdateWidget(old);
    // Sent on every rebuild rather than diffed field by field: the item list is
    // the bulk of the payload and comparing it costs about what sending it
    // does, while a missed change is a group stuck mid-morph.
    updateNativeView('setConfig', _toMap());
  }

  /// Total extent along the layout axis, for the box before the native
  /// measurement lands. Widths are only known here for items that state one;
  /// an icon-only glass is square, and a titled one is measured natively.
  double get _fallbackMain {
    var total = widget.spacing * (widget.items.length - 1).clamp(0, 999);
    for (final item in widget.items) {
      total += widget.vertical
          ? item.height
          : (item.width ?? (item.title == null ? item.height : 96));
    }
    return total;
  }

  double get _fallbackCross => widget.items.isEmpty
      ? 0
      : widget.items.map((e) => e.height).reduce((a, b) => a > b ? a : b);

  @override
  Widget build(BuildContext context) {
    if (kIsWeb ||
        defaultTargetPlatform != TargetPlatform.iOS ||
        widget.items.isEmpty) {
      return const SizedBox.shrink();
    }
    return SizedBox(
      width:
          intrinsicWidth ?? (widget.vertical ? _fallbackCross : _fallbackMain),
      height:
          intrinsicHeight ?? (widget.vertical ? _fallbackMain : _fallbackCross),
      child: wrapForTransition(
        UiKitView(
          viewType:
              'com.example.cupertino_widgets/cupertino_native_glass_group',
          layoutDirection: TextDirection.ltr,
          creationParams: _toMap(),
          creationParamsCodec: const StandardMessageCodec(),
          // The taps belong to the native glasses: each one hit-tests its own
          // shape, and the arena would otherwise delay them inside a scrollable.
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
          gestureRecognizers: scrollFriendlyGestures,
          onPlatformViewCreated: (id) => setUpChannel(
            id,
            'cupertino_widgets/glass_group_$id',
            onMethodCall: (call) async {
              if (call.method == 'onAction') {
                final args = call.arguments as Map?;
                final id = args?['actionId'] as String?;
                if (id != null) widget.onAction?.call(id);
              }
              return null;
            },
          ),
        ),
      ),
    );
  }
}
