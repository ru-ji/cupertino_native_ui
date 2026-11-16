import Flutter
import Foundation

/// Which Flutter engine a messenger belongs to. Dart reaches the plugin through
/// `PlatformDispatcher.instance.engineId`, which equals the registrar's
/// `engineIdentifier`, so the two sides agree on an engine without a channel.
enum NativeEngines {
    private static var ids: [ObjectIdentifier: Int64] = [:]

    static func register(_ messenger: FlutterBinaryMessenger, engineId: Int64) {
        ids[ObjectIdentifier(messenger as AnyObject)] = engineId
    }

    static func engineId(of messenger: FlutterBinaryMessenger) -> Int64? {
        ids[ObjectIdentifier(messenger as AnyObject)]
    }
}

typealias NativeCallHandler = (FlutterMethodCall, @escaping FlutterResult) -> Void

/// Per-engine routing for `NativeChannel`: handlers by channel name, the Dart
/// sinks events and replies travel back through, and events that arrived
/// before Dart attached to their channel (the buffering a real channel does).
final class NativeEngineHub {
    private static var hubs: [Int64: NativeEngineHub] = [:]
    private static let codec = FlutterStandardMessageCodec.sharedInstance()
    private static let pendingLimit = 64

    static func hub(_ engineId: Int64) -> NativeEngineHub {
        if let hub = hubs[engineId] { return hub }
        let hub = NativeEngineHub()
        hubs[engineId] = hub
        return hub
    }

    var eventSink: ((String, String, Data) -> Void)?
    var replySink: ((Int64, Data) -> Void)?
    var handlers: [String: NativeCallHandler] = [:]
    private var attached: Set<String> = []
    private var pending: [String: [(String, Data)]] = [:]

    // MARK: Dart to Swift

    /// Runs the handler for `channel`. Returns the encoded reply when the
    /// handler answered before returning; nil means the reply goes to
    /// `replySink` under `token` later.
    func invoke(channel: String, method: String, args: Data, token: Int64) -> Data? {
        guard let handler = handlers[channel] else { return Self.reply(.notImplemented) }
        var immediate: Data?
        var returned = false
        let call = FlutterMethodCall(
            methodName: method, arguments: Self.codec.decode(args))
        handler(call) { [weak self] value in
            let data = Self.reply(Self.outcome(of: value))
            if returned {
                self?.replySink?(token, data)
            } else {
                immediate = data
            }
        }
        returned = true
        return immediate
    }

    // MARK: Swift to Dart

    func attach(channel: String) {
        attached.insert(channel)
        guard let queued = pending.removeValue(forKey: channel), let sink = eventSink else {
            return
        }
        for (method, args) in queued { sink(channel, method, args) }
    }

    func detach(channel: String) {
        attached.remove(channel)
    }

    func emit(channel: String, method: String, arguments: Any?) {
        let args = Self.codec.encode(arguments) ?? Data()
        if attached.contains(channel), let sink = eventSink {
            sink(channel, method, args)
            return
        }
        var queue = pending[channel] ?? []
        if queue.count >= Self.pendingLimit { queue.removeFirst() }
        queue.append((method, args))
        pending[channel] = queue
    }

    // MARK: Reply encoding: [0, value] | [1] | [2, code, message, details]

    private enum Outcome {
        case value(Any?)
        case notImplemented
        case error(FlutterError)
    }

    private static func outcome(of value: Any?) -> Outcome {
        if let error = value as? FlutterError { return .error(error) }
        if let object = value as AnyObject?, object === FlutterMethodNotImplemented {
            return .notImplemented
        }
        return .value(value)
    }

    private static func reply(_ outcome: Outcome) -> Data {
        let message: [Any?]
        switch outcome {
        case .value(let value): message = [0, value]
        case .notImplemented: message = [1]
        case .error(let error): message = [2, error.code, error.message, error.details]
        }
        return codec.encode(message) ?? Data()
    }
}

/// Stands in for `FlutterMethodChannel` on a per-view channel: the same two
/// calls (`setMethodCallHandler`, `invokeMethod`), carried over direct FFI
/// instead of the binary messenger. Falls back to a real channel when the
/// messenger's engine is unknown.
final class NativeChannel {
    private let name: String
    private let hub: NativeEngineHub?
    private let fallback: FlutterMethodChannel?

    init(name: String, binaryMessenger: FlutterBinaryMessenger) {
        self.name = name
        if let engineId = NativeEngines.engineId(of: binaryMessenger) {
            hub = NativeEngineHub.hub(engineId)
            fallback = nil
        } else {
            hub = nil
            fallback = FlutterMethodChannel(name: name, binaryMessenger: binaryMessenger)
        }
    }

    deinit {
        hub?.handlers[name] = nil
        hub?.detach(channel: name)
    }

    func setMethodCallHandler(_ handler: NativeCallHandler?) {
        if let fallback {
            fallback.setMethodCallHandler(handler)
        } else {
            hub?.handlers[name] = handler
        }
    }

    func invokeMethod(_ method: String, arguments: Any?) {
        if let fallback {
            fallback.invokeMethod(method, arguments: arguments)
        } else {
            hub?.emit(channel: name, method: method, arguments: arguments)
        }
    }
}
