import Foundation

/// One glass in a group.
///
/// Configuration, not a view: this is the price of the shared host. A group's
/// children are declared as data so SwiftUI can arrange them itself, which is
/// exactly what lets them share one `GlassEffectContainer` — and sharing that
/// container is the only way two glasses ever merge.
@available(iOS 15.0, *)
struct GlassGroupItemConfig: Codable, Hashable, Identifiable {
    /// Sent back to Dart on tap, and the identity SwiftUI morphs along.
    let actionId: String
    let icon: IconConfig?
    let title: String?
    /// "circle" | "capsule" | "roundedRect"; nil = circle.
    let shape: String?
    let width: Double?
    let height: Double?
    let enabled: Bool?

    var id: String { actionId }
}

@available(iOS 15.0, *)
struct GlassGroupConfig: Codable {
    let items: [GlassGroupItemConfig]
    /// Distance between the glasses AND the radius within which the container
    /// lets them merge — one number, because in SwiftUI it is one number:
    /// `GlassEffectContainer(spacing:)` decides when two shapes are close
    /// enough to become one.
    let spacing: Double?
    /// "regular" | "clear"; nil = regular.
    let variant: String?
    /// ARGB tint mixed into every glass in the group.
    let tint: Int?
    /// Touch shimmer; nil = true.
    let interactive: Bool?
    /// Lay the glasses out vertically instead of horizontally.
    let vertical: Bool?
    /// Corner radius for `roundedRect` items; nil = 16.
    let cornerRadius: Double?
    let isDark: Bool?
}
