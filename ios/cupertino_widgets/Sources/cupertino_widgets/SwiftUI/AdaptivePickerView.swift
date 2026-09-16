import SwiftUI

/// A native `Picker` in one of SwiftUI's styles.
///
/// `.palette` is the Liquid Glass one: the options sit side by side as icons
/// in a glass row, the selection travelling between them. It only reads
/// correctly with icons, so palette items should carry one.
@available(iOS 26.0, *)
struct AdaptivePickerView: View {
    let config: PickerConfig
    let onChanged: (Int) -> Void

    @State private var selection: Int

    init(config: PickerConfig, onChanged: @escaping (Int) -> Void) {
        self.config = config
        self.onChanged = onChanged
        _selection = State(initialValue: config.selectedIndex)
    }

    private var tintColor: Color? {
        guard let val = config.color else { return nil }
        return Color(argb: val)
    }

    var body: some View {
        picker
            .applyPickerStyle(config.style)
            .applyLabelsHidden(config.labelHidden != false)
            .applyControlSize(config.controlSize)
            .tint(tintColor)
            .onChange(of: selection) { newValue in
                onChanged(newValue)
            }
            // Dart is the source of truth: a selection pushed from there wins
            // over whatever the control last reported.
            .onChange(of: config.selectedIndex) { newValue in
                if selection != newValue { selection = newValue }
            }
    }

    private var picker: some View {
        Picker(selection: $selection) {
            ForEach(config.items) { item in
                itemLabel(item).tag(item.id)
            }
        } label: {
            Text(config.label ?? "")
        }
    }

    @ViewBuilder
    private func itemLabel(_ item: PickerItemConfig) -> some View {
        if let icon = item.icon {
            if let title = item.title, !title.isEmpty {
                Label { Text(title) } icon: { IconView(icon: icon) }
            } else {
                IconView(icon: icon)
            }
        } else {
            Text(item.title ?? "")
        }
    }
}

@available(iOS 26.0, *)
extension View {
    @ViewBuilder
    fileprivate func applyPickerStyle(_ style: String?) -> some View {
        switch style {
        case "wheel": self.pickerStyle(.wheel)
        case "menu": self.pickerStyle(.menu)
        case "segmented": self.pickerStyle(.segmented)
        case "palette": self.pickerStyle(.palette)
        case "inline": self.pickerStyle(.inline)
        case "navigationLink": self.pickerStyle(.navigationLink)
        default: self.pickerStyle(.automatic)
        }
    }

    @ViewBuilder
    fileprivate func applyLabelsHidden(_ hidden: Bool) -> some View {
        if hidden {
            self.labelsHidden()
        } else {
            self
        }
    }
}
