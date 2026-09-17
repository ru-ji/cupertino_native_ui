import Flutter
import SwiftUI

/// A scaffold page body that hosts the Flutter engine inside a native
/// ScrollView. Reused for both searchable roots and pushed pages.
@available(iOS 26.0, *)
struct PageScrollBody: View {
    let engine: FlutterEngine?
    let scrollEdgeEffect: String?
    /// Native spinner while the body engine boots / renders its first frame.
    var showLoadingIndicator = false
    /// Bumped to send the scroll back to the top — the search view opens as
    /// its own thing, not at whatever offset the page was left at.
    var scrollToTopSignal = 0

    private static let topAnchor = "cupertino_widgets.page_top"

    var body: some View {
        if let engine = engine {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(spacing: 0) {
                        Color.clear
                            .frame(height: 0)
                            .id(Self.topAnchor)
                        FlutterContentView(
                            engine: engine,
                            showLoadingIndicator: showLoadingIndicator)
                            .frame(maxWidth: .infinity)
                    }
                }
                // Stays on the ScrollView itself — the edge effect is a
                // property of the scroll view, not of the reader around it.
                .applyScrollEdgeEffect(scrollEdgeEffect)
                .onChange(of: scrollToTopSignal) { _ in
                    proxy.scrollTo(Self.topAnchor, anchor: .top)
                }
            }
        } else if showLoadingIndicator {
            // Engine not yet created (lazy tab). Show a native spinner
            // while the Dart isolate boots — avoids a blank white flash.
            VStack {
                Spacer()
                ProgressView()
                Spacer()
            }
        } else {
            Color.clear
        }
    }
}

/// Root page body that also reports the `.searchable` field's active state.
///
/// `isSearching` is only delivered to a *descendant* of the view the
/// `.searchable` modifier is attached to, so this dedicated view reads it in
/// its own `body` (the searchable modifier is applied to it in `navStack`).
@available(iOS 26.0, *)
struct SearchablePageBody: View {
    @Environment(\.isSearching) private var isSearching

    let engine: FlutterEngine?
    let scrollEdgeEffect: String?
    var showLoadingIndicator = false
    let onActiveChange: (Bool) -> Void

    @State private var scrollToTopSignal = 0

    var body: some View {
        PageScrollBody(
            engine: engine,
            scrollEdgeEffect: scrollEdgeEffect,
            showLoadingIndicator: showLoadingIndicator,
            scrollToTopSignal: scrollToTopSignal)
            .onChange(of: isSearching) { newValue in
                onActiveChange(newValue)
                // Opening search shows a different body (suggestions, then
                // results); it starts at the top instead of keeping the
                // browsing offset.
                if newValue { scrollToTopSignal += 1 }
            }
    }
}

@available(iOS 26.0, *)
extension View {
    /// Applies an optional `SearchConfig` as a native `.searchable(...)` field.
    /// No-op when `config` is nil.
    @available(iOS 26.0, *)
    @ViewBuilder
    func applySearchable(
        _ config: SearchConfig?,
        text: Binding<String>,
        onSubmit: @escaping () -> Void
    ) -> some View {
        if let config = config {
            self
                .searchable(
                    text: text,
                    placement: searchFieldPlacement(config.placement),
                    prompt: config.placeholder.map { Text($0) }
                )
                .applySearchToolbarBehavior(config.toolbarBehavior)
                .onSubmit(of: .search, onSubmit)
        } else {
            self
        }
    }

    /// `.searchToolbarBehavior(.minimize)`: a toolbar-placed field collapses
    /// to a magnifying-glass button while the page scrolls.
    @available(iOS 26.0, *)
    @ViewBuilder
    func applySearchToolbarBehavior(_ raw: String?) -> some View {
        if raw == "minimize" {
            self.searchToolbarBehavior(.minimize)
        } else {
            self
        }
    }
}

/// Maps the Dart `CupertinoNativeSearchPlacement` name to SwiftUI's placement.
@available(iOS 26.0, *)
private func searchFieldPlacement(_ raw: String?) -> SearchFieldPlacement {
    switch raw {
    case "toolbar":
        return .toolbar
    case "navigationBarDrawer":
        return .navigationBarDrawer(displayMode: .automatic)
    case "navigationBarDrawerAlways":
        return .navigationBarDrawer(displayMode: .always)
    default:
        return .automatic
    }
}
