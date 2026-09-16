import Flutter
import SwiftUI
import UIKit

@available(iOS 26.0, *)
class NativePickerFactory: NSObject, FlutterPlatformViewFactory {
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
        return NativePickerView(
            frame: frame, viewIdentifier: viewId, arguments: args, messenger: messenger)
    }

    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

/// Hosts a SwiftUI `Picker` as a Flutter platform view.
@available(iOS 26.0, *)
class NativePickerView: NativeHostingView {
    private var channel: FlutterMethodChannel?

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        messenger: FlutterBinaryMessenger
    ) {
        super.init()
        _view.viewId = viewId

        channel = FlutterMethodChannel(
            name: "cupertino_widgets/picker_\(viewId)", binaryMessenger: messenger)
        sizeChannel = channel
        channel?.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }

        if let argsMap = args as? [String: Any],
            let config = decodeConfig(PickerConfig.self, from: argsMap)
        {
            setupSwiftUI(with: config)
        }
    }

    private func setupSwiftUI(with config: PickerConfig) {
        isDark = config.isDark
        let picker = AdaptivePickerView(config: config) { [weak self] index in
            self?.channel?.invokeMethod("onChanged", arguments: index)
        }
        // The wheel and the segmented strip fill the box Flutter gave them;
        // a menu or palette picker hugs its own content.
        let fills = config.style == "wheel" || config.style == "segmented"
        if fills {
            attach(AnyView(picker))
        } else {
            attach(AnyView(picker)) { host, container in
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
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "snapshot" {
            result(PlatformViewSnapshot.capture(view()))
            return
        }
        switch call.method {
        case "getIntrinsicSize":
            result(intrinsicSize())
        case "updatePicker":
            if let argsMap = call.arguments as? [String: Any],
                let config = decodeConfig(PickerConfig.self, from: argsMap)
            {
                setupSwiftUI(with: config)
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
