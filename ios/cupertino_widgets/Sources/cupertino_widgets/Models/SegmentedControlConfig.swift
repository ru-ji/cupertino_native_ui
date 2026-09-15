import Foundation

struct SegmentedControlConfig: Codable {
    let items: [String]
    let selectedIndex: Int
    let color: Int?  // Tint color
    /// The app's brightness, from Dart's theme — not the device's. Pins the
    /// hosted view's appearance so a light app on a dark-mode phone does not
    /// draw dark controls. See `NativeHostingView.isDark`.
    let isDark: Bool?
    /// "menu" for a menu picker; segmented otherwise.
    var style: String? = nil
}
