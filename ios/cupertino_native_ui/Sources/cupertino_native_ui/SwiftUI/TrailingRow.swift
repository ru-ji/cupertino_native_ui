import SwiftUI


/// One row's lowered trailing controls, owning their own state model: the
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
        store.model(rowId: rowId, nodes: nodes)
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

/// The models of a list's transcribed rows.
///
/// Owned by the platform view. A row's model is created once per row id and
/// kept; it also owns its fields' keyboard bars (see
/// `NativeBodyModel.syncKeyboardBar`).
@available(iOS 15.0, *)
final class TrailingRowStore {
    private var models: [String: NativeBodyModel] = [:]

    func model(rowId: String, nodes: [BodyNodeConfig]) -> NativeBodyModel {
        if let existing = models[rowId] { return existing }
        let model = NativeBodyModel()
        model.seedAll(nodes)
        models[rowId] = model
        return model
    }

    /// Hands each row's controls the values a new config carries, as a
    /// native body does on every push. Rows not built yet are skipped: they
    /// seed from this config when they first appear. Called from the method
    /// channel, outside any view update.
    func apply(_ config: ListConfig) {
        func walk(_ rows: [ListRowConfig]) {
            for row in rows {
                if let trailing = row.trailing, let model = models[row.id] {
                    model.seedAll(trailing)
                    for node in trailing { model.applyConfigs(node) }
                }
                walk(row.children ?? [])
            }
        }
        for section in config.sections { walk(section.rows) }
    }

    /// Puts the responder back on the field `key` names, `"rowId.fieldId"`.
    ///
    /// The row's model is only ever created here, so a field that was focused
    /// before the platform view left the window already has one: this just
    /// bumps its focus command. See `NativeListView.refocusTranscribedField`.
    func refocus(key: String) {
        let parts = key.split(separator: ".", maxSplits: 1)
        guard parts.count == 2, let model = models[String(parts[0])] else { return }
        model.refocusField(id: String(parts[1]))
    }
}
