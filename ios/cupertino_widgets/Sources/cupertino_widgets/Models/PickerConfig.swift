import Foundation

/// A SwiftUI `Picker`. The style is what makes it a different control: a
/// spinning wheel, a menu button, a segmented strip, or the Liquid Glass
/// palette row.
@available(iOS 26.0, *)
struct PickerConfig: Codable {
    let label: String?
    let items: [PickerItemConfig]
    let selectedIndex: Int
    /// "wheel" | "menu" | "segmented" | "palette" | "inline" | "navigationLink"
    let style: String?
    /// Hides the label, for a picker that carries its own context.
    let labelHidden: Bool?
    let color: Int?  // ARGB tint
    let controlSize: String?
    let isDark: Bool?
}

@available(iOS 26.0, *)
struct PickerItemConfig: Codable, Identifiable, Hashable {
    let title: String?
    let icon: IconConfig?
    /// Stable identity for the SwiftUI tag; the index in the Dart list.
    let id: Int
}
