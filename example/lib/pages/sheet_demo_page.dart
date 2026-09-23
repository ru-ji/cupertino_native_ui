import 'package:flutter/cupertino.dart';
import 'package:cupertino_widgets/cupertino_widgets.dart';

/// [CupertinoNativeSheet] — the system page-sheet modal
/// (`UISheetPresentationController`): rising over the app it pushes this page
/// back and down, with native detents, grabber and swipe-to-dismiss. With an
/// app bar the sheet gets pinned native chrome (title, glass-circle bar
/// buttons, optional search field and segmented control) and the Flutter
/// content scrolls natively beneath it — like Safari's Page Menu.
class SheetDemoPage extends StatefulWidget {
  const SheetDemoPage({super.key});

  @override
  State<SheetDemoPage> createState() => _SheetDemoPageState();
}

class _SheetDemoPageState extends State<SheetDemoPage> {
  String _last = 'None yet';

  /// Liquid Glass (iOS 26+) closes a sheet with an X; before that the leading
  /// item reads like the system back button — a chevron and a label.
  bool _glass = true;

  @override
  void initState() {
    super.initState();
    CupertinoNativeGlassContainer.isSupported.then((v) {
      if (mounted) setState(() => _glass = v);
    });
  }

  CupertinoNativeScaffoldNavigationBar _appBar({bool withSearch = false}) {
    return CupertinoNativeScaffoldNavigationBar(
      title: 'New Event',
      titleDisplayMode: CupertinoNativeToolbarTitleDisplayMode.inline,
      leading: [
        CupertinoNativeBarItem(
          icon: CupertinoNativeIcon.symbol(
            _glass ? CupertinoSymbols.xmark : CupertinoSymbols.chevronBackward,
          ),
          title: _glass ? null : 'Cancel',
          actionId: 'close',
        ),
      ],
      trailing: [const CupertinoNativeBarItem(title: 'Add', actionId: 'add')],
      search: withSearch
          ? const CupertinoNativeSearchField(
              placeholder: 'Search invitees',
              placement:
                  CupertinoNativeSearchPlacement.navigationBarDrawerAlways,
            )
          : null,
    );
  }

  void _onBarAction(String id) {
    setState(() => _last = 'Bar action: $id');
    if (id == 'close' || id == 'add') CupertinoNativeSheet.dismiss();
  }

  Future<void> _present({
    required String label,
    CupertinoNativeScaffoldNavigationBar? appBar,
    CupertinoNativeSheetSegmentedControl? bottom,
    List<CupertinoNativeSheetDetent> detents = const [
      CupertinoNativeSheetDetent.medium,
      CupertinoNativeSheetDetent.large,
    ],
  }) async {
    setState(() => _last = '$label — presented');
    await CupertinoNativeSheet.show(
      route: 'newEvent',
      isDark: CupertinoTheme.brightnessOf(context) == Brightness.dark,
      appBar: appBar,
      bottom: bottom,
      detents: detents,
      showDragHandle: true,
      // Match the body's background so the chrome regions (bar, safe areas)
      // don't show as a different-colored band.
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      onBarAction: _onBarAction,
      onBottomChanged: (i) => setState(() => _last = 'Segment: $i'),
      onSearchChanged: (q) => setState(() => _last = 'Search: "$q"'),
    );
    if (mounted) setState(() => _last = '$label — dismissed');
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 44;
    return CupertinoPageScaffold(
      child: Stack(
        children: [
          ListView(
            padding: EdgeInsets.only(
              top: top,
              bottom: MediaQuery.paddingOf(context).bottom + 40,
            ),
            children: [
              CupertinoNativeList(
                onRowTap: (id) {
                  switch (id) {
                    case 'appBar':
                      _present(label: 'App bar sheet', appBar: _appBar());
                    case 'segmented':
                      _present(
                        label: 'Segmented sheet',
                        appBar: _appBar(),
                        bottom: const CupertinoNativeSheetSegmentedControl(
                          segments: ['Event', 'Reminder', 'Call'],
                        ),
                      );
                    case 'search':
                      _present(
                        label: 'Search sheet',
                        appBar: _appBar(withSearch: true),
                        detents: const [CupertinoNativeSheetDetent.large],
                      );
                    case 'bare':
                      _present(label: 'Bare sheet');
                  }
                },
                sections: [
                  CupertinoNativeListSection(
                    header: 'Present',
                    footer: 'Last event: $_last',
                    children: const [
                      CupertinoNativeListTile(
                        id: 'appBar',
                        title: 'With App Bar',
                        subtitle: 'Pinned title, ✕ leading, Add trailing — scrollable',
                        showChevron: true,
                      ),
                      CupertinoNativeListTile(
                        id: 'segmented',
                        title: 'With Bottom Segmented Control',
                        subtitle: 'Native segmented pinned under the bar',
                        showChevron: true,
                      ),
                      CupertinoNativeListTile(
                        id: 'search',
                        title: 'With Search Field',
                        subtitle:
                            'The scaffold-style native search, in a sheet',
                        showChevron: true,
                      ),
                      CupertinoNativeListTile(
                        id: 'bare',
                        title: 'Bare Sheet',
                        subtitle:
                            'No chrome — the Flutter body owns everything',
                        showChevron: true,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          CupertinoNativeNavigationBar(
            title: 'Sheet',
            leading: CupertinoNativeButton.glass(
              borderShape: CupertinoNativeButtonBorderShape.circle,
              onPressed: () => Navigator.pop(context),
              child: CupertinoSymbolImage.symbol(
                CupertinoSymbols.chevronBackward,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
