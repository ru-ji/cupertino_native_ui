import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import '../cupertino_native_symbol.dart';
import '../cupertino_symbol_image.dart';
import 'native_color.dart';

/// The texts and still symbols of a glass container's Flutter child, drawn by
/// SwiftUI *inside* the glass instead of by Flutter over it, so they take the
/// material's vibrancy and adapt to what is behind it as a native label does.
///
/// Flutter keeps the layout: [split] leaves every widget in place and wraps
/// each [Text] and symbol in a leaf that lays its child out but does not
/// paint it, and reports where it landed. The native side draws the leaf in
/// that frame. Everything else in the child is still Flutter, over the glass.
///
/// Only layout widgets are looked through: [Flex] (a [Row] or a [Column]),
/// [Wrap], [Padding], [Align], [SizedBox], [Flexible]. A Text inside any
/// other widget is that widget's, and stays Flutter with it.
class GlassLeaves {
  GlassLeaves(this.onChanged);

  /// Called after a frame in which the leaves changed, with their wire form.
  final ValueChanged<List<Map<String, Object?>>> onChanged;

  /// The leaves as last reported, in path order.
  List<Map<String, Object?>> current = const [];

  RenderBox? _host;
  final _leaves = <_RenderLeaf>{};
  bool _scheduled = false;

  /// [child] with its texts and symbols handed to the native side. [isDark]
  /// resolves an explicit colour; without one the native side keeps its own
  /// adaptive foreground.
  Widget split(Widget child, {required bool isDark}) =>
      _split(child, '0', isDark);

  /// Wraps the box the leaves' frames are measured in: the platform view's,
  /// whose origin is the native side's.
  Widget host(Widget child) => _LeafHost(leaves: this, child: child);

  Widget _split(Widget widget, String path, bool isDark) {
    List<Widget> children(List<Widget> list) => [
      for (final (i, child) in list.indexed) _split(child, '$path.$i', isDark),
    ];
    Widget? only(Widget? child) =>
        child == null ? null : _split(child, '$path.0', isDark);

    return switch (widget) {
      Text(:final data?) => _Leaf(
        leaves: this,
        path: path,
        describe: (child) => _describeText(child, widget, data, isDark),
        child: widget,
      ),
      // An animated symbol keeps its own view: the effect animates it.
      CupertinoNativeSymbol(
        effect: null,
        variableValue: null,
        paletteColors: [],
        gradient: false,
      ) =>
        _Leaf(
          leaves: this,
          path: path,
          describe: (_) => {
            'symbol': widget.name,
            'symbolSize': widget.size,
            'symbolWeight': _weightName(widget.weight),
            'renderingMode': widget.renderingMode?.name,
            'color': nativeArgb(widget.color, isDark: isDark),
          },
          child: widget,
        ),
      CupertinoSymbolImage() => _Leaf(
        leaves: this,
        path: path,
        describe: (_) => {
          'symbol': widget.name,
          'symbolSize': widget.size,
          'symbolWeight': _weightName(widget.weight),
          'symbolScale': widget.scale.name,
          'color': nativeArgb(widget.color, isDark: isDark),
        },
        child: widget,
      ),
      // Row and Column are Flex with the direction filled in.
      Flex() => Flex(
        key: widget.key,
        direction: widget.direction,
        mainAxisAlignment: widget.mainAxisAlignment,
        mainAxisSize: widget.mainAxisSize,
        crossAxisAlignment: widget.crossAxisAlignment,
        textDirection: widget.textDirection,
        verticalDirection: widget.verticalDirection,
        textBaseline: widget.textBaseline,
        clipBehavior: widget.clipBehavior,
        spacing: widget.spacing,
        children: children(widget.children),
      ),
      Wrap() => Wrap(
        key: widget.key,
        direction: widget.direction,
        alignment: widget.alignment,
        spacing: widget.spacing,
        runAlignment: widget.runAlignment,
        runSpacing: widget.runSpacing,
        crossAxisAlignment: widget.crossAxisAlignment,
        textDirection: widget.textDirection,
        verticalDirection: widget.verticalDirection,
        clipBehavior: widget.clipBehavior,
        children: children(widget.children),
      ),
      Padding() => Padding(
        key: widget.key,
        padding: widget.padding,
        child: only(widget.child),
      ),
      // Center is an Align.
      Align() => Align(
        key: widget.key,
        alignment: widget.alignment,
        widthFactor: widget.widthFactor,
        heightFactor: widget.heightFactor,
        child: only(widget.child),
      ),
      SizedBox() => SizedBox(
        key: widget.key,
        width: widget.width,
        height: widget.height,
        child: only(widget.child),
      ),
      // Expanded is a Flexible.
      Flexible(:final child) => Flexible(
        key: widget.key,
        flex: widget.flex,
        fit: widget.fit,
        child: _split(child, '$path.0', isDark),
      ),
      _ => widget,
    };
  }

