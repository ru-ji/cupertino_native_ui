import 'dart:convert';

import 'package:flutter/cupertino.dart' show CupertinoTheme;
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'internal/bar_slot.dart';
import 'internal/native_platform_view_mixin.dart';
import 'models/cupertino_native_icon.dart';
import 'models/cupertino_native_menu_item.dart';
import 'internal/native_color.dart';

/// The shape of one glass in a [CupertinoNativeGlassGroup].
enum CupertinoGlassGroupShape { circle, capsule, roundedRect }

/// How a glass arrives and leaves a [CupertinoNativeGlassGroup].
///
/// A transition runs when a glass is **inserted or removed**, and at no other
/// moment, so a change only animates if it changes which glasses exist, and
/// that is decided by [CupertinoNativeGlassGroupItem.actionId].
///
/// | Change | How you cause it | |
/// | --- | --- | --- |
/// | 0 → 1, 1 → 0 | flip `glassVisible` | [materialize] |
/// | 1 → 1 | give the item a new `actionId` | [matchedGeometry] |
/// | 1 → 2, 2 → 1 | replace the items with differently shaped ones | [matchedGeometry] |
///
/// [matchedGeometry] is SwiftUI's own default for glasses inside a container's
/// spacing, and it gives the departing glass and the arriving one one shape
/// that travels between them: it is what makes a merge a merge, and what lets
/// a "Select" capsule become an X circle in one piece. [materialize] matches no
/// geometry at all, the material scales in or out while the content fades,
/// which is what a glass wants when it appears where there was nothing.
enum CupertinoGlassTransition {
  /// Shapes travel into and out of each other. The default.
  matchedGeometry,

  /// The material animates in or out and the content fades; no geometry match.
  materialize,

  /// No transition: the glass appears and disappears immediately.
  identity,

  /// The material's own strength, turned up from nothing to full. Custom.
  ///
  /// Not one of SwiftUI's transitions, and the reason it exists: [materialize]
  /// *scales* the glass as it comes in, and the system's appearing button does
  /// not. What that one does reads as a gauge on the material (zero at rest,
  /// driven to full) while the content fades in place. So the glass here is
  /// never inserted or removed and nothing has a transition to run: the glass
  /// is always mounted and only the material's opacity moves.
  ///
  /// The cost of standing outside SwiftUI's transitions is that a glass on
  /// [intensity] does not merge or match geometry with its neighbours. It is
  /// for a glass that appears and disappears on its own.
  intensity,
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
    this.menuItems = const [],
  }) : assert(
         icon != null || title != null,
         'A glass with neither an icon nor a title has nothing to be shaped '
         'around.',
       );

  /// Handed back to [CupertinoNativeGlassGroup.onAction] on tap, and the
  /// glass's identity (SwiftUI's `glassEffectID`).
  ///
  /// A new [actionId] is a different glass: the old one leaves and the new
  /// one arrives in its place (a swap). The same [actionId] is the same
  /// glass wherever it sits in [CupertinoNativeGlassGroup.items], so an item
  /// inserted ahead of it does not take it over. Keep ids unique in a group.
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
  /// `null`, the default, leaves the item united with nothing, under its own
  /// identity. Give two items the same id to make them one glass, and move an
  /// item between ids to take it in and out of a union. The shapes have to
  /// match: a circle and a capsule never combine.
  ///
  /// An item that shares its id with another is drawn as a capsule whatever
  /// [shape] says. A union's frame is the whole group, and a circle is
  /// *inscribed* in the frame it is given, so a circle union collapses to one
  /// item's worth of glass in the middle with the content hanging outside it.
  /// A capsule fills the frame, which is what a merge needs; on a square item
  /// it is a circle anyway, so nothing changes for a lone glass.
  final String? unionId;

  /// Overrides [CupertinoNativeGlassGroup.transition] for this item.
  final CupertinoGlassTransition? transition;

  /// Turns this glass into a menu anchor instead of a plain button.
  ///
  /// The glass becomes the menu's own label, so the system has the capsule as
  /// its anchor and grows the menu out of it: the whole shape transforms,
  /// which is what a toolbar menu does and what presenting a popover beside
  /// the button cannot give. Taps report through the menu entries' own action
  /// ids, not the item's [actionId].
  ///
  /// Empty, the default, leaves it a button.
  final List<CupertinoNativeMenuItem> menuItems;

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
    'menuItems': menuItems.map((e) => e.toMap()).toList(),
  };
}

