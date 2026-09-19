import SwiftUI

/// Renders a `ListConfig` as native iOS grouped/inset-grouped/plain sections.
///
/// It deliberately does NOT use SwiftUI `List`/`Form`: those are greedy,
/// `UICollectionView`-backed containers that don't report a content-based
/// height, so embedded in a Flutter platform view they clip. A composed
/// `VStack` with the standard grouped styling looks the same, supports the same
/// rows (label / toggle / button), and self-sizes reliably (its
/// `intrinsicContentSize` is exact) so the Flutter box grows to fit.
@available(iOS 26.0, *)
struct AdaptiveListView: View {
    let config: ListConfig
    let onRowTap: (String) -> Void
    let onToggle: (String, Bool) -> Void

    /// A lowered trailing control changed — `(rowId, nodeId, value)`.
    let onTrailingEvent: (String, String, Any?) -> Void

    /// User-driven toggle state, seeded once from the config.
    @State private var toggleStates: [String: Bool]

    init(
        config: ListConfig,
        onRowTap: @escaping (String) -> Void,
        onToggle: @escaping (String, Bool) -> Void,
        onTrailingEvent: @escaping (String, String, Any?) -> Void
    ) {
        self.config = config
        self.onRowTap = onRowTap
        self.onToggle = onToggle
        self.onTrailingEvent = onTrailingEvent
        var initial: [String: Bool] = [:]
        for section in config.sections {
            for row in section.rows where row.type == "toggle" {
                initial[row.id] = row.toggleValue ?? false
            }
        }
        _toggleStates = State(initialValue: initial)
    }

    private var style: String { config.style ?? "insetGrouped" }
    private var isPlain: Bool { style == "plain" }
    private var isInset: Bool { !isPlain && style != "grouped" }
    /// Inset-grouped card corner radius, matching the Settings app's Liquid
    /// Glass concentric corners. Overridable from Dart via `cornerRadius`.
    private var cornerRadius: CGFloat {
        if let explicit = config.cornerRadius { return CGFloat(explicit) }
        return 26
    }

    var body: some View {
        if config.scrollable ?? false {
            ScrollView { sectionsStack }
                .scrollDismissesKeyboard(.never)
        } else {
            sectionsStack
        }
    }

