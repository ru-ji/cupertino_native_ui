import Flutter
import SwiftUI
import UIKit

@available(iOS 15.0, *)
class NativeSliderFactory: NSObject, FlutterPlatformViewFactory {
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
        return NativeSliderView(
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
class NativeSliderView: NativeHostingView {
    private var channel: FlutterMethodChannel
    private var viewModel = SliderViewModel()

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        messenger: FlutterBinaryMessenger
    ) {
        channel = FlutterMethodChannel(
            name: "adaptive_slider_\(viewId)", binaryMessenger: messenger)

        super.init()
        // So Dart can exempt this view from an edge effect's mask (bar chrome
        // is painted over the effect, not under it).
        _view.viewId = viewId

        // Push measurements instead of waiting to be polled.
        sizeChannel = channel
        channel.setMethodCallHandler({
            [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            self?.handle(call, result: result)
        })

        if let args = args as? [String: Any] {
            updateViewModel(with: args)
        }

        setupSwiftUI()
    }

    /// The slider fills the box Flutter built for it — the branch the button
    /// takes for `expand: true`; a slider has no natural width to hug. Its
    /// height still comes back through `getIntrinsicSize`, same as the button's.
    private func setupSwiftUI() {
        let sliderView = AdaptiveSliderView(viewModel: viewModel) { [weak self] value in
            self?.channel.invokeMethod("onChanged", arguments: value)
        }
        attach(AnyView(sliderView))
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
        case "updateProps":
            guard let args = call.arguments as? [String: Any] else {
                result(
                    FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                return
            }
            // No re-attach: the slider's state lives in an `ObservableObject`
            // this bridge owns, so an assignment already reaches the view —
            // and rebuilding mid-drag would drop the gesture.
            updateViewModel(with: args)
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func updateViewModel(with args: [String: Any]) {
        if let value = args["value"] as? NSNumber {
            viewModel.value = value.doubleValue
        }
        if let min = args["min"] as? NSNumber {
            viewModel.min = min.doubleValue
        }
        if let max = args["max"] as? NSNumber {
            viewModel.max = max.doubleValue
        }
        if let isEnabled = args["isEnabled"] as? Bool {
            viewModel.isEnabled = isEnabled
        }

        // Colors
        if let activeColorVal = args["activeColor"] as? Int {
            viewModel.activeColor = Color(argb: activeColorVal)
        } else {
            viewModel.activeColor = nil
        }

        if let thumbColorVal = args["thumbColor"] as? Int {
            viewModel.thumbColor = Color(argb: thumbColorVal)
        } else {
            viewModel.thumbColor = nil
        }
    }
}
