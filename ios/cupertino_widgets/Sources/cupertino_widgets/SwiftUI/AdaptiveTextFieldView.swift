import SwiftUI

/// Shared state between the platform view and its SwiftUI body. The platform
/// view owns it and writes to it from the method channel; the view observes.
@available(iOS 15.0, *)
final class TextFieldModel: ObservableObject {
    @Published var config: TextFieldConfig {
        didSet { configRevision &+= 1 }
    }
    @Published var text: String
    @Published var contentOpacity: Double = 1

    /// Bumped by `focus` / `unfocus` so the view can act on a repeated request.
    @Published var focusCommand: (id: Int, focused: Bool)?

    /// The sequence behind [focusCommand]. One counter for every driver — the
    /// platform view's own `focus`/`unfocus`, and the re-focus that puts the
    /// responder back after the hosting view left the window — because
    /// `BackingTextField` only acts on a command whose id it has not seen.
    /// Two counters would hand out the same id twice and swallow the second
    /// request, which is a keyboard that never comes back.
    private var focusCommandSeq = 0

    /// Asks the backing field to take (or give up) the responder. Safe to call
    /// outside a view update: the field applies it on the next main-queue turn.
    func requestFocus(_ focused: Bool) {
        focusCommandSeq += 1
        focusCommand = (id: focusCommandSeq, focused: focused)
    }

    /// The keyboard accessory for this field, or nil. Set on the backing
    /// `UITextField` while it is still unfocused, so UIKit presents it in the
    /// same animation as the keyboard — no `reloadInputViews()`.
    @Published var accessory: UIView?

    /// Where the backing `UITextField` sat, in window coordinates, the moment
    /// it took focus.
    ///
    /// Deliberately **not** `@Published`: the only reader is the focus event
    /// on its way to Flutter, and publishing it re-evaluated the field on
    /// every scroll tick — which rebuilt the accessory and made the keyboard
    /// close and re-present itself over and over.
    ///
    /// Read off the real `UITextField` in `textFieldDidBeginEditing` rather
    /// than from a SwiftUI `GeometryReader`, whose `.global` space is the
    /// hosting view's, not the window's, when the tree is embedded in a
    /// platform view.
    var focusFrameInWindow: CGRect = .zero

    /// Bumped whenever `config` is replaced — the toolbar's declared values
    /// reseed on it, without comparing configs in `body`.
    private(set) var configRevision = 0

    init(config: TextFieldConfig) {
        self.config = config
        self.text = config.text ?? ""
    }
}

/// The package's text field: SwiftUI chrome (glass, background) around a
/// `UITextField`, which draws its own icons and clear button — see [BackingTextField] for why the editable part
/// is UIKit (the keyboard toolbar).
@available(iOS 15.0, *)
struct AdaptiveTextFieldView: View {
    @ObservedObject var model: TextFieldModel

    let onChanged: (String) -> Void
    let onSubmitted: (String) -> Void
    let onEditingComplete: () -> Void
    let onFocusChange: (Bool) -> Void
    var onSelectionActive: (Bool) -> Void = { _ in }

    private var c: TextFieldConfig { model.config }

    var body: some View {
        row
            .padding(.horizontal, horizontalInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(background)
            .modifier(GlassBackground(config: c))
            .environment(\.colorScheme, c.isDark == true ? .dark : .light)
    }

    // MARK: - Pieces

    private var row: some View {
        field.opacity(model.contentOpacity)
    }

    private var field: some View {
        BackingTextField(
            model: model,
            text: binding,
            onFocusChange: onFocusChange,
            onSubmit: {
                onEditingComplete()
                onSubmitted(model.text)
            },
            onSelectionActive: onSelectionActive
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
            if config.glass == true, #available(iOS 26.0, *) {
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

        @available(iOS 26.0, *)
        @ViewBuilder
        private func applied(_ content: Content) -> some View {
            GlassEffectContainer { content.glassEffect(glass, in: shape) }
        }

        @available(iOS 26.0, *)
        private var glass: Glass {
            var style: Glass
            switch config.glassVariant {
            case "clear": style = .clear
            case "identity": style = .identity
            default: style = .regular
            }
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
