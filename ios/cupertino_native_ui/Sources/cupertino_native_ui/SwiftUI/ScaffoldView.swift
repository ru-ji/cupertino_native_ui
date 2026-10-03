import Flutter
import SwiftUI

/// The pure SwiftUI scaffold: NavigationStack (one per tab) + optional
/// TabView, with Flutter-engine bodies embedded inside native ScrollViews.
/// Because the scroll view and the navigation stack are both native, large
/// titles collapse on scroll, the tab bar can minimize (iOS 26), and pushes
/// animate with full system transitions including toolbar morphing.
@available(iOS 15.0, *)
struct ScaffoldView: View {
    @ObservedObject var model: ScaffoldModel
    let onToolbarAction: (String, String) -> Void  // (route, actionId)

    var body: some View {
        if let tabBar = model.config.tabBar {
            tabbedContent(tabBar)
                .applyTabTint(tabBar.accentColor)
                .applyTabBarMinimizeBehavior(tabBar.minimizeBehavior)
                .applyTabBottomAccessory(tabBar.accessory) { actionId in
                    onToolbarAction(model.selection, actionId)
                }
        } else {
            navStack(
                key: model.config.body ?? "", rootRoute: model.config.body ?? "",
                search: model.config.navigationBar?.search)
        }
    }

