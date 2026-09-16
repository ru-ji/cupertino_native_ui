import Foundation

/// A single toolbar button that reports taps back to Dart via `actionId`.
@available(iOS 26.0, *)
struct BarItemConfig: Codable, Hashable {
    let title: String?
    let icon: IconConfig?
    let actionId: String
    /// `.buttonStyle(.glass)`. Only meaningful outside the shared background,
    /// where a bare button would read as plain text.
    let glass: Bool?
}

/// One bar entry: `type == "item"` is a single button (fields inline),
/// `type == "group"` is several buttons sharing one glass capsule (`items`),
/// and `type == "spacer"` is a `ToolbarSpacer` — the gap that splits the
/// shared background into separate capsules. Separate entries render as
/// separate capsules.
@available(iOS 26.0, *)
struct BarEntryConfig: Codable, Hashable {
    let type: String
    let title: String?
    let icon: IconConfig?
    let actionId: String?
    let items: [BarItemConfig]?
    /// `.sharedBackgroundVisibility(.hidden)` on this entry's `ToolbarItem`
    /// (iOS 26+): the entry leaves the toolbar's shared capsule and carries
    /// its own background.
    let sharedBackgroundVisibility: Bool?
    let glass: Bool?

    var asItem: BarItemConfig? {
        guard type == "item", let actionId = actionId else { return nil }
        return BarItemConfig(title: title, icon: icon, actionId: actionId, glass: glass)
    }

    var hidesSharedBackground: Bool { sharedBackgroundVisibility == true }

    /// A `ToolbarSpacer`, not a button. `sharedBackgroundVisibility == true`
    /// makes it flexible (pushes the sides apart); otherwise it is the fixed
    /// gap that just breaks the capsule.
    var isSpacer: Bool { type == "spacer" }

    var groupItems: [BarItemConfig] {
        if type == "group" { return items ?? [] }
        if let item = asItem { return [item] }
        return []
    }
}

/// Navigation-bar configuration shared by the standalone app bar and every
/// page of the native scaffold.
@available(iOS 26.0, *)
struct AppBarConfig: Codable, Hashable {
    let title: String
    let subtitle: String?  // .navigationSubtitle (iOS 26+)
    let displayMode: String?  // "inline" | "large"
    let leading: [BarEntryConfig]?
    let trailing: [BarEntryConfig]?
    /// Entries for the bottom toolbar (`.bottomBar`) — the glass bar that
    /// rides above the home indicator in Mail, Safari and Notes.
    let bottom: [BarEntryConfig]?
    let search: SearchConfig?
}
