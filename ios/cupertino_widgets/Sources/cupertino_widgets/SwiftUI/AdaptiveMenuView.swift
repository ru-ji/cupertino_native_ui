import SwiftUI

@available(iOS 26.0, *)
struct AdaptiveMenuView: View {
    let config: MenuConfiguration
    let onAction: (String, Any?) -> Void

    var body: some View {
        let menu = Menu {
            ForEach(config.items) { item in
                MenuItemMapper(item: item, onAction: onAction)
            }
        } label: {
            if let sysImg = config.systemImage, config.labelStyle == "iconOnly" {
                // A Menu drops the button styles' content insets, so the glyph
                // gets its own square, like an icon-only Button's.
                applyCustomTextColor(
                    to: Image(systemName: sysImg).font(customFont)
                        .imageScale(.large)
                        .frame(width: 28, height: 28))
            } else if let sysImg = config.systemImage {
                applyCustomTextColor(
                    to: Label(config.title, systemImage: sysImg).font(customFont))
            } else {
                applyCustomTextColor(to: Text(config.title).font(customFont))
            }
        }

        // Same three the button uses: the label style decides what the anchor
        // shows, the button style draws the material, the border shape decides
        // its outline. A circle needs `iconOnly` — a label with text is laid
        // out as a capsule whatever shape is asked for.
        applyMenuButtonStyle(menu.applyLabelStyle(config.labelStyle))
            .applyButtonShape(config.borderShape)
            .applyControlSize(config.controlSize)
    }

    @ViewBuilder
    func applyMenuButtonStyle(_ menu: some View) -> some View {
        switch config.style {
        case "filled":
            menu.buttonStyle(.borderedProminent).tint(tintColor)
        case "tinted":
            menu.buttonStyle(.bordered).tint(tintColor)
        case "plain":
            menu.buttonStyle(.borderless).tint(tintColor)
        case "glass":
            menu.buttonStyle(.glass).tint(tintColor)
        case "glassProminent":
            menu.buttonStyle(.glassProminent).tint(tintColor)
        default:
            menu.buttonStyle(.automatic).tint(tintColor)
        }
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

    @ViewBuilder
    func applyCustomTextColor(to view: some View) -> some View {
        if let color = customTextColor {
            view.foregroundStyle(color)
        } else {
            view
        }
    }
}

@available(iOS 26.0, *)
struct MenuItemMapper: View {
    let item: MenuItemConfig
    let onAction: (String, Any?) -> Void

    var body: some View {
        switch item.type {
        case .action:
            if item.isDestructive == true {
                Button(role: .destructive) {
                    triggerAction()
                } label: {
                    menuLabel
                }
                .disabled(item.isDisabled == true)
            } else {
                Button(action: {
                    triggerAction()
                }) {
                    menuLabel
                }
                .disabled(item.isDisabled == true)
            }

        case .submenu:
            Menu {
                if let children = item.items {
                    ForEach(children) { child in
                        MenuItemMapper(item: child, onAction: onAction)
                    }
                }
            } label: {
                menuLabel
            }

        case .section:
            Section(header: Text(item.title ?? "")) {
                if let children = item.items {
                    ForEach(children) { child in
                        MenuItemMapper(item: child, onAction: onAction)
                    }
                }
            }

        case .toggle:
            Toggle(
                isOn: Binding(
                    get: { item.value ?? false },
                    set: { newValue in
                        if let id = item.actionId {
                            onAction(id, newValue)
                        }
                    }
                )
            ) {
                menuLabel
            }
        }
    }

    var menuLabel: some View {
        Group {
            if let sysImg = item.systemImage {
                Label(item.title ?? "", systemImage: sysImg)
            } else {
                Text(item.title ?? "")
            }
        }
    }

    func triggerAction() {
        if let id = item.actionId {
            onAction(id, nil)
        }
    }
}
