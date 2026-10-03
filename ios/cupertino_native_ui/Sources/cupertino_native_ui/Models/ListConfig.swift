import Foundation

/// One row of a native `List`/`Form` section. `type` selects the row rendering:
/// "label" (icon + title/subtitle + optional trailing value/chevron),
/// "toggle" (trailing switch), or "button" (tinted, tappable). Any row can
/// also carry [trailing]: lowered native nodes rendered at the row's end.
@available(iOS 15.0, *)
struct ListRowConfig: Codable {
    let id: String
    let title: String
    let subtitle: String?
    let icon: IconConfig?
    let value: String?
    let showChevron: Bool?
    let type: String?  // "label" | "toggle" | "button"
    let toggleValue: Bool?
    let enabled: Bool?
    /// Trailing checkmark of a selection row.
    let selected: Bool?
    /// False when no `onRowTap` listens: the plain row is then no `Button`.
    /// Nil (body lists, which always report taps) keeps it tappable.
    let tappable: Bool?
    /// A lowered `CupertinoNativeListTile.trailing`: native nodes (switch,
    /// slider, button, picker, …) rendered in the row by SwiftUI.
    let trailing: [BodyNodeConfig]?
    /// `.badge` text; nil for none.
    let badge: String?
    /// `.swipeActions` buttons (menu "action" items), first = full swipe.
    let swipeActions: [MenuItemConfig]?
    /// Nested rows: the row expands them as real rows beneath it.
    let children: [ListRowConfig]?
}

/// A `Section` of a native `List`/`Form`: optional header/footer + rows.
@available(iOS 15.0, *)
struct ListSectionConfig: Codable {
    let header: String?
    let footer: String?
    let rows: [ListRowConfig]
    /// Horizontal inset of the section card (inset-grouped/sidebar only).
    let cardInset: Double?
    /// Padding inside each row. Nil: SwiftUI decides the row's own padding.
    let rowPadding: EdgeInsetsDTO?
    /// Gap between sections in the stack.
    let sectionSpacing: Double?
    /// Top+bottom padding around the entire sections stack.
    let stackPadding: Double?
    /// Minimum row height.
    let minHeight: Double?
}

/// Codable DTO for row padding insets.
@available(iOS 15.0, *)
struct EdgeInsetsDTO: Codable {
    let left: Double?
    let top: Double?
    let right: Double?
    let bottom: Double?
}

/// Creation/update parameters for the native list/form platform view.
@available(iOS 15.0, *)
struct ListConfig: Codable {
    let variant: String?  // "list" | "form"
    let style: String?    // "automatic" | "plain" | "grouped" | "insetGrouped" | "sidebar"
    let scrollable: Bool?
    let isDark: Bool?
    let cornerRadius: Double?  // inset-grouped card radius; nil = default (26 on iOS 26+, else 10)
    let tint: Int?        // ARGB accent color
    let sections: [ListSectionConfig]
    /// Edit mode: the system selection circles at each row's leading edge.
    let editing: Bool?
    /// Ids of the rows checked in edit mode.
    let selection: [String]?
    /// Rows get the system reorder handles in edit mode (`.onMove`).
    let reorderable: Bool?
}
