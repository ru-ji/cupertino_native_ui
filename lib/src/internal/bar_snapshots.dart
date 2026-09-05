import 'dart:async';
import 'dart:ui' as ui;

import 'package:flutter/scheduler.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'edge_effect_coverage.dart';

/// Bitmaps of the native controls currently passing under a scroll edge
/// effect, and the widget that draws them inside the bar.
///
/// **The problem this is the answer to.** `Haze` is a `BackdropFilter`, and a
/// backdrop filter only ever filters its own render target. A platform view's
/// pixels are never in one — they are produced by iOS at composite time, after
/// Flutter has finished the frame — so the blur reaches every pixel of a page
/// except the native controls, which come back up crisp through the bar.
///
/// **The answer is to move the pixels.** A control that enters the bar's
/// rectangle is captured natively ([PlatformViewSnapshot]) and the covered
/// band of that bitmap is drawn HERE, inside the bar, immediately under the
/// shader. Ordinary Flutter pixels, in the shader's own render target: they
/// blur like everything else. Only then is the live view cut on the same line,
/// so the two halves meet exactly and neither is drawn twice.
///
/// It is the trick SwiftUI's tab bar plays with its indicator: the icons do
/// not move or change, the indicator repaints the part of them it covers, and
/// the eye reads one continuous control.
///
/// Registration is global rather than inherited because a bar and the content
/// it covers are siblings — usually a `Stack` the app builds — so there is no
/// common ancestor to hang a scope on that would not have to be spelled out by
/// every caller.
final barSnapshots = BarSnapshotRegistry();

/// One captured control: its bitmap, and the render object that says where it
/// currently is.
class BarSnapshotEntry {
  BarSnapshotEntry(this.image, this.box, this.dest);

  final ui.Image image;

  /// Where the bitmap goes back, relative to the control's top-left, in
  /// points. The platform side works it out — the capture is of the hosted
  /// view, which is centred inside its container for the controls that hug
  /// their content, and reaches past its own bounds for the ones that paint
  /// outside them. Sending the rectangle rather than a margin leaves no
  /// arithmetic to keep in step on two sides of a channel.
  final Rect dest;

  /// Read at PAINT time, never stored: the control is scrolling, so its
  /// position is only true for the frame being painted.
  final RenderBox box;
}

class BarSnapshotRegistry extends ChangeNotifier {
  final Map<int, BarSnapshotEntry> _entries = {};

  Iterable<BarSnapshotEntry> get entries => _entries.values;
  bool get isEmpty => _entries.isEmpty;
  bool holds(int viewId) => _entries.containsKey(viewId);

  /// Frames tick while anything is registered: the bars have to repaint as
  /// their content scrolls under them, and on a plain (non-collapsing) bar
  /// nothing else would ask them to.
  int? _frameCallback;

  void add(int viewId, BarSnapshotEntry entry) {
    _entries.remove(viewId)?.image.dispose();
    _entries[viewId] = entry;
    _startTicking();
    notifyListeners();
  }

  void remove(int viewId) {
    final entry = _entries.remove(viewId);
    if (entry == null) return;
    // After the frame that stops painting it: a painter still holding it this
    // frame would draw a disposed image.
    SchedulerBinding.instance.addPostFrameCallback(
      (_) => entry.image.dispose(),
    );
    if (_entries.isEmpty) _stopTicking();
    notifyListeners();
  }

  void _startTicking() {
    if (_frameCallback != null) return;
    void tick(Duration _) {
      if (_entries.isEmpty) return;
      notifyListeners();
      _frameCallback = SchedulerBinding.instance.scheduleFrameCallback(
        tick,
        rescheduling: true,
      );
      SchedulerBinding.instance.scheduleFrame();
    }

    _frameCallback = SchedulerBinding.instance.scheduleFrameCallback(tick);
    SchedulerBinding.instance.scheduleFrame();
  }

  void _stopTicking() {
    final id = _frameCallback;
    _frameCallback = null;
    if (id != null) SchedulerBinding.instance.cancelFrameCallbackWithId(id);
  }
}

/// Tells the platform side whether Dart holds a bitmap for a view, and can
/// therefore cut the live one.
///
/// The order matters and is the whole reason this is a round trip rather than
/// a decision the native side takes alone: the band is only hidden once
/// something is drawn in its place, so there is never a frame with a hole in
/// it.
Future<void> setEdgeCut(int viewId, bool cut) => const MethodChannel(
  'com.example.cupertino_widgets/alert',
).invokeMethod<void>('setEdgeCut', {'viewId': viewId, 'cut': cut});

