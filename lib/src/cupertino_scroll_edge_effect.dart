import 'package:flutter/cupertino.dart'
    show
        CupertinoColors,
        CupertinoDynamicColor,
        CupertinoPageScaffold,
        CupertinoTheme;
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show Scaffold, Theme;
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';

import 'cupertino_native_edge_blur.dart';

/// iOS 26 Liquid Glass scroll-edge-effect style. Used both by the standalone
/// `CupertinoNativeTabBar` (mapped to the bar's background material) and by
/// `CupertinoNativePageScaffold`'s native scroll views. No effect below iOS 26.
enum CupertinoScrollEdgeEffectStyle { automatic, soft, hard }

/// Which screen edge a [CupertinoScrollEdgeEffect] hugs.
enum CupertinoScrollEdgeEffectEdge { top, bottom }

/// iOS 26's **scroll edge effect** — the progressive blur plus adaptive wash
/// where content meets a screen edge.
///
/// Built on [CupertinoNativeEdgeBlur], it samples native controls as well as
/// Flutter content. The app must set `FLTDisablePartialRepaint` in its
/// `Info.plist`. Other platforms draw nothing for `soft`.
///
/// It has no colour of its own: both styles take the background of the page
/// showing under the effect — its [CupertinoPageScaffold]'s or [Scaffold]'s,
/// else the theme's — as the system's do. A bar laid over pages that each
/// have their own scaffold, a tab bar over its tabs, takes the visible one's.
/// On [CupertinoColors.systemBackground] or
/// [CupertinoColors.systemGroupedBackground] the `soft` wash follows the
/// content; on any other colour it is fixed in that colour, as SwiftUI's is
/// once a page has a `.background`.
///
/// Place it in a `Stack` behind a bar, sized to the region that should melt
/// into the edge:
///
/// ```dart
/// Stack(children: [
///   Positioned(top: 0, left: 0, right: 0, height: 120,
///     child: CupertinoScrollEdgeEffect(edge: CupertinoScrollEdgeEffectEdge.top)),
///   ...bar content...
/// ])
/// ```
class CupertinoScrollEdgeEffect extends StatefulWidget {
  const CupertinoScrollEdgeEffect({
    super.key,
    this.edge = CupertinoScrollEdgeEffectEdge.top,
    this.style = CupertinoScrollEdgeEffectStyle.soft,
    this.onBrightnessChanged,
  });

  final CupertinoScrollEdgeEffectEdge edge;

  /// `soft` is the progressive blur plus wash; `hard` the page's background
  /// over a blur, ending in a hard cutoff. `automatic` is `soft`.
  final CupertinoScrollEdgeEffectStyle style;

  /// Called when the content behind the effect turns bright or dark — so
  /// chrome drawn over the effect can follow, as the system's bar items do:
  /// dark over [Brightness.light], light over [Brightness.dark]. Measured
  /// under the wash, so it reports on a page of its own colour too. `soft`
  /// on iOS only.
  final ValueChanged<Brightness>? onBrightnessChanged;

  @override
  State<CupertinoScrollEdgeEffect> createState() =>
      _CupertinoScrollEdgeEffectState();
}

class _CupertinoScrollEdgeEffectState extends State<CupertinoScrollEdgeEffect> {
  /// The `.hard` wash: the page's colour at 91%, measured on iOS 26 over a
  /// green page.
  static const double _hardOpacity = 0.91;

  /// The `.hard` blur's `inputRadius`, even over the band: the system's
  /// measures σ ≈ 5–6pt on screen (2026-10-03), and a Core Animation radius
  /// of 1 shows as σ ≈ 1.5–1.85pt.
  // ponytail: derived, not measured on ours; calibrate from a capture.
  static const double _hardBlur = 3;

  /// The peak of the system's bright wash, which a page with a background of
  /// its own keeps as a fixed wash.
  static const double _washPeak = 0.84;

  /// The `soft` blur's peak `inputRadius`, held under the bar and fading
  /// with the wash: the system's own PocketBlur's (iOS 26 layer dump). Not a
  /// σ — on screen it measures σ ≈ 1.5–1.85pt (2026-10-03). Top edge only:
  /// the tab bar's edge is the wash alone, as the system's.
  static const double _blurPeak = 1;

  /// The background of a page showing under the effect that the effect is
  /// not inside — a tab of the tab bar laid over them. Null: the page around
  /// the effect.
  (Color, bool)? _pageUnder;

  @override
  void initState() {
    super.initState();
    SchedulerBinding.instance.addPostFrameCallback(_lookUnder);
  }

  /// After every frame — a tab switched, a page pushed inside one — finds
  /// the page under the effect. Asks for no frame of its own.
  void _lookUnder(Duration _) {
    if (!mounted) return;
    SchedulerBinding.instance.addPostFrameCallback(_lookUnder);
    final (hit, scaffold) = _scaffoldUnder();
    // Nothing took the hit — a page mid-transition ignores pointers: keep
    // what was there.
    if (!hit) return;
    final under = scaffold == null
        ? null
        : _backgroundOf(scaffold, scaffold.widget);
    if (under != _pageUnder) setState(() => _pageUnder = under);
  }