    @ViewBuilder
    private func tabbedContent(_ tabBar: TabBarConfig) -> some View {
        if #available(iOS 18.0, *) {
            tabbedContent18(tabBar)
        } else {
            // `Tab` is iOS 18; `tabItem` + `tag` is the pre-18 spelling. A
            // `search` role has no equivalent, so that tab is a plain one.
            TabView(selection: $model.selection) {
                ForEach(tabBar.tabs) { tab in
                    navStack(key: tab.id, rootRoute: tab.id, search: tab.search)
                        .tabItem {
                            Label(
                                tab.title,
                                systemImage: tab.resolvedSymbolName
                                    ?? (tab.role == "search" ? "magnifyingglass" : "circle"))
                        }
                        .tag(tab.id)
                        .badge(tab.badge.map { Text($0) })
                }
            }
        }
    }

    @available(iOS 18.0, *)
    @ViewBuilder
    private func tabbedContent18(_ tabBar: TabBarConfig) -> some View {
        TabView(selection: $model.selection) {
            ForEach(tabBar.tabs) { tab in
                if tab.role == "prominent", let prominent = Self.prominentRole {
                    Tab(
                        tab.title, systemImage: tab.resolvedSymbolName ?? "circle",
                        value: tab.id, role: prominent
                    ) {
                        navStack(key: tab.id, rootRoute: tab.id, search: tab.search)
                    }
                    .badge(tab.badge.map { Text($0) })
                } else if tab.role == "search" {
                    Tab(
                        tab.title, systemImage: tab.resolvedSymbolName ?? "magnifyingglass",
                        value: tab.id, role: .search
                    ) {
                        navStack(key: tab.id, rootRoute: tab.id, search: tab.search)
                    }
                    .badge(tab.badge.map { Text($0) })
                } else {
                    Tab(tab.title, systemImage: tab.resolvedSymbolName ?? "circle", value: tab.id) {
                        navStack(key: tab.id, rootRoute: tab.id, search: tab.search)
                    }
                    .badge(tab.badge.map { Text($0) })
                }
            }
        }
    }

    /// `TabRole.prominent` (iOS 27+); nil before, and the tab stays a plain one.
    @available(iOS 18.0, *)
    private static var prominentRole: TabRole? {
        #if compiler(>=6.4)
            if #available(iOS 27.0, *) { return .prominent }
        #endif
        return nil
    }

    private func pathBinding(_ key: String) -> Binding<[PushedRoute]> {
        Binding(
            get: { model.paths[key] ?? [] },
            set: { newValue in
                // NavigationStack syncs its binding on every view update;
                // only publish real changes or the objectWillChange->rebuild
                // loop starves the embedded Flutter views.
                if (model.paths[key] ?? []) != newValue {
                    model.paths[key] = newValue
                }
            }
        )
    }

    /// Two-way binding for a searchable page's field. Publishing on real edits
    /// also reports the keystroke (to the host isolate) and forwards it into
    /// the body engine via `model.setSearchText`.
    private func searchBinding(_ key: String) -> Binding<String> {
        Binding(
            get: { model.searchTexts[key] ?? "" },
            set: { model.setSearchText($0, for: key) }
        )
    }

    @ViewBuilder
    private func navStack(key: String, rootRoute: String, search: SearchConfig?) -> some View {
        if #available(iOS 16.0, *) {
            navStack16(key: key, rootRoute: rootRoute, search: search)
        } else {
            // No path-driven stack before iOS 16: the root page only, pushes
            // are not shown.
            NavigationView { root(rootRoute, search: search) }
        }
    }

    private func root(_ rootRoute: String, search: SearchConfig?) -> some View {
        pageRoot(rootRoute: rootRoute)
            .applyNavigationBar(model.config.navigationBar) { onToolbarAction(rootRoute, $0) }
            .applySearchable(
                search,
                text: searchBinding(rootRoute)
            ) {
                model.onSearchSubmitted?(rootRoute, model.searchTexts[rootRoute] ?? "")
            }
    }

    @available(iOS 16.0, *)
    @ViewBuilder
    private func navStack16(key: String, rootRoute: String, search: SearchConfig?) -> some View {
        NavigationStack(path: pathBinding(key)) {
            root(rootRoute, search: search)
                .navigationDestination(for: PushedRoute.self) { pushed in
                    PageScrollBody(
                        engine: model.pushedEngines[pushed.id],
                        scrollEdgeEffect: model.config.scrollEdgeEffect,
                        showLoadingIndicator: model.config.showLoadingIndicator ?? false
                    )
                    .applyPageBackground(model.config.backgroundColor)
                    .applyNavigationBar(pushed.navigationBar) { onToolbarAction(pushed.route, $0) }
                }
        }
    }

    /// The page's content: a SwiftUI tree described from Dart when the
    /// scaffold has a `nativeBody`, an embedded FlutterEngine otherwise.
    ///
    /// The two cannot be mixed: a native body IS the page, so there is no
    /// engine under it and nothing goes Flutter → SwiftUI → FlutterView →
    /// SwiftUI. That nesting is exactly what it exists to remove.
    @ViewBuilder
    private func pageRoot(rootRoute: String) -> some View {
        if model.config.nativeBody != nil {
            NativeBodyPage(
                model: model.bodyModel, scrollEdgeEffect: model.config.scrollEdgeEffect
            ) { id, value in
                model.onBodyEvent?(id, value)
            }
            .applyPageBackground(model.config.backgroundColor)
        } else {
            SearchablePageBody(
                engine: model.rootEngines[rootRoute],
                scrollEdgeEffect: model.config.scrollEdgeEffect,
                showLoadingIndicator: model.config.showLoadingIndicator ?? false,
                onActiveChange: { model.onSearchActiveChanged?(rootRoute, $0) }
            )
            .applyPageBackground(model.config.backgroundColor)
        }
    }
}

@available(iOS 15.0, *)
extension View {
    /// The scaffold's `backgroundColor`, on the page itself and under the
    /// bars too: the navigation stack paints the system background over the
    /// hosting view's, whatever the body, native or a Flutter engine.
    func applyPageBackground(_ argb: Int?) -> some View {
        background(argb.map { Color(argb: $0).ignoresSafeArea() })
    }
}

@available(iOS 15.0, *)
extension View {
    @ViewBuilder
    func applyTabTint(_ argb: Int?) -> some View {
        if let argb = argb {
            self.tint(Color(argb: argb))
        } else {
            self
        }
    }

