/// Reports a menu selection: the item's `actionId`, plus its current [value]
/// for items that carry one (a toggle's new state, for example). [value] is
/// null for plain actions.
///
/// Used by `CupertinoNativeMenu.onAction` and
/// `CupertinoNativeContextMenu.onAction`.
typedef CupertinoNativeMenuActionCallback = void Function(
  String actionId,
  Object? value,
);

/// Reports a tap on a list/form row, identified by
/// `CupertinoNativeListRow.id`.
typedef CupertinoNativeListRowCallback = void Function(String id);

/// Reports a flip of a `CupertinoNativeListRowType.toggle` row, identified by
/// `CupertinoNativeListRow.id`.
typedef CupertinoNativeListToggleCallback = void Function(
  String id,
  bool value,
);

/// Reports a bar item tap: the route the bar belongs to, and the item's
/// `actionId`. Used by `CupertinoNativeScaffold.onBarAction`.
typedef CupertinoNativeBarActionCallback = void Function(
  String route,
  String actionId,
);

/// Reports the current native navigation stack, root route first. Used by
/// `CupertinoNativeScaffold.onRouteChanged`.
typedef CupertinoNativeRouteChangedCallback = void Function(
  List<String> routes,
);

/// Reports a search field's text for the page at [route]. Used by
/// `CupertinoNativeScaffold.onSearchChanged` / `onSearchSubmitted`.
typedef CupertinoNativeSearchCallback = void Function(
  String route,
  String query,
);

/// Reports a search field becoming active/inactive (SwiftUI's `isSearching`)
/// for the page at [route].
typedef CupertinoNativeSearchActiveCallback = void Function(
  String route,
  bool active,
);
