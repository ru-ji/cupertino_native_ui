import 'package:flutter/cupertino.dart';
import 'package:cupertino_native_ui/cupertino_native_ui.dart';

/// [CupertinoNativeSheet]: the system page-sheet modal
/// (`UISheetPresentationController`): rising over the app it pushes this page
/// back and down, with native detents, grabber and swipe-to-dismiss. With an
/// app bar the sheet gets pinned native chrome (title, glass-circle bar
/// buttons, optional search field and segmented control) and the Flutter
/// content scrolls natively beneath it, like Safari's Page Menu.
class SheetDemoPage extends StatefulWidget {
  const SheetDemoPage({super.key});

  @override
  State<SheetDemoPage> createState() => _SheetDemoPageState();
}

class _SheetDemoPageState extends State<SheetDemoPage> {
  String _last = 'None yet';

  /// Liquid Glass (iOS 26+) closes a sheet with an X; before that the leading
  /// item reads like the system back button: a chevron and a label.
  bool _glass = true;

  @override
  void initState() {
    super.initState();
    CupertinoNativeGlassContainer.isSupported.then((v) {
      if (mounted) setState(() => _glass = v);
    });
  }

  CupertinoNativeScaffoldNavigationBar _navigationBar({
    String title = 'New Event',
    bool withSearch = false,
  }) {
    return CupertinoNativeScaffoldNavigationBar(
      title: title,
      titleDisplayMode: CupertinoNativeToolbarTitleDisplayMode.inline,
      leading: [
        CupertinoNativeToolbarItem(
          icon: CupertinoNativeIcon.symbol(
            _glass ? CupertinoSymbols.xmark : CupertinoSymbols.chevronBackward,
          ),
          title: _glass ? null : 'Cancel',
          actionId: 'close',
        ),
      ],
      trailing: [
        const CupertinoNativeToolbarItem(title: 'Add', actionId: 'add'),
      ],
      search: withSearch
          ? const CupertinoNativeSearchField(
              placeholder: 'Search invitees',
              placement:
                  CupertinoNativeSearchPlacement.navigationBarDrawerAlways,
            )
          : null,
    );
  }

  void _onToolbarAction(String id) {
    setState(() => _last = 'Bar action: $id');
    if (id == 'close' || id == 'add') CupertinoNativeSheet.dismiss();
  }

  Future<void> _present({
    required String label,
    CupertinoNativeScaffoldNavigationBar? navigationBar,
    CupertinoNativeSheetSegmentedControl? bottom,
    List<CupertinoNativeSheetDetent> detents = const [
      CupertinoNativeSheetDetent.medium,
      CupertinoNativeSheetDetent.large,
    ],
  }) async {
    setState(() => _last = '$label: presented');
    await CupertinoNativeSheet.show(
      route: 'newEvent',
      isDark: CupertinoTheme.brightnessOf(context) == Brightness.dark,
      navigationBar: navigationBar,
      bottom: bottom,
      detents: detents,
      showDragHandle: true,
      // Match the body's background so the chrome regions (bar, safe areas)
      // don't show as a different-colored band.
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      onToolbarAction: _onToolbarAction,
      onBottomChanged: (i) => setState(() => _last = 'Segment: $i'),
      onSearchChanged: (q) => setState(() => _last = 'Search: "$q"'),
    );
    if (mounted) setState(() => _last = '$label: dismissed');
  }

  // The native-body sheet: Display & Brightness, as in Settings, SwiftUI end
  // to end. Nothing here runs in a Flutter engine: every change comes back
  // through `onBodyEvent` and the tree is pushed back.
  int _appearance = 1;
  double _brightness = 0.7;
  bool _trueTone = true;
  int _nightShift = 0;
  int _textSize = 3;
  bool _boldText = false;
  int _autoLock = 1;
  bool _raiseToWake = true;
  static const _nightShifts = ['Off', 'Sunset to Sunrise', '10 PM to 7 AM'];
  static const _autoLocks = ['Never', '30 seconds', '1 minute', '5 minutes'];

  static CupertinoNativeBody _header(String text) => CupertinoNativeBody.text(
    text,
    style: CupertinoNativeTextStyle.footnote,
    color: CupertinoColors.secondaryLabel,
    padding: const EdgeInsets.fromLTRB(36, 14, 36, 0),
  );

