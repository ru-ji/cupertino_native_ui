import CoreGraphics
import CoreText
import Flutter
import SwiftUI
import UIKit

/// A native icon, decoded from `CupertinoNativeIcon.toMap()` on the Dart side.
@available(iOS 15.0, *)
struct IconConfig: Codable, Hashable {
    let sfSymbol: String?
    let renderingMode: String?  // "monochrome" | "hierarchical" | "palette" | "multicolor"
    let size: Double?
    let color: Int?  // ARGB
    /// SF Symbol stroke weight: "light" | "medium" | "semibold" | "bold".
    let weight: String?
}

/// Renders an [IconConfig] as a SwiftUI view: an SF Symbol `Image`. Used by
/// buttons, bars and list rows so they all draw an icon the same way.
@available(iOS 15.0, *)
struct IconView: View {
    let icon: IconConfig

    var body: some View {
        if let sf = icon.sfSymbol {
            symbolBody(sf)
        } else {
            Image(systemName: "questionmark")
        }
    }

    private var iconColor: Color? {
        guard let argb = icon.color else { return nil }
        return Color(argb: argb)
    }

    private var symbolWeight: Font.Weight? {
        switch icon.weight {
        case "light": return .light
        case "medium": return .medium
        case "semibold": return .semibold
        case "bold": return .bold
        default: return nil
        }
    }

    private func symbolBody(_ name: String) -> some View {
        let base = Image(systemName: name)
        let weight = symbolWeight
        let sized: AnyView
        switch (icon.size, weight) {
        case let (size?, weight):
            sized = AnyView(base.font(.system(size: CGFloat(size), weight: weight ?? .regular)))
        case (nil, let weight?):
            sized = AnyView(base.font(.body.weight(weight)))
        default:
            sized = AnyView(base)
        }
        return applyColor(applyRenderingMode(sized))
    }

    @ViewBuilder
    private func applyRenderingMode(_ view: some View) -> some View {
        switch icon.renderingMode {
        case "hierarchical": view.symbolRenderingMode(.hierarchical)
        case "palette": view.symbolRenderingMode(.palette)
        case "multicolor": view.symbolRenderingMode(.multicolor)
        case "monochrome": view.symbolRenderingMode(.monochrome)
        default: view
        }
    }

    @ViewBuilder
    private func applyColor(_ view: some View) -> some View {
        if let color = iconColor {
            view.foregroundStyle(color)
        } else {
            view
        }
    }
}
