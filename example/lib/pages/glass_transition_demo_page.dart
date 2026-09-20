import 'package:flutter/cupertino.dart';
import 'package:cupertino_widgets/cupertino_widgets.dart';

/// Every transition a [CupertinoNativeGlassGroup] can make, one at a time, so
/// each can be judged on its own.
///
/// The group is a single platform view, and a glass can only merge with another
/// glass inside it — that is the whole reason this widget exists, and the whole
/// reason none of this is reproducible with two separate glass buttons.
///
/// The four changes:
///
/// * **Appear** — 0 → 1 and 1 → 0. A glass arrives where there was nothing.
///   The item keeps its slot and only loses its material, so the group's box
///   does not shrink underneath the arrival.
/// * **Swap** — 1 → 1. One glass replaced by another in the same place. A new
///   `actionId` is a *different* glass to SwiftUI, so the old one leaves and
///   the new one arrives where it stood; there is no geometry to match.
/// * **Merge** — 1 → 2 and 2 → 1. Two glasses taken into and out of one shared
///   shape, by giving them the same `unionId`.
///
/// `Shape` is worth playing with on Merge. A union's frame is the whole group,
/// and a circle is *inscribed* in the frame it is given — so a bare circle
/// union would collapse to a single item's worth of glass in the middle, with
/// both icons left outside it. The widget therefore draws any unioned item as a
/// capsule, which fills the frame; on a square item a capsule *is* a circle, so
/// nothing is lost. `Rounded` fills it too, with a corner radius instead.
///
/// `Blend` is the other. The container also merges glasses that are nearer to
/// each other than its own spacing, whether or not their ids match — a
/// different number from the gap the items are laid out with, and one this
/// widget used to pass for both.
class GlassTransitionDemoPage extends StatefulWidget {
  const GlassTransitionDemoPage({super.key});

  @override
  State<GlassTransitionDemoPage> createState() =>
      _GlassTransitionDemoPageState();
}

/// The three shapes the change takes. Four transitions, three knobs: 0 → 1 and
/// 1 → 0 are one case, and 1 → 2 and 2 → 1 are another, because each pair
/// changes the same thing.
enum _Change {
  appear('Appear', '0 → 1', 8),
  swap('Swap', '1 → 1', 8),
  merge('Merge', '1 ⇄ 2', 20);

  const _Change(this.label, this.arrow, this.gap);

  final String label;
  final String arrow;

  /// The gap the items are laid out with, in points. The merge case wants a
  /// gap wide enough that two separate glasses are unmistakably separate.
  final double gap;
}

class _GlassTransitionDemoPageState extends State<GlassTransitionDemoPage> {
  static const _transitions = [
    CupertinoGlassTransition.matchedGeometry,
    CupertinoGlassTransition.materialize,
    CupertinoGlassTransition.identity,
  ];
  static const _transitionLabels = ['Match', 'Materialize', 'None'];

  static const _shapes = [
    CupertinoGlassGroupShape.circle,
    CupertinoGlassGroupShape.capsule,
    CupertinoGlassGroupShape.roundedRect,
  ];
  static const _shapeLabels = ['Circle', 'Capsule', 'Round'];

  _Change _change = _Change.merge;
  CupertinoGlassTransition _transition =
      CupertinoGlassTransition.matchedGeometry;
  CupertinoGlassGroupShape _shape = CupertinoGlassGroupShape.circle;

  /// Which way round the change is: present/absent, A/B, or united/separate.
  bool _on = true;

  /// Whether the container's blend radius is the gap (the old behaviour) or
  /// zero, leaving the union as the only thing that can unite two glasses.
  bool _blendWithGap = false;

