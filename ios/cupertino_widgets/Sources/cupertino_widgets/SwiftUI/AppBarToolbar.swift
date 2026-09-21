import SwiftUI

/// Maps `AppBarConfig` entries to system toolbar items for scaffold pages.
/// Each entry gets its own ToolbarItem (own glass capsule on iOS 26); a
/// "group" entry renders its buttons in one HStack sharing a capsule.
/// Supports up to 4 entries per side.
@available(iOS 26.0, *)
struct AppBarToolbar: ToolbarContent {
    let config: AppBarConfig
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
        _ entries: [BarEntryConfig]?, _ placement: ToolbarItemPlacement
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
        _ entries: [BarEntryConfig]?, _ index: Int, _ placement: ToolbarItemPlacement
    ) -> some ToolbarContent {
        if let entry = entry(entries, index) {
            if entry.isSpacer {
                // Flexible pushes the two sides of the bar apart; fixed just
                // breaks the shared capsule between two groups.
                ToolbarSpacer(
                    entry.hidesSharedBackground ? .flexible : .fixed, placement: placement)
            } else if entry.hidesSharedBackground {
                ToolbarItem(placement: placement) { entryView(entry) }
                    .sharedBackgroundVisibility(.hidden)
            } else {
                ToolbarItem(placement: placement) { entryView(entry) }
            }
        }
    }

    private func entry(_ entries: [BarEntryConfig]?, _ index: Int) -> BarEntryConfig? {
        guard let entries = entries, index < entries.count else { return nil }
        return entries[index]
    }

    @ViewBuilder
    private func entryView(_ entry: BarEntryConfig) -> some View {
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
    private func barButton(_ item: BarItemConfig, ownBackground: Bool) -> some View {
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

    private func rawButton(_ item: BarItemConfig) -> some View {
        BarRawButton(item: item, onAction: onAction)
    }
}

/// One bar button: the icon, the title, or both.
@available(iOS 15.0, *)
struct BarRawButton: View {
    let item: BarItemConfig
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
struct LegacyAppBarToolbar: ToolbarContent {
    let config: AppBarConfig
    let onAction: (String) -> Void

    var body: some ToolbarContent {
        ToolbarItemGroup(placement: .navigationBarLeading) { buttons(config.leading) }
        ToolbarItemGroup(placement: .navigationBarTrailing) { buttons(config.trailing) }
        ToolbarItemGroup(placement: .bottomBar) { buttons(config.bottom) }
    }

    @ViewBuilder
    private func buttons(_ entries: [BarEntryConfig]?) -> some View {
        let items = (entries ?? []).filter { !$0.isSpacer }.flatMap { $0.groupItems }
        ForEach(items, id: \.actionId) { LegacyBarButton(item: $0, onAction: onAction) }
    }
}

/// A bar button as iOS 15–18 draws a back button: the symbol, 6pt, then the
/// title, both at 17pt. Icon-only and title-only items are the plain button.
@available(iOS 15.0, *)
private struct LegacyBarButton: View {
    let item: BarItemConfig
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
            BarRawButton(item: item, onAction: onAction)
        }
    }
}

@available(iOS 15.0, *)
extension View {
    /// Applies an optional `AppBarConfig` (title, display mode, toolbar items)
    /// to a navigation destination. No-op when `config` is nil.
    @available(iOS 15.0, *)
    @ViewBuilder
    func applyAppBar(_ config: AppBarConfig?, onAction: @escaping (String) -> Void) -> some View {
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
    fileprivate func applyToolbar(_ config: AppBarConfig, onAction: @escaping (String) -> Void)
        -> some View
    {
        if #available(iOS 26.0, *) {
            self.toolbar { AppBarToolbar(config: config, onAction: onAction) }
        } else {
            self.toolbar { LegacyAppBarToolbar(config: config, onAction: onAction) }
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
