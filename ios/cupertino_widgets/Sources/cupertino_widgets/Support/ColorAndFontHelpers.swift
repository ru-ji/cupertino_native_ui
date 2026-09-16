import SwiftUI

@available(iOS 26.0, *)
extension Color {
    /// Decodes a Flutter ARGB32 color integer (as produced by `Color.value` on the Dart side).
    init(argb: Int) {
        let a = Double((argb >> 24) & 0xFF) / 255.0
        let r = Double((argb >> 16) & 0xFF) / 255.0
        let g = Double((argb >> 8) & 0xFF) / 255.0
        let b = Double(argb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, opacity: a)
    }
}

@available(iOS 26.0, *)
extension UIColor {
    /// Decodes a Flutter ARGB32 color integer (as produced by `Color.value` on the Dart side).
    convenience init(argb: Int) {
        let a = CGFloat((argb >> 24) & 0xFF) / 255.0
        let r = CGFloat((argb >> 16) & 0xFF) / 255.0
        let g = CGFloat((argb >> 8) & 0xFF) / 255.0
        let b = CGFloat(argb & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b, alpha: a)
    }
}

@available(iOS 26.0, *)
extension Font.Weight {
    /// Maps the Dart `FontWeight.index` (0 = w100/ultraLight ... 8 = w900/black) to a SwiftUI `Font.Weight`.
    init(weightIndex: Int) {
        switch weightIndex {
        case 0: self = .ultraLight
        case 1: self = .thin
        case 2: self = .light
        case 3: self = .regular
        case 4: self = .medium
        case 5: self = .semibold
        case 6: self = .bold
        case 7: self = .heavy
        case 8: self = .black
        default: self = .regular
        }
    }
}
