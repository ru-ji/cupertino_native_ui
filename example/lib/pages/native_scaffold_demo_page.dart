import 'package:flutter/cupertino.dart';
import 'package:cupertino_widgets/cupertino_widgets.dart';

/// Full native SwiftUI scaffold: large title that collapses on scroll,
/// grouped toolbar items, a tab bar with a search-role tab and
/// minimize-on-scroll (iOS 26), soft scroll edge effect, and native push/pop
/// transitions (see ScaffoldHomeBody). Bodies come from `scaffoldRoutes()`
/// via `CupertinoNativePageScaffold.maybeRun` in main() — no entry point needed.
class NativeScaffoldDemoPage extends StatelessWidget {
  const NativeScaffoldDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CupertinoNativePageScaffold(
        scrollEdgeEffect: CupertinoScrollEdgeEffectStyle.soft,
        navigationBar: CupertinoNativeScaffoldNavigationBar(
          title: 'Library',
          subtitle: '128 items',
          titleDisplayMode: CupertinoNativeToolbarTitleDisplayMode.large,
          trailing: [
            // Each CupertinoNativeBarItem gets its own glass capsule (iOS 26).
            // Wrap multiple items in CupertinoNativeBarItemGroup to share one capsule.
            CupertinoNativeBarItem(
              icon: CupertinoNativeIcon.symbol(CupertinoSymbols.plus),
              actionId: 'add',
            ),
            CupertinoNativeBarItem(
              icon: CupertinoNativeIcon.symbol(CupertinoSymbols.ellipsisCircle),
              actionId: 'more',
            ),
          ],
        ),
        tabBar: CupertinoNativeTabBar(
          minimizeBehavior: CupertinoNativeTabBarMinimizeBehavior.onScrollDown,
          // iOS 26 bottom accessory (a persistent bar above the tab bar). It
          // shows its subtitle only in the system's `.expanded` placement.
          accessory: CupertinoNativeTabBarAccessory(
            title: 'Now Playing',
            subtitle: 'Deep Focus — Track 3',
            icon: CupertinoNativeIcon.named('music.note'),
            actionId: 'accessory',
          ),
          items: [
            CupertinoNativeTab(
              title: 'Home',
              icon: CupertinoNativeIcon.symbol(CupertinoSymbols.houseFill),
              id: 'home',
            ),
            CupertinoNativeTab(
              title: 'Search',
              icon: CupertinoNativeIcon.symbol(
                CupertinoSymbols.magnifyingglass,
              ),
              id: 'search',
              role: CupertinoNativeTabRole.search,
              // The search-role tab presents itself as a native search field.
              search: CupertinoNativeSearchField(
                placeholder: 'Search your library',
              ),
            ),
            CupertinoNativeTab(
              title: 'Profile',
              icon: CupertinoNativeIcon.symbol(CupertinoSymbols.personFill),
              id: 'profile',
            ),
            CupertinoNativeTab(
              title: 'Settings',
              icon: CupertinoNativeIcon.symbol(CupertinoSymbols.gear),
              id: 'settings',
            ),
          ],
        ),
        onBarAction: (route, actionId) {
          debugPrint('Scaffold bar action on $route: $actionId');
        },
        onTabChanged: (id) => debugPrint('Scaffold tab changed: $id'),
        onRouteChanged: (routes) =>
            debugPrint('Scaffold stack: ${routes.join(' > ')}'),
      ),
    );
  }
}
