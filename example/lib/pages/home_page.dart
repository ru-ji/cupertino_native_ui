import 'package:cupertino_widgets/cupertino_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Scaffold, Theme, ThemeMode;
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import '../app.dart';
import 'alert_demo_page.dart';
import 'app_bar_demo_page.dart';
import 'button_demo_page.dart';
import 'context_menu_demo_page.dart';
import 'date_picker_demo_page.dart';
import 'effects_demo_page.dart';
import 'liquid_glass_demo_page.dart';
import 'native_body_demo_page.dart';
import 'native_list_form_demo_page.dart';
import 'native_scaffold_demo_page.dart';
import 'native_searchable_demo_page.dart';
import 'progress_demo_page.dart';
import 'segmented_control_demo_page.dart';
import 'sheet_demo_page.dart';
import 'slider_demo_page.dart';
import 'standalone_tab_bar_demo_page.dart';
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
                        _row('slider', 'Slider', 'slider.horizontal.3',
                            CupertinoColors.systemBlue),
                        _row('switch', 'Switch', 'switch.2',
                            CupertinoColors.systemGreen),
                        _row('segmented', 'Segmented Control',
                            'rectangle.split.3x1', CupertinoColors.systemOrange),
                        _row('button', 'Button', 'hand.tap',
                            CupertinoColors.systemPurple),
                        _row('contextMenu', 'Context Menu',
                            'hand.point.up.left', CupertinoColors.systemBrown),
                        _row('textField', 'Text Field', 'character.cursor.ibeam',
                            CupertinoColors.systemTeal),
                        _row('datePicker', 'Date Picker', 'calendar',
                            CupertinoColors.systemRed),
                      ],
                    ),
                    CupertinoNativeListSection(
                      header: 'Navigation',
                      children: [
                        _row('tabBar', 'Tab Bar', 'square.grid.2x2',
                            CupertinoColors.systemPink),
                        _row('nativeBody', 'Native Body', 'swift',
                            CupertinoColors.systemOrange),
                        _row('nativeScaffold', 'Native Scaffold', 'iphone',
                            CupertinoColors.systemBlue),
                        _row('searchable', 'Searchable', 'magnifyingglass',
                            CupertinoColors.systemGrey),
                        _row('sheet', 'Sheet',
                            'rectangle.portrait.bottomhalf.inset.filled',
                            CupertinoColors.systemGreen),
                        _row('navigationBar', 'Navigation Bar',
                            'rectangle.topthird.inset.filled',
                            CupertinoColors.systemIndigo),
                      ],
                    ),
                    CupertinoNativeListSection(
                      header: 'Views',
                      children: [
                        _row('listForm', 'List & Form', 'list.bullet',
                            CupertinoColors.systemYellow),
                        _row('liquidGlass', 'Liquid Glass', 'sparkles',
                            CupertinoColors.systemCyan),
                        _row('effects', 'Widget Effects', 'wand.and.stars',
                            CupertinoColors.systemPurple),
                      ],
                    ),
                    CupertinoNativeListSection(
                      header: 'Feedback',
                      footer:
                          'Every control on these pages is a real UIKit/SwiftUI '
                          'view rendered inside Flutter.',
                      children: [
                        _row('alert', 'Alert', 'exclamationmark.triangle',
                            CupertinoColors.systemRed),
                        _row('progress', 'Progress', 'chart.bar.xaxis',
                            CupertinoColors.systemCyan),
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
      'slider' => const SliderDemoPage(),
      'switch' => const SwitchDemoPage(),
      'segmented' => const SegmentedControlDemoPage(),
      'button' => const ButtonDemoPage(),
      'contextMenu' => const ContextMenuDemoPage(),
      'textField' => const TextFieldDemoPage(),
      'datePicker' => const DatePickerDemoPage(),
      'tabBar' => const StandaloneTabBarDemoPage(),
      'nativeBody' => const NativeBodyDemoPage(),
      'nativeScaffold' => const NativeScaffoldDemoPage(),
      'searchable' => const NativeSearchableDemoPage(),
      'sheet' => const SheetDemoPage(),
      'navigationBar' => const AppBarDemoPage(),
      'listForm' => const NativeListFormDemoPage(),
      'liquidGlass' => const LiquidGlassDemoPage(),
      'effects' => const EffectsDemoPage(),
      'alert' => const AlertDemoPage(),
      'progress' => const ProgressDemoPage(),
      _ => const SliderDemoPage(),
    };
    Navigator.of(context).push(
      CupertinoPageRoute(builder: (_) => page, title: 'Back'),
    );
  }
}
