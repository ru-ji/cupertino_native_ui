import Flutter
import SwiftUI
import UIKit

@available(iOS 15.0, *)
class NativeMenuFactory: NSObject, FlutterPlatformViewFactory {
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
        return NativeMenuView(
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
class NativeMenuView: NativeHostingView {
    private var channel: FlutterMethodChannel?

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        messenger: FlutterBinaryMessenger
    ) {
        super.init()
        // So Dart can exempt this view from an edge effect's mask (bar chrome
        // is painted over the effect, not under it).
        _view.viewId = viewId

        channel = FlutterMethodChannel(
            name: "cupertino_widgets/menu_\(viewId)", binaryMessenger: messenger)
        // Push measurements instead of waiting to be polled.
        sizeChannel = channel
        channel?.setMethodCallHandler({
            [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            self?.handle(call, result: result)
        })

        if let argsMap = args as? [String: Any],
            let config = decodeConfig(MenuConfiguration.self, from: argsMap)
        {
            setupSwiftUI(with: config)
        }
    }

    private func setupSwiftUI(with config: MenuConfiguration) {
        let menuView = AdaptiveMenuView(config: config) { [weak self] actionId, value in
            var args: [String: Any] = ["id": actionId]
            if let val = value {
                args["value"] = val
            }
            self?.channel?.invokeMethod("onAction", arguments: args)
        }
        attach(AnyView(menuView))
        // Follows the app's own (possibly forced) theme, not the device's
        // system appearance. The UIMenu's blur/vibrancy chrome is presented
        // in a system overlay window — not in this view's hierarchy — so the
        // scene's windows need the override too, not just the anchor.
        if let isDark = config.isDark {
            let style: UIUserInterfaceStyle = isDark ? .dark : .light
            hostingController?.overrideUserInterfaceStyle = style
            for scene in UIApplication.shared.connectedScenes {
                guard let windowScene = scene as? UIWindowScene else { continue }
                for window in windowScene.windows {
                    window.overrideUserInterfaceStyle = style
                }
            }
        }
    }

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
        case "updateMenu":
            if let argsMap = call.arguments as? [String: Any],
                let config = decodeConfig(MenuConfiguration.self, from: argsMap)
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
