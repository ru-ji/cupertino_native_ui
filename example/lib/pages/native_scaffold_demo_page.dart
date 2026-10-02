import 'package:flutter/cupertino.dart';
import 'package:cupertino_widgets/cupertino_widgets.dart';

/// Mail, on a fully native SwiftUI scaffold: a large title with a subtitle
/// that collapses on scroll, the native search drawer, a glass bottom
/// toolbar, and native push and pop into a message — which brings its own
/// toolbars. The inbox and the messages are Flutter bodies (`mail_bodies.dart`),
/// registered in `scaffoldRoutes()`.
class NativeScaffoldDemoPage extends StatelessWidget {
  const NativeScaffoldDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CupertinoNativePageScaffold(
        body: 'inbox',
        scrollEdgeEffect: CupertinoScrollEdgeEffectStyle.soft,
        navigationBar: const CupertinoNativeScaffoldNavigationBar(
          title: 'Inbox',
          subtitle: 'Updated Just Now',
          titleDisplayMode: CupertinoNativeToolbarTitleDisplayMode.large,
          trailing: [
            CupertinoNativeToolbarItem(title: 'Select', actionId: 'select'),
          ],
          search: CupertinoNativeSearchField(
            placeholder: 'Search',
            placement: CupertinoNativeSearchPlacement.navigationBarDrawerAlways,
          ),
          // Mail's bottom bar: the filter on one side, compose on the other,
          // each in its own glass — the spacer breaks the shared capsule.
          bottom: [
            CupertinoNativeToolbarItem(
              systemImage: 'line.3.horizontal.decrease.circle',
              actionId: 'filter',
            ),
            CupertinoNativeToolbarSpacer(),
            CupertinoNativeToolbarItem(
              systemImage: 'square.and.pencil',
              actionId: 'compose',
            ),
          ],
        ),
        onToolbarAction: (route, actionId) =>
            debugPrint('Mail toolbar on $route: $actionId'),
        onRouteChanged: (routes) =>
            debugPrint('Mail stack: ${routes.join(' > ')}'),
      ),
    );
  }
}
