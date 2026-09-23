import Foundation

/// One glass in a group.
///
/// Configuration, not a view: this is the price of the shared host. A group's
/// children are declared as data so SwiftUI can arrange them itself, which is
/// exactly what lets them share one `GlassEffectContainer` — and sharing that
/// container is the only way two glasses ever merge.
@available(iOS 15.0, *)
struct GlassGroupItemConfig: Codable, Hashable, Identifiable {
    /// Sent back to Dart on tap.
    let actionId: String
    /// The identity SwiftUI morphs along. nil = `actionId`.
    ///
    /// Split from `actionId` because a toggle button (add ↔ remove, select ↔
    /// done) wants ONE continuous glass whose *payload* changes, not a glass
    /// that gets torn down and replaced every tap — replacing it mid-flight is
    /// what let a tap land on the outgoing view's gesture and fire the old
    /// action, snapping the state back. Give both states the same `slotId` to
    /// keep it one view; leave it unset for the old "different id = different
    /// glass" replace behaviour.
    let slotId: String?
    let icon: IconConfig?
    let title: String?
    /// "circle" | "capsule" | "roundedRect"; nil = circle.
    let shape: String?
    let width: Double?
    let height: Double?
    let enabled: Bool?
    /// `false` keeps the item's slot in the layout but gives it no glass, so a
    /// glass can materialise in or out without the group's box changing size.
    /// nil = true.
    let glassVisible: Bool?
    /// Joins this glass to every other item carrying the same id, making them
    /// one shape (`glassEffectUnion`). nil = the item's own `actionId`, i.e.
    /// united with nothing.
    let unionId: String?
    /// "matchedGeometry" | "materialize" | "identity"; nil = the group's.
    let transition: String?
    /// Turns this glass into a menu anchor: the capsule itself is what the
    /// system morphs open, so the menu grows out of the glass rather than
    /// appearing beside it. nil or empty = a plain button.
    let menuItems: [MenuItemConfig]?

    var id: String { slotId ?? actionId }
}

@available(iOS 15.0, *)
struct GlassGroupConfig: Codable {
    let items: [GlassGroupItemConfig]
    /// Distance between the glasses, and — unless `mergeDistance` says
    /// otherwise — the radius within which the container lets them merge.
    /// 0 or less is the old "one shared glass" mode.
    let spacing: Double?
    /// How close two glasses have to be before the *container* blends them,
    /// which is not the same question as how far apart they are laid out.
    ///
    /// SwiftUI takes both — the container's `spacing` is the radius, the
    /// stack's own spacing is the gap — and this widget used to pass one
    /// number for both, so the radius could never be set below the gap and a
    /// union could not be tested on its own. nil = the gap, the old behaviour.
    let mergeDistance: Double?
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
    /// Default for every item that does not state its own; nil = matchedGeometry.
    let transition: String?
    /// How far the glass squares up as a change plays, 0…1. nil or 0 = never.
    let morphOnChange: Double?
}
