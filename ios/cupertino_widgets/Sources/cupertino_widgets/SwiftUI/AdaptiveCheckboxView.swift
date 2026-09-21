import SwiftUI

/// The iOS 26-style checkbox SwiftUI draws: a rounded square that sits quiet
/// (quaternary fill, separator stroke) when off and fills with the tint — a
/// springy white checkmark bouncing in — when on.
///
/// Driven by a `Binding`, not its own state: the standalone platform view
/// binds the value it echoes to Dart, and a native body node binds the
/// `NativeBodyModel` — so a value pushed from Dart wins either way.
@available(iOS 15.0, *)
struct AdaptiveCheckboxView: View {
    let config: CheckboxConfig
    @Binding var isOn: Bool

    var body: some View {
        // A `Button`, not a raw tap gesture: in a native list row the whole
        // row is itself a Button, and an inner Button wins the tap while a
        // TapGesture would lose it to the row.
        Button { toggle() } label: {
            Group {
                if let label = config.label {
                    HStack(spacing: 12) {
                        Text(label)
                            .font(customFont)
                            .foregroundColor(customTextColor)
                            .frame(maxWidth: .infinity, alignment: .leading)
                        box
                    }
                } else {
                    // The 22pt box in the 44pt touch target, centred: iOS's
                    // tap floor, whatever size Flutter gives the hosting view.
                    box
                        .frame(width: 44, height: 44)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(config.enabled == false ? 0.35 : 1)
        .disabled(config.enabled == false)
        .applySelectionFeedback(trigger: isOn)
    }

    private var box: some View {
        RoundedRectangle(cornerRadius: 7, style: .continuous)
            .fill(isOn ? AnyShapeStyle(tint) : AnyShapeStyle(.tertiary))
            .overlay(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .stroke(
                        isOn ? AnyShapeStyle(tint) : AnyShapeStyle(Color(uiColor: .separator)),
                        lineWidth: 1.5)
            )
            .frame(width: 22, height: 22)
            .overlay {
                Image(systemName: "checkmark")
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(.white)
                    .scaleEffect(isOn ? 1 : 0.5)
                    .opacity(isOn ? 1 : 0)
            }
    }

    private func toggle() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.65)) {
            isOn.toggle()
        }
    }

    // MARK: - Style Helpers

    var tint: Color {
        guard let val = config.color else { return .accentColor }
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
