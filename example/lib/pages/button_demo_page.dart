import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Icons;
import 'package:cupertino_native_ui/cupertino_native_ui.dart';

/// [CupertinoNativeButton]: styles, icon and label + icon buttons, sizes and
/// full width. The rows are native list cells with the buttons lowered
/// straight into SwiftUI as trailing controls.
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
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: CustomScrollView(
        slivers: [
          CupertinoNativeSliverNavigationBar(largeTitle: 'Button'),
          SliverPadding(
            padding: EdgeInsets.only(
              bottom:
                  MediaQuery.paddingOf(context).bottom +
                  MediaQuery.viewInsetsOf(context).bottom +
                  40,
            ),
            sliver: SliverList.list(
              children: [
                CupertinoNativeList(
                  sections: [
                    CupertinoNativeListSection(
                      header: 'Styles',
                      footer:
                          'glass and glassProminent use the iOS 26 Liquid Glass '
                          'material. Last action: $_lastAction',
                      children: [
                        _buttonRow(
                          'filled',
                          'Filled',
                          CupertinoNativeButton.filled(
                            onPressed: () => _did('Filled'),
                            child: Text('Get'),
                          ),
                        ),
                        _buttonRow(
                          'tinted',
                          'Tinted',
                          CupertinoNativeButton.tinted(
                            onPressed: () => _did('Tinted'),
                            child: Text('Follow'),
                          ),
                        ),
                        _buttonRow(
                          'glass',
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
                          'glassProminent',
                          'Glass Prominent',
                          CupertinoNativeButton.glassProminent(
                            color: CupertinoColors.systemPurple,
                            onPressed: () => _did('Glass Prominent'),
                            child: Text('Continue'),
                          ),
                        ),
                        _buttonRow(
                          'plain',
                          'Plain',
                          CupertinoNativeButton(
                            onPressed: () => _did('Plain'),
                            child: Text('Not Now'),
                          ),
                        ),
                      ],
                    ),
                    CupertinoNativeListSection(
                      header: 'Icon',
                      children: [
                        for (final (id, name, make) in _buttonStyles('icon'))
                          _buttonRow(id, name, make()),
                      ],
                    ),
                    CupertinoNativeListSection(
                      header: 'Label + Icon',
                      children: [
                        for (final (id, name, make) in _buttonStyles(
                          'labelIcon',
                          withLabel: true,
                        ))
                          _buttonRow(id, name, make()),
                      ],
                    ),
                    CupertinoNativeListSection(
                      header: 'Custom Icons',
                      footer:
                          'An Icon (any icon font) or an ImageIcon of an asset, '
                          'drawn natively and tinted like a symbol.',
                      children: [
                        _buttonRow(
                          'cupertinoIcon',
                          'CupertinoIcons',
                          CupertinoNativeButton.glass(
                            borderShape:
                                CupertinoNativeButtonBorderShape.circle,
                            onPressed: () => _did('CupertinoIcons'),
                            child: Icon(CupertinoIcons.heart_fill),
                          ),
                        ),
                        _buttonRow(
                          'materialIcon',
                          'Material Icons',
                          CupertinoNativeButton.tinted(
                            onPressed: () => _did('Material Icons'),
                            child: Row(
                              mainAxisSize: MainAxisSize.min,
                              spacing: 6,
                              children: [
                                Icon(Icons.rocket_launch),
                                Text('Launch'),
                              ],
                            ),
                          ),
                        ),
                        _buttonRow(
                          'assetIcon',
                          'Asset',
                          CupertinoNativeButton.glassProminent(
                            borderShape:
                                CupertinoNativeButtonBorderShape.circle,
                            onPressed: () => _did('Asset'),
                            child: ImageIcon(
                              AssetImage('assets/icons/star.png'),
                            ),
                          ),
                        ),
                      ],
                    ),
                    CupertinoNativeListSection(
                      header: 'Sizes',
                      children: [
                        _buttonRow(
                          'large',
                          'Large',
                          CupertinoNativeButton.tinted(
                            sizeStyle: CupertinoNativeControlSize.large,
                            onPressed: () => _did('Large'),
                            child: Text('Large'),
                          ),
                        ),
                        _buttonRow(
                          'regular',
                          'Regular',
                          CupertinoNativeButton.tinted(
                            onPressed: () => _did('Regular'),
                            child: Text('Regular'),
                          ),
                        ),
                        _buttonRow(
                          'small',
                          'Small',
                          CupertinoNativeButton.tinted(
                            sizeStyle: CupertinoNativeControlSize.small,
                            onPressed: () => _did('Small'),
                            child: Text('Small'),
                          ),
                        ),
                        _buttonRow(
                          'mini',
                          'Mini',
                          CupertinoNativeButton.tinted(
                            sizeStyle: CupertinoNativeControlSize.mini,
                            onPressed: () => _did('Mini'),
                            child: Text('Mini'),
                          ),
                        ),
                      ],
                    ),
                    CupertinoNativeListSection(
                      header: 'Popup Menu',
                      children: [
                        _buttonRow(
                          'menuGlass',
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
                          'menuIcon',
                          'Icon',
                          CupertinoNativeMenu(
                            systemImage: 'ellipsis',
                            style: CupertinoNativeButtonStyle.glass,
                            borderShape:
                                CupertinoNativeButtonBorderShape.circle,
                            labelStyle:
                                CupertinoNativeButtonLabelStyle.iconOnly,
                            items: _menuItems,
                            onAction: (id, _) => _did('Menu $id'),
                          ),
                        ),
                        _buttonRow(
                          'menuTinted',
                          'Tinted',
                          CupertinoNativeMenu(
                            title: 'Options',
                            style: CupertinoNativeButtonStyle.tinted,
                            labelStyle:
                                CupertinoNativeButtonLabelStyle.titleOnly,
                            items: _menuItems,
                            onAction: (id, _) => _did('Menu $id'),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                // No section: one button needs no card, and a Flutter card
                // around a native control is what interleaves the layers.
                Padding(
                  padding: const EdgeInsets.all(16),
                  child: CupertinoNativeButton.filled(
                    expand: true,
                    color: CupertinoColors.systemRed,
                    sizeStyle: CupertinoNativeControlSize.large,
                    onPressed: () => _did('Sign Out'),
                    child: const Text('Sign Out'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The five button styles, as icon buttons and optionally with a label.
  List<(String, String, Widget Function())> _buttonStyles(
    String section, {
    bool withLabel = false,
  }) {
    void did(String name) => _did('${withLabel ? 'label + icon ' : ''}$name');

    Widget content() {
      final icon = CupertinoSymbolImage.symbol(CupertinoSymbols.heartFill);
      if (!withLabel) return icon;
      return Row(
        mainAxisSize: MainAxisSize.min,
        spacing: 6,
        children: [
          CupertinoSymbolImage.symbol(CupertinoSymbols.squareAndArrowUp),
          const Text('Share'),
        ],
      );
    }

    return [
      (
        '$section-plain',
        'Plain',
        () => CupertinoNativeButton(
          onPressed: () => did('Plain'),
          child: content(),
        ),
      ),
      (
        '$section-filled',
        'Filled',
        () => CupertinoNativeButton.filled(
          borderShape: CupertinoNativeButtonBorderShape.circle,
          onPressed: () => did('Filled'),
          child: content(),
        ),
      ),
      (
        '$section-tinted',
        'Tinted',
        () => CupertinoNativeButton.tinted(
          borderShape: CupertinoNativeButtonBorderShape.circle,
          onPressed: () => did('Tinted'),
          child: content(),
        ),
      ),
      (
        '$section-glass',
        'Glass',
        () => CupertinoNativeButton.glass(
          borderShape: CupertinoNativeButtonBorderShape.circle,
          onPressed: () => did('Glass'),
          child: content(),
        ),
      ),
      (
        '$section-glassProminent',
        'Glass Prominent',
        () => CupertinoNativeButton.glassProminent(
          borderShape: CupertinoNativeButtonBorderShape.circle,
          onPressed: () => did('Glass Prominent'),
          child: content(),
        ),
      ),
    ];
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

  static CupertinoNativeListTile _buttonRow(
    String id,
    String label,
    Widget button,
  ) {
    return CupertinoNativeListTile(id: id, title: label, trailing: button);
  }
}
