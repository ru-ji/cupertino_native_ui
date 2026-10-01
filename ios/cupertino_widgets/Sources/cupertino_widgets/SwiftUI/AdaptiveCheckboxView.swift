import SwiftUI

/// The checkbox: iOS has none, so this is the selection symbol Reminders and
/// Mail use — `circle` when off, `checkmark.circle.fill` in the tint when on.
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

    // No SwiftUI checkbox on iOS (`.toggleStyle(.checkbox)` is macOS-only):
    // the system's own idiom is the Reminders / Mail selection symbol.
    private var box: some View {
        Image(systemName: isOn ? "checkmark.circle.fill" : "circle")
            .font(.system(size: 22))
            .foregroundStyle(isOn ? tint : Color(uiColor: .tertiaryLabel))
            .modifier(SymbolReplaceTransition())
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

@available(iOS 15.0, *)
extension View {
    @ViewBuilder
    func applySelectionFeedback(trigger: Bool) -> some View {
        if #available(iOS 17.0, *) {
            self.sensoryFeedback(.selection, trigger: trigger)
        } else {
            self
        }
    }
}

/// The iOS 17+ symbol swap animation; a plain cross-fade before.
@available(iOS 15.0, *)
struct SymbolReplaceTransition: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.contentTransition(.symbolEffect(.replace))
        } else {
            content
        }
    }
}