    private var sectionsStack: some View {
        // A per-section value wins; otherwise the inset-grouped metrics. These
        // are composed VStacks, not a real `List`, so SwiftUI adds no margins
        // of its own — the defaults have to be written here.
        let effectiveSectionSpacing = config.sections.first(where: { $0.sectionSpacing != nil })?.sectionSpacing.map { CGFloat($0) }
        let effectiveStackPadding = config.sections.first(where: { $0.stackPadding != nil })?.stackPadding.map { CGFloat($0) }

        return VStack(spacing: effectiveSectionSpacing ?? (isPlain ? 0 : 20)) {
            ForEach(Array(config.sections.enumerated()), id: \.offset) { _, section in
                sectionView(section)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, effectiveStackPadding ?? (isPlain ? 0 : 14))
        .applyListTint(config.tint)
    }

    // MARK: - Section

    @ViewBuilder
    private func sectionView(_ section: ListSectionConfig) -> some View {
        let effectiveMinHeight = section.minHeight.map { CGFloat($0) } ?? 46

        return VStack(alignment: .leading, spacing: 8) {
            if let header = section.header {
                Text(header.uppercased())
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, textInset)
            }

            VStack(spacing: 0) {
                // The separator is an overlay pinned to the row's bottom edge
                // (how UITableView draws its own), not a sibling `Divider()`:
                // a free-standing hairline between stack children could get
                // dropped at certain row boundaries when the hosting view
                // snapshots, leaving rows with no divider between them.
                ForEach(Array(section.rows.enumerated()), id: \.element.id) { index, row in
                    rowView(row)
                        .frame(minHeight: effectiveMinHeight)
                        // A caller's rowPadding replaces the default 16/6.
                        .padding(rowInsets(section.rowPadding))
                        .overlay(alignment: .bottom) {
                            if index < section.rows.count - 1 {
                                Rectangle()
                                    .fill(.separator)
                                    .frame(height: 1.0)
                                    .padding(.leading, separatorInset(row))
                            }
                        }
                }
            }
            .background(
                isPlain ? AnyShapeStyle(Color.clear) : AnyShapeStyle(.background.tertiary)
            )
            .clipShape(
                RoundedRectangle(cornerRadius: isInset ? cornerRadius : 0, style: .continuous)
            )
            .padding(.horizontal, section.cardInset.map { CGFloat($0) } ?? (isInset ? 16 : 0))

            if let footer = section.footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, textInset)
            }
        }
    }

    private func rowInsets(_ custom: EdgeInsetsDTO?) -> EdgeInsets {
        guard let custom else { return EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16) }
        return EdgeInsets(
            top: CGFloat(custom.top ?? 0), leading: CGFloat(custom.left ?? 0),
            bottom: CGFloat(custom.bottom ?? 0), trailing: CGFloat(custom.right ?? 0))
    }

    private var textInset: CGFloat { isInset ? 32 : 16 }
    private func separatorInset(_ row: ListRowConfig) -> CGFloat {
        row.icon != nil ? 56 : 16
    }

    // MARK: - Rows

    @ViewBuilder
    private func rowView(_ row: ListRowConfig) -> some View {
        switch row.type {
        case "toggle":
            HStack(spacing: 12) {
                rowLabel(row)
                Spacer(minLength: 8)
                Toggle("", isOn: toggleBinding(row))
                    .labelsHidden()
                    .disabled(!(row.enabled ?? true))
            }
        case "button":
            Button {
                onRowTap(row.id)
            } label: {
                HStack {
                    rowLabel(row)
                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .foregroundStyle(Color.accentColor)
            .disabled(!(row.enabled ?? true))
        default:
            // Not a Button: the row often carries lowered interactive controls
            // (a Toggle, a menu Picker, a checkbox) and a row Button would
            // swallow their taps — a menu Picker would never open. The tap is
            // scoped to the label/value/chevron region only, so a trailing
            // control keeps every touch (a parent contentShape would otherwise
            // race the Picker's own gesture and the menu would never open).
            HStack(spacing: 12) {
                HStack(spacing: 12) {
                    rowLabel(row)
                    Spacer(minLength: 8)
                    if let value = row.value {
                        Text(value).foregroundStyle(.secondary)
                    }
                    if row.showChevron ?? false {
                        Image(systemName: "chevron.forward")
                            .font(.footnote.weight(.semibold))
                            .foregroundStyle(.tertiary)
                    }
                }
                .contentShape(Rectangle())
                .onTapGesture {
                    guard row.enabled ?? true else { return }
                    onRowTap(row.id)
                }
                if let trailing = row.trailing {
                    TrailingRow(
                        rowId: row.id,
                        nodes: trailing,
                        onEvent: onTrailingEvent)
                }
            }
            .disabled(!(row.enabled ?? true))
        }
    }

    @ViewBuilder
    private func rowLabel(_ row: ListRowConfig) -> some View {
        HStack(spacing: 12) {
            if let icon = row.icon {
                IconView(icon: icon)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(row.title)
                if let subtitle = row.subtitle {
                    Text(subtitle)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func toggleBinding(_ row: ListRowConfig) -> Binding<Bool> {
        Binding(
            get: { toggleStates[row.id] ?? (row.toggleValue ?? false) },
            set: { newValue in
                toggleStates[row.id] = newValue
                onToggle(row.id, newValue)
            }
        )
    }
}

/// One row's lowered trailing controls, owning their own state model — the
/// same `NativeBodyModel` the toolbar and native bodies use, seeded from the
/// nodes the first time the row appears. A user's touch owns the value from
/// then on; pushes from Dart cannot fight it mid-gesture.
@available(iOS 26.0, *)
struct TrailingRow: View {
    let rowId: String
    let nodes: [BodyNodeConfig]
    let onEvent: (String, String, Any?) -> Void

    @StateObject private var model: NativeBodyModel

    init(
        rowId: String,
        nodes: [BodyNodeConfig],
        onEvent: @escaping (String, String, Any?) -> Void
    ) {
        self.rowId = rowId
        self.nodes = nodes
        self.onEvent = onEvent
        let seed = NativeBodyModel()
        seed.seedAll(nodes)
        _model = StateObject(wrappedValue: seed)
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

@available(iOS 26.0, *)
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