  CupertinoNativeBody _nativeBody() => CupertinoNativeBody.column(
    spacing: 8,
    padding: const EdgeInsets.only(bottom: 32),
    children: [
      _header('APPEARANCE'),
      CupertinoNativeBody.segmented(
        id: 'appearance',
        items: const ['Light', 'Dark', 'Automatic'],
        selectedIndex: _appearance,
        padding: const EdgeInsets.symmetric(horizontal: 20),
      ),
      _header('BRIGHTNESS'),
      CupertinoNativeBody.slider(
        id: 'brightness',
        value: _brightness,
        minimumIcon: const CupertinoNativeIcon.named('sun.min'),
        maximumIcon: const CupertinoNativeIcon.named('sun.max.fill'),
        padding: const EdgeInsets.symmetric(horizontal: 24),
      ),
      CupertinoNativeBody.list(
        id: 'display',
        sections: [
          CupertinoNativeListSection(
            footer:
                'Automatically adapt the display based on ambient lighting '
                'conditions to make colors appear consistent.',
            children: [
              CupertinoNativeListTile(
                id: 'trueTone',
                title: 'True Tone',
                type: CupertinoNativeListTileType.toggle,
                toggleValue: _trueTone,
              ),
              CupertinoNativeListTile(
                id: 'nightShift',
                title: 'Night Shift',
                additionalInfo: _nightShifts[_nightShift],
                showChevron: true,
              ),
            ],
          ),
        ],
      ),
      _header('TEXT SIZE'),
      CupertinoNativeBody.slider(
        id: 'textSize',
        value: _textSize.toDouble(),
        max: 6,
        step: 1,
        minimumIcon: const CupertinoNativeIcon.named('textformat.size.smaller'),
        maximumIcon: const CupertinoNativeIcon.named('textformat.size.larger'),
        padding: const EdgeInsets.symmetric(horizontal: 24),
      ),
      CupertinoNativeBody.text(
        'Apps that support Dynamic Type will adjust to your preferred '
        'reading size.',
        fontSize: 13.0 + _textSize * 2,
        fontWeight: _boldText ? FontWeight.w700 : FontWeight.w400,
        padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 4),
      ),
      CupertinoNativeBody.list(
        id: 'text',
        sections: [
          CupertinoNativeListSection(
            children: [
              CupertinoNativeListTile(
                id: 'boldText',
                title: 'Bold Text',
                type: CupertinoNativeListTileType.toggle,
                toggleValue: _boldText,
              ),
            ],
          ),
          CupertinoNativeListSection(
            children: [
              CupertinoNativeListTile(
                id: 'autoLock',
                title: 'Auto-Lock',
                additionalInfo: _autoLocks[_autoLock],
                showChevron: true,
              ),
              CupertinoNativeListTile(
                id: 'raiseToWake',
                title: 'Raise to Wake',
                type: CupertinoNativeListTileType.toggle,
                toggleValue: _raiseToWake,
              ),
            ],
          ),
        ],
      ),
    ],
  );

  Future<void> _presentNative() async {
    setState(() => _last = 'Display & Brightness: presented');
    await CupertinoNativeSheet.show(
      nativeBody: _nativeBody(),
      navigationBar: const CupertinoNativeScaffoldNavigationBar(
        title: 'Display & Brightness',
        titleDisplayMode: CupertinoNativeToolbarTitleDisplayMode.inline,
        trailing: [CupertinoNativeToolbarItem(title: 'Done', actionId: 'done')],
      ),
      detents: const [
        CupertinoNativeSheetDetent.medium,
        CupertinoNativeSheetDetent.large,
      ],
      showDragHandle: true,
      backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
        context,
      ),
      onToolbarAction: (_) => CupertinoNativeSheet.dismiss(),
      onBodyEvent: (id, value) {
        switch (id) {
          case 'appearance':
            _appearance = (value as num).toInt();
          case 'brightness':
            _brightness = (value as num).toDouble();
          case 'textSize':
            _textSize = (value as num).round();
          case 'display.trueTone':
            _trueTone = value as bool;
          case 'text.boldText':
            _boldText = value as bool;
          case 'text.raiseToWake':
            _raiseToWake = value as bool;
          case 'display' when value == 'nightShift':
            _nightShift = (_nightShift + 1) % _nightShifts.length;
          case 'text' when value == 'autoLock':
            _autoLock = (_autoLock + 1) % _autoLocks.length;
        }
        // Controlled: push the tree back so the rows follow.
        CupertinoNativeSheet.updateNativeBody(_nativeBody());
      },
    );
    if (mounted) {
      setState(
        () => _last =
            'Display: ${const ['Light', 'Dark', 'Automatic'][_appearance]}, '
            'brightness ${(_brightness * 100).round()}%, '
            'text size ${_textSize + 1}/7',
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    final top = MediaQuery.paddingOf(context).top + 44;
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
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
                    case 'navigationBar':
                      _present(
                        label: 'App bar sheet',
                        navigationBar: _navigationBar(),
                      );
                    case 'segmented':
                      _present(
                        label: 'Segmented sheet',
                        navigationBar: _navigationBar(),
                        bottom: const CupertinoNativeSheetSegmentedControl(
                          segments: ['Event', 'Reminder', 'Call'],
                        ),
                      );
                    case 'search':
                      _present(
                        label: 'Search sheet',
                        navigationBar: _navigationBar(withSearch: true),
                        detents: const [CupertinoNativeSheetDetent.large],
                      );
                    case 'bare':
                      _present(label: 'Bare sheet');
                    case 'native':
                      _presentNative();
                  }
                },
                sections: [
                  CupertinoNativeListSection(
                    header: 'Present',
                    footer: 'Last event: $_last',
                    children: const [
                      CupertinoNativeListTile(
                        id: 'navigationBar',
                        title: 'With App Bar',
                        subtitle:
                            'Pinned title, ✕ leading, Add trailing, scrollable',
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
                        id: 'native',
                        title: 'Native Body',
                        subtitle: 'A reminder form in pure SwiftUI, no Flutter engine',
                        showChevron: true,
                      ),
                      CupertinoNativeListTile(
                        id: 'bare',
                        title: 'Bare Sheet',
                        subtitle: 'No chrome: the Flutter body owns everything',
                        showChevron: true,
                      ),
                    ],
                  ),
                ],
              ),
            ],
          ),
          CupertinoNativeNavigationBar(title: 'Sheet'),
        ],
      ),
    );
  }
}
