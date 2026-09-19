import SwiftUI

/// The iOS 26-style radio button SwiftUI draws: a circle that sits quiet
/// (quaternary fill, separator ring) when off and fills with the tint — a
/// white centre dot springing in — when selected.
///
/// Driven by a `Binding`, not its own state: the standalone platform view
/// binds the value it echoes to Dart, and a native body node binds the
/// `NativeBodyModel` — so a value pushed from Dart wins either way.
@available(iOS 26.0, *)
struct AdaptiveRadioView: View {
    let config: RadioConfig
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
                        button
                    }
                } else {
                    // The 22pt circle in the 44pt touch target, centred: iOS's
                    // tap floor, whatever size Flutter gives the hosting view.
                    button
                        .frame(width: 44, height: 44)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .opacity(config.enabled == false ? 0.35 : 1)
        .disabled(config.enabled == false)
        .sensoryFeedback(.selection, trigger: isOn)
    }

    private var button: some View {
        Circle()
            .fill(isOn ? AnyShapeStyle(tint) : AnyShapeStyle(.tertiary))
            .overlay(
                Circle()
                    .stroke(
                        isOn ? AnyShapeStyle(tint) : AnyShapeStyle(.separator),
                        lineWidth: 1.5)
            )
            .frame(width: 22, height: 22)
            .overlay {
                Circle()
                    .fill(Color.white)
                    .frame(width: 9, height: 9)
                    .scaleEffect(isOn ? 1 : 0.3)
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
