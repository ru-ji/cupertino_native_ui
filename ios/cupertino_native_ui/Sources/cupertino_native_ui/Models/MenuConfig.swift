import Foundation

@available(iOS 15.0, *)
enum MenuItemType: String, Codable, Hashable {
    case action
    case submenu
    case section
    case toggle
    /// A row of compact icon buttons at the top of a menu (`ControlGroup`).
    case controlGroup
}

/// `Hashable` so that anything holding one stays hashable too: a glass group
/// item carries a menu, and the morph's trigger compares items.
///
/// Not `Identifiable`: `actionId` only routes a tap back over the channel.
/// Menus list their entries by position (`ForEach(…enumerated(), id: \.offset)`),
/// the identity SwiftUI gives views written one after another.
@available(iOS 15.0, *)
struct MenuItemConfig: Codable, Hashable {
    let type: MenuItemType
    let title: String?
    let subtitle: String?
    let systemImage: String?
    let isDestructive: Bool?
    let isDisabled: Bool?
    let actionId: String?
    let value: Bool?
    let items: [MenuItemConfig]?
}

@available(iOS 15.0, *)
struct MenuConfiguration: Codable {
    let title: String
    let systemImage: String?
    let items: [MenuItemConfig]
    let style: String?
    /// "automatic" | "capsule" | "circle" | "roundedRectangle"
    let borderShape: String?
    /// "titleAndIcon" | "titleOnly" | "iconOnly"
    let labelStyle: String?
    /// "mini" | "small" | "regular" | "large" | "extraLarge"
    let controlSize: String?
    let color: Int?
    let fontSize: Double?
    let fontWeight: Int?
    let textColor: Int?
    let isDark: Bool?
    /// A tap runs the primary action; a long press opens the menu.
    let hasPrimaryAction: Bool?
    /// `.menuOrder(.fixed)`: items stay in the given order (iOS 16+).
    let fixedOrder: Bool?
}
