import Foundation

/// Configuration for a scaffold page's native SwiftUI `.searchable` field.
/// Attached to an `AppBarConfig`; when present the page becomes searchable.
@available(iOS 26.0, *)
struct SearchConfig: Codable, Hashable {
    let placeholder: String?
    // "automatic" | "toolbar" | "navigationBarDrawer" | "navigationBarDrawerAlways"
    let placement: String?
    /// "automatic" | "minimize" — `.searchToolbarBehavior(...)`, for a
    /// toolbar-placed field (the iOS 26 bottom-docked search).
    let toolbarBehavior: String?
}