  /// Hit-tests what is painted under the effect's centre — the siblings
  /// before it in a stack, up the tree until one takes the hit — and returns
  /// the innermost scaffold on the way down to what was hit. A stack only
  /// paints the children it shows, so this is the visible page.
  (bool, Element?) _scaffoldUnder() {
    final effect = context.findRenderObject();
    if (effect is! RenderBox || !effect.attached || !effect.hasSize) {
      return (false, null);
    }
    final point = effect.localToGlobal(effect.size.center(Offset.zero));
    RenderObject child = effect;
    RenderObject? parent = effect.parent;
    while (parent != null) {
      if (parent is RenderStack && parent is! RenderIndexedStack ||
          parent is RenderCustomMultiChildLayoutBox) {
        final container =
            parent
                as ContainerRenderObjectMixin<
                  RenderBox,
                  ContainerBoxParentData<RenderBox>
                >;
        for (
          var sibling = container.childBefore(child as RenderBox);
          sibling != null;
          sibling = container.childBefore(sibling)
        ) {
          if (!sibling.hasSize) continue;
          final result = BoxHitTestResult();
          if (sibling.hitTest(result, position: sibling.globalToLocal(point))) {
            // The deepest render object hit: entries run deepest first.
            final target = result.path
                .map((entry) => entry.target)
                .whereType<RenderObject>()
                .first;
            return (true, _innermostScaffold(parent, target));
          }
        }
      } else if (parent is! RenderObjectWithChildMixin &&
          parent is! RenderIndexedStack) {
        // A route's theater, a viewport…: what it paints under the effect
        // is not a sibling to hit-test.
        return (false, null);
      }
      child = parent;
      parent = parent.parent;
    }
    return (false, null);
  }

  /// The innermost scaffold from [container] down to [target], found by
  /// following [target]'s render ancestors down the element tree.
  Element? _innermostScaffold(RenderObject container, RenderObject target) {
    final path = <RenderObject>{};
    for (
      RenderObject? node = target;
      node != null && node != container;
      node = node.parent
    ) {
      path.add(node);
    }
    Element? element;
    context.visitAncestorElements((ancestor) {
      if (ancestor is RenderObjectElement &&
          ancestor.renderObject == container) {
        element = ancestor;
        return false;
      }
      return true;
    });
    Element? scaffold;
    while (element != null) {
      if (element!.widget case CupertinoPageScaffold() || Scaffold()) {
        scaffold = element;
      }
      Element? next;
      element!.visitChildren((child) {
        if (next == null && path.contains(child.renderObject)) next = child;
      });
      element = next;
    }
    return scaffold;
  }

  /// The page's background — the nearest scaffold's, Cupertino or Material,
  /// else its theme's — and whether it is one of the app's own.
  static (Color, bool) _pageBackground(BuildContext context) {
    Widget? scaffold;
    context.visitAncestorElements((element) {
      if (element.widget case CupertinoPageScaffold() || Scaffold()) {
        scaffold = element.widget;
        return false;
      }
      return true;
    });
    return _backgroundOf(context, scaffold);
  }

  /// [scaffold]'s background, resolved in [context] — its theme's without
  /// one of its own — and whether it is the app's own colour: anything but
  /// the system background a [CupertinoPageScaffold] starts from, or the
  /// grouped one. Only those let the wash adapt, as only a page without a
  /// `.background` lets
  /// SwiftUI's; whether it came from the page, the theme or neither does not
  /// matter.
  static (Color, bool) _backgroundOf(BuildContext context, Widget? scaffold) {
    final color = switch (scaffold) {
      CupertinoPageScaffold(:final backgroundColor?) => backgroundColor,
      Scaffold(:final backgroundColor?) => backgroundColor,
      Scaffold() => Theme.of(context).scaffoldBackgroundColor,
      _ => CupertinoTheme.of(context).scaffoldBackgroundColor,
    };
    final resolved = CupertinoDynamicColor.resolve(color, context);
    return (resolved, !_systemBackgrounds.contains(resolved.toARGB32()));
  }

  /// Every variant of [CupertinoColors.systemBackground] — white, black, and
  /// the elevated darks — and of [CupertinoColors.systemGroupedBackground]:
  /// what an inset-grouped `List` lays under its cards itself, with no
  /// `.background`, so SwiftUI's wash still adapts on it.
  static final Set<int> _systemBackgrounds = {
    for (final system in [
      CupertinoColors.systemBackground,
      CupertinoColors.systemGroupedBackground,
    ])
      for (final color in [
        system.color,
        system.darkColor,
        system.highContrastColor,
        system.darkHighContrastColor,
        system.elevatedColor,
        system.darkElevatedColor,
        system.highContrastElevatedColor,
        system.darkHighContrastElevatedColor,
      ])
        color.toARGB32(),
  };

  @override
  Widget build(BuildContext context) {
    final (background, own) = _pageUnder ?? _pageBackground(context);
    final style = widget.style;
    final edge = widget.edge;
    final onBrightnessChanged = widget.onBrightnessChanged;
    // `hard` is not a denser fade, it is the absence of one: one flat wash
    // over one even blur, stopping at a hard line. The native view blurs
    // Flutter content and native views alike, with the same filter.
    if (style == CupertinoScrollEdgeEffectStyle.hard) {
      final wash = background.withValues(alpha: _hardOpacity);
      if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
        return CupertinoNativeEdgeBlur(
          edge: edge,
          hard: true,
          sigma: _hardBlur,
          tint: wash,
        );
      }
      return IgnorePointer(child: ColoredBox(color: wash));
    }
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.iOS) {
      // No intensity: always on. A light blur under the top wash — none at
      // the bottom — in the page's background, as the system's. The system
      // background follows
      // the content; any other colour fixes the wash to it — SwiftUI's stops
      // adapting once a page has a `.background`.
      return CupertinoNativeEdgeBlur(
        edge: edge,
        sigma: edge == CupertinoScrollEdgeEffectEdge.top ? _blurPeak : 0,
        adaptiveTint: !own,
        tint: own ? background.withValues(alpha: _washPeak) : background,
        onBrightnessChanged: onBrightnessChanged,
      );
    }
    // The native blur is iOS only; elsewhere there is no soft effect.
    return const SizedBox.shrink();
  }
}
