import Foundation

@available(iOS 26.0, *)
enum MenuItemType: String, Codable {
    case action
    case submenu
    case section
    case toggle
}

@available(iOS 26.0, *)
struct MenuItemConfig: Codable, Identifiable {
    var id: String { actionId ?? UUID().uuidString }
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

@available(iOS 26.0, *)
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
}
