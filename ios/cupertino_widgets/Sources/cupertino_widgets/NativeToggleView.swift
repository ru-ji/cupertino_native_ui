import Flutter
import SwiftUI
import UIKit

@available(iOS 15.0, *)
class NativeToggleFactory: NSObject, FlutterPlatformViewFactory {
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
        return NativeToggleView(
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
class NativeToggleView: NativeHostingView {
    private var channel: FlutterMethodChannel?

    /// The value the hosted switch shows. `AdaptiveToggleView` seeds its `@State`
    /// once, so a new value from Dart needs a rebuilt hosting controller; the echo
    /// of a native flip does not.
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
            name: "cupertino_widgets/toggle_\(viewId)", binaryMessenger: messenger)
        sizeChannel = channel
        channel?.setMethodCallHandler({
            [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            self?.handle(call, result: result)
        })

        if let argsMap = args as? [String: Any],
            let config = decodeConfig(ToggleConfig.self, from: argsMap)
        {
            setupSwiftUI(with: config)
        }
    }

    private func setupSwiftUI(with config: ToggleConfig) {
        shownValue = config.value
        isDark = config.isDark
        let toggleView = makeContent(config: config)
        guard config.label == nil else {
            // A labeled switch is a full-width list row: like the button's
            // `expand`, it fills the box Flutter gave it.
            attach(AnyView(toggleView))
            return
        }
        // Otherwise hug the switch's own size, centered, and keep it inside the box
        // whatever size Flutter gives it.
        attach(AnyView(toggleView)) { host, container in
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

    private func makeContent(config: ToggleConfig) -> AdaptiveToggleView {
        AdaptiveToggleView(
            config: config,
            onAction: { [weak self] newValue in
                self?.shownValue = newValue
                self?.channel?.invokeMethod("onChanged", arguments: newValue)
            }
        )
    }

    /// The switch paints wider than it lays out (shadow, the iOS 26 outer stroke),
    /// so the measured size is padded before Flutter builds its box.
    private static let paintOverflow: CGFloat = 4
    /// Extra width on top of [paintOverflow]: the switch overruns its layout box
    /// the most.
    private static let extraWidth: CGFloat = 3

    override func intrinsicSize() -> [String: Double] {
        let measured = super.intrinsicSize()
        guard let width = measured["width"], let height = measured["height"],
            width > 0, height > 0
        else { return measured }
        return [
            "width": width + Double(Self.paintOverflow + Self.extraWidth),
            "height": height + Double(Self.paintOverflow),
        ]
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
        case "updateToggle":
            if let argsMap = call.arguments as? [String: Any],
                let config = decodeConfig(ToggleConfig.self, from: argsMap)
            {
                // Appearance is owned by the hosting controller, so it must be
                // re-pinned whichever branch this update takes.
                isDark = config.isDark
                if config.value == shownValue {
                    // Label, tint or font only: swap the root view, which keeps
                    // the switch's in-flight animation intact.
                    update(AnyView(makeContent(config: config)))
                } else {
                    setupSwiftUI(with: config)
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
}
