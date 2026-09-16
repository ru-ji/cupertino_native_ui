import 'models/cupertino_native_bar_item.dart';

/// How a [CupertinoNativeScaffoldNavigationBar] title is displayed, mapped to SwiftUI's
/// `.toolbarTitleDisplayMode(...)`.
///
/// - [automatic]: inherit the surrounding context (large at a stack root,
///   inline once pushed).
/// - [inline]: always a small centered title.
/// - [inlineLarge]: an inline title rendered at the large title's size.
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

  /// In the toolbar (`.toolbar`). On iPhone this is the iOS 26 placement:
  /// the field docks at the BOTTOM of the screen in its own glass capsule,
  /// not under the title. Pair it with
  /// [CupertinoNativeSearchToolbarBehavior.minimize] to have it collapse to a
  /// magnifying-glass button when the page scrolls.
  toolbar,

  /// In a drawer below the navigation bar, revealed on scroll when space is
  /// tight (`.navigationBarDrawer(displayMode: .automatic)`).
  navigationBarDrawer,

  /// In a drawer below the navigation bar, always visible
  /// (`.navigationBarDrawer(displayMode: .always)`).
  navigationBarDrawerAlways,
}

/// How a toolbar-placed search field behaves as the page scrolls, mirroring
/// SwiftUI's `SearchToolbarBehavior`. Only meaningful with
/// [CupertinoNativeSearchPlacement.toolbar].
enum CupertinoNativeSearchToolbarBehavior {
  /// System default for the context.
  automatic,

  /// The field collapses into a single magnifying-glass button, expanding
  /// again when tapped — the Liquid Glass bottom-search behaviour.
  minimize,
}

/// Adds a native SwiftUI `.searchable(...)` search field to a
/// [CupertinoNativeScaffoldNavigationBar]. Tapping the field expands it to the top and hides
/// the title automatically (system behavior).
///
/// The suggestions, results and any loading indicator shown below the field
/// are rendered by your Flutter body: listen to
/// [CupertinoNativePageScaffold.searchState] and rebuild the body accordingly.
class CupertinoNativeSearchField {
  /// Placeholder shown in the empty field (SwiftUI `prompt`).
  final String? placeholder;

  /// Where the field is placed. Defaults to
  /// [CupertinoNativeSearchPlacement.automatic].
  final CupertinoNativeSearchPlacement placement;

  /// How a [CupertinoNativeSearchPlacement.toolbar] field reacts to scrolling.
  /// Ignored for the other placements.
  final CupertinoNativeSearchToolbarBehavior toolbarBehavior;

  const CupertinoNativeSearchField({
    this.placeholder,
    this.placement = CupertinoNativeSearchPlacement.automatic,
    this.toolbarBehavior = CupertinoNativeSearchToolbarBehavior.automatic,
  });

  /// Serialized form embedded in [CupertinoNativeScaffoldNavigationBar.toMap].
  Map<String, dynamic> toMap() {
    return {
      'placeholder': placeholder,
      'placement': placement.name,
      'toolbarBehavior': toolbarBehavior.name,
    };
  }
}

/// Navigation-bar configuration for a [CupertinoNativePageScaffold] page: the
/// title, how the title is displayed, and the leading/trailing bar items.
class CupertinoNativeScaffoldNavigationBar {
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

  /// Entries for the bottom toolbar — SwiftUI's `.bottomBar` placement, the
  /// glass bar that rides above the home indicator in Mail, Safari and Notes.
  /// Insert a [CupertinoNativeBarSpacer] to split its shared capsule.
  ///
  /// Up to 5 entries; extra ones are dropped.
  final List<CupertinoNativeBarEntry> bottom;

  /// Optional native search field attached to this page's navigation bar.
  /// When set, the page becomes `.searchable`.
  final CupertinoNativeSearchField? search;

  const CupertinoNativeScaffoldNavigationBar({
    required this.title,
    this.subtitle,
    this.titleDisplayMode = CupertinoNativeToolbarTitleDisplayMode.automatic,
    this.leading = const [],
    this.trailing = const [],
    this.bottom = const [],
    this.search,
  });

  /// Serialized form consumed by `CupertinoNativePageScaffold` to configure each
  /// page's native navigation bar.
  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'subtitle': subtitle,
      'displayMode': titleDisplayMode.name,
      'leading': leading.map((e) => e.toMap()).toList(),
      'trailing': trailing.map((e) => e.toMap()).toList(),
      'bottom': bottom.map((e) => e.toMap()).toList(),
      'search': search?.toMap(),
    };
  }
}
