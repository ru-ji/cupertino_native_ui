import SwiftUI


/// One row's lowered trailing controls, owning their own state model — the
/// same `NativeBodyModel` the toolbar and native bodies use, seeded from the
/// nodes the first time the row appears. A user's touch owns the value from
/// then on; pushes from Dart cannot fight it mid-gesture.
@available(iOS 15.0, *)
struct TrailingRow: View {
    let rowId: String
    let nodes: [BodyNodeConfig]
    let store: TrailingRowStore
    let onEvent: (String, String, Any?) -> Void

    /// Read, never created here: the store owns it, so re-evaluating this
    /// view cannot churn models or bars.
    private var model: NativeBodyModel {
        store.model(
            rowId: rowId,
            nodes: nodes,
            onEvent: { nodeId, value in onEvent(rowId, nodeId, value) })
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(Array(nodes.enumerated()), id: \.offset) { index, node in
                NativeBodyNode(node: node, model: model) { nodeId, value in
                    onEvent(rowId, nodeId, value)
                }
                .id(node.id ?? "\(node.type)-\(index)")
            }
        }
    }
}

@available(iOS 15.0, *)
extension View {
    @ViewBuilder
    func applyListTint(_ argb: Int?) -> some View {
        if let argb = argb {
            self.tint(Color(argb: argb))
        } else {
            self
        }
    }
}

/// The models and keyboard bars of a list's transcribed rows.
///
/// Owned by the platform view. A row's model is created once per row id and
/// kept, and a field that asked for a toolbar gets its bar attached here —
/// outside any view update, so nothing is rebuilt per frame.
@available(iOS 15.0, *)
final class TrailingRowStore {
    private var models: [String: NativeBodyModel] = [:]
    private var bars: [String: KeyboardAccessoryBar] = [:]

    func model(
        rowId: String,
        nodes: [BodyNodeConfig],
        onEvent: @escaping (String, Any?) -> Void
    ) -> NativeBodyModel {
        if let existing = models[rowId] { return existing }
        let model = NativeBodyModel()
        model.seedAll(nodes)
        models[rowId] = model
        for node in nodes { attachAccessory(node, rowId: rowId, model: model, onEvent: onEvent) }
        return model
    }

    private func attachAccessory(
        _ node: BodyNodeConfig,
        rowId: String,
        model: NativeBodyModel,
        onEvent: @escaping (String, Any?) -> Void
    ) {
        if let id = node.id, let config = node.textField,
            let items = config.keyboardToolbar, !items.isEmpty
        {
            let key = "\(rowId).\(id)"
            let bar =
                bars[key]
                ?? KeyboardAccessoryBar(
                    nodes: items,
                    isDark: node.isDark == true,
                    onEvent: { itemId, value in onEvent("\(id).toolbar.\(itemId)", value) })
            bars[key] = bar
            model.fieldModel(for: id, config: config).accessory = bar.inputView
        }
        for child in node.children ?? [] {
            attachAccessory(child, rowId: rowId, model: model, onEvent: onEvent)
        }
    }

    /// Puts the responder back on the field `key` names, `"rowId.fieldId"`.
    ///
    /// The row's model is only ever created here, so a field that was focused
    /// before the platform view left the window already has one — this just
    /// bumps its focus command. See `NativeListView.refocusTranscribedField`.
    func refocus(key: String) {
        let parts = key.split(separator: ".", maxSplits: 1)
        guard parts.count == 2, let model = models[String(parts[0])] else { return }
        model.refocusField(id: String(parts[1]))
    }
}
