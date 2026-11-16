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

/// A call argument or event payload. Scalars (nil, Bool, Int, Double, String)
/// cross FFI as plain values, with no codec on either side; anything else
/// (maps, lists, bytes) travels encoded in the standard codec as `data`.
struct NativePayload {
    /// 0 encoded, 1 nil, 2 bool, 3 int, 4 double, 5 string.
    var kind: Int64 = 1
    var number: Double = 0
    var text: String?
    var data: Data?

    /// Ints past 2^53 do not survive a Double, so they go encoded.
    private static let exactIntLimit: Int64 = 1 << 53

    init(kind: Int64, number: Double, text: String?, data: Data?) {
        self.kind = kind
        self.number = number
        self.text = text
        self.data = data
    }

    init(_ value: Any?, codec: FlutterStandardMessageCodec) {
        switch value {
        case nil:
            self.init(kind: 1, number: 0, text: nil, data: nil)
        case let flag as Bool:
            self.init(kind: 2, number: flag ? 1 : 0, text: nil, data: nil)
        case let int as Int where abs(Int64(int)) <= Self.exactIntLimit:
            self.init(kind: 3, number: Double(int), text: nil, data: nil)
        case let double as Double:
            self.init(kind: 4, number: double, text: nil, data: nil)
        case let string as String:
            self.init(kind: 5, number: 0, text: string, data: nil)
        default:
            self.init(kind: 0, number: 0, text: nil, data: codec.encode(value) ?? Data())
        }
    }

    func value(codec: FlutterStandardMessageCodec) -> Any? {
        switch kind {
        case 0: return data.flatMap { codec.decode($0) }
        case 2: return number != 0
        case 3: return Int(number)
        case 4: return number
        case 5: return text
        default: return nil
        }
    }
}

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

    var eventSink: ((String, String, NativePayload) -> Void)?
    var replySink: ((Int64, Data) -> Void)?
    var handlers: [String: NativeCallHandler] = [:]
    private var attached: Set<String> = []
    private var pending: [String: [(String, NativePayload)]] = [:]
    private static let okNilReply: Data = codec.encode([0, nil]) ?? Data()

    // MARK: Dart to Swift

    /// Runs the handler for `channel`. Returns the encoded reply when the
    /// handler answered before returning; nil means the reply goes to
    /// `replySink` under `token` later.
    func invoke(channel: String, method: String, args: NativePayload, token: Int64) -> Data? {
        guard let handler = handlers[channel] else { return Self.reply(.notImplemented) }
        var immediate: Data?
        var returned = false
        let call = FlutterMethodCall(
            methodName: method, arguments: args.value(codec: Self.codec))
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
        let args = NativePayload(arguments, codec: Self.codec)
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
        case .value(let value):
            if value == nil { return okNilReply }
            message = [0, value]
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