  /// The items for the current change. Only `actionId`, `unionId` and
  /// `glassVisible` ever move — the group itself is the same widget throughout,
  /// which is the point: what varies is the change, not the container.
  List<CupertinoNativeGlassGroupItem> get _items {
    switch (_change) {
      case _Change.appear:
        return [
          CupertinoNativeGlassGroupItem(
            actionId: 'appear',
            shape: _shape,
            glassVisible: _on,
            icon: CupertinoNativeIcon.named('sparkles'),
          ),
        ];
      case _Change.swap:
        // A different actionId each way, so SwiftUI sees a different glass.
        return [
          CupertinoNativeGlassGroupItem(
            actionId: _on ? 'swap.back' : 'swap.forward',
            shape: _shape,
            icon: CupertinoNativeIcon.named(
              _on ? 'arrow.uturn.backward' : 'arrow.uturn.forward',
            ),
          ),
        ];
      case _Change.merge:
        // Same actionIds both ways; only the union id moves.
        return [
          CupertinoNativeGlassGroupItem(
            actionId: 'merge.back',
            shape: _shape,
            unionId: _on ? 'pair' : null,
            icon: CupertinoNativeIcon.named('arrow.uturn.backward'),
          ),
          CupertinoNativeGlassGroupItem(
            actionId: 'merge.forward',
            shape: _shape,
            unionId: _on ? 'pair' : null,
            icon: CupertinoNativeIcon.named('arrow.uturn.forward'),
          ),
        ];
    }
  }

