import SwiftUI
import UIKit

/// The editable part of [AdaptiveTextFieldView]: a real `UITextField`.
///
/// ## Why not SwiftUI's `TextField`
///
/// The keyboard toolbar is the field's `inputAccessoryView` — the same UIKit
/// slot SwiftUI's `.keyboard` placement fills. SwiftUI's `TextField` owns that
/// slot on its backing field and re-asserts its own `InputAccessoryGenerator`
/// as the field takes focus, so an accessory could only be attached *after*
/// focus, followed by `reloadInputViews()`: the keyboard presented, then grew
/// by the bar a beat later, and moving between fields re-ran that reload in the
/// middle of a responder change (the dead toolbar buttons).
///
/// A field we own is assigned its accessory while unfocused, and UIKit builds
/// the input views around it — one presentation, and field-to-field switches
/// handled by UIKit itself.
@available(iOS 15.0, *)
struct BackingTextField: UIViewRepresentable {
    @ObservedObject var model: TextFieldModel
    @Binding var text: String
    /// Called straight from the delegate, as the field takes or gives up the
    /// responder — before the keyboard starts to rise. Not through a SwiftUI
    /// state and `.onChange`: that waited for the next view update, and the
    /// keyboard was already moving when Flutter learned which field to lift.
    let onFocusChange: (Bool) -> Void
    let onSubmit: () -> Void

    private var c: TextFieldConfig { model.config }

    func makeCoordinator() -> Coordinator { Coordinator(self) }

    func makeUIView(context: Context) -> UITextField {
        let field = FocusReportingTextField()
        field.delegate = context.coordinator
        field.addTarget(
            context.coordinator, action: #selector(Coordinator.editingChanged(_:)),
            for: .editingChanged)
        field.setContentHuggingPriority(.defaultLow, for: .horizontal)
        field.setContentCompressionResistancePriority(.defaultLow, for: .horizontal)
        // `autofocus`: a field outside a window cannot become first responder.
        field.onFirstWindow = { [weak field] in
            if c.autofocus == true { field?.becomeFirstResponder() }
        }
        return field
    }

    func updateUIView(_ field: UITextField, context: Context) {
        context.coordinator.parent = self
        if field.text != text { field.text = text }
        field.placeholder = c.placeholder
        field.isSecureTextEntry = c.obscureText == true
        field.font = .systemFont(ofSize: CGFloat(c.fontSize ?? 17), weight: weight)
        field.textColor = c.textColor.map { UIColor(Color(argb: $0)) } ?? .label
        field.tintColor = c.cursorColor.map { UIColor(Color(argb: $0)) }
        field.textAlignment = textAlign
        field.keyboardType = Self.keyboardType(c.keyboardType)
        field.returnKeyType = returnKeyType
        field.textContentType = c.textContentType.map { UITextContentType(rawValue: $0) }
        field.autocapitalizationType = Self.capitalization(c.textCapitalization)
        field.autocorrectionType = c.autocorrect == false ? .no : .default
        field.spellCheckingType = c.enableSuggestions == false ? .no : .default
        field.isEnabled = c.enabled != false
        field.overrideUserInterfaceStyle = c.isDark == true ? .dark : .light
        field.clearButtonMode = clearButtonMode

        // UIKit's own side views: drawn inside the field, the text laid out
        // between them. Rebuilt only when the icon changes.
        let gap = CGFloat(c.iconSpacing ?? 8)
        let rebuild = gap != context.coordinator.gap
        context.coordinator.gap = gap
        if rebuild || c.prefixIcon != context.coordinator.prefix {
            context.coordinator.prefix = c.prefixIcon
            field.leftView = c.prefixIcon.map { Self.sideView($0, gap: gap, onTrailing: true) }
        }
        field.leftViewMode = field.leftView == nil ? .never : .always
        if rebuild || c.suffixIcon != context.coordinator.suffix {
            context.coordinator.suffix = c.suffixIcon
            field.rightView = c.suffixIcon.map { Self.sideView($0, gap: gap, onTrailing: false) }
        }
        field.rightViewMode = field.rightView == nil ? .never : .always

        if field.inputAccessoryView !== model.accessory {
            field.inputAccessoryView = model.accessory
            // Only a toolbar that changed *while editing* needs the reload;
            // the normal path attaches before focus and needs none.
            if field.isFirstResponder { field.reloadInputViews() }
        }

        if let command = model.focusCommand, command.id != context.coordinator.lastFocusCommand {
            context.coordinator.lastFocusCommand = command.id
            // Deferred: responder changes inside a view update are unsafe.
            DispatchQueue.main.async {
                if command.focused { field.becomeFirstResponder() } else { field.resignFirstResponder() }
            }
        }
    }

