/// Base class for all menu elements
abstract class CupertinoNativeMenuItem {
  const CupertinoNativeMenuItem();

  Map<String, dynamic> toMap();
}

/// A standard action button in the menu
class CupertinoNativeMenuAction extends CupertinoNativeMenuItem {
  final String title;
  final String? subtitle;
  final String? systemImage;
  final bool isDestructive;
  final bool isDisabled;
  final String actionId;

  const CupertinoNativeMenuAction({
    required this.title,
    required this.actionId,
    this.subtitle,
    this.systemImage,
    this.isDestructive = false,
    this.isDisabled = false,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'action',
      'title': title,
      'subtitle': subtitle,
      'systemImage': systemImage,
      'isDestructive': isDestructive,
      'isDisabled': isDisabled,
      'actionId': actionId,
    };
  }
}

/// A nested submenu
class CupertinoNativeSubmenu extends CupertinoNativeMenuItem {
  final String title;
  final String? systemImage;
  final List<CupertinoNativeMenuItem> items;

  const CupertinoNativeSubmenu({
    required this.title,
    required this.items,
    this.systemImage,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'submenu',
      'title': title,
      'systemImage': systemImage,
      'items': items.map((e) => e.toMap()).toList(),
    };
  }
}

/// A row of compact icon buttons at the top of a menu: SwiftUI's
/// `ControlGroup` (the Copy / Paste / Share strip of a text menu). Give each
/// action a `systemImage`; up to 3 fit, each with its title under the icon.
class CupertinoNativeMenuControlGroup extends CupertinoNativeMenuItem {
  final List<CupertinoNativeMenuAction> items;

  const CupertinoNativeMenuControlGroup({required this.items});

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'controlGroup',
      'items': items.map((e) => e.toMap()).toList(),
    };
  }
}

/// A section (grouped items)
class CupertinoNativeMenuSection extends CupertinoNativeMenuItem {
  final String? title;
  final List<CupertinoNativeMenuItem> items;

  const CupertinoNativeMenuSection({required this.items, this.title});

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'section',
      'title': title,
      'items': items.map((e) => e.toMap()).toList(),
    };
  }
}

/// A toggle item
class CupertinoNativeMenuToggle extends CupertinoNativeMenuItem {
  final String title;
  final bool value;
  final String actionId;
  final String? systemImage;

  const CupertinoNativeMenuToggle({
    required this.title,
    required this.value,
    required this.actionId,
    this.systemImage,
  });

  @override
  Map<String, dynamic> toMap() {
    return {
      'type': 'toggle',
      'title': title,
      'value': value,
      'actionId': actionId,
      'systemImage': systemImage,
    };
  }
}
