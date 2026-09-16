import Foundation

/// Liquid Glass container configuration, decoded from Dart the same way every
/// other control's config is (`decodeConfig` over the creation params /
/// update arguments) — see `ButtonConfig`.
@available(iOS 26.0, *)
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
    /// A scaffold-style body route. When set, the container hosts a Flutter
    /// engine on that route as a SwiftUI view and applies `glassEffect` to
    /// *it* — the content is inside the glass rather than stacked over it.
    let route: String?
    /// Animate config changes on the SwiftUI side instead of snapping: Dart
    /// sends the target once and CoreAnimation interpolates, so a tint or a
    /// shape change costs one message rather than one per frame.
    let animated: Bool?
    /// Fill the box Flutter built rather than hug a native icon.
    let expand: Bool?
    /// The app's brightness, from Dart's theme — not the device's. Pins the
    /// hosted view's appearance so a light app on a dark-mode phone does not
    /// draw dark glass. See `NativeHostingView.isDark`.
    let isDark: Bool?
}
