import 'package:cupertino_widgets/cupertino_widgets.dart';
import 'package:flutter/cupertino.dart';

/// The same change as the custom page's Swap — an `ellipsis` becoming a
/// `chevron.backward` — but played by the system instead of reproduced.
///
/// The transition the recordings show is a navigation bar's, and a navigation
/// bar's buttons are not glasses in a `GlassEffectContainer`: they are toolbar
/// items, animated by the bar itself. There is no modifier to copy, so the
/// nearest thing to the real effect is not a better imitation — it is the real
/// one, which this package already exposes. `CupertinoNativeBarItem` is a
/// genuine `ToolbarItem` in a genuine toolbar; change one and the system plays
/// its own transition, whatever that transition happens to be this release.
///
/// Tap the button in the bar to swap it. Held against
/// `GlassCustomTransitionDemoPage`, this is what the custom one is chasing.
class SystemBarDemoPage extends StatefulWidget {
  const SystemBarDemoPage({super.key});

  @override
  State<SystemBarDemoPage> createState() => _SystemBarDemoPageState();
}

class _SystemBarDemoPageState extends State<SystemBarDemoPage> {
  bool _isBack = false;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CupertinoNativePageScaffold(
        body: 'systemBarBody',
        onBarAction: (route, actionId) {
          if (actionId == 'swap') setState(() => _isBack = !_isBack);
        },
        navigationBar: CupertinoNativeScaffoldNavigationBar(
          title: 'System bar',
          titleDisplayMode: CupertinoNativeToolbarTitleDisplayMode.large,
          trailing: [
            CupertinoNativeBarItem(
              actionId: 'swap',
              icon: CupertinoNativeIcon.named(
                _isBack ? 'chevron.backward' : 'ellipsis',
              ),
              // Its own glass capsule, out of the toolbar's shared background —
              // the single round button the recordings show.
              sharedBackgroundVisibility: true,
            ),
          ],
        ),
      ),
    );
  }
}

/// The body behind the bar. It exists only so the bar has a page to sit on.
class SystemBarBody extends StatelessWidget {
  const SystemBarBody({super.key});

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(32),
        child: Text(
          'Tap the button in the bar.\n\n'
          'This one is a real toolbar item, so the transition is the '
          'system’s own — not a reproduction of it.',
          textAlign: TextAlign.center,
          style: TextStyle(fontSize: 15),
        ),
      ),
    );
  }
}
