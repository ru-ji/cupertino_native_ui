import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

/// The native views among a bar's items, and where they sit: the bar's scroll
/// edge effect cuts its wash out under each, so their glass sees the content
/// under the bar — and turns light or dark with it, as the system's bar items
/// do — instead of a wash that hides it (a dark wash never let it turn light).
///
/// Generic on purpose: an item holding any native view — the package's glass
/// buttons and containers, or a glass of the app's own — gets its hole. A
/// Flutter-drawn item keeps the wash behind it.
class BarHoles extends ChangeNotifier {
  final _items = <RenderBarHole>{};
  bool _scheduled = false;
  bool _disposed = false;

  @override
  void dispose() {
    _disposed = true;
    super.dispose();
  }

  /// The box the holes are measured in: the effect's.
  RenderBox? Function()? origin;

  /// Capsules to cut, in the effect's points, as `x, y, width, height` runs.
  /// Replaced, never mutated, so a listener can compare by identity.
  List<double> rects = const [];

  void _dirty() {
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      // A bar leaving reports its items going after the bar itself is gone.
      if (_disposed) return;
      final box = origin?.call();
      if (box == null || !box.attached || !box.hasSize) return;
      final at = box.localToGlobal(Offset.zero);
      final next = <double>[];
      for (final item in _items) {
        if (!item.attached || !item.hasSize || !_holdsNativeView(item)) {
          continue;
        }
        for (final rect in item.rects ?? [Offset.zero & item.size]) {
          final topLeft = item.localToGlobal(rect.topLeft) - at;
          next.addAll([topLeft.dx, topLeft.dy, rect.width, rect.height]);
        }
      }
      if (listEquals(next, rects)) return;
      rects = next;
      notifyListeners();
    });
  }

  static bool _holdsNativeView(RenderObject root) {
    var found = false;
    void visit(RenderObject node) {
      if (found) return;
      if (node is RenderUiKitView) {
        found = true;
        return;
      }
      node.visitChildren(visit);
    }

    visit(root);
    return found;
  }
}

/// Makes [holes] the registry of the bar's items and of its edge effect.
class BarHolesScope extends InheritedWidget {
  const BarHolesScope({super.key, required this.holes, required super.child});

  final BarHoles holes;

  /// No dependency: the registry object never changes for a bar.
  static BarHoles? maybeOf(BuildContext context) =>
      context.getInheritedWidgetOfExactType<BarHolesScope>()?.holes;

  @override
  bool updateShouldNotify(BarHolesScope oldWidget) => holes != oldWidget.holes;
}

/// One bar item: reports where it sits whenever it paints or goes away.
class BarHole extends SingleChildRenderObjectWidget {
  const BarHole({super.key, this.rects, required super.child});

  /// The glass inside the item, in its own coordinates, when it is not the
  /// whole item — a tab bar's pills inside the bar's wider frame. Empty cuts
  /// nothing. Null: the item's box.
  final List<Rect>? rects;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      RenderBarHole(BarHolesScope.maybeOf(context))..rects = rects;

  @override
  void updateRenderObject(BuildContext context, RenderBarHole renderObject) {
    renderObject
      ..holes = BarHolesScope.maybeOf(context)
      ..rects = rects;
  }
}

/// [BarHole]'s render object.
class RenderBarHole extends RenderProxyBox {
  RenderBarHole(this._holes);

  BarHoles? _holes;

  /// See [BarHole.rects].
  List<Rect>? get rects => _rects;
  List<Rect>? _rects;
  set rects(List<Rect>? value) {
    if (listEquals(value, _rects)) return;
    _rects = value;
    _holes?._dirty();
  }

  set holes(BarHoles? value) {
    if (value == _holes) return;
    _holes?._items.remove(this);
    _holes?._dirty();
    _holes = value;
    if (attached) _holes?._items.add(this);
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _holes?._items.add(this);
  }

  @override
  void detach() {
    _holes?._items.remove(this);
    _holes?._dirty();
    super.detach();
  }

  // ponytail: a move with no repaint of the item (a parent's offset alone)
  // is not seen; the bar's items repaint when its row lays out.
  @override
  void paint(PaintingContext context, Offset offset) {
    super.paint(context, offset);
    _holes?._dirty();
  }
}