/// Several liquid-glass controls in ONE platform view, so they behave as one
/// piece of glass: brought close, they stretch towards each other and merge,
/// then separate again, the effect a row of separate glass buttons cannot
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
    this.mergeDistance,
    this.vertical = false,
    this.tint,
    this.clear = false,
    this.interactive = true,
    this.cornerRadius = 16,
    this.transition = CupertinoGlassTransition.matchedGeometry,
    this.morphOnChange = 0,
    this.alignment = Alignment.center,
  });

  final List<CupertinoNativeGlassGroupItem> items;

  /// Called with the tapped item's [CupertinoNativeGlassGroupItem.actionId].
  final ValueChanged<String>? onAction;

  /// Distance between the glasses. Unless [mergeDistance] overrides it, this is
  /// also how close they have to be before the container merges them by
  /// proximity.
  ///
  /// 0 renders the items as one shared glass, like a toolbar group.
  final double spacing;

  /// How close two glasses have to be before the container blends them,
  /// overriding [spacing].
  ///
  /// The gap is how far apart the items are laid out, the radius how near they
  /// must be before the container merges them by proximity anyway. With one
  /// number for both, the radius could never be set below the gap, and a
  /// union could not be tested on its own.
  ///
  /// Set it below the gap to make [CupertinoNativeGlassGroupItem.unionId] the
  /// only thing that unites two glasses. `null`, the default, inherits
  /// [spacing], which is the behaviour this widget has always had.
  final double? mergeDistance;

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

  /// How far the glass squares up as a change plays, 0…1. 0, the default,
  /// leaves the outline alone; around 0.45 reads like the system's own.
  ///
  /// A swap and a reshape both work by handing the glass a new identity, and on
  /// its own that reads as flat: the material is matched so perfectly that
  /// nothing announces the change. What the system plays there is not a bulge
  /// and not a scale: a 60fps capture of its bar button swapping an icon shows
  /// the circle *squaring up*, top and bottom edges flattening first and then
  /// the sides, before unwinding. The glass barely changes size at all.
  ///
  /// On the group rather than on one glass, because the glass that starts the
  /// change is not the one that finishes it.
  ///
  /// A number rather than a flag because how far it goes before it stops
  /// reading as a press is set by eye against the real thing, on a device.
  final double morphOnChange;

  /// Where the glasses sit in the group's box, and so which way they grow
  /// when a change makes the group wider or taller.
  ///
  /// The box takes its new size once the change has played, so the glasses
  /// should be pinned to the side the box is pinned to: a group at the end of
  /// a row wants [Alignment.centerRight], its glasses then grow leftwards and
  /// nothing jumps when the box catches up. Read when the view is created.
  final Alignment alignment;

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
    'mergeDistance': widget.mergeDistance,
    'variant': widget.clear ? 'clear' : 'regular',
    'tint': nativeArgb(widget.tint, isDark: _isDark),
    'interactive': widget.interactive,
    'vertical': widget.vertical,
    'cornerRadius': widget.cornerRadius,
    'isDark': _isDark,
    'transition': widget.transition.name,
    'morphOnChange': widget.morphOnChange,
    'alignmentX': widget.alignment.x,
    'alignmentY': widget.alignment.y,
  };

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    // In a bar, the content under the bar, as for the bar's own buttons.
    final dark =
        (BarSlot.brightnessOf(context) ??
            CupertinoTheme.brightnessOf(context)) ==
        Brightness.dark;
    if (dark != _isDark) {
      _isDark = dark;
      _sendIfChanged();
    }
  }

  @override
  void didUpdateWidget(covariant CupertinoNativeGlassGroup old) {
    super.didUpdateWidget(old);
    _sendIfChanged();
  }

  /// Sends the config unless the native side already has this exact one.
  ///
  /// Compared as JSON: one string compare instead of a field-by-field diff
  /// of the item list, and no channel message for a rebuild that changed
  /// nothing. Not re-measured from here: `getIntrinsicSize` lays the hosted
  /// view out to measure it, and forcing a layout in the middle of the morph
  /// is how the morph gets dropped.
  void _sendIfChanged() {
    final sent = jsonEncode(_toMap());
    if (sent == _sent) return;
    _sent = sent;
    updateNativeView('setConfig', _toMap());
  }

  /// What the view is created with, recorded as sent: without it the first
  /// rebuild of a group that never changed re-sent the same config.
  Map<String, dynamic>? _created;

  Map<String, dynamic> _creationParams() {
    final map = _toMap();
    _sent = jsonEncode(map);
    return map;
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
    final size = Size(
      intrinsicWidth ?? (widget.vertical ? _fallbackCross : _fallbackMain),
      intrinsicHeight ?? (widget.vertical ? _fallbackMain : _fallbackCross),
    );
    final view = wrapForTransition(
      UiKitView(
        viewType:
            'com.example.cupertino_native_ui/cupertino_native_glass_group',
        layoutDirection: TextDirection.ltr,
        creationParams: _created ??= _creationParams(),
        creationParamsCodec: const StandardMessageCodec(),
        // The taps belong to the native glasses: each one hit-tests its own
        // shape, and the arena would otherwise delay them inside a scrollable.
        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        gestureRecognizers: scrollFriendlyGestures(),
        onPlatformViewCreated: (id) => setUpChannel(
          id,
          'cupertino_native_ui/glass_group_$id',
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
    );
    return SizedBox(width: size.width, height: size.height, child: view);
  }
}
