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
    let onSelectionChanged: ([String]) -> Void
    var onSwipeAction: (String, String) -> Void = { _, _ in }
    var onReorder: (Int, Int, Int) -> Void = { _, _, _ in }
    let onTrailingEvent: (String, String, Any?) -> Void
    /// (height, animated): `animated` only for an expandable row opening or
    /// closing — every other height change lands at once.
    let onHeight: (CGFloat, Bool) -> Void

    @State private var toggles: [String: Bool] = [:]
    @State private var contentHeight: CGFloat?
    /// Ids of the expandable rows (`children`) currently open.
    @State private var expanded: Set<String> = []
    /// The user's last pick, shown until Dart echoes it back through `config`.
    @State private var picked: Set<String>?

    private var selection: Binding<Set<String>> {
        Binding(
            get: { picked ?? Set(config.selection ?? []) },
            set: { picked = $0; onSelectionChanged(Array($0)) })
    }

    var body: some View {
        // The selection only exists while editing. Not even an empty one
        // otherwise: any selection binding makes every cell selectable, so a
        // tap on a plain row flashed the pressed highlight.
        List(selection: config.editing == true ? selection : nil) {
            ForEach(Array(config.sections.enumerated()), id: \.offset) { index, section in
                Section {
                    ForEach(visibleRows(section.rows), id: \.id) { row in
                        rowView(row)
                            .badge(row.badge.map { Text($0) })
                            .modifier(SwipeActions(row: row, onAction: onSwipeAction))
                    }
                    .onMove(perform: config.reorderable == true ? { from, to in
                        // One row at a time: `List` drags a single row.
                        guard let first = from.first else { return }
                        onReorder(index, first, to > first ? to - 1 : to)
                    } : nil)
                } header: {
                    if let header = section.header { Text(header) }
                } footer: {
                    VStack(alignment: .leading, spacing: 0) {
                        // The cell grows to the new line count before SwiftUI re-lays the
                        // text, which then truncates into the old one-line height.
                        if let footer = section.footer {
                            Text(footer).fixedSize(horizontal: false, vertical: true)
                        }
                        if index == 0 { ContentHeightReader(onHeight: adopt) }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .environment(\.editMode, .constant(config.editing == true ? .active : .inactive))
        .animation(.default, value: config.editing)
        .onChange(of: config.selection ?? []) { _ in picked = nil }
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
        // The Flutter box animates an expansion; what it has not revealed yet
        // stays hidden instead of painting past it.
        .clipped()
    }

    /// The list's scroll content height — what it would need to show every
    /// row — is the only honest measure: a `List` fills whatever frame it gets.
    private func adopt(_ height: CGFloat) {
        guard height > 1, abs(height - (contentHeight ?? 0)) > 0.5 else { return }
        contentHeight = height
        onHeight(height, expanding)
    }

    /// Plain SwiftUI rows: the `List` draws cells and separators itself.
    @ViewBuilder
    private func rowView(_ row: ListRowConfig) -> some View {
        if let children = row.children, !children.isEmpty {
            // Not a `DisclosureGroup`: with the row modifiers on it (badge,
            // swipe actions) the List took it for one cell and laid the open
            // children out beside the title. The children are real rows
            // instead — see `visibleRows` — under the same rotating chevron.
            // See `toggle` for how the expansion animates.
            Button { toggle(row.id) } label: {
                HStack {
                    label(row)
                    Spacer()
                    Image(systemName: "chevron.forward")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.tint)
                        .rotationEffect(.degrees(isOpen(row.id) ? 90 : 0))
                        .animation(.easeInOut(duration: Self.expandDuration), value: isOpen(row.id))
                }
            }
            .foregroundStyle(Color.primary)
            .disabled(!(row.enabled ?? true))
        } else if row.type == "toggle" {
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
            let content = HStack {
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
            // A Button only when Dart listens: otherwise the cell would flash
            // the pressed highlight for a tap nobody handles.
            if row.tappable ?? true {
                Button { onRowTap(row.id) } label: { content }
                    .foregroundStyle(row.type == "button" ? Color.accentColor : Color.primary)
                    .disabled(!(row.enabled ?? true))
            } else {
                content
                    .foregroundStyle(row.type == "button" ? Color.accentColor : Color.primary)
                    .opacity(row.enabled ?? true ? 1 : 0.4)
            }
        }
    }

    /// The Flutter box's height animation, which the close waits out.
    static let expandDuration = 0.25

    /// Spare height under the content — see the List's frame.
    /// A row's height, to make room for opening children before they are
    /// measured; the real measure corrects it a frame later.
    private static var estimatedRowHeight: CGFloat {
        if #available(iOS 26.0, *) { return 52 }
        return 44
    }

    private func isOpen(_ id: String) -> Bool { expanded.contains(id) }

    /// While an expandable row opens or closes: its measure is reported as
    /// animated.
    @State private var expanding = false
    /// The list's height before each open row was opened — what closing it
    /// animates the Flutter box back to.
    @State private var closedHeights: [String: CGFloat] = [:]

    /// Opens or closes an expandable row with the List's own row animation
    /// while the Flutter box — pinned to the top, clipping the list —
    /// animates to the new height with the same duration and curve (Dart
    /// side), so what is under the list moves with the rows.
    ///
    /// One target per toggle, sent as the animation starts: a second one
    /// restarted Dart's tween and left the box trailing the rows. Opening,
    /// that is the rows' measure — the list first makes room at an estimated
    /// row height so it never scrolls to show rows past its frame; the room
    /// is clipped, never shown. Closing, it is the height noted before
    /// opening, known before the rows leave, so the box shrinks with them
    /// instead of after them.
    private func toggle(_ id: String) {
        expanding = true
        if expanded.contains(id) {
            if let height = closedHeights.removeValue(forKey: id) { onHeight(height, true) }
        } else if let height = contentHeight {
            closedHeights[id] = height
            if let count = Self.row(id, in: config.sections.flatMap(\.rows))?.children?.count {
                contentHeight = height + CGFloat(count) * Self.estimatedRowHeight
            }
        }
        withAnimation(.easeInOut(duration: Self.expandDuration)) {
            if expanded.contains(id) {
                expanded.remove(id)
            } else {
                expanded.insert(id)
            }
        }
        DispatchQueue.main.asyncAfter(deadline: .now() + Self.expandDuration + 0.1) {
            expanding = false
        }
    }

    private static func row(_ id: String, in rows: [ListRowConfig]) -> ListRowConfig? {
        for row in rows {
            if row.id == id { return row }
            if let found = Self.row(id, in: row.children ?? []) { return found }
        }
        return nil
    }

    /// The rows to show: every row, followed by its children while it is open
    /// (recursively).
    private func visibleRows(_ rows: [ListRowConfig]) -> [ListRowConfig] {
        rows.flatMap { row -> [ListRowConfig] in
            guard expanded.contains(row.id), let children = row.children else { return [row] }
            return [row] + visibleRows(children)
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
        // A calendar or a wheel is a block, not a pill.
        case "datePicker": return (datePicker?.style ?? "compact") != "compact"
        case "control":
            switch control?.kind {
            case "multiDatePicker", "textEditor": return true
            case "gauge": return !(control?.gaugeStyle ?? "").hasPrefix("circular")
            default: return false
            }
        default: return false
        }
    }
}

/// A row's trailing swipe buttons; nothing when it has none, so the row keeps
/// no empty swipe gesture.
@available(iOS 15.0, *)
private struct SwipeActions: ViewModifier {
    let row: ListRowConfig
    let onAction: (String, String) -> Void

    func body(content: Content) -> some View {
        if let actions = row.swipeActions, !actions.isEmpty {
            content.swipeActions(edge: .trailing, allowsFullSwipe: true) {
                ForEach(actions) { action in
                    Button(role: action.isDestructive == true ? .destructive : nil) {
                        onAction(row.id, action.actionId ?? "")
                    } label: {
                        if let image = action.systemImage {
                            Label(action.title ?? "", systemImage: image)
                        } else {
                            Text(action.title ?? "")
                        }
                    }
                }
            }
        } else {
            content
        }
    }
}
