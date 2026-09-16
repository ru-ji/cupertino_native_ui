import Flutter
import SwiftUI
import UIKit

@available(iOS 26.0, *)
class NativeProgressFactory: NSObject, FlutterPlatformViewFactory {
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
        return NativeProgressView(
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

@available(iOS 26.0, *)
class NativeProgressView: NativeHostingView {
    private var channel: FlutterMethodChannel?

    /// The style the hosted view was attached with. Circular and linear are laid
    /// out by different constraints, and constraints are installed at attach
    /// time — so a style change is the one edit a root-view swap cannot deliver.
    private var shownStyle = 0

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        messenger: FlutterBinaryMessenger
    ) {
        super.init()
        _view.viewId = viewId

        channel = FlutterMethodChannel(
            name: "cupertino_widgets/progress_\(viewId)", binaryMessenger: messenger)
        sizeChannel = channel
        channel?.setMethodCallHandler({
            [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            self?.handle(call, result: result)
        })

        if let argsMap = args as? [String: Any] {
            setupSwiftUI(with: argsMap)
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
        case "updateProgress":
            if let args = call.arguments as? [String: Any] {
                // Appearance is owned by the hosting controller, so it must be
                // re-pinned whichever branch this update takes.
                isDark = args["isDark"] as? Bool
                if args["style"] as? Int ?? 0 == shownStyle {
                    // Value, total or label only: swapping the root view keeps
                    // a determinate bar's progress animating instead of
                    // restarting it on every tick.
                    update(AnyView(makeContent(with: args)))
                } else {
                    setupSwiftUI(with: args)
                }
                result(nil)
            } else {
                result(
                    FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func setupSwiftUI(with args: [String: Any]) {
        let style = args["style"] as? Int ?? 0
        shownStyle = style
        // Appearance is owned by the hosting controller, not the content.
        isDark = args["isDark"] as? Bool
        attach(
            AnyView(makeContent(with: args)),
            configureConstraints: { host, container in
                NSLayoutConstraint.activate([
                    host.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                    host.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                    host.leadingAnchor.constraint(greaterThanOrEqualTo: container.leadingAnchor),
                    host.trailingAnchor.constraint(lessThanOrEqualTo: container.trailingAnchor),
                ])
                // If linear, stretch to the full width
                if style == 1 {
                    host.widthAnchor.constraint(equalTo: container.widthAnchor).isActive = true
                }
            })
    }

    private func makeContent(with args: [String: Any]) -> AdaptiveProgressView {
        let value = args["value"] as? Double
        let total = args["total"] as? Double ?? 1.0
        let label = args["label"] as? String
        let style = args["style"] as? Int ?? 0
        let colorInt = args["color"] as? Int

        let color: Color? = colorInt != nil ? Color(argb: colorInt!) : nil

        return AdaptiveProgressView(
            value: value,
            total: total,
            label: label,
            style: style,
            color: color
        )
    }
}
