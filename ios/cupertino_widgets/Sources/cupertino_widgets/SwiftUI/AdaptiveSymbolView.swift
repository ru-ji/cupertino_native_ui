import SwiftUI

/// An SF Symbol with a `.symbolEffect` applied. The effects split in two:
/// *discrete* ones fire once per `trigger` bump, *indefinite* ones run while
/// `repeating` is true. `pulse`, `variableColor`, `wiggle`, `rotate` and
/// `breathe` can do either; `bounce` is discrete only.
@available(iOS 26.0, *)
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
        Image(systemName: config.name)
            .font(.system(size: CGFloat(config.size ?? 17), weight: fontWeight))
            .applySymbolRenderingMode(config.renderingMode)
            .applyForeground(config.color)
    }

    private var fontWeight: Font.Weight {
        guard let weight = config.weight else { return .regular }
        return Font.Weight(weightIndex: weight)
    }

    private var trigger: Int { config.trigger ?? 0 }
    private var isRepeating: Bool { config.repeating == true }

    @ViewBuilder
    private func applyEffect(_ view: some View) -> some View {
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

@available(iOS 26.0, *)
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
    fileprivate func applyForeground(_ argb: Int?) -> some View {
        if let argb = argb {
            self.foregroundStyle(Color(argb: argb))
        } else {
            self
        }
    }

    /// `.contentTransition(.symbolEffect(.replace))` — one symbol morphs into
    /// the next when the name changes.
    @ViewBuilder
    fileprivate func applyReplaceTransition(_ enabled: Bool) -> some View {
        if enabled {
            self.contentTransition(.symbolEffect(.replace))
        } else {
            self
        }
    }
}
