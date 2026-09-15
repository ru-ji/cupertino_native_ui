import SwiftUI

@available(iOS 15.0, *)
struct AdaptiveButtonView: View {
    let config: ButtonConfig
    let onPressed: () -> Void

    var tintColor: Color? {
        guard let val = config.color else { return nil }
        return Color(argb: val)
    }

    var body: some View {

        // An explicit size has to reach the label, not just frame the button, so
        // the style's background stretches to it.
        let fills = config.expand == true || config.width != nil || config.height != nil

        let button = Button(action: onPressed) {
            if let icon = config.icon {
                applyCustomTextColor(
                    to: Label {
                        Text(config.title).font(customFont)
                    } icon: {
                        // Icon-only buttons are bar items: large image scale, like UIBarButtonItem.
                        IconView(icon: icon)
                            .imageScale(config.title.isEmpty ? .large : .medium)
                    }
                )
                .applyFill(fills, bothAxes: config.height != nil)
            } else {
                applyCustomTextColor(to: Text(config.title).font(customFont))
                    .applyFill(fills, bothAxes: config.height != nil)
            }
        }

        // Label style must be applied to the button view hierarchy to affect Label inside
        let labeledButton = button.applyLabelStyle(config.labelStyle)

        return Group {
            switch config.style {
            case "filled":
                labeledButton
                    .buttonStyle(.borderedProminent)
                    .tint(tintColor)
            case "tinted":
                labeledButton
                    .buttonStyle(.bordered)
                    .tint(tintColor)
            case "plain":
                labeledButton
                    .buttonStyle(.borderless)
                    .foregroundStyle(tintColor ?? .accentColor)
            case "glass":
                if #available(iOS 26.0, *) {
                    labeledButton.buttonStyle(.glass).tint(tintColor)
                } else {
                    // Below iOS 26: the system's bordered style.
                    labeledButton.buttonStyle(.bordered).tint(tintColor)
                }
            case "glassProminent":
                if #available(iOS 26.0, *) {
                    labeledButton.buttonStyle(.glassProminent).tint(tintColor)
                } else {
                    labeledButton.buttonStyle(.borderedProminent).tint(tintColor)
                }
            default:
                labeledButton
                    .buttonStyle(.automatic)
            }
        }
        .applyControlSize(config.controlSize)
        .applyButtonShape(config.borderShape)
        // An explicit size from Dart wins over the style's own metrics.
        .applyExplicitSize(width: config.width, height: config.height)
        // Fixed size when the engine hands over a transformed bounding box, unless
        // the button expands.
        .applyFixedSize(config.expand != true && config.width == nil && config.height == nil)
    }

    // MARK: - Text Style Helpers

    var customFont: Font? {
        if let size = config.fontSize {
            if let weightIndex = config.fontWeight {
                return .system(size: size).weight(Font.Weight(weightIndex: weightIndex))
            }
            return .system(size: size)
        }
        if let weightIndex = config.fontWeight {
            return .body.weight(Font.Weight(weightIndex: weightIndex))
        }
        return nil
    }

    var customTextColor: Color? {
        guard let val = config.textColor else { return nil }
        return Color(argb: val)
    }

    @ViewBuilder
    func applyCustomTextColor(to view: some View) -> some View {
        if let color = customTextColor {
            view.foregroundStyle(color)
        } else {
            view
        }
    }
}

// MARK: - Styles & Extensions

@available(iOS 15.0, *)
extension View {
    /// Pins the control to an explicit point size. A nil axis is left to the
    /// control's own metrics.
    @ViewBuilder
    func applyExplicitSize(width: Double?, height: Double?) -> some View {
        if width != nil || height != nil {
            self.frame(width: width.map { CGFloat($0) }, height: height.map { CGFloat($0) })
        } else {
            self
        }
    }

    /// Which halves of a `Label` the control shows. `iconOnly` is what makes a
    /// circular control possible at all: `buttonBorderShape(.circle)` only
    /// rounds a control whose content is square, so a label carrying text is
    /// laid out as a capsule whatever shape is asked for.
    @ViewBuilder
    func applyLabelStyle(_ style: String?) -> some View {
        switch style {
        case "iconOnly": self.labelStyle(.iconOnly)
        case "titleOnly": self.labelStyle(.titleOnly)
        case "titleAndIcon": self.labelStyle(.titleAndIcon)
        default: self.labelStyle(.automatic)
        }
    }

    /// SwiftUI's `ControlSize`: the control's metrics, not an explicit size.
    @ViewBuilder
    func applyControlSize(_ size: String?) -> some View {
        switch size {
        case "mini": self.controlSize(.mini)
        case "small": self.controlSize(.small)
        case "large": self.controlSize(.large)
        case "extraLarge":
            if #available(iOS 17.0, *) {
                self.controlSize(.extraLarge)
            } else {
                self.controlSize(.large)
            }
        default: self.controlSize(.regular)
        }
    }

    @ViewBuilder
    func applyButtonShape(_ shape: String?) -> some View {
        switch shape {
        case "capsule":
            self.buttonBorderShape(.capsule)
        case "roundedRectangle":
            self.buttonBorderShape(.roundedRectangle)
        case "circle":
            if #available(iOS 17.0, *) {
                self.buttonBorderShape(.circle)
            } else {
                self.buttonBorderShape(.capsule)  // Fallback
            }
        default:
            self.buttonBorderShape(.automatic)
        }
    }

    /// Lets a button's label fill the space the style offers, so the style's
    /// background stretches with it. `bothAxes` for an explicit height —
    /// `expand` alone is a width-only concept (a full-width button keeps its
    /// natural height).
    @ViewBuilder
    func applyFill(_ fill: Bool, bothAxes: Bool) -> some View {
        if fill {
            self.frame(maxWidth: .infinity, maxHeight: bothAxes ? .infinity : nil)
        } else {
            self
        }
    }

    @ViewBuilder
    func applyFixedSize(_ fixed: Bool) -> some View {
        if fixed {
            self.fixedSize()
        } else {
            self
        }
    }
}
