import UIKit

/// Entry points Dart calls directly through FFI (package:objective_c), with no
/// platform channel in between: no codec, no async hop, callable from any
/// isolate. The Dart side is generated from `ios/.../cupertino_native_ui_objc/include/native_interop.h`,
/// which must be kept in sync with the signatures here.
@objc(CNUNativeInterop)
public final class NativeInterop: NSObject {

    @objc public static func isLiquidGlassSupported() -> Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }

    @objc public static func clearPhotoCache() {
        if #available(iOS 17.0, *) { PhotoCache.clear() }
    }

    /// Rasterizes an SF Symbol to PNG bytes, or nil for an unknown name.
    /// `weight` is light/medium/semibold/bold (anything else is regular),
    /// `symbolScale` is small/large (anything else is medium). `argb` is
    /// ignored unless `hasColor`.
    @objc public static func renderSymbol(
        name: String, size: Double, argb: Int, hasColor: Bool,
        weight: String, symbolScale: String, scale: Double
    ) -> Data? {
        FlutterCupertinoPlugin.renderSymbol(
            name: name, size: size, argb: hasColor ? argb : nil,
            weight: weight, symbolScale: symbolScale, scale: scale)
    }

    /// Pre-boots the engines for scaffold body `routes` (a JSON array of names).
    @objc public static func prewarmScaffold(routesJson: String, isDark: Bool) {
        let routes =
            (try? JSONSerialization.jsonObject(with: Data(routesJson.utf8))) as? [String] ?? []
        DispatchQueue.main.async {
            NativeScaffoldView.prewarm(routes: routes, isDark: isDark)
        }
    }

    /// Presents a UIAlertController alert. `json` is the same map the channel
    /// used to carry. `completion` gets the JSON of the outcome: the tapped
    /// action's index, `{"index":i,"texts":[...]}` with text fields, or nil.
    @objc public static func showAlert(json: String, completion: @escaping (String?) -> Void) {
        present(json: json, style: .alert, completion: completion)
    }

    /// As `showAlert`, as an action sheet (popover when `sourceRect` is given).
    @objc public static func showActionSheet(
        json: String, completion: @escaping (String?) -> Void
    ) {
        present(json: json, style: .actionSheet, completion: completion)
    }

    private static func present(
        json: String, style: UIAlertController.Style, completion: @escaping (String?) -> Void
    ) {
        guard
            let args = (try? JSONSerialization.jsonObject(with: Data(json.utf8)))
                as? [String: Any],
            let title = args["title"] as? String,
            let actions = args["actions"] as? [[String: Any]]
        else {
            completion(nil)
            return
        }
        var anchor: CGRect? = nil
        if let rect = args["sourceRect"] as? [String: Any],
            let x = rect["x"] as? Double, let y = rect["y"] as? Double,
            let w = rect["width"] as? Double, let h = rect["height"] as? Double
        {
            anchor = CGRect(x: x, y: y, width: w, height: h)
        }
        DispatchQueue.main.async {
            AlertManager.shared.show(
                title: title, message: args["message"] as? String, actions: actions,
                textFields: args["textFields"] as? [[String: Any]] ?? [],
                isDark: args["isDark"] as? Bool ?? false, style: style, sourceRect: anchor,
                result: { value in
                    guard let value, JSONSerialization.isValidJSONObject([value]),
                        let data = try? JSONSerialization.data(
                            withJSONObject: [value]),
                        let text = String(data: data, encoding: .utf8)
                    else {
                        completion(nil)
                        return
                    }
                    // Wrapped in an array above so a bare number is valid JSON.
                    completion(text)
                })
        }
    }

    // MARK: Per-view channels (see NativeChannel)

    /// Calls the handler of a native view's channel. Returns the encoded reply
    /// when it is ready at once, nil when it will arrive through the reply sink.
    @objc public static func invoke(
        engineId: Int64, channel: String, method: String, args: Data, token: Int64
    ) -> Data? {
        run(
            engineId: engineId, channel: channel, method: method,
            args: NativePayload(kind: 0, number: 0, text: nil, data: args), token: token)
    }

    /// `invoke` for a scalar argument (kind 1 nil, 2 bool, 3 int, 4 double,
    /// 5 string): no codec on either side of the call.
    @objc public static func invokeScalar(
        engineId: Int64, channel: String, method: String, kind: Int64, number: Double,
        text: String?, token: Int64
    ) -> Data? {
        run(
            engineId: engineId, channel: channel, method: method,
            args: NativePayload(kind: kind, number: number, text: text, data: nil),
            token: token)
    }

    private static func run(
        engineId: Int64, channel: String, method: String, args: NativePayload, token: Int64
    ) -> Data? {
        let hub = NativeEngineHub.hub(engineId)
        if Thread.isMainThread {
            return hub.invoke(channel: channel, method: method, args: args, token: token)
        }
        DispatchQueue.main.async {
            if let data = hub.invoke(
                channel: channel, method: method, args: args, token: token)
            {
                hub.replySink?(token, data)
            }
        }
        return nil
    }

    @objc public static func attach(engineId: Int64, channel: String) {
        NativeEngineHub.hub(engineId).attach(channel: channel)
    }

    @objc public static func detach(engineId: Int64, channel: String) {
        NativeEngineHub.hub(engineId).detach(channel: channel)
    }

    /// Receives every Swift-to-Dart event: channel, method, then the payload
    /// as `kind` (see `invokeScalar`, plus 0 for encoded) with its `number`,
    /// `text` or encoded `data`.
    @objc public static func setEventSink(
        engineId: Int64,
        sink: @escaping (String, String, Int64, Double, String?, Data?) -> Void
    ) {
        NativeEngineHub.hub(engineId).eventSink = { channel, method, payload in
            sink(channel, method, payload.kind, payload.number, payload.text, payload.data)
        }
    }

    @objc public static func setReplySink(
        engineId: Int64, sink: @escaping (Int64, Data) -> Void
    ) {
        NativeEngineHub.hub(engineId).replySink = sink
    }
}
