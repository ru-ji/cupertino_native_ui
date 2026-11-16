import 'dart:async';
import 'dart:io' show Platform;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:objective_c/objective_c.dart';

import 'native_interop_bindings.g.dart';
import 'native_log.dart';

/// A per-view channel to a native platform view, carried over direct FFI
/// instead of the binary messenger. It mirrors the `MethodChannel` calls the
/// plugin uses (`invokeMethod`, `invokeMapMethod`, `setMethodCallHandler`), so
/// a view's Dart and Swift code keep the same method names and payloads.
///
/// Values still travel in the standard codec's encoding, which keeps types
/// (ints, doubles, byte data) identical to a real channel. What is gone is the
/// messenger: no platform-thread queue, no per-message dispatch, and a Swift
/// reply that is ready at once comes back as the return value of the call.
///
/// Off iOS, and wherever the engine has no id (flutter test), it is a plain
/// `MethodChannel`, so tests can still mock it.
class NativeChannel {
  NativeChannel(this.name) : _engineId = _directEngineId(), _fallback = null {
    if (_engineId != null) _Hub.ensure(_engineId);
  }

  final String name;
  final int? _engineId;
  MethodChannel? _fallback;

  static int? _directEngineId() {
    if (kIsWeb || !Platform.isIOS) return null;
    return ui.PlatformDispatcher.instance.engineId;
  }

  MethodChannel get _channel => _fallback ??= MethodChannel(name);

  Future<T?> invokeMethod<T>(String method, [Object? arguments]) async {
    final engineId = _engineId;
    if (engineId == null) return _channel.invokeMethod<T>(method, arguments);
    final reply = await _Hub.invoke(engineId, name, method, arguments);
    return reply as T?;
  }

  Future<Map<K, V>?> invokeMapMethod<K, V>(
    String method, [
    Object? arguments,
  ]) async {
    final result = await invokeMethod<Map<Object?, Object?>>(method, arguments);
    return result?.cast<K, V>();
  }

  void setMethodCallHandler(
    Future<dynamic> Function(MethodCall call)? handler,
  ) {
    final engineId = _engineId;
    if (engineId == null) {
      _channel.setMethodCallHandler(handler);
      return;
    }
    _Hub.setHandler(engineId, name, handler);
  }
}

/// Per-isolate state behind [NativeChannel]: the event and reply sinks Swift
/// calls back through, the handlers by channel name, and calls awaiting a
/// reply.
class _Hub {
  static const _codec = StandardMessageCodec();
  static final Map<String, Future<dynamic> Function(MethodCall)> _handlers = {};
  static final Map<int, Completer<Object?>> _pending = {};
  static int _nextToken = 0;
  static bool _ready = false;

  static void ensure(int engineId) {
    if (_ready) return;
    _ready = true;
    CNUNativeInterop.setEventSinkWithEngineId(
      engineId,
      sink:
          ObjCBlock_ffiVoid_NSString_NSString_Int64_ffiDouble_NSString_NSData.listener(
            (channel, method, kind, number, text, data) {
              final handler = _handlers[channel.toDartString()];
              if (handler == null) return;
              final call = MethodCall(
                method.toDartString(),
                _payload(kind, number, text, data),
              );
              // Swift never waits on a reply to an event: an error is only logged.
              unawaited(
                Future<dynamic>.sync(() => handler(call))
                    .catchError((Object e) {
                      nativeLog(
                        () => 'NativeChannel handler for "${call.method}": $e',
                      );
                    }),
              );
            },
          ),
    );
    CNUNativeInterop.setReplySinkWithEngineId(
      engineId,
      sink: ObjCBlock_ffiVoid_Int64_NSData.listener((token, data) {
        final completer = _pending.remove(token);
        if (completer == null) return;
        _complete(completer, data);
      }),
    );
  }

  static void setHandler(
    int engineId,
    String name,
    Future<dynamic> Function(MethodCall call)? handler,
  ) {
    if (handler == null) {
      _handlers.remove(name);
      CNUNativeInterop.detachWithEngineId(engineId, channel: name.toNSString());
      return;
    }
    _handlers[name] = handler;
    // Events Swift sent before this handler existed are delivered now.
    CNUNativeInterop.attachWithEngineId(engineId, channel: name.toNSString());
  }

  static Future<Object?> invoke(
    int engineId,
    String channel,
    String method,
    Object? arguments,
  ) {
    final token = _nextToken++;
    final completer = Completer<Object?>();
    _pending[token] = completer;
    try {
      final kind = _scalarKind(arguments);
      // Scalars (and no argument at all) skip the codec in both directions.
      final immediate = kind == 0
          ? CNUNativeInterop.invokeWithEngineId(
              engineId,
              channel: channel.toNSString(),
              method: method.toNSString(),
              args: _encode(arguments),
              token: token,
            )
          : CNUNativeInterop.invokeScalarWithEngineId(
              engineId,
              channel: channel.toNSString(),
              method: method.toNSString(),
              kind: kind,
              number: switch (arguments) {
                final bool b => b ? 1 : 0,
                final num n => n.toDouble(),
                _ => 0,
              },
              text: arguments is String ? arguments.toNSString() : null,
              token: token,
            );
      if (immediate != null) {
        _pending.remove(token);
        _complete(completer, immediate);
      }
    } on Object catch (e, s) {
      _pending.remove(token);
      completer.completeError(e, s);
    }
    return completer.future;
  }

  /// 1 null, 2 bool, 3 int, 4 double, 5 string; 0 for anything the codec
  /// has to carry (maps, lists, bytes, and ints past 2^53).
  static int _scalarKind(Object? value) => switch (value) {
    null => 1,
    bool _ => 2,
    int i when i.abs() <= (1 << 53) => 3,
    double _ => 4,
    String _ => 5,
    _ => 0,
  };

  static Object? _payload(
    int kind,
    double number,
    NSString? text,
    NSData? data,
  ) => switch (kind) {
    0 => data == null ? null : _decode(data),
    2 => number != 0,
    3 => number.toInt(),
    4 => number,
    5 => text?.toDartString(),
    _ => null,
  };

  static NSData _encode(Object? value) {
    final bytes = _codec.encodeMessage(value)!;
    return bytes.buffer
        .asUint8List(bytes.offsetInBytes, bytes.lengthInBytes)
        .toNSData();
  }

  static Object? _decode(NSData data) {
    final bytes = data.toList();
    if (bytes.isEmpty) return null;
    return _codec.decodeMessage(ByteData.sublistView(bytes));
  }

  /// Reply layout: `[0, value]`, `[1]` (no handler), `[2, code, msg, details]`.
  static void _complete(Completer<Object?> completer, NSData data) {
    final reply = _decode(data) as List<Object?>;
    switch (reply[0]) {
      case 0:
        completer.complete(reply[1]);
      case 1:
        completer.completeError(MissingPluginException());
      default:
        completer.completeError(
          PlatformException(
            code: reply[1]! as String,
            message: reply[2] as String?,
            details: reply[3],
          ),
        );
    }
  }
}
