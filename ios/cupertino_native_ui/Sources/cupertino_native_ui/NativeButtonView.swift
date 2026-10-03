import Flutter
import SwiftUI
import UIKit

@available(iOS 15.0, *)
class NativeButtonFactory: NSObject, FlutterPlatformViewFactory {
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
        return NativeButtonView(
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
class NativeButtonView: NativeHostingView {
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
            name: "cupertino_native_ui/button_\(viewId)", binaryMessenger: messenger)
        sizeChannel = channel
        channel?.setMethodCallHandler({
            [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            self?.handle(call, result: result)
        })

        if let argsMap = args as? [String: Any],
            let config = decodeConfig(ButtonConfig.self, from: argsMap)
        {
            setupSwiftUI(with: config)
        }
    }

    /// `update` is true for every call after the first: it swaps the hosted
    /// SwiftUI view's `rootView` in place instead of tearing down and
    /// recreating the `UIHostingController`. A title/state change (e.g. an
    /// "Add" ↔ "Remove" toggle) used to go through `attach` here on every
    /// update, which discarded the in-flight press gesture and
    /// `ButtonStyleConfiguration.isPressed` animation along with the old
    /// controller: a tap mid-press would see the button snap back to idle
    /// because it was, underneath, a brand-new button.
    private func setupSwiftUI(with config: ButtonConfig, update: Bool = false) {
        isDark = config.isDark
        appearanceDark = config.appearanceDark
        let buttonView = AdaptiveButtonView(config: config) { [weak self] in
            self?.channel?.invokeMethod("onPressed", arguments: nil)
        }
        if update, hostingController != nil {
            self.update(AnyView(buttonView))
            return
        }
        guard config.expand != true else {
            // expand: true is explicitly "fill the box Flutter gave me".
            attach(AnyView(buttonView))
            return
        }
        // Otherwise size the hosting view to the button's own content and
        // center it, instead of stretching it across the container.
        //
        // Flutter sizes a transformed platform view's box to the ROTATED
        // BOUNDING BOX: at 45° a capsule button's box becomes square. A
        // stretched button fills that box, and since its border shape is a
        // capsule, a square capsule renders as the big circle seen when
        // rotating. Pinning to the content's natural size keeps the button
        // (and the glass material painting its background) at the right size
        // and shape under any transform.
        attach(AnyView(buttonView)) { host, container in
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
        case "updateButton":
            if let argsMap = call.arguments as? [String: Any],
                let config = decodeConfig(ButtonConfig.self, from: argsMap)
            {
                setupSwiftUI(with: config, update: true)
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
