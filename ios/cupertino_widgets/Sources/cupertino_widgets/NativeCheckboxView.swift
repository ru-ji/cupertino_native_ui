import Flutter
import SwiftUI
import UIKit

@available(iOS 15.0, *)
class NativeCheckboxFactory: NSObject, FlutterPlatformViewFactory {
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
        return NativeCheckboxView(
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

@available(iOS 15.0, *)
class NativeCheckboxView: NativeHostingView {
    private var channel: FlutterMethodChannel?

    /// The value the hosted box shows. The view is `Binding`-driven, so a new
    /// value from Dart updates the same binding; the echo of a native tap
    /// does too.
    private var shownValue = false

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        messenger: FlutterBinaryMessenger
    ) {
        super.init()
        _view.viewId = viewId

        channel = FlutterMethodChannel(
            name: "cupertino_widgets/checkbox_\(viewId)", binaryMessenger: messenger)
        sizeChannel = channel
        channel?.setMethodCallHandler({
            [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            self?.handle(call, result: result)
        })

        if let argsMap = args as? [String: Any],
            let config = decodeConfig(CheckboxConfig.self, from: argsMap)
        {
            setupSwiftUI(with: config)
        }
    }

    private func setupSwiftUI(with config: CheckboxConfig) {
        shownValue = config.value
        isDark = config.isDark
        let checkboxView = makeContent(config: config)
        guard config.label == nil else {
            // A labeled checkbox is a full-width list row: like the button's
            // `expand`, it fills the box Flutter gave it.
            attach(AnyView(checkboxView))
            return
        }
        // Otherwise hug the 44pt touch target, centered, and keep it inside
        // the box whatever size Flutter gives it.
        attach(AnyView(checkboxView)) { host, container in
            host.setContentHuggingPriority(.required, for: .horizontal)
            host.setContentHuggingPriority(.required, for: .vertical)
            NSLayoutConstraint.activate([
                host.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                host.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                host.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor),
                host.heightAnchor.constraint(lessThanOrEqualTo: container.heightAnchor),
            ])
        }
    }

    private func makeContent(config: CheckboxConfig) -> AdaptiveCheckboxView {
        AdaptiveCheckboxView(
            config: config,
            isOn: Binding(
                get: { [weak self] in self?.shownValue ?? config.value },
                set: { [weak self] newValue in
                    self?.shownValue = newValue
                    self?.channel?.invokeMethod("onChanged", arguments: newValue)
                }
            )
        )
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // A bitmap of this view, for Flutter to draw in its own layer tree.
        // See PlatformViewSnapshot.
        if call.method == "snapshot" {
            result(PlatformViewSnapshot.capture(view()))
            return
        }
        switch call.method {
        case "cancelTouches":
            cancelTouches()
            result(nil)
        case "getIntrinsicSize":
            result(intrinsicSize())
        case "updateCheckbox":
            if let argsMap = call.arguments as? [String: Any],
                let config = decodeConfig(CheckboxConfig.self, from: argsMap)
            {
                // Appearance is owned by the hosting controller, so it must
                // be re-pinned whichever branch this update takes.
                isDark = config.isDark
                shownValue = config.value
                // The view reads the binding, so swapping the root is enough:
                // no controller rebuild, no in-flight animation lost.
                update(AnyView(makeContent(config: config)))
                result(nil)
            } else {
                result(
                    FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}
