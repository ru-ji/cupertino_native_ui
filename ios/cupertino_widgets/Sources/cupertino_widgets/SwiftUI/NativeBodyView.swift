import SwiftUI

/// Live state for a native body: the values its controls own between pushes
/// from Dart, keyed by node id.
///
/// A control is the source of truth for its own value while the user is
/// touching it — a slider that round-tripped every drag step through Dart
/// would stutter. Dart is told about every change and can push a different
/// value back, which wins.
@available(iOS 26.0, *)
final class NativeBodyModel: ObservableObject {
    @Published var root: BodyNodeConfig?

    @Published var toggles: [String: Bool] = [:]
    @Published var sliders: [String: Double] = [:]
    @Published var pickers: [String: Int] = [:]

    /// One `TextFieldModel` per field node, so `AdaptiveTextFieldView` behaves
    /// exactly as it does standalone.
    private var fieldModels: [String: TextFieldModel] = [:]

    /// Created once per field id and reused. Never reassigned during a view
    /// update — the model is `@Published`, and writing to it from inside
    /// `body` is how a SwiftUI update loop starts. `applyConfigs` pushes new
    /// configs instead, from the method channel.
    func fieldModel(for id: String, config: TextFieldConfig) -> TextFieldModel {
        if let existing = fieldModels[id] { return existing }
        let model = TextFieldModel(config: config)
        fieldModels[id] = model
        return model
    }

    /// Pushes updated field configs (placeholder, enabled, glass) without the
    /// fields losing what the user has typed. Called when Dart sends a new
    /// tree, outside any view update.
    func applyConfigs(_ node: BodyNodeConfig?) {
        guard let node = node else { return }
        if let id = node.id, let config = node.textField, let model = fieldModels[id] {
            model.config = config
        }
        for child in node.children ?? [] { applyConfigs(child) }
    }

    /// Seeds a list of roots, for the keyboard toolbar.
    func seedAll(_ nodes: [BodyNodeConfig]) {
        for node in nodes { seed(node) }
    }

    /// Seeds the values a freshly-arrived tree declares, without clobbering
    /// what the user has already changed on a node that was already there.
    func seed(_ node: BodyNodeConfig?) {
        guard let node = node else { return }
        if let id = node.id {
            if let toggle = node.toggle, toggles[id] == nil { toggles[id] = toggle.value }
            if let slider = node.slider, sliders[id] == nil { sliders[id] = slider.value }
            if let picker = node.picker, pickers[id] == nil {
                pickers[id] = picker.selectedIndex
            }
        }
        for child in node.children ?? [] { seed(child) }
    }
}

/// Renders a `BodyNodeConfig` tree as SwiftUI.
@available(iOS 26.0, *)
struct NativeBodyView: View {
    @ObservedObject var model: NativeBodyModel

    /// (nodeId, value) — value is Bool, Double, Int, String, or nil for a
    /// button.
    let onEvent: (String, Any?) -> Void

    var body: some View {
        if let root = model.root {
            NativeBodyNode(node: root, model: model, onEvent: onEvent)
        } else {
            Color.clear
        }
    }
}

/// One node. Split out from `NativeBodyView` so the recursion has a type to
/// recurse into — a `View` cannot reference itself inside its own `body`.
/// Internal rather than private: the keyboard toolbar renders a tree's
/// top-level nodes straight into a `ToolbarItemGroup` (see `KeyboardToolbar`).
@available(iOS 26.0, *)
struct NativeBodyNode: View {
    let node: BodyNodeConfig
    @ObservedObject var model: NativeBodyModel
    let onEvent: (String, Any?) -> Void

    var body: some View {
        content
            .applyBodyPadding(node.padding)
            .applyBodyExpand(node.expand == true)
    }

    private var children: [BodyNodeConfig] { node.children ?? [] }

