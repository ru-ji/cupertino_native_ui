import SwiftUI

/// Shared state between the platform view and its SwiftUI body. The platform
/// view owns it and writes to it from the method channel; the view observes.
@available(iOS 26.0, *)
final class TextFieldModel: ObservableObject {
    @Published var config: TextFieldConfig
    @Published var text: String
    @Published var contentOpacity: Double = 1

    /// Bumped by `focus` / `unfocus` so the view can act on a repeated request.
    @Published var focusCommand: (id: Int, focused: Bool)?

    init(config: TextFieldConfig) {
        self.config = config
        self.text = config.text ?? ""
    }
}

/// The package's text field, in SwiftUI end to end — `TextField` /
/// `SecureField`, not a hosted `UITextField`.
///
/// Everything the UIKit version reached for through `UITextField` has a
/// first-class modifier here: autofill through `textContentType`, the keyboard
/// through `keyboardType`, the return key through `submitLabel`, focus through
/// `@FocusState`. Prefix and suffix symbols are ordinary views in an `HStack`
/// rather than `leftView`/`rightView` slots, and the glass goes through the
/// same `GlassEffectContainer` + `.glassEffect(_:in:)` as every other glass
/// surface in this package.
@available(iOS 26.0, *)
struct AdaptiveTextFieldView: View {
    @ObservedObject var model: TextFieldModel

    let onChanged: (String) -> Void
    let onSubmitted: (String) -> Void
    let onEditingComplete: () -> Void
    let onFocusChange: (Bool) -> Void

    @FocusState private var focused: Bool

    private var c: TextFieldConfig { model.config }

    var body: some View {
        row
            .padding(.horizontal, horizontalInset)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .background(background)
            .modifier(GlassBackground(config: c))
            .onChange(of: focused) { onFocusChange($0) }
            .onChange(of: model.focusCommand?.id) { _ in
                if let command = model.focusCommand { focused = command.focused }
            }
            .onAppear { if c.autofocus == true { focused = true } }
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

    @ViewBuilder
    private var field: some View {
        let prompt = c.placeholder.map { Text($0) }
        Group {
            if c.obscureText == true {
                SecureField("", text: binding, prompt: prompt)
            } else {
                TextField("", text: binding, prompt: prompt)
            }
        }
        .focused($focused)
        .frame(maxWidth: .infinity, alignment: verticalAlignment)
        .font(font)
        .foregroundStyle(textColor)
        .tint(cursorColor)
        .multilineTextAlignment(textAlign)
        .keyboardType(keyboardType)
        .submitLabel(submitLabel)
        .textContentType(contentType)
        .textInputAutocapitalization(capitalization)
        .autocorrectionDisabled(c.autocorrect == false)
        .disabled(c.enabled == false)
        .onSubmit {
            onEditingComplete()
            onSubmitted(model.text)
        }
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

    private var font: Font {
        .system(size: CGFloat(c.fontSize ?? 17), weight: weight)
    }

    private var weight: Font.Weight {
        switch c.fontWeight ?? 3 {
        case 0: return .ultraLight
        case 1: return .thin
        case 2: return .light
        case 4: return .medium
        case 5: return .semibold
        case 6: return .bold
        case 7: return .heavy
        case 8: return .black
        default: return .regular
        }
    }

    private var textColor: Color { c.textColor.map { Color(argb: $0) } ?? .primary }
    private var cursorColor: Color? { c.cursorColor.map { Color(argb: $0) } }

    private var textAlign: TextAlignment {
        switch c.textAlign {
        case "center": return .center
        case "right", "end": return .trailing
        default: return .leading
        }
    }

    private var keyboardType: UIKeyboardType {
        switch c.keyboardType {
        case "number", "numberWithOptions", "datetime": return .numbersAndPunctuation
        case "phone": return .phonePad
        case "emailAddress": return .emailAddress
        case "url": return .URL
        case "visiblePassword": return .asciiCapable
        case "name": return .namePhonePad
        default: return .default
        }
    }

    private var submitLabel: SubmitLabel {
        switch c.textInputAction {
        case "go": return .go
        case "search": return .search
        case "send": return .send
        case "next": return .next
        case "done": return .done
        case "continueAction": return .continue
        case "join": return .join
        case "route": return .route
        default: return .return
        }
    }

    private var capitalization: TextInputAutocapitalization {
        switch c.textCapitalization {
        case "words": return .words
        case "sentences": return .sentences
        case "characters": return .characters
        default: return .never
        }
    }

    private var contentType: UITextContentType? {
        guard let name = c.textContentType else { return nil }
        return UITextContentType(rawValue: name)
    }
}

