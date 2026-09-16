import Flutter
import SwiftUI
import UIKit

@available(iOS 26.0, *)
class NativeTextFieldFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return NativeTextFieldView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            messenger: messenger
        )
    }

    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

/// A SwiftUI `TextField` embedded as a Flutter platform view.
///
/// The field itself lives in [AdaptiveTextFieldView]; this class is only the
/// bridge — it owns the shared [TextFieldModel], forwards edits and focus
/// changes to Dart, and applies what Dart pushes back over the channel.
@available(iOS 26.0, *)
class NativeTextFieldView: NativeHostingView {
    private let channel: FlutterMethodChannel
    private let model: TextFieldModel
    private var focusCommandId = 0

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        messenger: FlutterBinaryMessenger
    ) {
        channel = FlutterMethodChannel(
            name: "cupertino_widgets/textfield_\(viewId)", binaryMessenger: messenger)
        let config =
            (args as? [String: Any]).flatMap { decodeConfig(TextFieldConfig.self, from: $0) }
        model = TextFieldModel(config: config ?? TextFieldConfig.empty)

        super.init()
        _view.viewId = viewId

        setupSwiftUI()

        sizeChannel = channel
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    /// Built on first focus and kept: rebuilding it on every focus would
    /// swap the keyboard's accessory under the user.
    private var accessory: KeyboardAccessoryBar?

    /// Puts the bar on the field's responder. Retried on the next runloop
    /// turn: `onChange(of: focused)` can fire a hair before UIKit has made the
    /// backing text field first responder, and there is nothing to install on
    /// until it has.
    private func installKeyboardAccessory() {
        let nodes = model.config.keyboardToolbar ?? []
        guard !nodes.isEmpty else { return }
        let bar =
            accessory
            ?? KeyboardAccessoryBar(
                nodes: nodes, isDark: model.config.isDark == true,
                onEvent: { [weak self] id, value in
                    self?.channel.invokeMethod(
                        "onToolbarEvent", arguments: ["id": id, "value": value])
                })
        accessory = bar
        if bar.install(in: _view) { return }
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            _ = bar.install(in: self._view)
        }
    }

    private func setupSwiftUI() {
        // A text field fills the box Flutter gives it, inset by the 16pt paint room
        // (`withPaintRoomFilling`) so its glass rim and shadow stay inside the view.
        attach(AnyView(content)) { host, container in
            let room: CGFloat = 16
            let insets = [
                host.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: room),
                host.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -room),
                host.topAnchor.constraint(equalTo: container.topAnchor, constant: room),
                host.bottomAnchor.constraint(equalTo: container.bottomAnchor, constant: -room),
            ]
            // Below required: the container is 0x0 until Flutter sizes the
            // platform view, and 16pt of inset on each side of a zero-width
            // box is unsatisfiable. At 999 Auto Layout bends them for that one
            // pass instead of logging a conflict and breaking one at random.
            for constraint in insets { constraint.priority = .defaultHigh + 1 }
            NSLayoutConstraint.activate(insets)
        }
        // The caret, the selection handles and the magnifier draw outside the
        // field's bounds, so this host must not clip — unlike every other
        // hosted view here, whose content has no business leaving its box.
        _view.clipsToBounds = false
    }

    private var content: some View {
        AdaptiveTextFieldView(
            model: model,
            onChanged: { [weak self] text in
                self?.channel.invokeMethod("onChanged", arguments: ["text": text])
            },
            onSubmitted: { [weak self] text in
                self?.channel.invokeMethod("onSubmitted", arguments: ["text": text])
            },
            onEditingComplete: { [weak self] in
                self?.channel.invokeMethod("onEditingComplete", arguments: nil)
            },
            onFocusChange: { [weak self] focused in
                self?.channel.invokeMethod("onFocusChange", arguments: ["focused": focused])
                // The accessory belongs to the responder, which only exists
                // once the field is focused.
                if focused { self?.installKeyboardAccessory() }
            }
        )
    }

    private func setFocus(_ focused: Bool) {
        focusCommandId += 1
        model.focusCommand = (id: focusCommandId, focused: focused)
    }

    // MARK: - Method channel

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // A bitmap of this view, for Flutter to draw in its own layer tree.
        // See PlatformViewSnapshot.
        if call.method == "snapshot" {
            result(PlatformViewSnapshot.capture(view()))
            return
        }
        switch call.method {
        case "getIntrinsicSize":
            result(intrinsicSize())
        case "updateTextField":
            guard let dict = call.arguments as? [String: Any],
                let config = decodeConfig(TextFieldConfig.self, from: dict)
            else {
                result(
                    FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                return
            }
            // Assigned, not rebuilt: the field's state lives in the model, and
            // rebuilding would dismiss the keyboard mid-edit.
            model.config = config
            if let text = config.text, text != model.text { model.text = text }
            result(nil)
        case "setText":
            guard let args = call.arguments as? [String: Any],
                let text = args["text"] as? String
            else {
                result(
                    FlutterError(code: "INVALID_ARGS", message: "Missing text", details: nil))
                return
            }
            if model.text != text { model.text = text }
            result(nil)
        case "focus":
            setFocus(true)
            result(nil)
        case "unfocus":
            setFocus(false)
            result(nil)
        case "setBrightness":
            guard let args = call.arguments as? [String: Any],
                let isDark = (args["isDark"] as? NSNumber)?.boolValue
            else {
                result(
                    FlutterError(code: "INVALID_ARGS", message: "Missing isDark", details: nil))
                return
            }
            model.config = model.config.withIsDark(isDark)
            result(nil)
        case "setContentOpacity":
            // Scroll-driven fade of the field's content while the capsule squeezes.
            guard let args = call.arguments as? [String: Any],
                let opacity = (args["opacity"] as? NSNumber)?.doubleValue
            else {
                result(
                    FlutterError(code: "INVALID_ARGS", message: "Missing opacity", details: nil))
                return
            }
            model.contentOpacity = max(0, min(1, opacity))
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
