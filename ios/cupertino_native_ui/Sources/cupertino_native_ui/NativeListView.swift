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

/// Hosts a native SwiftUI `List`/`Form` (see `AdaptiveSystemListView`) as a Flutter
/// platform view. Self-sizes to its content height (measured against the
/// Flutter-provided width) so it can sit inside a Flutter scroll view.
@available(iOS 15.0, *)
class NativeListView: NativeHostingView {
    private var channel: FlutterMethodChannel?

    /// The toggle-row values the hosted list is actually showing. Same trap as
    /// the switch and the segmented control: `AdaptiveSystemListView` seeds its
    /// `@State` from the config once, so a row's value changed from Dart never
    /// reaches the screen through a root-view swap. Rebuilding the hosting
    /// controller applies it; every other edit (labels, sections, tint) takes
    /// the cheap path, which is the common one for a list.
    private var shownToggles: [String: Bool] = [:]

    /// The content height the system list's probe has reported, in points.
    ///
    /// A `List` has **no intrinsic height**: `sizeThatFits` hands back whatever
    /// frame the list was given, and `AdaptiveSystemListView` starts at
    /// `UIScreen.main.bounds.height * 2` so every row lays out and its probe can
    /// measure them. That placeholder is finite and plausible, so the base
    /// class's measurement published it to Dart as the list's intrinsic size,
    /// which sized the Flutter box to *twice the screen*. On a body that is a
    /// Flutter `Column` of lists (the sheet's form) the boxes then added up to
    /// ~3700pt of content inside one sheet, which is the endless scroll.
    ///
    /// The probe is the only thing that knows the real height, so once it has
    /// one it is the only source this view reports from, see the
    /// `intrinsicSize()` override.
    private var systemListHeight: CGFloat?

    /// Keyboard bars for the fields transcribed into rows, and the models
    /// those rows render from.
    ///
    /// Both live here, not in a SwiftUI view: a `View`'s `init` runs on every
    /// re-evaluation, so a bar built there was rebuilt and freed every frame,
    /// and the accessory a focused field pointed at was already dead.
    private let rowStore = TrailingRowStore()

    /// The transcribed field that currently holds the responder, as
    /// `"rowId.fieldId"`, or nil. Kept from the `.focused` reports the rows
    /// send, so the responder can be put back, see [refocusOnReattach].
    private var focusedFieldKey: String?

