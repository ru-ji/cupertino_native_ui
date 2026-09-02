import Flutter
import SwiftUI
import UIKit

@available(iOS 15.0, *)
class NativeDatePickerFactory: NSObject, FlutterPlatformViewFactory {
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
        return NativeDatePickerView(
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

/// Observable state for the SwiftUI DatePicker; mutated from the method
/// channel, mirrored back to Dart on user edits.
@available(iOS 15.0, *)
final class DatePickerModel: ObservableObject {
    @Published var date: Date {
        didSet {
            guard !suppressCallback, date != oldValue else { return }
            onChanged?(date)
        }
    }
    @Published var mode: String
    @Published var minimumDate: Date?
    @Published var maximumDate: Date?
    @Published var tint: Color?

    /// Set while applying an update that came FROM Dart, so it isn't echoed.
    var suppressCallback = false
    var onChanged: ((Date) -> Void)?

    init(date: Date, mode: String, minimumDate: Date?, maximumDate: Date?, tint: Color?) {
        self.date = date
        self.mode = mode
        self.minimumDate = minimumDate
        self.maximumDate = maximumDate
        self.tint = tint
    }

    var components: DatePickerComponents {
        switch mode {
        case "time": return [.hourAndMinute]
        case "dateAndTime": return [.date, .hourAndMinute]
        default: return [.date]
        }
    }

    var range: ClosedRange<Date> {
        (minimumDate ?? .distantPast)...(maximumDate ?? .distantFuture)
    }
}

/// The compact-style system date picker: renders as a tappable pill that
/// pops the native calendar / time wheel over the app — the same control as
/// iOS Settings and Calendar.
@available(iOS 15.0, *)
class NativeDatePickerView: NativeHostingView {
    private var channel: FlutterMethodChannel?
    private let model: DatePickerModel

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        messenger: FlutterBinaryMessenger
    ) {
        let argsMap = args as? [String: Any] ?? [:]
        model = DatePickerModel(
            date: Self.date(from: argsMap["value"]) ?? Date(),
            mode: argsMap["mode"] as? String ?? "date",
            minimumDate: Self.date(from: argsMap["minimumDate"]),
            maximumDate: Self.date(from: argsMap["maximumDate"]),
            tint: (argsMap["tint"] as? Int).map { Color(argb: $0) }
        )
        super.init()
        // So Dart can exempt this view from an edge effect's mask (bar chrome
        // is painted over the effect, not under it).
        _view.viewId = viewId

        channel = FlutterMethodChannel(
            name: "cupertino_widgets/date_picker_\(viewId)", binaryMessenger: messenger)
        // Push measurements instead of waiting to be polled.
        sizeChannel = channel
        channel?.setMethodCallHandler({
            [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            self?.handle(call, result: result)
        })
        model.onChanged = { [weak self] date in
            self?.channel?.invokeMethod(
                "onChanged", arguments: Int(date.timeIntervalSince1970 * 1000))
        }

        setupSwiftUI(isDark: argsMap["isDark"] as? Bool)
    }

    /// The picker fills the box Flutter built for it — the branch the button
    /// takes for `expand: true`. Its own size comes back through
    /// `getIntrinsicSize`, same round trip as the button's.
    private func setupSwiftUI(isDark: Bool?) {
        attach(AnyView(AdaptiveDatePickerView(model: model)))
        // Follows the app's own (possibly forced) theme, not the device's
        // system appearance — the popped-open calendar/wheel otherwise reads
        // the window's actual interface style.
        if let isDark = isDark {
            hostingController?.overrideUserInterfaceStyle = isDark ? .dark : .light
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "getIntrinsicSize":
            result(intrinsicSize())
        case "updateDatePicker":
            guard let args = call.arguments as? [String: Any] else {
                result(
                    FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
                return
            }
            // No re-attach: the picker's state lives in an `ObservableObject`
            // this bridge owns, so assigning to it already reaches the view.
            model.suppressCallback = true
            if let date = Self.date(from: args["value"]) { model.date = date }
            if let mode = args["mode"] as? String { model.mode = mode }
            model.minimumDate = Self.date(from: args["minimumDate"])
            model.maximumDate = Self.date(from: args["maximumDate"])
            model.tint = (args["tint"] as? Int).map { Color(argb: $0) }
            model.suppressCallback = false
            if let isDark = args["isDark"] as? Bool {
                hostingController?.overrideUserInterfaceStyle = isDark ? .dark : .light
            }
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Milliseconds since epoch (Dart's `millisecondsSinceEpoch`) → Date.
    private static func date(from value: Any?) -> Date? {
        guard let ms = (value as? NSNumber)?.doubleValue else { return nil }
        return Date(timeIntervalSince1970: ms / 1000)
    }
}

@available(iOS 15.0, *)
struct AdaptiveDatePickerView: View {
    @ObservedObject var model: DatePickerModel

    var body: some View {
        DatePicker(
            "",
            selection: $model.date,
            in: model.range,
            displayedComponents: model.components
        )
        .labelsHidden()
        .datePickerStyle(.compact)
        .tint(model.tint)
    }
}
