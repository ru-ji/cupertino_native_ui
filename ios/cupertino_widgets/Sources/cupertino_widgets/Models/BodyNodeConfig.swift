import Foundation
import SwiftUI

/// One node of a scaffold's **native body** — a SwiftUI view tree described
/// from Dart instead of rendered by an embedded FlutterEngine.
///
/// The ordinary body route boots its own engine, so a native control inside it
/// goes Flutter → SwiftUI → FlutterView → SwiftUI: a platform view nested in a
/// hierarchy that was already native. A native body cuts the middle out —
/// Dart sends this tree, SwiftUI renders it, and the result is the same view
/// hierarchy you would get writing the SwiftUI by hand.
///
/// The price is that the body is no longer arbitrary Flutter: it is only what
/// this tree can describe. That is the whole trade, and it cannot be had both
/// ways.
///
/// Leaf nodes carry the same `*Config` the standalone platform views decode,
/// so a control renders identically whichever way it is reached.
@available(iOS 15.0, *)
struct BodyNodeConfig: Codable {
    /// "column" | "row" | "scroll" | "padding" | "spacer" | "divider" |
    /// "text" | "button" | "menu" | "textField" | "toggle" | "checkbox" | "radio" |
    /// "slider" | "picker" | "segmented" | "datePicker" | "progress" |
    /// "list" | "symbol" | "flutter" | "glass"
    let type: String

    /// For `type == "flutter"`: the body route to host here, registered in
    /// `maybeRun` like a scaffold body. It runs in its own engine.
    let route: String?

    /// The app's brightness, threaded down so a hosted island matches.
    let isDark: Bool?

    /// Identifies the node in the events sent back to Dart. Required for
    /// anything interactive.
    let id: String?

    let children: [BodyNodeConfig]?

    // Layout
    let spacing: Double?
    /// Cross-axis alignment: "leading" | "center" | "trailing" for a column,
    /// "top" | "center" | "bottom" for a row.
    let alignment: String?
    let padding: BodyEdgeInsets?
    /// Fixed extent for a spacer; nil makes it flexible.
    let extent: Double?
    /// `.frame(maxWidth: .infinity)` on this node.
    let expand: Bool?

    /// For `type == "scroll"`.
    let scroll: ScrollConfig?

    // Leaf payloads — exactly one is set, matching `type`.
    let text: BodyTextConfig?
    let button: ButtonConfig?
    let menu: MenuConfiguration?
    let textField: TextFieldConfig?
    let toggle: ToggleConfig?
    let checkbox: CheckboxConfig?
    let radio: RadioConfig?
    let slider: BodySliderConfig?
    let picker: PickerConfig?
    let list: ListConfig?
    let symbol: SymbolConfig?
    let glass: GlassConfig?
    let segmented: SegmentedControlConfig?
    let datePicker: DatePickerConfig?
    let progress: ProgressConfig?
}

/// A compact `DatePicker` inside a native body: the same control the
/// standalone platform view renders, driven by `DatePickerModel`.
@available(iOS 15.0, *)
struct DatePickerConfig: Codable {
    let value: Double?  // milliseconds since epoch
    let minimumDate: Double?
    let maximumDate: Double?
    let mode: String?  // "date" | "time" | "dateAndTime"
    let tint: Int?
    let isDark: Bool?
}

/// A native `ProgressView` inside a native body: determinate with `value`,
/// an indeterminate spinner without.
@available(iOS 15.0, *)
struct ProgressConfig: Codable {
    let value: Double?
    let total: Double?
    let label: String?
    let style: Int?  // 0 automatic | 1 linear | 2 circular
    let color: Int?
    let isDark: Bool?
}

@available(iOS 15.0, *)
struct BodyEdgeInsets: Codable {
    let top: Double
    let leading: Double
    let bottom: Double
    let trailing: Double
}

@available(iOS 15.0, *)
struct BodyTextConfig: Codable {
    let value: String
    /// A SwiftUI text style name: "largeTitle" | "title" | "title2" |
    /// "title3" | "headline" | "subheadline" | "body" | "callout" |
    /// "footnote" | "caption". nil = body.
    let style: String?
    let fontSize: Double?
    let fontWeight: Int?  // Flutter FontWeight.index
    let color: Int?  // ARGB
    /// "leading" | "center" | "trailing"
    let align: String?
}

/// The slider has no `Codable` config of its own — the standalone view drives
/// an observable model — so the body carries its own.
@available(iOS 15.0, *)
struct BodySliderConfig: Codable {
    let value: Double
    let min: Double
    let max: Double
    let step: Double?
    let color: Int?
    let enabled: Bool?
}

/// A scroll node's own settings.
@available(iOS 15.0, *)
struct ScrollConfig: Codable {
    /// "automatic" | "interactively" | "immediately" | "never", from Dart's
    /// `CupertinoNativeScrollDismissKeyboard`.
    let dismissKeyboard: String?

    @available(iOS 16.0, *)
    var dismissMode: ScrollDismissesKeyboardMode {
        switch dismissKeyboard {
        case "interactively": return .interactively
        case "immediately": return .immediately
        case "never": return .never
        default: return .automatic
        }
    }
}

@available(iOS 16.0, *)
extension BodyNodeConfig {
    /// The dismiss mode of the first `scroll` node in this tree, for the
    /// scaffold's own scroll view to adopt.
    var firstScrollDismissMode: ScrollDismissesKeyboardMode? {
        if type == "scroll" { return scroll?.dismissMode }
        for child in children ?? [] {
            if let mode = child.firstScrollDismissMode { return mode }
        }
        return nil
    }
}
