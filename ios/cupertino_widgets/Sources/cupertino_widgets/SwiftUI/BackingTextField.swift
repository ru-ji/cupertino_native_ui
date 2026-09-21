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
    @Binding var focused: Bool
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
        field.keyboardType = keyboardType
        field.returnKeyType = returnKeyType
        field.textContentType = c.textContentType.map { UITextContentType(rawValue: $0) }
        field.autocapitalizationType = capitalization
        field.autocorrectionType = c.autocorrect == false ? .no : .default
        field.spellCheckingType = c.enableSuggestions == false ? .no : .default
        field.isEnabled = c.enabled != false
        field.overrideUserInterfaceStyle = c.isDark == true ? .dark : .light

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
            parent.focused = true
        }
        func textFieldDidEndEditing(_ field: UITextField) { parent.focused = false }

        func textFieldShouldReturn(_ field: UITextField) -> Bool {
            parent.onSubmit()
            return true
        }
    }

    // MARK: - Mapping

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

    private var capitalization: UITextAutocapitalizationType {
        switch c.textCapitalization {
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
