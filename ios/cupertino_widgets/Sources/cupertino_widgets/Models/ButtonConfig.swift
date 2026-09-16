import Foundation

@available(iOS 26.0, *)
struct ButtonConfig: Codable {
    let title: String
    let icon: IconConfig?  // SF Symbol or Flutter glyph
    let style: String  // "automatic", "filled", etc.
    let color: Int?  // ARGB Int
    let controlSize: String?  // "mini", "small", "regular", "large", "extraLarge"
    let borderShape: String?  // "automatic", "capsule", "circle", "roundedRectangle"
    let labelStyle: String?  // "automatic", "iconOnly", "titleAndIcon", "titleOnly"
    let expand: Bool?
    let fontSize: Double?
    let fontWeight: Int?
    let textColor: Int?
    /// The app's brightness, from Dart's theme — not the device's. Pins the
    /// hosted view's appearance so a light app on a dark-mode phone does not
    /// draw dark controls. See `NativeHostingView.isDark`.
    let isDark: Bool?
    /// Explicit point size from Dart. Sizes the SwiftUI control itself, not
    /// just the Flutter box around it.
    let width: Double?
    let height: Double?
}
