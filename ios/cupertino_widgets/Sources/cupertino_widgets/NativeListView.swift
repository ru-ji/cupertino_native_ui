import Flutter
import SwiftUI
import UIKit

@available(iOS 15.0, *)
class NativeListFactory: NSObject, FlutterPlatformViewFactory {
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
        return NativeListView(
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

/// Hosts a native SwiftUI `List`/`Form` (see `AdaptiveListView`) as a Flutter
/// platform view. Self-sizes to its content height (measured against the
/// Flutter-provided width) so it can sit inside a Flutter scroll view.
@available(iOS 15.0, *)
class NativeListView: NativeHostingView {
    private var channel: FlutterMethodChannel?

    /// The toggle-row values the hosted list is actually showing. Same trap as
    /// the switch and the segmented control: `AdaptiveListView` seeds its
    /// `@State` from the config once, so a row's value changed from Dart never
    /// reaches the screen through a root-view swap. Rebuilding the hosting
    /// controller applies it; every other edit — labels, sections, tint — takes
    /// the cheap path, which is the common one for a list.
    private var shownToggles: [String: Bool] = [:]

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
            name: "cupertino_widgets/list_\(viewId)", binaryMessenger: messenger)
        // Push measurements instead of waiting to be polled.
        sizeChannel = channel
        channel?.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }

        let argsMap = args as? [String: Any]
        if let argsMap = argsMap, let config = decodeConfig(ListConfig.self, from: argsMap) {
            setupSwiftUI(with: config, isDark: (argsMap["isDark"] as? NSNumber)?.boolValue)
        }
    }

    /// The list fills the box Flutter built for it — the branch the button
    /// takes for `expand: true`. Its height still travels the same round trip
    /// as the button's, through the `intrinsicSize()` override below.
    private func setupSwiftUI(with config: ListConfig, isDark: Bool?) {
        shownToggles = Self.toggleValues(in: config)
        attach(AnyView(makeContent(config)))
        _view.backgroundColor = .clear
        if let isDark = isDark {
            hostingController?.overrideUserInterfaceStyle = isDark ? .dark : .light
        }
        scheduleSizeReports()
    }

    private static func toggleValues(in config: ListConfig) -> [String: Bool] {
        var values: [String: Bool] = [:]
        for section in config.sections {
            for row in section.rows where row.type == "toggle" {
                values[row.id] = row.toggleValue ?? false
            }
        }
        return values
    }

    private func makeContent(_ config: ListConfig) -> AnyView {
        if #available(iOS 15.0, *) {
            return AnyView(
                AdaptiveListView(
                    config: config,
                    onRowTap: { [weak self] id in
                        self?.channel?.invokeMethod("onRowTap", arguments: ["id": id])
                    },
                    onToggle: { [weak self] id, value in
                        self?.shownToggles[id] = value
                        self?.channel?.invokeMethod(
                            "onToggle", arguments: ["id": id, "value": value])
                    }
                ))
        } else {
            return AnyView(Text("CupertinoNativeList requires iOS 15.0+"))
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getIntrinsicSize":
            result(intrinsicSize())
        case "updateList":
            if let argsMap = call.arguments as? [String: Any],
                let config = decodeConfig(ListConfig.self, from: argsMap)
            {
                let isDark = (argsMap["isDark"] as? NSNumber)?.boolValue
                if Self.toggleValues(in: config) == shownToggles {
                    update(AnyView(makeContent(config)))
                    if let isDark = isDark {
                        hostingController?.overrideUserInterfaceStyle = isDark ? .dark : .light
                    }
                    scheduleSizeReports()
                } else {
                    setupSwiftUI(with: config, isDark: isDark)
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

    /// Measures the list against the Flutter-provided *width* (a `List` needs a
    /// finite width to lay out and report its full content height) rather than
    /// the base class's unbounded measurement.
    override func intrinsicSize() -> [String: Double] {
        let size = measuredSize()
        return ["width": Double(size.width), "height": Double(size.height)]
    }

    private func measuredSize() -> CGSize {
        guard let host = hostingController else { return .zero }
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        let width = _view.bounds.width > 1 ? _view.bounds.width : UIScreen.main.bounds.width

        var height: CGFloat = 0
        // Primary: sizeThatFits asks the UIHostingController for the size
        // its SwiftUI content needs at the given width — the most reliable
        // measurement for a List/Form that self-sizes to its rows.
        let fittingSize = host.sizeThatFits(
            in: CGSize(width: width, height: .greatestFiniteMagnitude))
        if fittingSize.height > 1 && fittingSize.height < 100_000 {
            height = fittingSize.height
        }
        // Fallback: iOS 16+ sizingOptions == .intrinsicContentSize
        if height <= 1, #available(iOS 16.0, *) {
            let intrinsic = host.view.intrinsicContentSize.height
            if intrinsic > 1 && intrinsic < 100_000 { height = intrinsic }
        }
        // Fallback: UIKit auto-layout fitting
        if height <= 1 {
            height = host.view.systemLayoutSizeFitting(
                CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
                withHorizontalFittingPriority: .required,
                verticalFittingPriority: .fittingSizeLevel).height
        }
        return CGSize(width: width, height: height)
    }

    /// Pushes the measured content height to Flutter as layout settles (initial
    /// render, cell rendering, font/async loads), so the fixed platform-view
    /// box grows to fit instead of clipping content.
    private func scheduleSizeReports() {
        let delays: [Double] = [0.0, 0.1, 0.3, 0.6, 1.0, 1.5, 2.0]
        for delay in delays {
            DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [weak self] in
                self?.reportContentSize()
            }
        }
    }

    private func reportContentSize() {
        let height = measuredSize().height
        guard height > 1 else { return }
        channel?.invokeMethod("onContentSize", arguments: ["height": Double(height)])
    }
}
