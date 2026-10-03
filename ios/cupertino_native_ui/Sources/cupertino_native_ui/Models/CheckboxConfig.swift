import Foundation

@available(iOS 15.0, *)
struct CheckboxConfig: Codable {
    let value: Bool
    let label: String?
    let color: Int?  // Checked fill; nil uses the system accent
    let fontSize: Double?
    let fontWeight: Int?
    let textColor: Int?
    /// Whether the box takes taps. Mirrors Dart's `onChanged == nil`.
    let enabled: Bool?
    /// The app's brightness, from Dart's theme — not the device's. Pins the
    /// hosted view's appearance so a light app on a dark-mode phone does not
    /// draw dark controls. See `NativeHostingView.isDark`.
    let isDark: Bool?
}
