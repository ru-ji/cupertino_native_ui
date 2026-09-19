import SwiftUI

/// Shared state between the platform view and its SwiftUI body. The platform
/// view owns it and writes to it from the method channel; the view observes.
@available(iOS 26.0, *)
final class TextFieldModel: ObservableObject {
    @Published var config: TextFieldConfig {
        didSet { configRevision &+= 1 }
    }
    @Published var text: String
    @Published var contentOpacity: Double = 1

    /// Bumped by `focus` / `unfocus` so the view can act on a repeated request.
    @Published var focusCommand: (id: Int, focused: Bool)?

    /// The keyboard accessory for this field, or nil. Set on the backing
    /// `UITextField` while it is still unfocused, so UIKit presents it in the
    /// same animation as the keyboard — no `reloadInputViews()`.
    @Published var accessory: UIView?

    /// Bumped whenever `config` is replaced — the toolbar's declared values
    /// reseed on it, without comparing configs in `body`.
    private(set) var configRevision = 0

    init(config: TextFieldConfig) {
        self.config = config
        self.text = config.text ?? ""
    }
}

/// The package's text field: SwiftUI chrome (glass, icons, clear button)
/// around a `UITextField` — see [BackingTextField] for why the editable part
/// is UIKit (the keyboard toolbar).
@available(iOS 26.0, *)
struct AdaptiveTextFieldView: View {
    @ObservedObject var model: TextFieldModel

    let onChanged: (String) -> Void
    let onSubmitted: (String) -> Void
    let onEditingComplete: () -> Void
    let onFocusChange: (Bool) -> Void

    /// Mirrors the backing field's first-responder state. Not `@FocusState`:
    /// the field is a `UITextField` (see [BackingTextField]), which SwiftUI's
    /// focus system does not drive.
    @State private var focused = false

    private var c: TextFieldConfig { model.config }

    var body: some View {
        row
            .padding(.horizontal, horizontalInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(background)
            .modifier(GlassBackground(config: c))
            .onChange(of: focused) { onFocusChange($0) }
            .environment(\.colorScheme, c.isDark == true ? .dark : .light)
    }

    // MARK: - Pieces

    private var row: some View {
        HStack(spacing: 8) {
            if let prefix = c.prefixIcon { IconView(icon: prefix) }
            field
            if showsClearButton { clearButton }
            if let suffix = c.suffixIcon { IconView(icon: suffix) }
        }
        .opacity(model.contentOpacity)
    }

    private var field: some View {
        BackingTextField(
            model: model,
            text: binding,
            focused: $focused,
            onSubmit: {
                onEditingComplete()
                onSubmitted(model.text)
            }
        )
        .frame(maxWidth: .infinity, alignment: verticalAlignment)
    }

    /// `readOnly` is enforced here rather than with `.disabled`, which would
    /// also grey the text out and refuse focus — a read-only field still takes
    /// the caret and the selection, it just does not accept edits.
    private var binding: Binding<String> {
        Binding(
            get: { model.text },
            set: { newValue in
                guard c.readOnly != true else { return }
                var value = newValue
                if let maxLength = c.maxLength, value.count > maxLength {
                    value = String(value.prefix(maxLength))
                }
                guard value != model.text else { return }
                model.text = value
                onChanged(value)
            }
        )
    }

    private var clearButton: some View {
        Button {
            model.text = ""
            onChanged("")
        } label: {
            Image(systemName: "xmark.circle.fill")
                .foregroundStyle(.secondary)
        }
        .buttonStyle(.plain)
    }

    private var showsClearButton: Bool {
        switch c.clearButtonMode {
        case "always": return !model.text.isEmpty
        case "whileEditing": return focused && !model.text.isEmpty
        case "unlessEditing": return !focused && !model.text.isEmpty
        default: return false
        }
    }

    @ViewBuilder
    private var background: some View {
        if let argb = c.backgroundColor {
            RoundedRectangle(cornerRadius: CGFloat(c.cornerRadius ?? 0), style: .continuous)
                .fill(Color(argb: argb))
        }
    }

    /// Glass, and only glass, so the whole field including its icons sits on
    /// one material — the same shape the background uses.
    private struct GlassBackground: ViewModifier {
        let config: TextFieldConfig

        func body(content: Content) -> some View {
            if config.glass == true {
                applied(content)
            } else {
                content
            }
        }

        /// `RoundedRectangle` clamps a radius past half its height on its own,
        /// which `layer.cornerRadius` could not — so the app bar's collapsing
        /// search capsule needs no manual clamp any more.
        private var shape: RoundedRectangle {
            RoundedRectangle(
                cornerRadius: CGFloat(config.glassCornerRadius ?? 16), style: .continuous)
        }

        @ViewBuilder
        private func applied(_ content: Content) -> some View {
            GlassEffectContainer { content.glassEffect(glass, in: shape) }
        }

        @available(iOS 26.0, *)
        private var glass: Glass {
            var style: Glass = config.glassVariant == "clear" ? .clear : .regular
            if let tint = config.glassTint { style = style.tint(Color(argb: tint)) }
            if config.glassInteractive ?? true { style = style.interactive() }
            return style
        }
    }

    // MARK: - Mapping

    /// Glass and a rounded background both need the text off their edges.
    private var horizontalInset: CGFloat {
        c.glass == true || CGFloat(c.cornerRadius ?? 0) > 0 ? 16 : 0
    }

    private var verticalAlignment: Alignment {
        switch c.verticalAlignment {
        case "top": return .top
        case "bottom": return .bottom
        default: return .center
        }
    }
}