    /// The field to put the responder back on when this view next enters a
    /// window, as `"rowId.fieldId"`, or nil.
    ///
    /// Captured on the way *out*, and it has to be the key rather than a flag:
    /// leaving the window resigns the field, that blur travels to SwiftUI as a
    /// `focused == false` change, and the report it sends back clears
    /// [focusedFieldKey] a turn later. By the time the engine re-adds the view
    /// there is nothing left to read the intent off.
    ///
    /// Only ever set while a field genuinely held the responder, so a page
    /// whose route dismissed the keyboard first (`endEditing`, from
    /// `RouteKeyboardDismissal` on the Dart side) has nothing to restore and
    /// the keyboard does not come back on the way out.
    ///
    /// The list hosts real `UITextField`s now that a row's `trailing` can be a
    /// `CupertinoNativeTextField`, and the engine takes a platform view out of
    /// the `FlutterView` on any frame it is not composited: scrolling is
    /// enough. A view outside a window cannot be first responder, so UIKit
    /// resigns the field and the keyboard closes mid-edit. Nothing public keeps
    /// a responder alive outside a window, so the fix is to put it back the
    /// moment the view returns. The standalone field has done this from the
    /// start; the list needed the same treatment once fields moved into it.
    private var refocusOnReattach: String?

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        messenger: FlutterBinaryMessenger
    ) {
        super.init()
        _view.viewId = viewId

        channel = FlutterMethodChannel(
            name: "cupertino_native_ui/list_\(viewId)", binaryMessenger: messenger)
        sizeChannel = channel
        channel?.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }

        let argsMap = args as? [String: Any]
        if let argsMap = argsMap, let config = decodeConfig(ListConfig.self, from: argsMap) {
            setupSwiftUI(with: config, isDark: (argsMap["isDark"] as? NSNumber)?.boolValue)
        }
    }

    /// The list fills the box Flutter built for it: the branch the button
    /// takes for `expand: true`. Its height still travels the same round trip
    /// as the button's, through the `intrinsicSize()` override below.
    private func setupSwiftUI(with config: ListConfig, isDark: Bool?) {
        shownToggles = Self.toggleValues(in: config)
        self.isDark = isDark
        attach(AnyView(makeContent(config)))
        _view.backgroundColor = .clear
        // Stay parented while the engine takes this platform view out of the
        // window on a frame it is not composited. Unparented, the hosted
        // UIHostingController drops its field's first responder: the same trap
        // NativeTextFieldView documents.
        _view.keepsParentWhileDetached = true
        // Staying parented is not enough on its own: the container still leaves
        // the window, so the responder has to be re-driven on the way back.
        _view.onWindowChanged = { [weak self] window in
            guard let self else { return }
            NativeLog.log(
                "list window → \(window == nil ? "nil" : "attached") "
                    + "focused=\(self.focusedFieldKey ?? "none") "
                    + "restore=\(self.refocusOnReattach ?? "none")")
            if window == nil {
                self.refocusOnReattach = self.focusedFieldKey
            } else if let key = self.refocusOnReattach {
                self.refocusOnReattach = nil
                self.rowStore.refocus(key: key)
                NativeLog.log("list refocus → \(key)")
            }
        }
    }

    /// A row's `.focused` report is the only place that says which transcribed
    /// field holds the responder; the value carries the field's own frame, and
    /// `focused` says whether it took or gave it up.
    private func noteTranscribedFocus(rowId: String, nodeId: String, value: Any?) {
        let suffix = ".focused"
        guard nodeId.hasSuffix(suffix) else { return }
        let key = "\(rowId).\(nodeId.dropLast(suffix.count))"
        let focused = (value as? [String: Any])?["focused"] as? Bool ?? false
        if focused {
            focusedFieldKey = key
        } else if focusedFieldKey == key {
            focusedFieldKey = nil
        }
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

    /// The system `List`: radius, row height and margins are the system's own.
    private func makeContent(_ config: ListConfig) -> AnyView {
        AnyView(
            AdaptiveSystemListView(
                config: config, store: rowStore,
                onRowTap: { [weak self] id in
                    self?.channel?.invokeMethod("onRowTap", arguments: ["id": id])
                },
                onToggle: { [weak self] id, value in
                    self?.shownToggles[id] = value
                    self?.channel?.invokeMethod("onToggle", arguments: ["id": id, "value": value])
                },
                onSelectionChanged: { [weak self] ids in
                    self?.channel?.invokeMethod("onSelectionChanged", arguments: ["ids": ids])
                },
                onSwipeAction: { [weak self] rowId, actionId in
                    self?.channel?.invokeMethod(
                        "onSwipeAction", arguments: ["rowId": rowId, "actionId": actionId])
                },
                onReorder: { [weak self] section, from, to in
                    self?.channel?.invokeMethod(
                        "onReorder", arguments: ["section": section, "from": from, "to": to])
                },
                onTrailingEvent: { [weak self] rowId, nodeId, value in
                    self?.noteTranscribedFocus(rowId: rowId, nodeId: nodeId, value: value)
                    NativeLog.log("list trailing event \(rowId).\(nodeId) = \(String(describing: value))")
                    self?.channel?.invokeMethod(
                        "onTrailingEvent",
                        arguments: ["rowId": rowId, "nodeId": nodeId, "value": value])
                },
                onHeight: { [weak self] h, animated in
                    // The probe's number is the list's real height: keep it for
                    // `getIntrinsicSize`, and push it so the Flutter box grows to
                    // fit. See `systemListHeight`.
                    self?.systemListHeight = h
                    self?.channel?.invokeMethod(
                        "onContentSize", arguments: ["height": Double(h), "animated": animated])
                    self?.reportWheels()
                }))
    }

    /// The wheels last reported to Dart, in this view's coordinates.
    private var reportedWheels: [CGRect] = []

    /// Tells Dart where the rows' wheels are. Flutter decides who gets a
    /// touch before UIKit sees it, and in a scrolling page a vertical drag
    /// goes to the page, unless it lands on a wheel, which it spins.
    ///
    /// Sent whenever the rows move: a new height or a new config. On the next
    /// turn, once the collection view has laid its cells out.
    private func reportWheels() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            var wheels: [CGRect] = []
            func find(_ view: UIView) {
                if view is UIPickerView || (view as? UIDatePicker)?.datePickerStyle == .wheels {
                    wheels.append(view.convert(view.bounds, to: self._view))
                    return
                }
                view.subviews.forEach(find)
            }
            find(self._view)
            guard wheels != self.reportedWheels else { return }
            self.reportedWheels = wheels
            self.channel?.invokeMethod(
                "onWheels",
                arguments: wheels.map {
                    [Double($0.minX), Double($0.minY), Double($0.width), Double($0.height)]
                })
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
        case "cancelTouches":
            cancelTouches()
            result(nil)
        case "getIntrinsicSize":
            result(intrinsicSize())
        // The route is leaving; drop the responder now so the keyboard rides
        // the transition down instead of waiting for this view's disposal.
        // Logged because "the route dismissed it" and "it dropped on its own"
        // look identical on screen, and this is the line that tells them apart.
        case "endEditing":
            NativeLog.log(
                "list endEditing (route leaving) focused=\(focusedFieldKey ?? "none")")
            _view.endEditing(true)
            result(nil)
        case "updateList":
            if let argsMap = call.arguments as? [String: Any],
                let config = decodeConfig(ListConfig.self, from: argsMap)
            {
                let isDark = (argsMap["isDark"] as? NSNumber)?.boolValue
                if Self.toggleValues(in: config) == shownToggles {
                    update(AnyView(makeContent(config)))
                    if let isDark = isDark { self.isDark = isDark }
                    reportWheels()
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
    ///
    /// The probe's number wins once it has one, and that is the whole fix: a
    /// system `List` has no intrinsic height, so `sizeThatFits` echoes back the
    /// frame it was given, and that frame is `AdaptiveSystemListView`'s
    /// start-tall placeholder (twice the screen) until the probe measures the
    /// content. Publishing the placeholder is what sized a Flutter box to twice
    /// the screen, which on a body that is a `Column` of lists added up to
    /// thousands of points of blank scroll inside one sheet.
    ///
    /// The frame-derived answer stays as the **fallback**, and it has to. It is
    /// the only thing that gives the box a height before the probe lands:
    /// returning zero until then leaves the list with no height at all and the
    /// page renders empty. Only the *value* changes here, and only once there is
    /// a real one to change it to.
    override func intrinsicSize() -> [String: Double] {
        if let height = systemListHeight {
            let width = _view.bounds.width > 1 ? _view.bounds.width : UIScreen.main.bounds.width
            return ["width": Double(width), "height": Double(height)]
        }
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
        // its SwiftUI content needs at the given width, the most reliable
        // measurement for a List/Form that self-sizes to its rows.
        let fittingSize = host.sizeThatFits(
            in: CGSize(width: width, height: .greatestFiniteMagnitude))
        if fittingSize.height > 1 && fittingSize.height < 100_000 {
            height = fittingSize.height
        }
        // Fallback: sizingOptions == .intrinsicContentSize
        if height <= 1 {
            let intrinsic = host.view.intrinsicContentSize.height
            if intrinsic > 1 && intrinsic < 100_000 { height = intrinsic }
        }
        // Fallback: UIKit auto-layout fitting
        if height <= 1 {
            height =
                host.view.systemLayoutSizeFitting(
                    CGSize(width: width, height: UIView.layoutFittingCompressedSize.height),
                    withHorizontalFittingPriority: .required,
                    verticalFittingPriority: .fittingSizeLevel
                ).height
        }
        return CGSize(width: width, height: height)
    }
}
