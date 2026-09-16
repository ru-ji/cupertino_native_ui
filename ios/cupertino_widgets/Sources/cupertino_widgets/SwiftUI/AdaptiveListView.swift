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

    /// User-driven toggle state, seeded once from the config.
    @State private var toggleStates: [String: Bool]

    init(
        config: ListConfig,
        onRowTap: @escaping (String) -> Void,
        onToggle: @escaping (String, Bool) -> Void
    ) {
        self.config = config
        self.onRowTap = onRowTap
        self.onToggle = onToggle
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
        } else {
            sectionsStack
        }
    }

    private var sectionsStack: some View {
        VStack(spacing: isPlain ? 0 : 22) {
            ForEach(Array(config.sections.enumerated()), id: \.offset) { _, section in
                sectionView(section)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, isPlain ? 0 : 14)
        .applyListTint(config.tint)
    }

    // MARK: - Section

    @ViewBuilder
    private func sectionView(_ section: ListSectionConfig) -> some View {
        VStack(alignment: .leading, spacing: 6) {
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
                        .frame(minHeight: 44)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 6)
                        .overlay(alignment: .bottom) {
                            if index < section.rows.count - 1 {
                                Rectangle()
                                    .fill(Color(uiColor: .separator))
                                    .frame(height: 1.0 / UIScreen.main.scale)
                                    .padding(.leading, separatorInset(row))
                            }
                        }
                }
            }
            .background(isPlain ? Color.clear : Color(.secondarySystemGroupedBackground))
            .clipShape(
                RoundedRectangle(cornerRadius: isInset ? cornerRadius : 0, style: .continuous)
            )
            .padding(.horizontal, cardInset)

            if let footer = section.footer {
                Text(footer)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, textInset)
            }
        }
    }

    private var cardInset: CGFloat { isInset ? 16 : 0 }
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
            Button {
                onRowTap(row.id)
            } label: {
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
            }
            .buttonStyle(.plain)
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
