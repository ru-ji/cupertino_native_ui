import SwiftUI
import UIKit

/// The bar above the keyboard, installed as the focused field's real
/// `inputAccessoryView`.
///
/// SwiftUI's `.toolbar { ToolbarItemGroup(placement: .keyboard) }` is the
/// documented way to do this, and it is what this used to be — but it resolves
/// to nothing when the SwiftUI tree is a child `UIHostingController` embedded
/// in a Flutter platform view, which is how every widget in this package is
/// hosted. `inputAccessoryView` is the UIKit mechanism underneath it, and it
/// does not care where the hosting controller sits.
///
/// The container is a `UIInputView` in the `.keyboard` style, so the bar takes
/// the keyboard's own background and metrics rather than a colour we picked.
@available(iOS 26.0, *)
final class KeyboardAccessoryBar {
    /// Standard accessory height — `UIInputView` draws the keyboard's material
    /// behind it.
    private static let height: CGFloat = 48

    private let model: NativeBodyModel
    private let host: UIHostingController<AnyView>
    let view: UIInputView

    init(nodes: [BodyNodeConfig], isDark: Bool, onEvent: @escaping (String, Any?) -> Void) {
        let model = NativeBodyModel()
        model.seedAll(nodes)
        self.model = model

        let bar = AnyView(
            HStack(spacing: 16) {
                ForEach(Array(nodes.enumerated()), id: \.offset) { index, node in
                    NativeBodyNode(node: node, model: model, onEvent: onEvent)
                        .id(node.id ?? "\(node.type)-\(index)")
                }
            }
            .padding(.horizontal, 16)
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        )

        host = UIHostingController(rootView: bar)
        host.view.backgroundColor = .clear
        host.overrideUserInterfaceStyle = isDark ? .dark : .light

        view = UIInputView(
            frame: CGRect(
                x: 0, y: 0, width: UIScreen.main.bounds.width, height: Self.height),
            inputViewStyle: .keyboard)
        view.autoresizingMask = .flexibleWidth
        host.view.frame = view.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        view.addSubview(host.view)
    }

    /// Installs the bar on whatever is first responder inside `root`, and asks
    /// UIKit to swap it in if the keyboard is already up.
    ///
    /// `inputAccessoryView` is read-only on `UIResponder` and writable on
    /// `UITextField` / `UITextView`, which is what SwiftUI's `TextField` and
    /// `TextEditor` are backed by.
    @discardableResult
    func install(in root: UIView) -> Bool {
        guard let responder = Self.firstResponder(in: root) else { return false }
        if let field = responder as? UITextField {
            guard field.inputAccessoryView !== view else { return true }
            field.inputAccessoryView = view
            field.reloadInputViews()
            return true
        }
        if let textView = responder as? UITextView {
            guard textView.inputAccessoryView !== view else { return true }
            textView.inputAccessoryView = view
            textView.reloadInputViews()
            return true
        }
        return false
    }

    private static func firstResponder(in view: UIView) -> UIView? {
        if view.isFirstResponder { return view }
        for subview in view.subviews {
            if let found = firstResponder(in: subview) { return found }
        }
        return nil
    }
}
