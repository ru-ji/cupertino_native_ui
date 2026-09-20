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

    /// Whether the field currently holds focus, so a config push knows whether
    /// the keyboard accessory is live and needs the new toolbar.
    private var isFocused = false

    /// The last `updateTextField` arguments actually applied. A push that
    /// changed nothing is dropped: assigning the same config bumps
    /// `configRevision`, which re-evaluates the SwiftUI body and reseeds the
    /// keyboard toolbar for no reason.
    private var lastAppliedArgs: [String: Any]?

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

        // Before the field exists, so it is created with its accessory.
        syncAccessory(rawToolbar: (args as? [String: Any])?["keyboardToolbar"] as? [Any])
        setupSwiftUI()

        sizeChannel = channel
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    /// Built when a toolbar arrives and kept until the toolbar Dart sent
    /// changes; handed to the field through `model.accessory`.
    private var accessory: KeyboardAccessoryBar?

    /// The `keyboardToolbar` array Dart last sent, compared with `isEqual:` —
    /// a `JSONEncoder` re-encoding is not stable (key order varies), so it
    /// reported a change on every push.
    private var accessoryToolbarPayload: [Any]?

    private func syncAccessory(rawToolbar: [Any]?) {
        let nodes = model.config.keyboardToolbar ?? []
        guard !nodes.isEmpty else {
            accessory = nil
            accessoryToolbarPayload = nil
            model.accessory = nil
            return
        }
        if accessory != nil,
            NSArray(array: accessoryToolbarPayload ?? []).isEqual(to: rawToolbar ?? [])
        {
            accessory?.applyBrightness(model.config.isDark == true)
            return
        }
        let bar = KeyboardAccessoryBar(
            nodes: nodes, isDark: model.config.isDark == true,
            onEvent: { [weak self] id, value in
                self?.channel.invokeMethod(
                    "onToolbarEvent", arguments: ["id": id, "value": value])
            })
        accessory = bar
        accessoryToolbarPayload = rawToolbar
        model.accessory = bar.inputView
    }

    private func setupSwiftUI() {
        // A text field fills the box Flutter gives it, inset by the 16pt paint room
        // (`withPaintRoomFilling`) so its glass rim and shadow stay inside the view.
        attach(AnyView(content)) { [weak self] host, container in
            // Must match Dart's `withPaintRoomFilling(room:)`: only a glass
            // field is given room outside its box, because an inflated
            // platform view overlaps its neighbours and costs a composited
            // layer at every overlap.
            let room: CGFloat = self?.model.config.glass == true ? 16 : 0
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
        // Stay parented while the Flutter engine takes this platform view out
        // of the window on a frame it is not composited (a covering route, a
        // scroll off-screen). Unparented, the hosted UIHostingController drops
        // the field's first responder and the keyboard closes mid-edit.
        _view.keepsParentWhileDetached = true
        // Staying parented is not enough on its own — see
        // [wantsFocusWhenVisible].
        _view.onWindowChanged = { [weak self] window in
            guard let self else { return }
            NativeLog.log(
                "textfield window → \(window == nil ? "nil" : "attached") "
                    + "focused=\(self.isFocused) "
                    + "restore=\(self.wantsFocusWhenVisible) "
                    + "superview=\(self._view.superview == nil ? "nil" : "set")")
            if window == nil {
                // Read on the way *out*, not on the way back: by the time the
                // engine re-adds the view SwiftUI has already reset `focused`.
                self.wantsFocusWhenVisible = self.isFocused
            } else if self.wantsFocusWhenVisible {
                self.wantsFocusWhenVisible = false
                self.setFocus(true)
            }
        }
    }

    /// Whether the field should take focus back when the engine re-adds this
    /// platform view.
    ///
    /// The engine takes a platform view out of the `FlutterView` on any frame
    /// it is not composited, and scrolling a field past the viewport is enough
    /// to stop it being composited. A view outside a window cannot be first
    /// responder, so UIKit resigns the field and the keyboard closes. Nothing
    /// public keeps a responder alive outside a window and the engine offers no
    /// way to decline the removal, so what the plugin can do is put the field
    /// back the moment the view returns — scrolling back then needs no fresh
    /// tap.
    ///
    /// Focus is re-driven through `TextFieldModel.focusCommand`, which
    /// [BackingTextField] applies to its `UITextField`.
    private var wantsFocusWhenVisible = false

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
                guard let self else { return }
                self.isFocused = focused
                self.channel.invokeMethod("onFocusChange", arguments: ["focused": focused])
                NativeLog.log(
                    "field focus → \(focused) "
                        + "window=\(_view.window == nil ? "nil" : "set") "
                        + "superview=\(_view.superview == nil ? "nil" : "set") "
                        + "hostWindow=\(hostingController?.view.window == nil ? "nil" : "set")")
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
            // Nothing visible moved: skip the model assignment and its
            // downstream body re-evaluation (see lastAppliedArgs).
            if let last = lastAppliedArgs,
                NSDictionary(dictionary: dict).isEqual(to: last)
            {
                result(nil)
                return
            }
            lastAppliedArgs = dict
            // Assigned, not rebuilt: the field's state lives in the model, and
            // rebuilding would dismiss the keyboard mid-edit.
            model.config = config
            if let text = config.text, text != model.text { model.text = text }
            syncAccessory(rawToolbar: dict["keyboardToolbar"] as? [Any])
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
            accessory?.applyBrightness(isDark)
            NativeLog.log("setBrightness → \(isDark ? "dark" : "light")")
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
