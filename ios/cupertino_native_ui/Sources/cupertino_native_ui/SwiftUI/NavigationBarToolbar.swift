import SwiftUI

/// Maps `NavigationBarConfig` entries to system toolbar items for scaffold pages.
/// Each entry is its own ToolbarItem; consecutive items share the system's
/// glass capsule on iOS 26 until a `ToolbarSpacer` splits it. A "group" entry
/// renders its buttons in one HStack inside a single item.
/// Supports up to 4 entries per side.
@available(iOS 26.0, *)
struct NavigationBarToolbar: ToolbarContent {
    let config: NavigationBarConfig
    let onAction: (String) -> Void

    /// Split by side, because `@ToolbarContentBuilder` — like every SwiftUI
    /// result builder — tops out at 10 children per block, and the three
    /// sides together are 13.
    var body: some ToolbarContent {
        side(config.leading, .navigationBarLeading)
        side(config.trailing, .navigationBarTrailing)
        side(config.bottom, .bottomBar)
    }

    /// Up to 5 entries per side. A fixed number of slots rather than a
    /// `ForEach`: `ToolbarContent` has no such thing, so each position is its
    /// own statically-known item.
    @ToolbarContentBuilder
    private func side(
        _ entries: [ToolbarContentConfig]?, _ placement: ToolbarItemPlacement
    ) -> some ToolbarContent {
        item(entries, 0, placement)
        item(entries, 1, placement)
        item(entries, 2, placement)
        item(entries, 3, placement)
        item(entries, 4, placement)
    }

    /// One toolbar slot, in the two shapes iOS 26 offers.
    ///
    /// An entry that keeps the shared background is a plain `ToolbarItem`: the
    /// system draws one capsule behind the whole toolbar and the buttons sit
    /// in it, unstyled, the way they always have.
    ///
    /// An entry that opts out gets `.sharedBackgroundVisibility(.hidden)` and
    /// carries its own — which is why `.buttonStyle(.glass)` comes with it by
    /// default: alone outside the capsule, a bare button is indistinguishable
    /// from plain text. `glass: false` is exactly that plain look, on purpose.
    @ToolbarContentBuilder
    private func item(
        _ entries: [ToolbarContentConfig]?, _ index: Int, _ placement: ToolbarItemPlacement
    ) -> some ToolbarContent {
        if let entry = entry(entries, index) {
            if entry.isSpacer {
                // Flexible pushes the two sides of the bar apart; fixed just
                // breaks the shared capsule between two groups.
                ToolbarSpacer(
                    entry.hidesSharedBackground ? .flexible : .fixed, placement: placement)
            } else if entry.hidesSharedBackground {
                ToolbarItem(placement: resolved(placement, entry)) { entryView(entry) }
                    .sharedBackgroundVisibility(.hidden)
                    .applyVisibilityPriority(entry.visibilityPriority)
            } else {
                ToolbarItem(placement: resolved(placement, entry)) { entryView(entry) }
                    .applyVisibilityPriority(entry.visibilityPriority)
            }
        }
    }

    /// A pinned trailing entry takes `.topBarPinnedTrailing` (iOS 27+), the
    /// slot the bar never folds into its overflow menu.
    private func resolved(_ placement: ToolbarItemPlacement, _ entry: ToolbarContentConfig)
        -> ToolbarItemPlacement
    {
        #if compiler(>=6.4)
            if entry.pinned == true, #available(iOS 27.0, *) { return .topBarPinnedTrailing }
        #endif
        return placement
    }

    private func entry(_ entries: [ToolbarContentConfig]?, _ index: Int) -> ToolbarContentConfig? {
        guard let entries = entries, index < entries.count else { return nil }
        return entries[index]
    }

    @ViewBuilder
    private func entryView(_ entry: ToolbarContentConfig) -> some View {
        let items = entry.groupItems
        let ownBackground = entry.hidesSharedBackground
        if items.count > 1 {
            HStack {
                ForEach(items, id: \.actionId) { item in
                    barButton(item, ownBackground: ownBackground)
                }
            }
        } else if let item = items.first {
            barButton(item, ownBackground: ownBackground)
        }
    }

    @ViewBuilder
    private func barButton(_ item: ToolbarItemConfig, ownBackground: Bool) -> some View {
        applyGlassStyle(to: rawButton(item), enabled: item.glass != false && ownBackground)
    }

    /// `.glass` only where the item left the shared background — inside it the
    /// system already draws the material, and a second one on top of it is the
    /// double capsule.
    @ViewBuilder
    private func applyGlassStyle(to button: some View, enabled: Bool) -> some View {
        if enabled {
            button.buttonStyle(.glass)
        } else {
            button
        }
    }

    private func rawButton(_ item: ToolbarItemConfig) -> some View {
        ToolbarButton(item: item, onAction: onAction)
    }
}

/// One bar button: the icon, the title, or both.
@available(iOS 15.0, *)
struct ToolbarButton: View {
    let item: ToolbarItemConfig
    let onAction: (String) -> Void

    var body: some View {
        Button {
            onAction(item.actionId)
        } label: {
            if let icon = item.icon {
                if let title = item.title {
                    Label {
                        Text(title)
                    } icon: {
                        IconView(icon: icon)
                    }
                } else {
                    IconView(icon: icon)
                }
            } else {
                Text(item.title ?? "")
            }
        }
    }
}

