import 'dart:convert';

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

/// How a glass arrives and leaves a [CupertinoNativeGlassGroup].
///
/// The four changes a group can be asked to make, and the transition each one
/// wants:
///
/// | Change | What happened | |
/// | --- | --- | --- |
/// | 0 → 1 | an item arrived | [materialize] |
/// | 1 → 0 | an item left | [materialize] |
/// | 1 → 1 | an item's `actionId` changed, so it is a different glass in the same place | [materialize] |
/// | 1 → 2, 2 → 1 | items joined or left a union | [matchedGeometry] |
///
/// [matchedGeometry] is SwiftUI's own default for glasses that sit inside the
/// container's spacing, and it is the one that makes shapes travel into and out
/// of each other — two glasses becoming one capsule, and back. [materialize]
/// fades the content in while the material animates in or out and matches no
/// geometry at all, which is what a glass wants when it appears where there was
/// nothing, or replaces another one in exactly the same spot.
enum CupertinoGlassTransition {
  /// Shapes travel into and out of each other. The default.
  matchedGeometry,

  /// The material animates in or out and the content fades; no geometry match.
  materialize,

  /// No transition — the glass appears and disappears immediately.
  identity,
}

/// One glass in a group: an icon, a title, or both.
///
/// Configuration rather than a widget: the items are laid out by SwiftUI in
/// one host, which is what lets them merge.
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
    this.glassVisible = true,
    this.unionId,
    this.transition,
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
  ///
  /// The same id is what makes a glass *replaced*: give an item a new
  /// [actionId] and SwiftUI sees a different glass where the old one stood, so
  /// the old one leaves and the new one arrives. That is the 1 → 1 case, and it
  /// wants [CupertinoGlassTransition.materialize].
  final String actionId;

  final CupertinoNativeIcon? icon;
  final String? title;
  final CupertinoGlassGroupShape shape;

  /// Defaults to a square (icon only) or to the label's own width.
  final double? width;
  final double height;
  final bool enabled;

  /// Whether this item carries a glass at all. Defaults to `true`.
  ///
  /// `false` keeps the item's slot in the group and drops only the material,
  /// which is how a glass is made to arrive from nothing: leave the item in
  /// [CupertinoNativeGlassGroup.items] and flip this. Taking the item out of
  /// the list instead would shrink the group's box underneath the transition,
  /// and the arriving glass would have nowhere to land.
  final bool glassVisible;

  /// Glasses sharing a [unionId] are drawn as one shape.
  ///
  /// `null` — the default — leaves the item united with nothing, under its own
  /// [actionId]. Give two items the same id to make them one glass, and move an
  /// item between ids to take it in and out of a union. The shapes have to
  /// match: a circle and a capsule never combine.
  final String? unionId;

  /// Overrides [CupertinoNativeGlassGroup.transition] for this item.
  final CupertinoGlassTransition? transition;

  Map<String, dynamic> toMap() => {
    'actionId': actionId,
    'icon': icon?.toMap(),
    'title': title,
    'shape': shape.name,
    'width': width,
    'height': height,
    'enabled': enabled,
    'glassVisible': glassVisible,
    'unionId': unionId,
    'transition': transition?.name,
  };
}

/// Several liquid-glass controls in ONE platform view, so they behave as one
/// piece of glass: brought close, they stretch towards each other and merge,
/// then separate again — the effect a row of separate glass buttons cannot
/// have.
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
/// Falls back to nothing at all
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
    this.transition = CupertinoGlassTransition.matchedGeometry,
  });

  final List<CupertinoNativeGlassGroupItem> items;

  /// Called with the tapped item's [CupertinoNativeGlassGroupItem.actionId].
  final ValueChanged<String>? onAction;

  /// Distance between the glasses — and, at the same time, how close they have
  /// to be before they merge. In SwiftUI it is one number
  /// (`GlassEffectContainer(spacing:)`), so it is one here: animate it and the
  /// group flows apart and back together.
  ///
  /// 0 renders the items as one shared glass, like a toolbar group.
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

  /// The default for every item that does not state its own
  /// [CupertinoNativeGlassGroupItem.transition].
  ///
  /// [CupertinoGlassTransition.matchedGeometry] is SwiftUI's own default for
  /// glasses inside a container's spacing, and it is what makes a merge a
  /// merge: the shapes travel into each other. Ask for
  /// [CupertinoGlassTransition.materialize] on a group whose glasses appear and
  /// disappear one at a time, or when a single glass is swapped for another in
  /// the same place.
  final CupertinoGlassTransition transition;

  @override
  State<CupertinoNativeGlassGroup> createState() =>
      _CupertinoNativeGlassGroupState();
}

class _CupertinoNativeGlassGroupState extends State<CupertinoNativeGlassGroup>
    with NativePlatformViewStateMixin {
  bool _isDark = false;
  String? _sent;

  Map<String, dynamic> _toMap() => {
    'items': widget.items.map((e) => e.toMap()).toList(),
    'spacing': widget.spacing,
    'variant': widget.clear ? 'clear' : 'regular',
    'tint': widget.tint?.toARGB32(),
    'interactive': widget.interactive,
    'vertical': widget.vertical,
    'cornerRadius': widget.cornerRadius,
    'isDark': _isDark,
    'transition': widget.transition.name,
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
    // Compared as JSON: one string compare instead of a field-by-field diff
    // of the item list, and no channel message for a rebuild that changed nothing.
    final sent = jsonEncode(_toMap());
    if (sent == _sent) return;
    _sent = sent;
    updateNativeView('setConfig', _toMap());
  }

  /// Total extent along the layout axis, for the box before the native
  /// measurement lands. Widths are only known here for items that state one;
  /// an icon-only glass is square, and a titled one is measured natively.
  ///
  /// Items with `glassVisible: false` still count: they keep their slot, so the
  /// box must not shrink while one of them materialises.
  double get _fallbackMain {
    final gap = widget.spacing <= 0 ? 11.0 : widget.spacing;
    var total = gap * (widget.items.length - 1).clamp(0, 999);
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
