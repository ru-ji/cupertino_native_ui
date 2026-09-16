import SwiftUI

@available(iOS 26.0, *)
struct AdaptiveSegmentedControlView: View {
    let config: SegmentedControlConfig
    let onAction: (Int) -> Void

    @State private var selectedIndex: Int

    init(config: SegmentedControlConfig, onAction: @escaping (Int) -> Void) {
        self.config = config
        self.onAction = onAction
        _selectedIndex = State(initialValue: config.selectedIndex)
    }

    @ViewBuilder
    var body: some View {
        if config.style == "menu" {
            picker.pickerStyle(.menu).tint(tintColor)
        } else {
            picker.pickerStyle(.segmented).applySegmentedTint(tintColor)
        }
    }

    private var picker: some View {
        Picker("Options", selection: binding) {
            ForEach(0..<config.items.count, id: \.self) { index in
                Text(config.items[index]).tag(index)
            }
        }
    }

    var binding: Binding<Int> {
        Binding(
            get: { selectedIndex },
            set: { newValue in
                selectedIndex = newValue
                onAction(newValue)
            }
        )
    }

    // MARK: - Style Helpers

    var tintColor: Color? {
        guard let val = config.color else { return nil }
        return Color(argb: val)
    }
}

@available(iOS 26.0, *)
extension View {
    @ViewBuilder
    func applySegmentedTint(_ color: Color?) -> some View {
        if let color = color {
            self.colorMultiply(color)
        } else {
            self
        }
    }
}
