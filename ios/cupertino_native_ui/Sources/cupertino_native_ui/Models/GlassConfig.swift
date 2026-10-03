import Foundation

/// Liquid Glass container configuration, decoded from Dart the same way every
/// other control's config is (`decodeConfig` over the creation params /
/// update arguments), see `ButtonConfig`.
@available(iOS 15.0, *)
struct GlassConfig: Codable, Equatable {
    let shape: String  // "capsule" | "circle" | "roundedRect"
    let cornerRadius: Double?
    let variant: String?  // "regular" | "clear"
    let tint: Int?  // ARGB
    let interactive: Bool?
    let pressable: Bool?
    let icon: IconConfig?
    /// Inset between the glass edge and its content, in points.
    let paddingLeft: Double?
    let paddingTop: Double?
    let paddingRight: Double?
    let paddingBottom: Double?
    /// The container's own size, when the caller asked for one. Nil hugs the
    /// content.
    let width: Double?
    let height: Double?
    /// Animate config changes on the SwiftUI side instead of snapping: Dart
    /// sends the target once and CoreAnimation interpolates, so a tint or a
    /// shape change costs one message rather than one per frame.
    let animated: Bool?
    /// Fill the box Flutter built rather than hug a native icon.
    let expand: Bool?
    /// The app's brightness, from Dart's theme, not the device's. Pins the
    /// hosted view's appearance so a light app on a dark-mode phone does not
    /// draw dark glass. See `NativeHostingView.isDark`.
    let isDark: Bool?
    /// The content under the bar, for a glass in a bar: its own appearance,
    /// which never reaches the window. See `NativeHostingView.appearanceDark`.
    let appearanceDark: Bool?
    /// The Flutter child's texts and still symbols, laid out by Flutter and
    /// drawn here, inside the glass. See `GlassLeavesView`.
    let leaves: [GlassLeaf]?
}

/// A text or a symbol from the container's Flutter child, with the frame
/// Flutter laid it out in, relative to the platform view.
struct GlassLeaf: Codable, Equatable {
    let x: Double
    let y: Double
    let width: Double
    let height: Double
    /// Explicit colour (ARGB). Nil keeps the adaptive foreground.
    let color: Int?

    let text: String?
    /// Already scaled by Flutter's text scaler.
    let fontSize: Double?
    /// Dart `FontWeight` index, 0 = w100 ... 8 = w900.
    let fontWeight: Int?
    let italic: Bool?
    let align: String?  // "leading" | "center" | "trailing"
    /// Flutter set it on one unbroken line.
    let singleLine: Bool?
    let maxLines: Int?

    let symbol: String?
    let symbolSize: Double?
    let symbolWeight: String?  // IconConfig.weight
    let symbolScale: String?  // "small" | "medium" | "large"
    let renderingMode: String?
}