  /// A plain [Text] as the native side draws it, from the paragraph Flutter
  /// laid out, so the size, weight and lines are the ones on screen. Null
  /// keeps it Flutter: a font of the app's own, or decoration SwiftUI's
  /// `Text` would not reproduce.
  static Map<String, Object?>? _describeText(
    RenderBox child,
    Text text,
    String data,
    bool isDark,
  ) {
    RenderObject? node = child;
    while (node is! RenderParagraph && node is RenderObjectWithChildMixin) {
      node = node.child;
    }
    if (node is! RenderParagraph) return null;
    final style = node.text.style;
    if (style == null) return null;
    final family = style.fontFamily;
    if (family != null &&
        !family.startsWith('CupertinoSystem') &&
        !family.startsWith('.SF')) {
      return null;
    }
    if ((style.decoration ?? TextDecoration.none) != TextDecoration.none ||
        (style.shadows?.isNotEmpty ?? false) ||
        style.foreground != null ||
        style.background != null ||
        style.backgroundColor != null) {
      return null;
    }
    final lines = node
        .getBoxesForSelection(
          TextSelection(baseOffset: 0, extentOffset: data.length),
        )
        .map((box) => box.top.round())
        .toSet()
        .length;
    final rtl = node.textDirection == TextDirection.rtl;
    return {
      'text': data,
      'fontSize': node.textScaler.scale(style.fontSize ?? 14),
      'fontWeight': (style.fontWeight ?? FontWeight.normal).value ~/ 100 - 1,
      'italic': style.fontStyle == FontStyle.italic,
      'align': switch (node.textAlign) {
        TextAlign.center => 'center',
        TextAlign.right => 'trailing',
        TextAlign.end => rtl ? 'leading' : 'trailing',
        TextAlign.start => rtl ? 'trailing' : 'leading',
        _ => 'leading',
      },
      // One unbroken line: SwiftUI's may measure a hair wider, and must not
      // wrap or truncate for it.
      'singleLine': lines <= 1 && !node.didExceedMaxLines,
      'maxLines': node.maxLines,
      // Only a colour the Text sets itself. The inherited one is the theme's
      // label colour, which is exactly what the native foreground adapts.
      'color': nativeArgb(text.style?.color, isDark: isDark),
    };
  }

  /// `IconConfig.weight`'s names.
  static String? _weightName(FontWeight weight) => switch (weight.value) {
    <= 300 => 'light',
    500 => 'medium',
    600 => 'semibold',
    >= 700 => 'bold',
    _ => null,
  };

  /// A leaf moved, changed or went: report the set once the frame is done.
  void _dirty() {
    if (_scheduled) return;
    _scheduled = true;
    SchedulerBinding.instance.addPostFrameCallback((_) {
      _scheduled = false;
      final leaves = _leaves.toList()..sort((a, b) => a.path.compareTo(b.path));
      final next = [for (final leaf in leaves) ?leaf.wire];
      if (_same(next, current)) return;
      current = next;
      onChanged(next);
    });
  }
}

bool _same(List<Map<String, Object?>> a, List<Map<String, Object?>> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (!mapEquals(a[i], b[i])) return false;
  }
  return true;
}

/// The box the leaves are measured against: the platform view's.
class _LeafHost extends SingleChildRenderObjectWidget {
  const _LeafHost({required this.leaves, required super.child});

  final GlassLeaves leaves;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLeafHost(leaves);

  @override
  void updateRenderObject(BuildContext context, _RenderLeafHost renderObject) {
    renderObject.leaves = leaves;
  }
}

class _RenderLeafHost extends RenderProxyBox {
  _RenderLeafHost(this.leaves);

  GlassLeaves leaves;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    leaves._host = this;
  }

  @override
  void detach() {
    if (leaves._host == this) leaves._host = null;
    super.detach();
  }
}

class _Leaf extends SingleChildRenderObjectWidget {
  const _Leaf({
    required this.leaves,
    required this.path,
    required this.describe,
    required super.child,
  });

  final GlassLeaves leaves;
  final String path;
  final Map<String, Object?>? Function(RenderBox child) describe;

  @override
  RenderObject createRenderObject(BuildContext context) =>
      _RenderLeaf(leaves, path, describe);

  @override
  void updateRenderObject(BuildContext context, _RenderLeaf renderObject) {
    renderObject
      ..leaves = leaves
      ..path = path
      ..describe = describe
      ..markNeedsPaint();
  }
}

/// Lays its child out as Flutter would and, when the native side can draw
/// it, paints nothing: it reports its frame instead. Semantics still come
/// from the child, so accessibility reads the Flutter text.
class _RenderLeaf extends RenderProxyBox {
  _RenderLeaf(this.leaves, this.path, this.describe);

  GlassLeaves leaves;
  String path;
  Map<String, Object?>? Function(RenderBox child) describe;

  /// What the native side draws for this leaf; null while Flutter paints it.
  Map<String, Object?>? wire;

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    leaves._leaves.add(this);
  }

  @override
  void detach() {
    leaves._leaves.remove(this);
    leaves._dirty();
    super.detach();
  }

  // ponytail: a repaint boundary between the host and a leaf would hide a
  // move from here; the split never builds one.
  @override
  void paint(PaintingContext context, Offset offset) {
    final host = leaves._host;
    final described = child == null || host == null ? null : describe(child!);
    if (described == null) {
      wire = null;
      super.paint(context, offset);
    } else {
      final origin = localToGlobal(Offset.zero, ancestor: host);
      wire = {
        ...described,
        'x': origin.dx,
        'y': origin.dy,
        'width': size.width,
        'height': size.height,
      };
    }
    leaves._dirty();
  }
}