    final class Coordinator: NSObject, UITextFieldDelegate {
        var parent: BackingTextField
        var lastFocusCommand: Int?
        var prefix: IconConfig?
        var suffix: IconConfig?
        var gap: CGFloat?

        init(_ parent: BackingTextField) { self.parent = parent }

        @objc func editingChanged(_ field: UITextField) {
            parent.text = field.text ?? ""
            // The binding may refuse (readOnly) or trim (maxLength).
            if field.text != parent.text { field.text = parent.text }
        }

        func textFieldDidBeginEditing(_ field: UITextField) {
            // Before the focus report goes out: Flutter reads this to reveal
            // the row rather than the whole platform view.
            parent.model.focusFrameInWindow = field.convert(field.bounds, to: nil)
            parent.onFocusChange(true)
        }
        func textFieldDidEndEditing(_ field: UITextField) { parent.onFocusChange(false) }

        /// The native clear button: refused on a read-only field, reported
        /// like any other edit otherwise.
        func textFieldShouldClear(_ field: UITextField) -> Bool {
            guard parent.model.config.readOnly != true else { return false }
            parent.text = ""
            return true
        }

        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            parent.onSubmit()
            return true
        }
    }

    // MARK: - Mapping

    private var clearButtonMode: UITextField.ViewMode {
        switch c.clearButtonMode {
        case "always": return .always
        case "whileEditing": return .whileEditing
        case "unlessEditing": return .unlessEditing
        default: return .never
        }
    }

    /// An SF Symbol for `leftView` / `rightView`, `gap` off the text: UIKit
    /// lays the side view flush against it.
    private static func sideView(_ icon: IconConfig, gap: CGFloat, onTrailing gapOnTrailing: Bool)
        -> UIView
    {
        let weight: UIImage.SymbolWeight
        switch icon.weight {
        case "light": weight = .light
        case "medium": weight = .medium
        case "semibold": weight = .semibold
        case "bold": weight = .bold
        default: weight = .regular
        }
        let color = icon.color.map { UIColor(Color(argb: $0)) } ?? .label
        var config = UIImage.SymbolConfiguration(
            pointSize: CGFloat(icon.size ?? 17), weight: weight)
        switch icon.renderingMode {
        case "hierarchical":
            config = config.applying(UIImage.SymbolConfiguration(hierarchicalColor: color))
        case "multicolor":
            config = config.applying(UIImage.SymbolConfiguration.preferringMulticolor())
        default: break
        }
        let image = UIImageView(
            image: UIImage(systemName: icon.sfSymbol ?? "questionmark", withConfiguration: config))
        image.tintColor = color
        image.contentMode = .center

        let side = UIView()
        image.translatesAutoresizingMaskIntoConstraints = false
        side.addSubview(image)
        NSLayoutConstraint.activate([
            image.topAnchor.constraint(equalTo: side.topAnchor),
            image.bottomAnchor.constraint(equalTo: side.bottomAnchor),
            image.leadingAnchor.constraint(
                equalTo: side.leadingAnchor, constant: gapOnTrailing ? 0 : gap),
            image.trailingAnchor.constraint(
                equalTo: side.trailingAnchor, constant: gapOnTrailing ? -gap : 0),
        ])
        return side
    }

    private var weight: UIFont.Weight {
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

    private var textAlign: NSTextAlignment {
        switch c.textAlign {
        case "center": return .center
        case "right", "end": return .right
        default: return .natural
        }
    }

    /// Shared with the text editor.
    static func keyboardType(_ name: String?) -> UIKeyboardType {
        switch name {
        case "number", "numberWithOptions", "datetime": return .numbersAndPunctuation
        case "phone": return .phonePad
        case "emailAddress": return .emailAddress
        case "url": return .URL
        case "visiblePassword": return .asciiCapable
        case "name": return .namePhonePad
        default: return .default
        }
    }

    private var returnKeyType: UIReturnKeyType {
        switch c.textInputAction {
        case "go": return .go
        case "search": return .search
        case "send": return .send
        case "next": return .next
        case "done": return .done
        case "continueAction": return .continue
        case "join": return .join
        case "route": return .route
        default: return .default
        }
    }

    static func capitalization(_ name: String?) -> UITextAutocapitalizationType {
        switch name {
        case "words": return .words
        case "sentences": return .sentences
        case "characters": return .allCharacters
        default: return .none
        }
    }
}

/// Runs `onFirstWindow` once, the first time the field enters a window.
@available(iOS 15.0, *)
private final class FocusReportingTextField: UITextField {
    var onFirstWindow: (() -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        guard window != nil, let run = onFirstWindow else { return }
        onFirstWindow = nil
        DispatchQueue.main.async(execute: run)
    }
}
