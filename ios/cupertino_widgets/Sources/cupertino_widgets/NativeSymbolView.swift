import Flutter
import SwiftUI
import UIKit

@available(iOS 26.0, *)
class NativeSymbolFactory: NSObject, FlutterPlatformViewFactory {
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
        return NativeSymbolView(
            frame: frame, viewIdentifier: viewId, arguments: args, messenger: messenger)
    }

    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

/// Hosts a live SwiftUI `Image(systemName:)` so `.symbolEffect` has a view to
/// animate. Self-sizes to the symbol.
@available(iOS 26.0, *)
class NativeSymbolView: NativeHostingView {
    private var channel: FlutterMethodChannel?
    private let model = SymbolModel()

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        messenger: FlutterBinaryMessenger
    ) {
        super.init()
        _view.viewId = viewId

        channel = FlutterMethodChannel(
            name: "cupertino_widgets/symbol_\(viewId)", binaryMessenger: messenger)
        sizeChannel = channel
        channel?.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }

        if let argsMap = args as? [String: Any],
            let config = decodeConfig(SymbolConfig.self, from: argsMap)
        {
            model.config = config
            isDark = config.isDark
        }
        // Attached once and fed by the model from then on: re-attaching would
        // rebuild the Image, and a rebuilt view restarts (or drops) the effect
        // that is the whole point of this widget.
        attach(AnyView(AdaptiveSymbolView(model: model))) { host, container in
            host.setContentHuggingPriority(.required, for: .horizontal)
            host.setContentHuggingPriority(.required, for: .vertical)
            NSLayoutConstraint.activate([
                host.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                host.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            ])
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
        case "updateSymbol":
            if let argsMap = call.arguments as? [String: Any],
                let config = decodeConfig(SymbolConfig.self, from: argsMap)
            {
                isDark = config.isDark
                model.config = config
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

/// Observable box so updates change the rendered symbol without re-attaching
/// the hosting controller.
@available(iOS 26.0, *)
class SymbolModel: ObservableObject {
    @Published var config: SymbolConfig = SymbolConfig(
        name: "questionmark", size: nil, weight: nil, color: nil, renderingMode: nil,
        effect: nil, trigger: nil, repeating: nil, replaceOnChange: nil, isDark: nil)
}
