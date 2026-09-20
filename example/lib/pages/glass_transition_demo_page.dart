import 'package:cupertino_widgets/cupertino_widgets.dart';
import 'package:flutter/cupertino.dart';

import 'glass_demo_stage.dart';

/// The three changes SwiftUI makes on its own, one widget each, each with its
/// own button to play it and play it back.
///
/// Every one is driven by nothing but `glassEffectID` and
/// `glassEffectTransition` — by SwiftUI noticing that a glass with one id left
/// and a glass with another id arrived. No width animation, no content
/// cross-fade, no key: the transition IS the effect. Anything that needed more
/// than that lives on the custom page instead.
///
///   * [_ArriveDemo]   0 → 1. A glass where there was none. `materialize`.
///   * [_SwapDemo]     1 → 1. A different glass in the same place. The material
///                     is matched, so it never blinks; only the content turns
///                     over. `matchedGeometry`.
///   * [_ReshapeDemo]  1 ⇄ 2. Two glasses replaced by two differently sized
///                     glasses. Matched geometry morphs each old shape into its
///                     new one, and the small gap lets them touch and blend on
///                     the way past. `matchedGeometry`.
class GlassTransitionDemoPage extends StatelessWidget {
  const GlassTransitionDemoPage({super.key});

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
              children: const [
                SizedBox(height: 20),
                _ArriveDemo(),
                _SwapDemo(),
                _ReshapeDemo(),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// 0 → 1: a glass arrives where there was nothing.
///
/// The item never leaves the list — only its glass does. Taking the item out
/// instead would shrink the group's box underneath the transition and the
/// arriving glass would have nowhere to land.
class _ArriveDemo extends StatefulWidget {
  const _ArriveDemo();

  @override
  State<_ArriveDemo> createState() => _ArriveDemoState();
}

class _ArriveDemoState extends State<_ArriveDemo> {
  bool _shown = false;

  @override
  Widget build(BuildContext context) {
    return GlassDemoStage(
      title: 'Arrive',
      arrow: '0 → 1',
      blurb:
          'The only change here that is really an arrival. The item keeps '
          'its slot and loses only its material, so the box does not move '
          'underneath the glass landing in it.',
      code: 'glassVisible: \$_shown   ·   .materialize',
      buttonLabel: _shown ? 'Remove' : 'Add',
      onPressed: () => setState(() => _shown = !_shown),
      child: CupertinoNativeGlassGroup(
        transition: CupertinoGlassTransition.materialize,
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

/// 1 → 1: a different glass in the same place.
///
/// The `actionId` is what changes. To SwiftUI that is one glass leaving and
/// another arriving, and because both are the same 44pt circle the matched
/// geometry holds the material perfectly still while the icon turns over.
class _SwapDemo extends StatefulWidget {
  const _SwapDemo();

  @override
  State<_SwapDemo> createState() => _SwapDemoState();
}

class _SwapDemoState extends State<_SwapDemo> {
  bool _isBack = false;

  @override
  Widget build(BuildContext context) {
    return GlassDemoStage(
      title: 'Swap',
      arrow: '1 → 1',
      blurb:
          'A new actionId is a different glass, so one leaves and another '
          'arrives in its place. Both are the same circle, so the matched '
          'geometry holds the material still while the content turns over.',
      code:
          "actionId: '\${_isBack ? 'leading.back' : 'leading.more'}'"
          '   ·   .matchedGeometry',
      buttonLabel: 'Swap',
      onPressed: () => setState(() => _isBack = !_isBack),
      child: CupertinoNativeGlassGroup(
        interactive: false,
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

/// 1 ⇄ 2: the Photos "Select" change.
///
/// Both glasses are replaced at once — a menu circle and a "Select" capsule
/// become a wider menu capsule and an X circle — so matched geometry has an old
/// shape and a new shape for each and morphs between them. The 6pt gap is under
/// the container's blend radius, which is what makes the two run together into
/// one blob halfway through instead of sliding past each other.
class _ReshapeDemo extends StatefulWidget {
  const _ReshapeDemo();

  @override
  State<_ReshapeDemo> createState() => _ReshapeDemoState();
}

class _ReshapeDemoState extends State<_ReshapeDemo> {
  bool _selecting = false;

  @override
  Widget build(BuildContext context) {
    return GlassDemoStage(
      title: 'Reshape',
      arrow: '1 ⇄ 2',
      blurb:
          'Both glasses are replaced at once, so matched geometry has an '
          'old shape and a new one for each and morphs between them. The 6pt '
          'gap is under the blend radius, which is what lets them run '
          'together on the way past.',
      code: 'spacing: 6   ·   .matchedGeometry',
      buttonLabel: _selecting ? 'Done' : 'Select',
      onPressed: () => setState(() => _selecting = !_selecting),
      child: CupertinoNativeGlassGroup(
        spacing: 6,
        interactive: false,
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
