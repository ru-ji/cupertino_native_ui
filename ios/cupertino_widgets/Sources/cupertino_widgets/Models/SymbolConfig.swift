import Foundation

/// An animated SF Symbol. Unlike `CupertinoSymbolImage` — which rasterizes a
/// symbol into Flutter's own layer tree — this one stays a live SwiftUI
/// `Image`, because `.symbolEffect` animates the view, not the pixels.
@available(iOS 26.0, *)
struct SymbolConfig: Codable {
    let name: String
    let size: Double?
    let weight: Int?  // Flutter FontWeight.index (0 = w100 ... 8 = w900)
    let color: Int?  // ARGB
    let renderingMode: String?  // "monochrome" | "hierarchical" | "palette" | "multicolor"

    /// "bounce" | "pulse" | "variableColor" | "wiggle" | "rotate" |
    /// "breathe". Nil draws a still symbol.
    let effect: String?

    /// Discrete effects fire once each time this changes — Dart bumps it.
    let trigger: Int?

    /// Indefinite effects (pulse, variableColor, wiggle, rotate, breathe) run
    /// for as long as this is true, ignoring `trigger`.
    let repeating: Bool?

    /// `.contentTransition(.symbolEffect(.replace))`: changing `name` morphs
    /// one symbol into the other instead of cutting.
    let replaceOnChange: Bool?

    let isDark: Bool?
}