/// Captures a hosted view over its own channel and decodes the pixels.
///
/// Straight from the platform buffer to a [ui.Image]: premultiplied BGRA at
/// the device pixel ratio, which is exactly what [ui.decodeImageFromPixels]
/// takes, so there is no codec in the path.
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

/// Draws the registered bitmaps where their controls are, bounded by the
/// effect rectangles themselves.
///
/// Placed inside a bar directly beneath its [CupertinoScrollEdgeEffect], so
/// what it paints is what the shader then blurs. What it may paint is not this
/// widget's box but [publishedEdgeRegions] — the very rectangles the platform
/// side cuts the live views on. Deriving that boundary twice, once here from
/// the bar's layout and once there from the message, is how the two halves end
/// up disagreeing by a few points and leaving a band of bare background across
/// a control.
class BarSnapshotSurface extends StatelessWidget {
  const BarSnapshotSurface({super.key});

  @override
  Widget build(BuildContext context) =>
      IgnorePointer(child: _BarSnapshotPainter(registry: barSnapshots));
}

class _BarSnapshotPainter extends SingleChildRenderObjectWidget {
  const _BarSnapshotPainter({required this.registry});

  final BarSnapshotRegistry registry;

  @override
  _RenderBarSnapshots createRenderObject(BuildContext context) =>
      _RenderBarSnapshots(registry);

  @override
  void updateRenderObject(BuildContext context, _RenderBarSnapshots ro) =>
      ro.registry = registry;
}

class _RenderBarSnapshots extends RenderBox {
  _RenderBarSnapshots(this._registry) {
    _registry.addListener(markNeedsPaint);
  }

  BarSnapshotRegistry _registry;
  BarSnapshotRegistry get registry => _registry;
  set registry(BarSnapshotRegistry value) {
    if (identical(value, _registry)) return;
    _registry.removeListener(markNeedsPaint);
    _registry = value..addListener(markNeedsPaint);
    markNeedsPaint();
  }

  @override
  void dispose() {
    _registry.removeListener(markNeedsPaint);
    super.dispose();
  }

  @override
  bool get sizedByParent => true;

  @override
  Size computeDryLayout(BoxConstraints constraints) => constraints.biggest;

  @override
  void paint(PaintingContext context, Offset offset) {
    if (_registry.isEmpty || publishedEdgeRegions.isEmpty) return;
    final canvas = context.canvas;
    // Global coordinates into ours, once: every region and every control is
    // placed against the same transform this frame.
    final toLocal = Matrix4.tryInvert(getTransformTo(null));
    if (toLocal == null) return;
    canvas.save();
    // No antialiasing on the seam, and no overlap either — and the overlap
    // half is the expensive lesson.
    //
    // Drawing the bitmap a little past the rectangle looks like cheap
    // insurance against the platform side cutting a hair low. It is not:
    // past the rectangle the live view is still there, and a control is not a
    // stencil. `Tinted`, `Glass`, a slider's track — anything with a
    // translucent fill gets that fill composited a SECOND time over the copy
    // already on screen, and two 30% washes over one dark row make a pale band
    // exactly as tall as the overlap. That was the whitish line; the black one
    // was the same disagreement with the other sign.
    //
    // Neither is survivable by fudging. The two sides have to cut on the same
    // pixel, which is what the KVO hook in `HostingContainerView` is for: the
    // mask is now recomputed inside the transaction that moves the view, so
    // the line it draws is the line this clip draws.
    canvas.clipRect(
      publishedEdgeRegions.values
          .map((r) => MatrixUtils.transformRect(toLocal, r).shift(offset))
          .reduce((a, b) => a.expandToInclude(b)),
      doAntiAlias: false,
    );
    for (final entry in _registry.entries) {
      final box = entry.box;
      if (!box.attached || !box.hasSize || box.size.isEmpty) continue;
      // Where the control is on THIS frame, in our own coordinates. Both sides
      // of the seam come from this one number: the platform side cuts the live
      // view on the same rectangle, converted into its own space.
      final topLeft = MatrixUtils.transformPoint(
        box.getTransformTo(this),
        Offset.zero,
      );
      // The destination the platform side measured, moved to where the
      // control is on this frame.
      canvas.drawImageRect(
        entry.image,
        Offset.zero &
            Size(entry.image.width.toDouble(), entry.image.height.toDouble()),
        entry.dest.shift(offset + topLeft),
        Paint()..filterQuality = FilterQuality.medium,
      );
    }
    canvas.restore();
  }
}