/// The pre-iOS 26 bar. `ToolbarSpacer`, per-item shared backgrounds and
/// conditional toolbar content do not exist there, so this is one group per
/// side with the spacers dropped.
@available(iOS 15.0, *)
struct LegacyNavigationBarToolbar: ToolbarContent {
    let config: NavigationBarConfig
    let onAction: (String) -> Void

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarLeading) { buttons(config.leading) }
        ToolbarItemGroup(placement: .navigationBarTrailing) { buttons(config.trailing) }
        ToolbarItemGroup(placement: .bottomBar) { buttons(config.bottom) }
    }

    @ViewBuilder
    private func buttons(_ entries: [ToolbarContentConfig]?) -> some View {
        let items = (entries ?? []).filter { !$0.isSpacer }.flatMap { $0.groupItems }
        ForEach(items, id: \.actionId) { LegacyToolbarButton(item: $0, onAction: onAction) }
    }
}

/// A bar button as iOS 15–18 draws a back button: the symbol, 6pt, then the
/// title, both at 17pt. Icon-only and title-only items are the plain button.
@available(iOS 15.0, *)
private struct LegacyToolbarButton: View {
    let item: ToolbarItemConfig
    let onAction: (String) -> Void

    var body: some View {
        if let icon = item.icon, let title = item.title {
            Button {
                onAction(item.actionId)
            } label: {
                HStack(spacing: 6) {
                    IconView(icon: icon).font(.body.weight(.semibold))
                    Text(title)
                }
            }
        } else {
            ToolbarButton(item: item, onAction: onAction)
        }
    }
}

@available(iOS 15.0, *)
extension View {
    /// Applies an optional `NavigationBarConfig` (title, display mode, toolbar items)
    /// to a navigation destination. No-op when `config` is nil.
    @available(iOS 15.0, *)
    @ViewBuilder
    func applyNavigationBar(_ config: NavigationBarConfig?, onAction: @escaping (String) -> Void) -> some View {
        if let config = config {
            self
                .navigationTitle(config.title)
                .applyNavigationSubtitle(config.subtitle)
                .applyTitleDisplayMode(config.displayMode)
                .applyToolbar(config, onAction: onAction)
        } else {
            self
        }
    }

    @ViewBuilder
    fileprivate func applyToolbar(_ config: NavigationBarConfig, onAction: @escaping (String) -> Void)
        -> some View
    {
        if #available(iOS 26.0, *) {
            self.toolbar { NavigationBarToolbar(config: config, onAction: onAction) }
                .applyToolbar27(config, onAction: onAction)
        } else {
            self.toolbar { LegacyNavigationBarToolbar(config: config, onAction: onAction) }
        }
    }

    /// SwiftUI `.navigationSubtitle` — iOS 26+; no-op earlier.
    @available(iOS 15.0, *)
    @ViewBuilder
    func applyNavigationSubtitle(_ subtitle: String?) -> some View {
        if let subtitle, #available(iOS 26.0, *) {
            self.navigationSubtitle(subtitle)
        } else {
            self
        }
    }

    /// Applies the four title display modes.
    @available(iOS 15.0, *)
    @ViewBuilder
    func applyTitleDisplayMode(_ mode: String?) -> some View {
        if #available(iOS 17.0, *) {
            applyTitleDisplayMode17(mode)
        } else {
            switch mode {
            case "inline": self.navigationBarTitleDisplayMode(.inline)
            case "large": self.navigationBarTitleDisplayMode(.large)
            default: self.navigationBarTitleDisplayMode(.automatic)
            }
        }
    }

    @available(iOS 17.0, *)
    @ViewBuilder
    private func applyTitleDisplayMode17(_ mode: String?) -> some View {
        switch mode {
        case "inline": self.toolbarTitleDisplayMode(.inline)
        case "inlineLarge": self.toolbarTitleDisplayMode(.inlineLarge)
        case "large": self.toolbarTitleDisplayMode(.large)
        default: self.toolbarTitleDisplayMode(.automatic)
        }
    }
}

// MARK: - iOS 27

/// The iOS 27 toolbar APIs. Behind `compiler(>=6.4)` (Xcode 27) as well as
/// `#available`: an older SDK does not know the symbols at all.
@available(iOS 26.0, *)
extension ToolbarContent {
    @ToolbarContentBuilder
    func applyVisibilityPriority(_ priority: String?) -> some ToolbarContent {
        #if compiler(>=6.4)
            if #available(iOS 27.0, *) {
                if priority == "low" {
                    self.visibilityPriority(.low)
                } else if priority == "high" {
                    self.visibilityPriority(.high)
                } else {
                    self
                }
            } else {
                self
            }
        #else
            self
        #endif
    }
}

@available(iOS 26.0, *)
extension View {
    @ViewBuilder
    fileprivate func applyToolbar27(_ config: NavigationBarConfig, onAction: @escaping (String) -> Void)
        -> some View
    {
        #if compiler(>=6.4)
            if #available(iOS 27.0, *) {
                self
                    .toolbarOverflowMenu {
                        ForEach(config.overflow ?? [], id: \.actionId) { item in
                            ToolbarButton(item: item, onAction: onAction)
                        }
                    }
                    .toolbarMinimizationBehavior(
                        Self.minimization(config.minimizeBehavior), for: .navigationBar)
            } else {
                self
            }
        #else
            self
        #endif
    }

    #if compiler(>=6.4)
        @available(iOS 27.0, *)
        fileprivate static func minimization(_ name: String?) -> ToolbarMinimizationBehavior {
            switch name {
            case "never": .never
            case "onScrollDown": .onScrollDown
            case "onScrollUp": .onScrollUp
            default: .automatic
            }
        }
    #endif
}
