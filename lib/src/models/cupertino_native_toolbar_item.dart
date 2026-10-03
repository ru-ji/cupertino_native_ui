import 'cupertino_native_icon.dart';
import 'cupertino_symbols.dart';

/// How hard a toolbar entry holds its place when the bar runs out of room —
/// SwiftUI's `ToolbarItemVisibilityPriority` (iOS 27+; ignored earlier).
enum CupertinoNativeToolbarVisibilityPriority { automatic, low, high }

/// An entry of a [CupertinoNativeScaffoldNavigationBar]'s toolbar — SwiftUI's
/// `ToolbarContent`: a single button ([CupertinoNativeToolbarItem]), a group
/// of buttons sharing one glass capsule ([CupertinoNativeToolbarItemGroup]),
/// or a gap ([CupertinoNativeToolbarSpacer]).
///
/// Consecutive entries share ONE glass capsule, exactly like consecutive
/// SwiftUI `ToolbarItem`s; a [CupertinoNativeToolbarSpacer] between two entries
/// splits it (`ToolbarSpacer(.fixed)`), or an entry leaves it on its own with
/// `sharedBackgroundVisibility`.
sealed class CupertinoNativeToolbarContent {
  const CupertinoNativeToolbarContent();

  Map<String, dynamic> toMap();
}

/// A single toolbar button — SwiftUI's `ToolbarItem`. Provide an [icon], a [title], or both;
/// taps are reported through the app bar's `onAction` with [actionId].
/// The [icon] accepts an SF Symbol or a Flutter icon via [CupertinoNativeIcon].
class CupertinoNativeToolbarItem extends CupertinoNativeToolbarContent {
  final String? title;
  final CupertinoNativeIcon? icon;
  final String actionId;

  /// An SF Symbol name — the shorthand for
  /// `icon: CupertinoNativeIcon.named(...)`, like SwiftUI's
  /// `Button(_:systemImage:)`. [icon] wins when both are given.
  final String? systemImage;

  /// The same from the typo-safe [CupertinoSymbols] enum.
  final CupertinoSymbols? symbol;

  /// Whether this item opts out of the toolbar's shared background and
  /// carries its own — SwiftUI's `.sharedBackgroundVisibility(.hidden)` on
  /// the `ToolbarItem`, iOS 26+. False (the default) leaves it in the shared
  /// capsule the system draws behind the whole toolbar.
  final bool sharedBackgroundVisibility;

  /// Whether the button takes the `.glass` style. Only applies with
  /// [sharedBackgroundVisibility]: outside the shared background an unstyled
  /// button reads as plain text, so it is on by default — turn it off for
  /// exactly that plain look.
  final bool glass;

  /// Which entries the bar keeps visible when space runs out (iOS 27+).
  final CupertinoNativeToolbarVisibilityPriority visibilityPriority;

  /// Pins a trailing entry so it never folds into the overflow menu —
  /// `.topBarPinnedTrailing` (iOS 27+).
  final bool pinned;

  const CupertinoNativeToolbarItem({
    required this.actionId,
    this.title,
    this.icon,
    this.systemImage,
    this.symbol,
    this.sharedBackgroundVisibility = false,
    this.glass = true,
    this.visibilityPriority =
        CupertinoNativeToolbarVisibilityPriority.automatic,
    this.pinned = false,
  }) : assert(
         title != null || icon != null || systemImage != null || symbol != null,
         'Provide a title, an icon, or both',
       );

  CupertinoNativeIcon? get _icon {
    if (icon != null) return icon;
    if (symbol case final symbol?) return CupertinoNativeIcon.symbol(symbol);
    if (systemImage case final name?) return CupertinoNativeIcon.named(name);
    return null;
  }

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'item',
      'title': title,
      'icon': _icon?.toMap(),
      'actionId': actionId,
      'sharedBackgroundVisibility': sharedBackgroundVisibility,
      'glass': glass,
      'visibilityPriority': visibilityPriority.name,
      'pinned': pinned,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CupertinoNativeToolbarItem &&
        other.title == title &&
        other.icon == icon &&
        other.systemImage == systemImage &&
        other.symbol == symbol &&
        other.actionId == actionId &&
        other.sharedBackgroundVisibility == sharedBackgroundVisibility &&
        other.glass == glass &&
        other.visibilityPriority == visibilityPriority &&
        other.pinned == pinned;
  }

  @override
  int get hashCode => Object.hash(
    title,
    icon,
    systemImage,
    symbol,
    actionId,
    sharedBackgroundVisibility,
    glass,
    visibilityPriority,
    pinned,
  );
}

/// Several buttons in one toolbar item — SwiftUI's `ToolbarItemGroup`. They
/// share the capsule with their neighbours like any entry; put a
/// [CupertinoNativeToolbarSpacer] around the group to give it its own.
class CupertinoNativeToolbarItemGroup extends CupertinoNativeToolbarContent {
  final List<CupertinoNativeToolbarItem> items;

  /// As [CupertinoNativeToolbarItem.sharedBackgroundVisibility], applied to the
  /// whole group's toolbar item.
  final bool sharedBackgroundVisibility;

  /// As [CupertinoNativeToolbarItem.visibilityPriority], for the whole group.
  final CupertinoNativeToolbarVisibilityPriority visibilityPriority;

  /// As [CupertinoNativeToolbarItem.pinned], for the whole group.
  final bool pinned;

  const CupertinoNativeToolbarItemGroup({
    required this.items,
    this.sharedBackgroundVisibility = false,
    this.visibilityPriority =
        CupertinoNativeToolbarVisibilityPriority.automatic,
    this.pinned = false,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'group',
      'items': items.map((e) => e.toMap()).toList(),
      'sharedBackgroundVisibility': sharedBackgroundVisibility,
      'visibilityPriority': visibilityPriority.name,
      'pinned': pinned,
    };
  }
}

/// A gap between bar entries — SwiftUI's `ToolbarSpacer` (iOS 26).
///
/// The toolbar draws one shared glass capsule behind its items; a spacer
/// breaks it in two, so the entries on either side get their own. Mail's
/// bottom bar is the canonical use: actions on the left, compose on the
/// right, a flexible spacer between them.
class CupertinoNativeToolbarSpacer extends CupertinoNativeToolbarContent {
  /// Whether the spacer pushes the two sides as far apart as the bar allows
  /// (true, the default) or is just the fixed gap that breaks the capsule.
  final bool flexible;

  const CupertinoNativeToolbarSpacer({this.flexible = true});

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'spacer',
      // Reuses the shared-background key: on the native side a spacer has no
      // background of its own to hide, so the flag carries the flexibility.
      'sharedBackgroundVisibility': flexible,
    };
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CupertinoNativeToolbarSpacer && other.flexible == flexible);

  @override
  int get hashCode => flexible.hashCode;
}
