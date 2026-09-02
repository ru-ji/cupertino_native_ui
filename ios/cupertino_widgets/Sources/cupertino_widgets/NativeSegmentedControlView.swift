import Flutter
import SwiftUI
import UIKit

@available(iOS 15.0, *)
class NativeSegmentedControlFactory: NSObject, FlutterPlatformViewFactory {
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
        return NativeSegmentedControlView(
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
class NativeSegmentedControlView: NativeHostingView {
    private var channel: FlutterMethodChannel?

    /// The segment the hosted picker is actually showing. Same trap as the
    /// switch: `AdaptiveSegmentedControlView` seeds its `@State` from the
    /// config once, so swapping the root view later leaves the selection where
    /// the user last put it and a selection pushed from Dart never lands.
    /// Rebuilding the hosting controller applies it; the echo of a tap the user
    /// just made takes the cheap path.
    private var shownIndex = 0

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
            name: "cupertino_widgets/segmented_\(viewId)", binaryMessenger: messenger)
        // Push measurements instead of waiting to be polled.
        sizeChannel = channel
        channel?.setMethodCallHandler({
            [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            self?.handle(call, result: result)
        })

        if let argsMap = args as? [String: Any],
            let config = decodeConfig(SegmentedControlConfig.self, from: argsMap)
        {
            setupSwiftUI(with: config)
        }
    }

    /// The control fills the box Flutter built for it — the branch the button
    /// takes for `expand: true`. A segmented picker has no size worth hugging:
    /// it is a full-width control, and `getIntrinsicSize` reports what SwiftUI
    /// measures so Dart can build the box around it.
    private func setupSwiftUI(with config: SegmentedControlConfig) {
        shownIndex = config.selectedIndex
        attach(AnyView(makeContent(config: config)))
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getIntrinsicSize":
            result(intrinsicSize())
        case "updateSegmentedControl":
            if let argsMap = call.arguments as? [String: Any],
                let config = decodeConfig(SegmentedControlConfig.self, from: argsMap)
            {
                if config.selectedIndex == shownIndex {
                    // Items or tint only: swapping the root view is enough, and
                    // leaves the selection indicator's animation alone.
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

    private func makeContent(config: SegmentedControlConfig) -> AdaptiveSegmentedControlView {
        AdaptiveSegmentedControlView(
            config: config,
            onAction: { [weak self] newValue in
                self?.shownIndex = newValue
                self?.channel?.invokeMethod("onValueChanged", arguments: newValue)
            }
        )
    }
}
