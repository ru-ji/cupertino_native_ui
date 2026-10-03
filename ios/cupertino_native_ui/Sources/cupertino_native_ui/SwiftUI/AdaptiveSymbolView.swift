import SwiftUI

/// An SF Symbol with a `.symbolEffect` applied. The effects split in two:
/// *discrete* ones fire once per `trigger` bump, *indefinite* ones run while
/// `repeating` is true. `pulse`, `variableColor`, `wiggle`, `rotate` and
/// `breathe` can do either; `bounce` is discrete only.
@available(iOS 15.0, *)
struct AdaptiveSymbolView: View {
    @ObservedObject var model: SymbolModel

    private var config: SymbolConfig { model.config }

    var body: some View {
        applyEffect(styled)
            .applyReplaceTransition(config.replaceOnChange == true)
            // The symbol name is the identity the replace transition animates
            // between; without it SwiftUI reuses the view and cuts.
            .id(config.replaceOnChange == true ? "" : config.name)
    }

    private var styled: some View {
        image
            .font(.system(size: CGFloat(config.size ?? 17), weight: fontWeight))
            .applySymbolRenderingMode(config.renderingMode)
            .applyForeground(config.color, palette: config.paletteColors ?? [])
            .applyGradient(config.gradient == true)
    }

    private var image: Image {
        if let value = config.variableValue, #available(iOS 16.0, *) {
            return Image(systemName: config.name, variableValue: value)
        }
        return Image(systemName: config.name)
    }

    private var fontWeight: Font.Weight {
        guard let weight = config.weight else { return .regular }
        return Font.Weight(weightIndex: weight)
    }

    private var trigger: Int { config.trigger ?? 0 }
    private var isRepeating: Bool { config.repeating == true }

    @ViewBuilder
    private func applyEffect(_ view: some View) -> some View {
        if #available(iOS 18.0, *) {
            applyEffect18(view)
        } else if #available(iOS 17.0, *) {
            switch config.effect {
            case "bounce": view.symbolEffect(.bounce, value: trigger)
            case "pulse": view.symbolEffect(.pulse, value: trigger)
            default: view
            }
        } else {
            view
        }
    }

    @available(iOS 18.0, *)
    @ViewBuilder
    private func applyEffect18(_ view: some View) -> some View {
        switch config.effect {
        case "bounce":
            view.symbolEffect(.bounce, value: trigger)
        case "pulse":
            if isRepeating {
                view.symbolEffect(.pulse, options: .repeat(.continuous), isActive: true)
            } else {
                view.symbolEffect(.pulse, value: trigger)
            }
        case "variableColor":
            // Iterative: one layer at a time, the Wi-Fi/cellular look.
            view.symbolEffect(
                .variableColor.iterative, options: .repeat(.continuous), isActive: isRepeating)
        case "wiggle":
            if isRepeating {
                view.symbolEffect(.wiggle, options: .repeat(.continuous), isActive: true)
            } else {
                view.symbolEffect(.wiggle, value: trigger)
            }
        case "rotate":
            if isRepeating {
                view.symbolEffect(.rotate, options: .repeat(.continuous), isActive: true)
            } else {
                view.symbolEffect(.rotate, value: trigger)
            }
        case "breathe":
            if isRepeating {
                view.symbolEffect(.breathe, options: .repeat(.continuous), isActive: true)
            } else {
                view.symbolEffect(.breathe, value: trigger)
            }
        default:
            view
        }
    }
}

@available(iOS 15.0, *)
extension View {
    @ViewBuilder
    fileprivate func applySymbolRenderingMode(_ mode: String?) -> some View {
        switch mode {
        case "hierarchical": self.symbolRenderingMode(.hierarchical)
        case "palette": self.symbolRenderingMode(.palette)
        case "multicolor": self.symbolRenderingMode(.multicolor)
        case "monochrome": self.symbolRenderingMode(.monochrome)
        default: self
        }
    }

    @ViewBuilder
    fileprivate func applyForeground(_ argb: Int?, palette: [Int]) -> some View {
        let colors = palette.map { Color(argb: $0) }
        if colors.count >= 3 {
            self.foregroundStyle(colors[0], colors[1], colors[2])
        } else if colors.count == 2 {
            self.foregroundStyle(colors[0], colors[1])
        } else if let argb = argb {
            self.foregroundStyle(Color(argb: argb))
        } else {
            self
        }
    }

    /// `.contentTransition(.symbolEffect(.replace))`: one symbol morphs into
    /// the next when the name changes.
    @ViewBuilder
    fileprivate func applyReplaceTransition(_ enabled: Bool) -> some View {
        if enabled, #available(iOS 17.0, *) {
            self.contentTransition(.symbolEffect(.replace))
        } else {
            self
        }
    }
}

@available(iOS 15.0, *)
extension View {
    /// `.symbolColorRenderingMode(.gradient)`: iOS 26+; flat colour before.
    @ViewBuilder
    fileprivate func applyGradient(_ enabled: Bool) -> some View {
        if enabled, #available(iOS 26.0, *) {
            self.symbolColorRenderingMode(.gradient)
        } else {
            self
        }
    }
}
