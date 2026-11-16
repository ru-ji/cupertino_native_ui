import 'dart:async';
import 'dart:isolate';
import 'dart:typed_data';

import 'package:objective_c/objective_c.dart';

import 'native_interop_bindings.g.dart';

/// One SF Symbol render request: what `CNUNativeInterop.renderSymbol` takes.
typedef SymbolRequest = ({
  String name,
  double size,
  int? argb,
  String weight,
  String symbolScale,
  double scale,
});

/// Renders an SF Symbol to PNG bytes on the calling isolate.
Uint8List? renderSymbolSync(SymbolRequest r) {
  final data = CNUNativeInterop.renderSymbolWithName(
    r.name.toNSString(),
    size: r.size,
    argb: r.argb ?? 0,
    hasColor: r.argb != null,
    weight: r.weight.toNSString(),
    symbolScale: r.symbolScale.toNSString(),
    scale: r.scale,
  );
  return data?.toList();
}

/// A long-lived isolate that rasterizes symbols off the UI thread. A page of
/// icons asks for dozens at once; each render is a UIKit draw plus a PNG
/// encode, so they are worth keeping out of the frame budget. The FFI call
/// into `CNUNativeInterop` is valid from any isolate.
///
/// Falls back to rendering on the calling isolate if the worker cannot start
/// or dies, so an icon is never lost to the worker.
final class SymbolWorker {
  SymbolWorker._();
  static final SymbolWorker instance = SymbolWorker._();

  Future<SendPort?>? _starting;
  final Map<int, Completer<Uint8List?>> _pending = {};
  int _next = 0;
  bool _failed = false;

  Future<Uint8List?> render(SymbolRequest request) async {
    final port = _failed ? null : await (_starting ??= _start());
    if (port == null) return renderSymbolSync(request);
    final id = _next++;
    final completer = _pending[id] = Completer<Uint8List?>();
    port.send((id, request));
    try {
      return await completer.future;
    } on Object {
      return renderSymbolSync(request);
    }
  }

  Future<SendPort?> _start() async {
    try {
      final replies = ReceivePort();
      final ready = Completer<SendPort>();
      replies.listen((message) {
        if (message is SendPort) {
          ready.complete(message);
        } else if (message is (int, TransferableTypedData?)) {
          final (id, bytes) = message;
          _pending.remove(id)?.complete(bytes?.materialize().asUint8List());
        } else if (message == null) {
          // The worker exited: fail what is in flight, render locally after.
          _failed = true;
          for (final c in _pending.values) {
            c.completeError(StateError('symbol worker exited'));
          }
          _pending.clear();
        }
      });
      await Isolate.spawn(_entry, replies.sendPort, onExit: replies.sendPort);
      return await ready.future;
    } on Object {
      _failed = true;
      return null;
    }
  }

  static void _entry(SendPort replies) {
    final requests = ReceivePort();
    replies.send(requests.sendPort);
    requests.listen((message) {
      final (id, request) = message as (int, SymbolRequest);
      Uint8List? bytes;
      try {
        bytes = renderSymbolSync(request);
      } on Object {
        bytes = null;
      }
      replies.send((
        id,
        bytes == null ? null : TransferableTypedData.fromList([bytes]),
      ));
    });
  }
}
