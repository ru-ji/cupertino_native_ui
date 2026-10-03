import Flutter
import UIKit

@available(iOS 15.0, *)
class AlertManager {
    static let shared = AlertManager()

    /// `style`: `.alert` for a centred dialog, `.actionSheet` for the sheet
    /// of choices that rises from the bottom (SwiftUI's `.confirmationDialog`).
    /// An action sheet on iPad is a popover and needs an anchor: `sourceRect`
    /// is in window coordinates, and without one it is centred on the screen.
    func show(
        title: String,
        message: String?,
        actions: [[String: Any]],
        textFields: [[String: Any]] = [],
        isDark: Bool,
        style: UIAlertController.Style = .alert,
        sourceRect: CGRect? = nil,
        result: @escaping FlutterResult
    ) {
        // Find the top-most view controller to present the alert
        guard let window = Self.keyWindow(), 
            let rootVC = window.rootViewController
        else {
            result(FlutterError(code: "NO_WINDOW", message: "No key window found", details: nil))
            return
        }

        let alertController = UIAlertController(
            title: title,
            message: message,
            preferredStyle: style
        )
        // Follows the app's own (possibly forced) theme, not the device's
        // system appearance: same convention as every other native surface.
        alertController.overrideUserInterfaceStyle = isDark ? .dark : .light

        // UIKit's own fields, in the alert. An alert only: an action sheet
        // takes none.
        if style == .alert {
            for field in textFields {
                alertController.addTextField { textField in
                    textField.text = field["text"] as? String
                    textField.placeholder = field["placeholder"] as? String
                    textField.isSecureTextEntry = field["obscureText"] as? Bool ?? false
                    textField.keyboardType = BackingTextField.keyboardType(
                        field["keyboardType"] as? String)
                    textField.autocapitalizationType = BackingTextField.capitalization(
                        field["textCapitalization"] as? String)
                    textField.autocorrectionType =
                        field["autocorrect"] as? Bool == false ? .no : .default
                    textField.textContentType = (field["textContentType"] as? String)
                        .map { UITextContentType(rawValue: $0) }
                }
            }
        }

        for (index, actionData) in actions.enumerated() {
            let title = actionData["title"] as? String ?? ""
            let isDestructive = actionData["isDestructive"] as? Bool ?? false
            let isCancel = actionData["isCancel"] as? Bool ?? false

            var style: UIAlertAction.Style = .default
            if isDestructive {
                style = .destructive
            } else if isCancel {
                style = .cancel
            }

            let action = UIAlertAction(title: title, style: style) {
                [weak alertController] _ in
                // With fields, what was typed too, for their controllers.
                if let fields = alertController?.textFields, !fields.isEmpty {
                    result(["index": index, "texts": fields.map { $0.text ?? "" }])
                } else {
                    result(index)
                }
            }
            alertController.addAction(action)
        }

        // Ensure we present on the top-most controller
        DispatchQueue.main.async {
            let topController = self.getTopViewController(base: rootVC)
            // An action sheet with a source grows out of it: a popover on
            // iPad, and on iOS 26 a bubble on iPhone too, which drops the
            // Cancel button. Without a source on iPhone it is the sheet at the
            // bottom of the screen. Only a regular width needs one anyway: a
            // popover without an anchor traps, so it gets the screen centre.
            let regular = topController?.traitCollection.horizontalSizeClass == .regular
            if let popover = alertController.popoverPresentationController,
                sourceRect != nil || regular
            {
                popover.sourceView = topController?.view
                popover.sourceRect =
                    sourceRect
                    ?? CGRect(
                        x: (topController?.view.bounds.midX ?? 0),
                        y: (topController?.view.bounds.midY ?? 0), width: 0, height: 0)
                if sourceRect == nil { popover.permittedArrowDirections = [] }
            }
            topController?.present(alertController, animated: true, completion: nil)
        }
    }

    /// Scene-based key-window lookup (`UIApplication.windows` is deprecated
    /// since iOS 15). Prefers the key window of a foreground-active scene,
    /// falling back to any connected scene's key window.
    private static func keyWindow() -> UIWindow? {
        let scenes = UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
        let ordered =
            scenes.filter { $0.activationState == .foregroundActive }
            + scenes.filter { $0.activationState != .foregroundActive }
        for scene in ordered {
            if let window = scene.windows.first(where: { $0.isKeyWindow }) {
                return window
            }
        }
        return ordered.first?.windows.first
    }

    private func getTopViewController(base: UIViewController?) -> UIViewController? {
        if let nav = base as? UINavigationController {
            return getTopViewController(base: nav.visibleViewController)
        }
        if let tab = base as? UITabBarController, let selected = tab.selectedViewController {
            return getTopViewController(base: selected)
        }
        if let presented = base?.presentedViewController {
            return getTopViewController(base: presented)
        }
        return base
    }
}