    @ViewBuilder
    func applyScrollDismiss(_ body: BodyNodeConfig?) -> some View {
        if #available(iOS 16.0, *) {
            self.scrollDismissesKeyboard(body?.firstScrollDismissMode ?? .never)
        } else {
            self
        }
    }

    @ViewBuilder
    func applyTabBarMinimizeBehavior(_ behavior: String?) -> some View {
        if #available(iOS 26.0, *) {
            applyTabBarMinimizeBehavior26(behavior)
        } else {
            self
        }
    }

    @available(iOS 26.0, *)
    @ViewBuilder
    private func applyTabBarMinimizeBehavior26(_ behavior: String?) -> some View {
        switch behavior {
        case "onScrollDown": self.tabBarMinimizeBehavior(.onScrollDown)
        case "onScrollUp": self.tabBarMinimizeBehavior(.onScrollUp)
        case "never": self.tabBarMinimizeBehavior(.never)
        default: self.tabBarMinimizeBehavior(.automatic)
        }
    }

    /// iOS 26 Liquid Glass scroll edge effect style; no-op below 26.
    @ViewBuilder
    func applyScrollEdgeEffect(_ style: String?) -> some View {
        if #available(iOS 26.0, *) {
            applyScrollEdgeEffect26(style)
        } else {
            self
        }
    }

    @available(iOS 26.0, *)
    @ViewBuilder
    private func applyScrollEdgeEffect26(_ style: String?) -> some View {
        switch style {
        case "soft": self.scrollEdgeEffectStyle(.soft, for: .all)
        case "hard": self.scrollEdgeEffectStyle(.hard, for: .all)
        default: self
        }
    }

    /// iOS 26 tab-view bottom accessory (persistent view above the tab bar).
    /// No-op below iOS 26 or when `config` is nil.
    @ViewBuilder
    func applyTabBottomAccessory(
        _ config: TabAccessoryConfig?, onTap: @escaping (String) -> Void
    ) -> some View {
        if let config = config, #available(iOS 26.0, *) {
            self.tabViewBottomAccessory {
                TabBottomAccessoryView(config: config, onTap: onTap)
            }
        } else {
            self
        }
    }
}

/// The content of the iOS 26 tab-view bottom accessory. Reads the system
/// `tabViewBottomAccessoryPlacement` and shows its subtitle only in the
/// `.expanded` placement (in `.inline` it collapses to a single line).
@available(iOS 26.0, *)
struct TabBottomAccessoryView: View {
    let config: TabAccessoryConfig
    let onTap: (String) -> Void

    @Environment(\.tabViewBottomAccessoryPlacement) private var placement

    private var isExpanded: Bool {
        if case .expanded? = placement { return true }
        return false
    }

    var body: some View {
        Button {
            onTap(config.actionId)
        } label: {
            HStack(spacing: 12) {
                if let icon = config.icon {
                    IconView(icon: icon)
                }
                VStack(alignment: .leading, spacing: 2) {
                    Text(config.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    if isExpanded, let subtitle = config.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                Spacer(minLength: 0)
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

/// A native body as a whole page: the SwiftUI tree in the page's scroll view.
/// Shared by the scaffold and the sheet.
@available(iOS 15.0, *)
struct NativeBodyPage: View {
    @ObservedObject var model: NativeBodyModel
    let scrollEdgeEffect: String?
    let onEvent: (String, Any?) -> Void

    var body: some View {
        if model.root?.type == "photosPicker" {
            // The picker scrolls itself and fills the page (a sheet's body):
            // inside a ScrollView it would have no height at all.
            NativeBodyView(model: model, onEvent: onEvent)
        } else {
            scrollingBody
        }
    }

    private var scrollingBody: some View {
        ScrollView {
            NativeBodyView(model: model, onEvent: onEvent)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
        .applyScrollEdgeEffect(scrollEdgeEffect)
        // The body's own choice wins: this outer scroll is the one the
        // user actually drags, so a `.never` hard-written here silently
        // overrode `CupertinoNativeBody.scroll(dismissKeyboard:)`.
        .applyScrollDismiss(model.root)
    }
}
