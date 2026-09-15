import 'models/cupertino_native_bar_item.dart';

/// How a [CupertinoNativeAppBar] title is displayed, mapped to SwiftUI's
/// `.toolbarTitleDisplayMode(...)` (iOS 17+, with a sensible fallback to
/// `.navigationBarTitleDisplayMode` below that).
///
/// - [automatic]: inherit the surrounding context (large at a stack root,
///   inline once pushed).
/// - [inline]: always a small centered title.
/// - [inlineLarge]: an inline title rendered at the large title's size
///   (iOS 17+; falls back to [large]).
/// - [large]: the collapsible large title.
enum CupertinoNativeToolbarTitleDisplayMode {
  automatic,
  inline,
  inlineLarge,
  large,
}

/// Where a [CupertinoNativeSearchField] is placed, mirroring SwiftUI's
/// `SearchFieldPlacement`.
enum CupertinoNativeSearchPlacement {
  /// System default placement for the current context.
  automatic,

  /// In the navigation bar's toolbar area (`.toolbar`).
  toolbar,

  /// In a drawer below the navigation bar, revealed on scroll when space is
  /// tight (`.navigationBarDrawer(displayMode: .automatic)`).
  navigationBarDrawer,

  /// In a drawer below the navigation bar, always visible
  /// (`.navigationBarDrawer(displayMode: .always)`).
  navigationBarDrawerAlways,
}

/// Adds a native SwiftUI `.searchable(...)` search field to a
/// [CupertinoNativeAppBar]. Tapping the field expands it to the top and hides
/// the title automatically (system behavior).
///
/// The suggestions, results and any loading indicator shown below the field
/// are rendered by your Flutter body: listen to
/// [CupertinoNativeScaffold.searchState] and rebuild the body accordingly.
class CupertinoNativeSearchField {
  /// Placeholder shown in the empty field (SwiftUI `prompt`).
  final String? placeholder;

  /// Where the field is placed. Defaults to
  /// [CupertinoNativeSearchPlacement.automatic].
  final CupertinoNativeSearchPlacement placement;

  const CupertinoNativeSearchField({
    this.placeholder,
    this.placement = CupertinoNativeSearchPlacement.automatic,
  });

  /// Serialized form embedded in [CupertinoNativeAppBar.toMap].
  Map<String, dynamic> toMap() {
    return {'placeholder': placeholder, 'placement': placement.name};
  }
}

/// Navigation-bar configuration for a [CupertinoNativeScaffold] page: the
/// title, how the title is displayed, and the leading/trailing bar items.
///
/// This is a plain immutable config object (not a widget). It is serialized and
/// handed to the native SwiftUI `NavigationStack`, which owns the actual bar —
/// there is no standalone `UINavigationBar` widget.
class CupertinoNativeAppBar {
  final String title;

  /// Secondary line under the title (SwiftUI `.navigationSubtitle`, iOS 26+;
  /// ignored on earlier versions).
  final String? subtitle;

  /// How the title is displayed. Defaults to
  /// [CupertinoNativeToolbarTitleDisplayMode.automatic].
  final CupertinoNativeToolbarTitleDisplayMode titleDisplayMode;

  /// Leading/trailing entries: [CupertinoNativeBarItem] renders its own glass
  /// capsule, [CupertinoNativeBarItemGroup] renders several buttons sharing
  /// one capsule.
  final List<CupertinoNativeBarEntry> leading;
  final List<CupertinoNativeBarEntry> trailing;

  /// Optional native search field attached to this page's navigation bar.
  /// When set, the page becomes `.searchable`.
  final CupertinoNativeSearchField? search;

  const CupertinoNativeAppBar({
    required this.title,
    this.subtitle,
    this.titleDisplayMode = CupertinoNativeToolbarTitleDisplayMode.automatic,
    this.leading = const [],
    this.trailing = const [],
    this.search,
  });

  /// Serialized form consumed by `CupertinoNativeScaffold` to configure each
  /// page's native navigation bar.
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'subtitle': subtitle,
      'displayMode': titleDisplayMode.name,
      'leading': leading.map((e) => e.toMap()).toList(),
      'trailing': trailing.map((e) => e.toMap()).toList(),
      'search': search?.toMap(),
    };
  }
}
