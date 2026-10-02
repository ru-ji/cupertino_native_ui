import 'package:cupertino_widgets/cupertino_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Scaffold, Theme, ThemeMode;
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import '../app.dart';
import 'bars_demo_page.dart';
import 'button_demo_page.dart';
import 'context_menu_demo_page.dart';
import 'edge_effect_probe_page.dart';
import 'hard_edge_demo_page.dart';
import 'liquid_glass_demo_page.dart';
import 'native_list_demo_page.dart';
import 'native_scaffold_demo_page.dart';
import 'native_searchable_demo_page.dart';
import 'pickers_demo_page.dart';
import 'sheet_demo_page.dart';
import 'slider_demo_page.dart';
import 'switch_demo_page.dart';
import 'text_field_demo_page.dart';

/// The demo catalog — a native SwiftUI list of rows, like every page in the
/// app now. Each row is a real SwiftUI cell with a native chevron; tapping
/// one reports its id and the page is pushed.
class HomePage extends StatelessWidget {
  const HomePage({super.key});

  @override
  Widget build(BuildContext context) {
    final isDark = Theme.of(context).brightness == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      // A plain Flutter scaffold under the package's own bar: it owns the page
      // background and the safe areas, the bar rides above it as a sliver.
      child: Scaffold(
        backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
          context,
        ),
        body: CustomScrollView(
          slivers: [
            // The package's own iOS 26 app bar heads the catalog itself; the
            // trailing glass action toggles the whole app's brightness.
            CupertinoNativeSliverNavigationBar(
              largeTitle: 'Cupertino Widgets',
              trailing: [
                CupertinoNativeButton.glass(
                  borderShape: CupertinoNativeButtonBorderShape.circle,
                  onPressed: () => MyApp.themeMode.value = isDark
                      ? ThemeMode.light
                      : ThemeMode.dark,
                  child: CupertinoSymbolImage(isDark ? 'sun.max' : 'moon'),
                ),
              ],
              // Edge effect tinted like the page background.
              tintColor: CupertinoColors.systemGroupedBackground,
            ),
            SliverPadding(
              padding: EdgeInsets.only(
                bottom: MediaQuery.paddingOf(context).bottom + 40,
              ),
              sliver: SliverToBoxAdapter(
                child: CupertinoNativeList(
                  style: CupertinoNativeListStyle.insetGrouped,
                  onRowTap: (id) => _open(context, id),
                  sections: [
                    CupertinoNativeListSection(
                      header: 'Controls',
                      children: [
                        _row(
                          'button',
                          'Button',
                          'hand.tap',
                          CupertinoColors.systemPurple,
                        ),
                        _row(
                          'switch',
                          'Switch',
                          'switch.2',
                          CupertinoColors.systemGreen,
                        ),
                        _row(
                          'slider',
                          'Slider',
                          'slider.horizontal.3',
                          CupertinoColors.systemBlue,
                        ),
                        _row(
                          'pickers',
                          'Pickers',
                          'filemenu.and.selection',
                          CupertinoColors.systemOrange,
                        ),
                        _row(
                          'textField',
                          'Text Field',
                          'character.cursor.ibeam',
                          CupertinoColors.systemTeal,
                        ),
                        _row(
                          'contextMenu',
                          'Context Menu',
                          'hand.point.up.left',
                          CupertinoColors.systemBrown,
                        ),
                      ],
                    ),
                    CupertinoNativeListSection(
                      header: 'Navigation',
                      children: [
                        _row(
                          'bars',
                          'Navigation & Tab Bar',
                          'rectangle.topthird.inset.filled',
                          CupertinoColors.systemIndigo,
                        ),
                        _row(
                          'nativeScaffold',
                          'Native Scaffold',
                          'iphone',
                          CupertinoColors.systemBlue,
                        ),
                        _row(
                          'hardEdge',
                          'Hard Edge Effect',
                          'rectangle.split.1x2',
                          CupertinoColors.systemTeal,
                        ),
                        _row(
                          'searchable',
                          'Searchable',
                          'magnifyingglass',
                          CupertinoColors.systemGrey,
                        ),
                        _row(
                          'sheet',
                          'Sheet',
                          'rectangle.portrait.bottomhalf.inset.filled',
                          CupertinoColors.systemGreen,
                        ),
                      ],
                    ),
                    CupertinoNativeListSection(
                      header: 'Views',
                      footer:
                          'Every control on these pages is a real UIKit/SwiftUI '
                          'view rendered inside Flutter.',
                      children: [
                        _row(
                          'list',
                          'List',
                          'list.bullet',
                          CupertinoColors.systemYellow,
                        ),
                        _row(
                          'liquidGlass',
                          'Liquid Glass',
                          'sparkles',
                          CupertinoColors.systemCyan,
                        ),
                        _row(
                          'edgeEffect',
                          'Scroll Edge Effect',
                          'square.stack.3d.up',
                          CupertinoColors.systemBlue,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  static CupertinoNativeListTile _row(
    String id,
    String title,
    String symbol,
    Color color,
  ) {
    return CupertinoNativeListTile(
      id: id,
      title: title,
      leading: CupertinoNativeIcon.named(symbol, color: color),
      showChevron: true,
    );
  }

  static void _open(BuildContext context, String id) {
    final Widget page = switch (id) {
      'button' => const ButtonDemoPage(),
      'switch' => const SwitchDemoPage(),
      'slider' => const SliderDemoPage(),
      'pickers' => const PickersDemoPage(),
      'textField' => const TextFieldDemoPage(),
      'contextMenu' => const ContextMenuDemoPage(),
      'bars' => const BarsDemoPage(),
      'nativeScaffold' => const NativeScaffoldDemoPage(),
      'hardEdge' => const HardEdgeDemoPage(),
      'searchable' => const NativeSearchableDemoPage(),
      'sheet' => const SheetDemoPage(),
      'list' => const NativeListDemoPage(),
      'liquidGlass' => const LiquidGlassDemoPage(),
      'edgeEffect' => const EdgeEffectProbePage(),
      _ => const SliderDemoPage(),
    };
    Navigator.of(context)
    // No route title: on iOS 15–18 the next bar's back button takes the
    // title of the page it came from, as UIKit's does.
    .push(CupertinoPageRoute(builder: (_) => page));
  }
}
