import Foundation

/// Creation/update parameters for the native text field platform view,
/// mirroring the customization surface of `CupertinoNativeTextField` on Dart.
@available(iOS 26.0, *)
struct TextFieldConfig: Codable {
    var text: String? = nil
    var placeholder: String? = nil
    var keyboardType: String? = nil  // "text" | "number" | "emailAddress" | ...
    var textInputAction: String? = nil  // "done" | "next" | "search" | ...
    var obscureText: Bool? = nil
    var autocorrect: Bool? = nil
    var enableSuggestions: Bool? = nil
    var textCapitalization: String? = nil  // "none" | "words" | "sentences" | "characters"
    var textAlign: String? = nil  // "left" | "right" | "center" | "start" | "end"
    var maxLength: Int? = nil
    var enabled: Bool? = nil
    var readOnly: Bool? = nil
    var autofocus: Bool? = nil
    var fontSize: Double? = nil
    var fontWeight: Int? = nil  // Flutter FontWeight.index (0...8)
    var textColor: Int? = nil  // ARGB
    var cursorColor: Int? = nil  // ARGB
    var clearButtonMode: String? = nil  // "never" | "whileEditing" | "unlessEditing" | "always"
    var textContentType: String? = nil
    var isDark: Bool? = nil  // Flutter brightness → override UITextField appearance
    var backgroundColor: Int? = nil  // ARGB — nil = transparent (iOS default)
    var cornerRadius: Double? = nil  // rounds the background; nil/0 = square, no inset
    var glass: Bool? = nil  // Liquid Glass background (iOS 26; material fallback below)
    var glassCornerRadius: Double? = nil  // glass shape radius; nil = 16
    var glassVariant: String? = nil  // "regular" | "clear"; nil = regular
    var glassInteractive: Bool? = nil  // touch shimmer on the glass; nil = true
    var glassTint: Int? = nil  // ARGB tint mixed into the glass
    var prefixIcon: IconConfig? = nil  // leading SF Symbol (UITextField.leftView)
    var suffixIcon: IconConfig? = nil  // trailing SF Symbol (UITextField.rightView)
    var verticalAlignment: String? = nil  // "top" | "center" | "bottom"
    /// The bar that rides above the keyboard while this field is focused —
    /// the items of a `ToolbarItemGroup(placement: .keyboard)`.
    ///
    /// An array, not an optional node: `BodyNodeConfig` already stores a
    /// `TextFieldConfig?` for its own field nodes, so a `BodyNodeConfig?`
    /// here would make the two structs recursively contain each other inline
    /// — a value type of infinite size. An array is a reference to heap
    /// storage, so the cycle costs nothing.
    var keyboardToolbar: [BodyNodeConfig]? = nil
}

@available(iOS 26.0, *)
extension TextFieldConfig {
    /// A platform view created without arguments still needs a config.
    static let empty = TextFieldConfig()

    /// Copy with Flutter's brightness applied, for the `setBrightness` call.
    func withIsDark(_ value: Bool) -> TextFieldConfig {
        var copy = self
        copy.isDark = value
        return copy
    }
}
