import 'package:flutter/cupertino.dart';
import 'package:cupertino_widgets/cupertino_widgets.dart';

import '../widgets/settings_ui.dart';

/// [CupertinoNativeButton]: styles, icon and label + icon buttons, sizes and
/// full width.
class ButtonDemoPage extends StatefulWidget {
  const ButtonDemoPage({super.key});

  @override
  State<ButtonDemoPage> createState() => _ButtonDemoPageState();
}

class _ButtonDemoPageState extends State<ButtonDemoPage> {
  String _lastAction = 'None yet';

  void _did(String action) => setState(() => _lastAction = action);

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Button',
      children: [
        SettingsSection(
          header: 'Styles',
          footer:
              'glass and glassProminent use the iOS 26 Liquid Glass '
              'material. Last action: $_lastAction',
          children: [
            _buttonRow(
              'Filled',
              CupertinoNativeButton.filled(
                onPressed: () => _did('Filled'),
                child: Text('Get'),
              ),
            ),
            _buttonRow(
              'Tinted',
              CupertinoNativeButton.tinted(
                onPressed: () => _did('Tinted'),
                child: Text('Follow'),
              ),
            ),
            _buttonRow(
              'Glass',
              CupertinoNativeButton.glass(
                onPressed: () => _did('Glass'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [
                    CupertinoSymbolImage.symbol(
                      CupertinoSymbols.squareAndArrowUp,
                    ),
                    Text('Share'),
                  ],
                ),
              ),
            ),
            _buttonRow(
              'Glass Prominent',
              CupertinoNativeButton.glassProminent(
                color: CupertinoColors.systemPurple,
                onPressed: () => _did('Glass Prominent'),
                child: Text('Continue'),
              ),
            ),
            _buttonRow(
              'Plain',
              CupertinoNativeButton(
                onPressed: () => _did('Plain'),
                child: Text('Not Now'),
              ),
            ),
          ],
        ),
        SettingsSection(
          header: 'Icon',
          children: [
            _buttonRow(
              'Plain',
              CupertinoNativeButton(
                onPressed: () => _did('Plain icon'),
                child: CupertinoSymbolImage.symbol(CupertinoSymbols.heartFill),
              ),
            ),
            _buttonRow(
              'Filled',
              CupertinoNativeButton.filled(
                borderShape: CupertinoNativeButtonBorderShape.circle,
                onPressed: () => _did('Filled icon'),
                child: CupertinoSymbolImage.symbol(CupertinoSymbols.heartFill),
              ),
            ),
            _buttonRow(
              'Tinted',
              CupertinoNativeButton.tinted(
                borderShape: CupertinoNativeButtonBorderShape.circle,
                onPressed: () => _did('Tinted icon'),
                child: CupertinoSymbolImage.symbol(CupertinoSymbols.heartFill),
              ),
            ),
            _buttonRow(
              'Glass',
              CupertinoNativeButton.glass(
                borderShape: CupertinoNativeButtonBorderShape.circle,
                onPressed: () => _did('Glass icon'),
                child: CupertinoSymbolImage.symbol(CupertinoSymbols.heartFill),
              ),
            ),
            _buttonRow(
              'Glass Prominent',
              CupertinoNativeButton.glassProminent(
                borderShape: CupertinoNativeButtonBorderShape.circle,
                onPressed: () => _did('Glass Prominent icon'),
                child: CupertinoSymbolImage.symbol(CupertinoSymbols.heartFill),
              ),
            ),
          ],
        ),
        SettingsSection(
          header: 'Label + Icon',
          children: [
            _buttonRow(
              'Plain',
              CupertinoNativeButton(
                onPressed: () => _did('Plain label + icon'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [
                    CupertinoSymbolImage.symbol(
                      CupertinoSymbols.squareAndArrowUp,
                    ),
                    Text('Share'),
                  ],
                ),
              ),
            ),
            _buttonRow(
              'Filled',
              CupertinoNativeButton.filled(
                onPressed: () => _did('Filled label + icon'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [
                    CupertinoSymbolImage.symbol(
                      CupertinoSymbols.squareAndArrowUp,
                    ),
                    Text('Share'),
                  ],
                ),
              ),
            ),
            _buttonRow(
              'Tinted',
              CupertinoNativeButton.tinted(
                onPressed: () => _did('Tinted label + icon'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [
                    CupertinoSymbolImage.symbol(
                      CupertinoSymbols.squareAndArrowUp,
                    ),
                    Text('Share'),
                  ],
                ),
              ),
            ),
            _buttonRow(
              'Glass',
              CupertinoNativeButton.glass(
                onPressed: () => _did('Glass label + icon'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [
                    CupertinoSymbolImage.symbol(
                      CupertinoSymbols.squareAndArrowUp,
                    ),
                    Text('Share'),
                  ],
                ),
              ),
            ),
            _buttonRow(
              'Glass Prominent',
              CupertinoNativeButton.glassProminent(
                onPressed: () => _did('Glass Prominent label + icon'),
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: 6,
                  children: [
                    CupertinoSymbolImage.symbol(
                      CupertinoSymbols.squareAndArrowUp,
                    ),
                    Text('Share'),
                  ],
                ),
              ),
            ),
          ],
        ),
        SettingsSection(
          header: 'Popup Menu',
          children: [
            _buttonRow(
              'Glass',
              CupertinoNativeMenu(
                title: 'Sort',
                systemImage: 'arrow.up.arrow.down',
                style: CupertinoNativeButtonStyle.glass,
                items: _menuItems,
                onAction: (id, _) => _did('Menu $id'),
              ),
            ),
            _buttonRow(
              'Icon',
              CupertinoNativeMenu(
                systemImage: 'ellipsis',
                style: CupertinoNativeButtonStyle.glass,
                borderShape: CupertinoNativeButtonBorderShape.circle,
                labelStyle: CupertinoNativeButtonLabelStyle.iconOnly,
                items: _menuItems,
                onAction: (id, _) => _did('Menu $id'),
              ),
            ),
            _buttonRow(
              'Tinted',
              CupertinoNativeMenu(
                title: 'Options',
                style: CupertinoNativeButtonStyle.tinted,
                labelStyle: CupertinoNativeButtonLabelStyle.titleOnly,
                items: _menuItems,
                onAction: (id, _) => _did('Menu $id'),
              ),
            ),
          ],
        ),
        SettingsSection(
          header: 'Sizes',
          children: [
            _buttonRow(
              'Large',
              CupertinoNativeButton.tinted(
                sizeStyle: CupertinoNativeControlSize.large,
                onPressed: () => _did('Large'),
                child: Text('Large'),
              ),
            ),
            _buttonRow(
              'Regular',
              CupertinoNativeButton.tinted(
                onPressed: () => _did('Regular'),
                child: Text('Regular'),
              ),
            ),
            _buttonRow(
              'Small',
              CupertinoNativeButton.tinted(
                sizeStyle: CupertinoNativeControlSize.small,
                onPressed: () => _did('Small'),
                child: Text('Small'),
              ),
            ),
            _buttonRow(
              'Mini',
              CupertinoNativeButton.tinted(
                sizeStyle: CupertinoNativeControlSize.mini,
                onPressed: () => _did('Mini'),
                child: Text('Mini'),
              ),
            ),
          ],
        ),
        SettingsSection(
          header: 'Full Width',
          footer:
              'expand: true fills the available width — the standard '
              'bottom-of-sheet call to action.',
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: CupertinoNativeButton.filled(
                expand: true,
                color: CupertinoColors.systemRed,
                sizeStyle: CupertinoNativeControlSize.large,
                onPressed: () => _did('Sign Out'),
                child: Text('Sign Out'),
              ),
            ),
          ],
        ),
      ],
    );
  }

  static const _menuItems = <CupertinoNativeMenuItem>[
    CupertinoNativeMenuAction(
      title: 'Share',
      systemImage: 'square.and.arrow.up',
      actionId: 'share',
    ),
    CupertinoNativeMenuAction(
      title: 'Favorite',
      systemImage: 'heart',
      actionId: 'favorite',
    ),
    CupertinoNativeMenuSection(
      items: [
        CupertinoNativeMenuAction(
          title: 'Delete',
          systemImage: 'trash',
          isDestructive: true,
          actionId: 'delete',
        ),
      ],
    ),
  ];

  Widget _buttonRow(String label, Widget button) {
    return SettingsRow(title: label, trailing: button);
  }
}