    @ViewBuilder
    private var content: some View {
        switch node.type {
        case "column":
            VStack(alignment: horizontalAlignment, spacing: node.spacing.map { CGFloat($0) }) {
                childViews
            }
        case "row":
            HStack(alignment: verticalAlignment, spacing: node.spacing.map { CGFloat($0) }) {
                childViews
            }
        case "scroll":
            ScrollView {
                VStack(alignment: horizontalAlignment, spacing: node.spacing.map { CGFloat($0) }) {
                    childViews
                }
            }
        case "padding":
            VStack(spacing: 0) { childViews }
        case "spacer":
            if let extent = node.extent {
                Color.clear.frame(width: CGFloat(extent), height: CGFloat(extent))
            } else {
                Spacer(minLength: 0)
            }
        case "divider":
            Divider()
        case "text":
            textView
        case "button":
            buttonView
        case "textField":
            textFieldView
        case "toggle":
            toggleView
        case "slider":
            sliderView
        case "picker":
            pickerView
        case "list":
            listView
        case "symbol":
            symbolView
        case "flutter":
            flutterView
        default:
            EmptyView()
        }
    }

    @ViewBuilder
    private var childViews: some View {
        ForEach(Array(children.enumerated()), id: \.offset) { index, child in
            NativeBodyNode(node: child, model: model, onEvent: onEvent)
                .id(child.id ?? "\(child.type)-\(index)")
        }
    }

    // MARK: - Leaves

    @ViewBuilder
    private var textView: some View {
        if let config = node.text {
            Text(config.value)
                .applyBodyFont(config)
                .applyBodyTextColor(config.color)
                .applyBodyTextAlign(config.align)
        }
    }

    @ViewBuilder
    private var buttonView: some View {
        if let config = node.button, let id = node.id {
            AdaptiveButtonView(config: config) { onEvent(id, nil) }
        }
    }

    @ViewBuilder
    private var textFieldView: some View {
        if let config = node.textField, let id = node.id {
            AdaptiveTextFieldView(
                model: model.fieldModel(for: id, config: config),
                onChanged: { onEvent(id, $0) },
                onSubmitted: { onEvent("\(id).submitted", $0) },
                onEditingComplete: {},
                onFocusChange: { onEvent("\(id).focused", $0) },
                onToolbarEvent: { toolbarId, value in
                    onEvent("\(id).\(toolbarId)", value)
                }
            )
            // The standalone platform view is sized by Flutter; here nothing
            // else states a height, so the field would collapse.
            .frame(height: 44)
        }
    }

    @ViewBuilder
    private var toggleView: some View {
        if let config = node.toggle, let id = node.id {
            Toggle(
                config.label ?? "",
                isOn: Binding(
                    get: { model.toggles[id] ?? config.value },
                    set: { newValue in
                        model.toggles[id] = newValue
                        onEvent(id, newValue)
                    })
            )
            .applyBodyTint(config.color)
            .applyBodyLabelsHidden(config.label == nil)
        }
    }

    @ViewBuilder
    private var sliderView: some View {
        if let config = node.slider, let id = node.id {
            let binding = Binding<Double>(
                get: { model.sliders[id] ?? config.value },
                set: { newValue in
                    model.sliders[id] = newValue
                    onEvent(id, newValue)
                })
            Group {
                if let step = config.step, step > 0 {
                    Slider(value: binding, in: config.min...config.max, step: step)
                } else {
                    Slider(value: binding, in: config.min...config.max)
                }
            }
            .applyBodyTint(config.color)
            .disabled(config.enabled == false)
        }
    }

    @ViewBuilder
    private var pickerView: some View {
        if let config = node.picker, let id = node.id {
            AdaptivePickerView(config: config) { index in
                model.pickers[id] = index
                onEvent(id, index)
            }
        }
    }

    @ViewBuilder
    private var listView: some View {
        if let config = node.list {
            AdaptiveListView(
                config: config,
                onRowTap: { onEvent(node.id ?? "list", $0) },
                onToggle: { rowId, value in onEvent("\(node.id ?? "list").\(rowId)", value) }
            )
        }
    }

