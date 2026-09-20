import 'package:cupertino_widgets/cupertino_widgets.dart';
import 'package:flutter/cupertino.dart';

import 'glass_demo_stage.dart';

/// The three changes again, but where SwiftUI's own answer was not the one the
/// system actually plays. Each one says what it does differently and why.
///
///   * [_IntensityDemo]  0 → 1 without a scale. `materialize` grows the glass
///                       in; the system's appearing button does not move at
///                       all. The material is a gauge driven from zero.
///   * [_SwapGrowDemo]   1 → 1 with the squaring-up. Matched geometry alone
///                       holds the material so still that nothing announces the
///                       change.
///   * [_ReshapeGrowDemo] 1 ⇄ 2 with the same morph.
///
/// [_morphAmount] is the one number to set by eye: it is how far the group
/// swells, as a fraction of its size.
class GlassCustomTransitionDemoPage extends StatelessWidget {
  const GlassCustomTransitionDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoNativeSliverNavigationBar(
            largeTitle: 'Custom transitions',
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
              children: const [
                SizedBox(height: 20),
                _IntensityDemo(),
                _SwapGrowDemo(),
                _ReshapeGrowDemo(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// How far the glass squares up on a change. Set against the real thing, on a
/// real device — there is no reasoning to the right number.
const double _morphAmount = 0.45;

/// 0 → 1, custom: the material turned up from zero.
///
/// `materialize` scales the glass in. The system's appearing button does not
/// scale — the material reads as a gauge driven from nothing to full while the
/// content fades in place. That is not a transition at all, so this glass is
/// never inserted or removed; see [CupertinoGlassTransition.intensity].
class _IntensityDemo extends StatefulWidget {
  const _IntensityDemo();

  @override
  State<_IntensityDemo> createState() => _IntensityDemoState();
}

class _IntensityDemoState extends State<_IntensityDemo> {
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    return GlassDemoStage(
      title: 'Arrive, without the scale',
      arrow: '0 → 1',
      blurb:
          'materialize grows the glass in; the system\u2019s appearing '
          'button does not move at all. The material reads as a gauge driven '
          'from zero while the content blurs in, which is not a transition — '
          'nothing is inserted or removed.',
      code: '.intensity',
      buttonLabel: _shown ? 'Remove' : 'Add',
      onPressed: () => setState(() => _shown = !_shown),
      child: CupertinoNativeGlassGroup(
        transition: CupertinoGlassTransition.intensity,
        interactive: false,
        items: [
          CupertinoNativeGlassGroupItem(
            actionId: 'back',
            glassVisible: _shown,
            icon: CupertinoNativeIcon.named('chevron.backward'),
          ),
        ],
      ),
    );
  }
}

/// 1 → 1, custom: the swap with the squaring-up on top.
///
/// The transition underneath is still SwiftUI's `matchedGeometry` — the new
/// `actionId` is what plays it, and the content turns over on its own. What is
/// added is the morph, because a perfectly matched material is so still that
/// the change goes unannounced.
class _SwapGrowDemo extends StatefulWidget {
  const _SwapGrowDemo();

  @override
  State<_SwapGrowDemo> createState() => _SwapGrowDemoState();
}

class _SwapGrowDemoState extends State<_SwapGrowDemo> {
  bool _isBack = false;

  @override
  Widget build(BuildContext context) {
    return GlassDemoStage(
      title: 'Swap, with the morph',
      arrow: '1 → 1',
      blurb:
          'The transition underneath is still matchedGeometry. What is '
          'added is the squaring-up: at 60fps the system\u2019s own button '
          'flattens its top and bottom edges, then its sides, and unwinds. It '
          'barely changes size.',
      code: 'morphOnChange: $_morphAmount',
      buttonLabel: 'Swap',
      onPressed: () => setState(() => _isBack = !_isBack),
      child: CupertinoNativeGlassGroup(
        interactive: false,
        morphOnChange: _morphAmount,
        items: [
          CupertinoNativeGlassGroupItem(
            actionId: _isBack ? 'leading.back' : 'leading.more',
            icon: CupertinoNativeIcon.named(
              _isBack ? 'chevron.backward' : 'ellipsis',
            ),
          ),
        ],
      ),
    );
  }
}

/// 1 ⇄ 2, custom: the Photos change with the same morph.
class _ReshapeGrowDemo extends StatefulWidget {
  const _ReshapeGrowDemo();

  @override
  State<_ReshapeGrowDemo> createState() => _ReshapeGrowDemoState();
}

class _ReshapeGrowDemoState extends State<_ReshapeGrowDemo> {
  bool _selecting = false;

  @override
  Widget build(BuildContext context) {
    return GlassDemoStage(
      title: 'Reshape, with the morph',
      arrow: '1 ⇄ 2',
      blurb:
          'The same squaring-up over the Photos change, where there are two '
          'glasses for it to catch instead of one.',
      code: 'morphOnChange: $_morphAmount   ·   spacing: 6',
      buttonLabel: _selecting ? 'Done' : 'Select',
      onPressed: () => setState(() => _selecting = !_selecting),
      child: CupertinoNativeGlassGroup(
        spacing: 6,
        interactive: false,
        morphOnChange: _morphAmount,
        items: _selecting
            ? [
                CupertinoNativeGlassGroupItem(
                  actionId: 'menu.wide',
                  shape: CupertinoGlassGroupShape.capsule,
                  icon: CupertinoNativeIcon.named('line.3.horizontal'),
                  title: '•••',
                ),
                CupertinoNativeGlassGroupItem(
                  actionId: 'close',
                  shape: CupertinoGlassGroupShape.capsule,
                  icon: CupertinoNativeIcon.named('xmark'),
                  width: 44,
                ),
              ]
            : [
                CupertinoNativeGlassGroupItem(
                  actionId: 'menu',
                  shape: CupertinoGlassGroupShape.capsule,
                  icon: CupertinoNativeIcon.named('line.3.horizontal'),
                  width: 44,
                ),
                CupertinoNativeGlassGroupItem(
                  actionId: 'select',
                  shape: CupertinoGlassGroupShape.capsule,
                  title: 'Select',
                ),
              ],
      ),
    );
  }
}
