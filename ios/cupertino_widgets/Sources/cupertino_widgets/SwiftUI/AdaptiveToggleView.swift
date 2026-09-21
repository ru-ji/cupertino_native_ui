import SwiftUI

@available(iOS 15.0, *)
struct AdaptiveToggleView: View {
    let config: ToggleConfig
    let onAction: (Bool) -> Void

    @State private var isOn: Bool

    init(config: ToggleConfig, onAction: @escaping (Bool) -> Void) {
        self.config = config
        self.onAction = onAction
        _isOn = State(initialValue: config.value)
    }

    var body: some View {
        Group {
            if let label = config.label {
                Toggle(isOn: binding) {
                    Text(label)
                        .font(customFont)
                        .foregroundColor(customTextColor)
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                // fixedSize keeps the switch at the size UIKit gives it (51x31)
                // instead of stretching to whatever box Flutter hands the
                // hosting view. Stretched, the control drew past that box —
                // unclipped, so the strip spilled onto neighbouring content and
                // off the screen edge, and showed over the incoming page during
                // a route transition.
                Toggle(isOn: binding) {
                    EmptyView()
                }
                .labelsHidden()
                .fixedSize()
            }
        }
        .applyToggleStyle(tintColor)
    }

    var binding: Binding<Bool> {
        Binding(
            get: { isOn },
            set: { newValue in
                isOn = newValue
                onAction(newValue)
            }
        )
    }

    // MARK: - Style Helpers

    var tintColor: Color? {
        guard let val = config.color else { return nil }
        return Color(argb: val)
    }

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
}

@available(iOS 15.0, *)
extension View {
    @ViewBuilder
    func applyToggleStyle(_ color: Color?) -> some View {
        if let color = color {
            self.toggleStyle(SwitchToggleStyle(tint: color))
        } else {
            self.toggleStyle(SwitchToggleStyle())
        }
    }
}
