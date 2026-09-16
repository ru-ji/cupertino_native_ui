import Foundation

@available(iOS 26.0, *)
struct TabBarConfig: Codable {
    let tabs: [TabItemConfig]
    var selection: String
    let accentColor: Int?
    let minimizeBehavior: String?  // "automatic" | "onScrollDown" | "onScrollUp" | "never"
    let accessory: TabAccessoryConfig?
}

/// iOS 26 tab-view bottom accessory (a persistent view above the tab bar, like
/// the Music mini-player). Adapts between the `.inline` and `.expanded`
/// placements the system chooses.
@available(iOS 26.0, *)
struct TabAccessoryConfig: Codable, Hashable {
    let title: String
    let subtitle: String?
    let icon: IconConfig?
    let actionId: String
}

@available(iOS 26.0, *)
struct TabItemConfig: Codable, Identifiable {
    let title: String
    let systemImage: String?
    let icon: IconConfig?
    let id: String
    let role: String?
    let search: SearchConfig?

    /// Resolved SF Symbol name: from [icon] if it's an SF Symbol, or from
    /// legacy [systemImage].
    var resolvedSymbolName: String? {
        if let sf = icon?.sfSymbol { return sf }
        return systemImage
    }
}
