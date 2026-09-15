import 'cupertino_native_icon.dart';

/// An entry on the leading/trailing side of a [CupertinoNativeScaffoldNavigationBar]:
/// either a single button ([CupertinoNativeBarItem]) or a group of buttons
/// sharing one glass capsule ([CupertinoNativeBarItemGroup]). Separate
/// entries render as separate capsules on iOS 26.
sealed class CupertinoNativeBarEntry {
  const CupertinoNativeBarEntry();

  Map<String, dynamic> toMap();
}

/// A single navigation-bar button. Provide an [icon], a [title], or both;
/// taps are reported through the app bar's `onAction` with [actionId].
/// The [icon] accepts an SF Symbol or a Flutter icon via [CupertinoNativeIcon].
class CupertinoNativeBarItem extends CupertinoNativeBarEntry {
  final String? title;
  final CupertinoNativeIcon? icon;
  final String actionId;

  /// Whether this item opts out of the toolbar's shared background and
  /// carries its own — SwiftUI's `.sharedBackgroundVisibility(.hidden)` on
  /// the `ToolbarItem`, iOS 26+. False (the default) leaves it in the shared
  /// capsule the system draws behind the whole toolbar.
  final bool sharedBackgroundVisibility;

  /// Whether the button takes the `.glass` style. Only applies with
  /// [sharedBackgroundVisibility]: outside the shared background an unstyled
  /// button reads as plain text, so it is on by default — turn it off for
  /// exactly that plain look. Ignored below iOS 26.
  final bool glass;

  const CupertinoNativeBarItem({
    required this.actionId,
    this.title,
    this.icon,
    this.sharedBackgroundVisibility = false,
    this.glass = true,
  }) : assert(
         title != null || icon != null,
         'Provide a title, an icon, or both',
       );

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'item',
      'title': title,
      'icon': icon?.toMap(),
      'actionId': actionId,
      'sharedBackgroundVisibility': sharedBackgroundVisibility,
      'glass': glass,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CupertinoNativeBarItem &&
        other.title == title &&
        other.icon == icon &&
        other.actionId == actionId &&
        other.sharedBackgroundVisibility == sharedBackgroundVisibility &&
        other.glass == glass;
  }

  @override
  int get hashCode =>
      Object.hash(title, icon, actionId, sharedBackgroundVisibility, glass);
}

/// Several buttons rendered inside ONE shared glass capsule (like the
/// segmented trailing buttons in iOS 26 system apps). Use separate
/// [CupertinoNativeBarItem] entries instead when each button should get its
/// own capsule.
class CupertinoNativeBarItemGroup extends CupertinoNativeBarEntry {
  final List<CupertinoNativeBarItem> items;

  /// As [CupertinoNativeBarItem.sharedBackgroundVisibility], applied to the
  /// whole group's toolbar item.
  final bool sharedBackgroundVisibility;

  const CupertinoNativeBarItemGroup({
    required this.items,
    this.sharedBackgroundVisibility = false,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'group',
      'items': items.map((e) => e.toMap()).toList(),
      'sharedBackgroundVisibility': sharedBackgroundVisibility,
    };
  }
}

/// A navigation-bar action of a [CupertinoNativeScaffoldNavigationBar] — the same thing as
/// [CupertinoNativeBarItem], under the name the native scaffold's bar is
/// usually described with.
typedef CupertinoNativeAppBarAction = CupertinoNativeBarItem;