    /// A Flutter island: real Flutter widgets, in their own engine, inside
    /// the native tree. The expensive node — it is an isolate.
    @ViewBuilder
    private var flutterView: some View {
        if let route = node.route {
            BodyFlutterView(route: route, isDark: node.isDark == true)
        }
    }

    @ViewBuilder
    private var symbolView: some View {
        if let config = node.symbol {
            BodySymbolView(config: config)
        }
    }

    // MARK: - Layout helpers

    private var horizontalAlignment: HorizontalAlignment {
        switch node.alignment {
        case "center": return .center
        case "trailing": return .trailing
        default: return .leading
        }
    }

    private var verticalAlignment: VerticalAlignment {
        switch node.alignment {
        case "top": return .top
        case "bottom": return .bottom
        default: return .center
        }
    }
}

/// Owns the `SymbolModel` an animated symbol needs. Building one inline would
/// hand `AdaptiveSymbolView` a fresh object on every update, restarting — or
/// dropping — the effect it exists to run.
@available(iOS 26.0, *)
private struct BodySymbolView: View {
    let config: SymbolConfig

    @StateObject private var model = SymbolModel()

    var body: some View {
        AdaptiveSymbolView(model: model)
            .onAppear { model.config = config }
            .onChange(of: config.trigger) { _ in model.config = config }
            .onChange(of: config.name) { _ in model.config = config }
    }
}

@available(iOS 26.0, *)
extension View {
    @ViewBuilder
    fileprivate func applyBodyLabelsHidden(_ hidden: Bool) -> some View {
        if hidden {
            self.labelsHidden()
        } else {
            self
        }
    }

    @ViewBuilder
    fileprivate func applyBodyPadding(_ insets: BodyEdgeInsets?) -> some View {
        if let insets = insets {
            self.padding(
                EdgeInsets(
                    top: CGFloat(insets.top), leading: CGFloat(insets.leading),
                    bottom: CGFloat(insets.bottom), trailing: CGFloat(insets.trailing)))
        } else {
            self
        }
    }

    @ViewBuilder
    fileprivate func applyBodyExpand(_ expand: Bool) -> some View {
        if expand {
            self.frame(maxWidth: .infinity)
        } else {
            self
        }
    }

    @ViewBuilder
    fileprivate func applyBodyTint(_ argb: Int?) -> some View {
        if let argb = argb {
            self.tint(Color(argb: argb))
        } else {
            self
        }
    }

    @ViewBuilder
    fileprivate func applyBodyTextColor(_ argb: Int?) -> some View {
        if let argb = argb {
            self.foregroundStyle(Color(argb: argb))
        } else {
            self
        }
    }

    @ViewBuilder
    fileprivate func applyBodyTextAlign(_ align: String?) -> some View {
        switch align {
        case "center": self.multilineTextAlignment(.center)
        case "trailing": self.multilineTextAlignment(.trailing)
        default: self.multilineTextAlignment(.leading)
        }
    }

    @ViewBuilder
    fileprivate func applyBodyFont(_ config: BodyTextConfig) -> some View {
        if let size = config.fontSize {
            self.font(
                .system(
                    size: CGFloat(size),
                    weight: config.fontWeight.map { Font.Weight(weightIndex: $0) } ?? .regular))
        } else {
            self.font(Self.namedFont(config.style))
                .fontWeight(config.fontWeight.map { Font.Weight(weightIndex: $0) })
        }
    }

    fileprivate static func namedFont(_ style: String?) -> Font {
        switch style {
        case "largeTitle": return .largeTitle
        case "title": return .title
        case "title2": return .title2
        case "title3": return .title3
        case "headline": return .headline
        case "subheadline": return .subheadline
        case "callout": return .callout
        case "footnote": return .footnote
        case "caption": return .caption
        default: return .body
        }
    }
}
