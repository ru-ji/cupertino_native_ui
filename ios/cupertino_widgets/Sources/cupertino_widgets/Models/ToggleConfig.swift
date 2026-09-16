import Foundation

@available(iOS 26.0, *)
struct ToggleConfig: Codable {
    let label: String?
    let value: Bool
    let color: Int?  // Tint color
    let fontSize: Double?
    let fontWeight: Int?
    let textColor: Int?
    /// The app's brightness, from Dart's theme — not the device's. Pins the
    /// hosted view's appearance so a light app on a dark-mode phone does not
    /// draw dark controls. See `NativeHostingView.isDark`.
    let isDark: Bool?
}
