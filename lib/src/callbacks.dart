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
/// `CupertinoNativeListTile.id`.
typedef CupertinoNativeListTileCallback = void Function(String id);

/// Reports a flip of a `CupertinoNativeListTileType.toggle` row, identified by
/// `CupertinoNativeListTile.id`.
typedef CupertinoNativeListToggleCallback = void Function(
  String id,
  bool value,
);

/// Reports a swipe action picked on a list row: the row's
/// `CupertinoNativeListTile.id` and the action's `actionId`.
typedef CupertinoNativeListSwipeCallback = void Function(
  String rowId,
  String actionId,
);

/// Reports a row dragged to a new place in edit mode, within its section —
/// indices as `List.insert` expects them after the removal.
typedef CupertinoNativeListReorderCallback = void Function(
  int section,
  int oldIndex,
  int newIndex,
);

/// Reports a toolbar item tap: the route the bar belongs to, and the item's
/// `actionId`. Used by `CupertinoNativePageScaffold.onToolbarAction`.
typedef CupertinoNativeToolbarActionCallback = void Function(
  String route,
  String actionId,
);

/// Reports the current native navigation stack, root route first. Used by
/// `CupertinoNativePageScaffold.onRouteChanged`.
typedef CupertinoNativeRouteChangedCallback = void Function(
  List<String> routes,
);

/// Reports a search field's text for the page at [route]. Used by
/// `CupertinoNativePageScaffold.onSearchChanged` / `onSearchSubmitted`.
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