  /// A one-line description of exactly what is on the stage, so a screenshot
  /// says what was being looked at.
  String get _caption {
    final blend = _blendWithGap ? '${_change.gap.toInt()}' : '0';
    return '${_change.arrow}  ·  ${_transitionLabels[_transitions.indexOf(_transition)]}'
        '  ·  ${_shapeLabels[_shapes.indexOf(_shape)]}'
        '  ·  gap ${_change.gap.toInt()}, blend $blend';
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoNativeSliverNavigationBar(
            largeTitle: 'Glass transitions',
            leading: Navigator.canPop(context)
                ? CupertinoNativeButton.glass(
                    borderShape: CupertinoNativeButtonBorderShape.circle,
                    onPressed: () => Navigator.pop(context),
                    child: CupertinoSymbolImage.symbol(
                      CupertinoSymbols.chevronBackward,
                    ),
                  )
                : null,
          ),
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom + 40,
            ),
            sliver: SliverList.list(
              children: [
                const SizedBox(height: 20),
                // The stage. Fixed height and a fixed backdrop, so the group's
                // position and size can be compared between one state and the
                // next without the page moving underneath it.
                Container(
                  height: 260,
                  margin: const EdgeInsets.symmetric(horizontal: 16),
                  clipBehavior: Clip.antiAlias,
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(26),
                  ),
                  child: Stack(
                    children: [
                      const Positioned.fill(child: _Backdrop()),
                      // A landmark the group sits on. If the group's box
                      // changed size the glass would move off this line.
                      Align(
                        alignment: Alignment.center,
                        child: SizedBox(
                          width: 260,
                          height: 1,
                          child: ColoredBox(
                            color: CupertinoColors.white.withValues(alpha: 0.35),
                          ),
                        ),
                      ),
                      Center(
                        child: CupertinoNativeGlassGroup(
                          spacing: _change.gap,
                          mergeDistance: _blendWithGap ? null : 0,
                          transition: _transition,
                          tint: CupertinoColors.systemBlue,
                          interactive: false,
                          onAction: (_) {},
                          items: _items,
                        ),
                      ),
                      Positioned(
                        left: 0,
                        right: 0,
                        bottom: 12,
                        child: Text(
                          _caption,
                          textAlign: TextAlign.center,
                          style: const TextStyle(
                            color: CupertinoColors.white,
                            fontSize: 12,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                CupertinoNativeList(
                  sections: [
                    CupertinoNativeListSection(
                      header: 'The change',
                      footer:
                          'Appear is 0 → 1 and 1 → 0: a glass arrives where '
                          'there was nothing, keeping its slot so the box does '
                          'not move under it. Swap is 1 → 1: one glass replaced '
                          'by another in the same place, with no geometry to '
                          'match. Merge is 1 ⇄ 2: two glasses taken into and out '
                          'of one shared shape. Flip State to play whichever is '
                          'showing.',
                      children: [
                        CupertinoNativeListTile(
                          id: 'change',
                          title: 'Change',
                          subtitle: _change.arrow,
                          trailing:
                              CupertinoNativeSlidingSegmentedControl<int>.menu(
                                children: {
                                  for (final (i, c) in _Change.values.indexed)
                                    i: Text(c.label),
                                },
                                groupValue: _change.index,
                                onValueChanged: (v) => setState(() {
                                  _change = _Change.values[v!];
                                  _on = true;
                                }),
                              ),
                        ),
                        CupertinoNativeListTile(
                          id: 'transition',
                          title: 'Transition',
                          subtitle: switch (_transition) {
                            CupertinoGlassTransition.matchedGeometry =>
                              'Shapes travel into each other',
                            CupertinoGlassTransition.materialize =>
                              'Material fades, no geometry match',
                            CupertinoGlassTransition.identity => 'No transition',
                          },
                          trailing:
                              CupertinoNativeSlidingSegmentedControl<int>.menu(
                                children: {
                                  for (final (i, label)
                                      in _transitionLabels.indexed)
                                    i: Text(label),
                                },
                                groupValue: _transitions.indexOf(_transition),
                                onValueChanged: (v) => setState(
                                  () => _transition = _transitions[v!],
                                ),
                              ),
                        ),
                        CupertinoNativeListTile(
                          id: 'shape',
                          title: 'Shape',
                          subtitle: switch (_shape) {
                            CupertinoGlassGroupShape.circle =>
                              'Inscribed — a union promotes it to a capsule',
                            CupertinoGlassGroupShape.capsule =>
                              'Fills the union — holds both icons',
                            CupertinoGlassGroupShape.roundedRect =>
                              'Fills the union, corner radius 16',
                          },
                          trailing:
                              CupertinoNativeSlidingSegmentedControl<int>.menu(
                                children: {
                                  for (final (i, label)
                                      in _shapeLabels.indexed)
                                    i: Text(label),
                                },
                                groupValue: _shapes.indexOf(_shape),
                                onValueChanged: (v) =>
                                    setState(() => _shape = _shapes[v!]),
                              ),
                        ),
                        CupertinoNativeListTile(
                          id: 'state',
                          title: switch (_change) {
                            _Change.appear => _on ? 'Present' : 'Absent',
                            _Change.swap => _on ? 'Glass A' : 'Glass B',
                            _Change.merge => _on ? 'United' : 'Separate',
                          },
                          subtitle: 'Flip to play the change',
                          trailing: CupertinoNativeSwitch(
                            value: _on,
                            onChanged: (v) => setState(() => _on = v),
                          ),
                        ),
                      ],
                    ),
                    CupertinoNativeListSection(
                      header: 'Blending',
                      footer:
                          'A union states that two glasses are one; the '
                          'container\'s spacing lets it *infer* the same thing '
                          'for glasses nearer than that spacing, whatever their '
                          'ids say. Two separate questions, and this widget used '
                          'to answer both with one number. On "0" only the union '
                          'id can unite them. On "Gap" the radius equals the gap.',
                      children: [
                        CupertinoNativeListTile(
                          id: 'blend',
                          title: 'Blend radius',
                          subtitle: _blendWithGap
                              ? 'The gap — the old behaviour'
                              : '0 — the union decides',
                          trailing:
                              CupertinoNativeSlidingSegmentedControl<int>.menu(
                                children: const {
                                  0: Text('Gap'),
                                  1: Text('0'),
                                },
                                groupValue: _blendWithGap ? 0 : 1,
                                onValueChanged: (v) =>
                                    setState(() => _blendWithGap = v == 0),
                              ),
                        ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// Vivid Flutter-drawn artwork for the glass to refract.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2980), Color(0xFF26D0CE)],
        ),
      ),
      child: Stack(
        children: const [
          _Blob(top: -40, left: -30, size: 200, color: Color(0xFFFF6B9D)),
          _Blob(bottom: -50, right: -40, size: 220, color: Color(0xFFFFC371)),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({
    this.top,
    this.left,
    this.right,
    this.bottom,
    required this.size,
    required this.color,
  });

  final double? top, left, right, bottom;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
