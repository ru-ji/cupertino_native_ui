import SwiftUI

/// Spike: the native list as a real SwiftUI `List` in `.insetGrouped`, so the
/// system alone decides the card radius, row height, margins and separators.
///
/// A `List` fills the box it is given instead of reporting its content height,
/// so it starts tall, reads its scroll content height (`onScrollGeometryChange`
/// on iOS 18+, the underlying scroll view's `contentSize` below), then freezes
/// to that height and reports it (`onHeight`). Flutter never sees the tall first frame.
///
/// **That last sentence only holds because nothing else publishes this frame.**
/// The starting height below is finite and plausible (twice the screen), so any
/// reader that treats it as the content's size will adopt it: `NativeListView`
/// used to, through the base class's intrinsic-size measurement, and a Flutter
/// box sized to twice the screen is what made a sheet's form scroll forever.
/// The host therefore sets `measuresIntrinsicSize = false` and answers
/// `intrinsicSize()` from this reported number alone — see `systemListHeight`
/// there. Keep the two in step.
@available(iOS 15.0, *)
struct AdaptiveSystemListView: View {
    let config: ListConfig
    let store: TrailingRowStore
    let onRowTap: (String) -> Void
    let onToggle: (String, Bool) -> Void
    let onTrailingEvent: (String, String, Any?) -> Void
    let onHeight: (CGFloat) -> Void

    @State private var toggles: [String: Bool] = [:]
    @State private var contentHeight: CGFloat?

    var body: some View {
        List {
            ForEach(Array(config.sections.enumerated()), id: \.offset) { index, section in
                Section {
                    ForEach(section.rows, id: \.id) { row in rowView(row) }
                } header: {
                    if let header = section.header { Text(header) }
                } footer: {
                    VStack(alignment: .leading, spacing: 0) {
                        if let footer = section.footer { Text(footer) }
                        if index == 0 { ContentHeightReader(onHeight: adopt) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .applyNoScroll()
        .applyClearBackground()
        .applyListTint(config.tint)
        .readContentHeight(adopt)
        // The window's safe areas must not pad the list: in a sheet they add
        // height, and they change as the list scrolls near the screen edges,
        // changing the measure and resizing the Flutter box on every frame.
        .ignoresSafeArea()
        .frame(height: contentHeight ?? UIScreen.main.bounds.height * 2)
        // The tall unmeasured first frame is never shown.
        .opacity(contentHeight == nil ? 0 : 1)
        // Pinned to the top of the Flutter box: a list taller or shorter than
        // the box would otherwise be centred in it and slide as either resizes.
        .frame(maxHeight: .infinity, alignment: .top)
    }

    /// The list's scroll content height — what it would need to show every
    /// row — is the only honest measure: a `List` fills whatever frame it gets.
    private func adopt(_ height: CGFloat) {
        guard height > 1, abs(height - (contentHeight ?? 0)) > 0.5 else { return }
        contentHeight = height
        onHeight(height)
    }

    /// Plain SwiftUI rows: the `List` draws cells and separators itself.
    @ViewBuilder
    private func rowView(_ row: ListRowConfig) -> some View {
        if row.type == "toggle" {
            Toggle(isOn: Binding(
                get: { toggles[row.id] ?? (row.toggleValue ?? false) },
                set: { toggles[row.id] = $0; onToggle(row.id, $0) })
            ) { label(row) }
        } else if let trailing = row.trailing {
            let control = TrailingRow(
                rowId: row.id, nodes: trailing, store: store, onEvent: onTrailingEvent)
            if trailing.contains(where: \.spansRow) {
                // A slider, a bar or a segmented control needs the row's whole
                // width: title (and value) on top, the control under it.
                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        label(row)
                        Spacer(minLength: 8)
                        if let value = row.value { Text(value).foregroundStyle(.secondary) }
                    }
                    control.frame(maxWidth: .infinity)
                }
            } else {
                HStack {
                    label(row)
                    // Takes the room the label leaves, flush right: a switch
                    // sits at the trailing edge.
                    if let value = row.value { Text(value).foregroundStyle(.secondary) }
                    control.frame(maxWidth: .infinity, alignment: .trailing)
                }
            }
        } else {
            Button { onRowTap(row.id) } label: {
                HStack {
                    label(row)
                    Spacer()
                    if let value = row.value { Text(value).foregroundStyle(.secondary) }
                    if row.selected ?? false {
                        Image(systemName: "checkmark")
                            .font(.body.weight(.semibold)).foregroundStyle(.tint)
                    }
                    if row.showChevron ?? false {
                        Image(systemName: "chevron.forward")
                            .font(.footnote.weight(.semibold)).foregroundStyle(.tertiary)
                    }
                }
            }
            .foregroundStyle(row.type == "button" ? Color.accentColor : Color.primary)
            .disabled(!(row.enabled ?? true))
        }
    }

    /// A `Label`: the List lines every icon up in one column, so titles — and
    /// the separators that start at them — align whatever the glyph's width.
    @ViewBuilder
    private func label(_ row: ListRowConfig) -> some View {
        let text = VStack(alignment: .leading, spacing: 2) {
            Text(row.title)
            if let subtitle = row.subtitle {
                Text(subtitle).font(.footnote).foregroundStyle(.secondary)
            }
        }
        if let icon = row.icon {
            Label { text } icon: { IconView(icon: icon) }
        } else {
            text
        }
    }
}

/// Below iOS 18 SwiftUI does not expose a list's content size, so a zero-size
/// view inside it finds the scroll view it lives in and observes `contentSize`.
private struct ContentHeightReader: UIViewRepresentable {
    let onHeight: (CGFloat) -> Void

    func makeUIView(context: Context) -> UIView { Probe(onHeight: onHeight) }
    func updateUIView(_ view: UIView, context: Context) {}

    final class Probe: UIView {
        let onHeight: (CGFloat) -> Void
        private var observation: NSKeyValueObservation?

        init(onHeight: @escaping (CGFloat) -> Void) {
            self.onHeight = onHeight
            super.init(frame: .zero)
        }
        required init?(coder: NSCoder) { fatalError() }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            guard observation == nil, #unavailable(iOS 18.0) else { return }
            var v = superview
            while let view = v, !(view is UIScrollView) { v = view.superview }
            observation = (v as? UIScrollView)?.observe(\.contentSize, options: [.initial, .new]) {
                [onHeight] scroll, _ in
                DispatchQueue.main.async { onHeight(scroll.contentSize.height) }
            }
        }
    }
}

@available(iOS 15.0, *)
extension View {
    /// The page's own colour shows through, not the list's grouped grey.
    @ViewBuilder fileprivate func applyClearBackground() -> some View {
        if #available(iOS 16.0, *) { self.scrollContentBackground(.hidden) } else { self }
    }

    @ViewBuilder fileprivate func readContentHeight(_ onHeight: @escaping (CGFloat) -> Void) -> some View {
        if #available(iOS 18.0, *) {
            self.onScrollGeometryChange(for: CGFloat.self, of: { $0.contentSize.height }) { _, h in
                onHeight(h)
            }
        } else { self }
    }

    @ViewBuilder fileprivate func applyNoScroll() -> some View {
        if #available(iOS 16.0, *) { self.scrollDisabled(true) } else { self }
    }
}

@available(iOS 15.0, *)
extension BodyNodeConfig {
    /// Controls that are only usable stretched across the row, so a list lays
    /// them under the title instead of beside it.
    var spansRow: Bool {
        switch type {
        case "slider": return true
        case "segmented": return segmented?.style != "menu"
        case "progress": return progress?.style == 1
        default: return false
        }
    }
}
