import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Captures a hosted view over its own channel and decodes the pixels, with
/// the rectangle the capture covers relative to the view.
///
/// Straight from the platform buffer to a [ui.Image]: premultiplied BGRA at
/// the device pixel ratio, which is exactly what [ui.decodeImageFromPixels]
/// takes, so there is no codec in the path. See `PlatformViewSnapshot.swift`.
Future<(ui.Image, Rect)?> captureNativeView(MethodChannel channel) async {
  final report = await channel.invokeMapMethod<String, dynamic>('snapshot');
  // Nothing to draw: an unlaid-out view, or one that has never rendered.
  if (report == null) return null;
  final completer = Completer<ui.Image>();
  ui.decodeImageFromPixels(
    report['bytes'] as Uint8List,
    report['width'] as int,
    report['height'] as int,
    ui.PixelFormat.bgra8888,
    completer.complete,
    rowBytes: report['rowBytes'] as int,
  );
  return (
    await completer.future,
    Rect.fromLTWH(
      (report['dx'] as num?)?.toDouble() ?? 0,
      (report['dy'] as num?)?.toDouble() ?? 0,
      (report['dw'] as num?)?.toDouble() ?? 0,
      (report['dh'] as num?)?.toDouble() ?? 0,
    ),
  );
}
