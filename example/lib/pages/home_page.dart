import 'package:cupertino_widgets/cupertino_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Scaffold, Theme, ThemeMode;
import 'package:flutter/services.dart' show SystemUiOverlayStyle;

import '../app.dart';
import '../widgets/settings_ui.dart';
import 'alert_demo_page.dart';
import 'app_bar_demo_page.dart';
import 'button_demo_page.dart';
import 'context_menu_demo_page.dart';
import 'date_picker_demo_page.dart';
import 'effects_demo_page.dart';
import 'liquid_glass_demo_page.dart';
import 'menu_demo_page.dart';
import 'native_list_form_demo_page.dart';
import 'edge_effect_probe_page.dart';
import 'native_scaffold_demo_page.dart';
import 'native_searchable_demo_page.dart';
import 'progress_demo_page.dart';
import 'segmented_control_demo_page.dart';
import 'sheet_demo_page.dart';
import 'slider_demo_page.dart';
import 'standalone_tab_bar_demo_page.dart';
import 'switch_demo_page.dart';
import 'text_field_demo_page.dart';

/// The demo catalog — Flutter-drawn inset-grouped sections, like every other
/// page outside the native scaffold and searchable demos. Only the demos
/// themselves host platform views: page chrome stays Flutter so the app bar's
/// scroll edge effect has real content to blur (a `BackdropFilter` can't
/// sample a UIKit view, which is why the effect never showed here before).
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
        body: DefaultTextStyle(
          style: rowTitleStyle(context),
          child: CustomScrollView(
            slivers: [
              // The package's own iOS 26 app bar heads the catalog itself; the
              // trailing glass action toggles the whole app's brightness.
              CupertinoSliverAppBar(
                largeTitle: 'Cupertino Widgets',
                trailing: [
                  CupertinoNativeButton(
                    icon: CupertinoNativeIcon.named(
                      isDark ? 'sun.max' : 'moon',
                    ),
                    style: CupertinoNativeButtonStyle.glass,
                    borderShape: CupertinoNativeButtonBorderShape.circle,
                    labelStyle: CupertinoNativeButtonLabelStyle.iconOnly,
                    onPressed: () => MyApp.themeMode.value = isDark
                        ? ThemeMode.light
                        : ThemeMode.dark,
                  ),
                ],
                // Edge effect tinted like the page background.
                tintColor: CupertinoColors.systemGroupedBackground,
              ),
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom: MediaQuery.paddingOf(context).bottom + 40,
                ),
                sliver: SliverList.list(
                  children: [
                    SettingsSection(
                      separatorIndent: 56,
                      header: 'Controls',
                      children: [
                        _row(
                          context,
                          'Slider',
                          const SliderDemoPage(),
                          'slider.horizontal.3',
                          CupertinoColors.systemBlue,
                        ),
                        _row(
                          context,
                          'Switch',
                          const SwitchDemoPage(),
                          'switch.2',
                          CupertinoColors.systemGreen,
                        ),
                        _row(
                          context,
                          'Segmented Control',
                          const SegmentedControlDemoPage(),
                          'rectangle.split.3x1',
                          CupertinoColors.systemOrange,
                        ),
                        _row(
                          context,
                          'Button',
                          const ButtonDemoPage(),
                          'hand.tap',
                          CupertinoColors.systemPurple,
                        ),
                        _row(
                          context,
                          'Popup Menu',
                          const MenuDemoPage(),
                          'ellipsis.circle',
                          CupertinoColors.systemIndigo,
                        ),
                        _row(
                          context,
                          'Context Menu',
                          const ContextMenuDemoPage(),
                          'hand.point.up.left',
                          CupertinoColors.systemBrown,
                        ),
                        _row(
                          context,
                          'Text Field',
                          const TextFieldDemoPage(),
                          'character.cursor.ibeam',
                          CupertinoColors.systemTeal,
                        ),
                        _row(
                          context,
                          'Date Picker',
                          const DatePickerDemoPage(),
                          'calendar',
                          CupertinoColors.systemRed,
                        ),
                      ],
                    ),
                    SettingsSection(
                      separatorIndent: 56,
                      header: 'Navigation',
                      children: [
                        _row(
                          context,
                          'Tab Bar',
                          const StandaloneTabBarDemoPage(),
                          'square.grid.2x2',
                          CupertinoColors.systemPink,
                        ),
                        _row(
                          context,
                          'Scroll Edge Effect',
                          const EdgeEffectProbePage(),
                          'square.stack.3d.down.right',
                          CupertinoColors.systemTeal,
                        ),
                        _row(
                          context,
                          'Native Scaffold',
                          const NativeScaffoldDemoPage(),
                          'iphone',
                          CupertinoColors.systemBlue,
                        ),
                        _row(
                          context,
                          'Searchable',
                          const NativeSearchableDemoPage(),
                          'magnifyingglass',
                          CupertinoColors.systemGrey,
                        ),
                        _row(
                          context,
                          'Sheet',
                          const SheetDemoPage(),
                          'rectangle.portrait.bottomhalf.inset.filled',
                          CupertinoColors.systemGreen,
                        ),
                        _row(
                          context,
                          'App Bar & Edge Effect',
                          const AppBarDemoPage(),
                          'rectangle.topthird.inset.filled',
                          CupertinoColors.systemIndigo,
                        ),
                      ],
                    ),
                    SettingsSection(
                      separatorIndent: 56,
                      header: 'Views',
                      children: [
                        _row(
                          context,
                          'List & Form',
                          const NativeListFormDemoPage(),
                          'list.bullet',
                          CupertinoColors.systemYellow,
                        ),
                        _row(
                          context,
                          'Liquid Glass',
                          const LiquidGlassDemoPage(),
                          'sparkles',
                          CupertinoColors.systemCyan,
                        ),
                        _row(
                          context,
                          'Widget Effects',
                          const EffectsDemoPage(),
                          'wand.and.stars',
                          CupertinoColors.systemPurple,
                        ),
                      ],
                    ),
                    SettingsSection(
                      separatorIndent: 56,
                      header: 'Feedback',
                      footer:
                          'Every control on these pages is a real UIKit/SwiftUI '
                          'view rendered inside Flutter.',
                      children: [
                        _row(
                          context,
                          'Alert',
                          const AlertDemoPage(),
                          'exclamationmark.triangle',
                          CupertinoColors.systemRed,
                        ),
                        _row(
                          context,
                          'Progress',
                          const ProgressDemoPage(),
                          'chart.bar.xaxis',
                          CupertinoColors.systemCyan,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static Widget _row(
    BuildContext context,
    String title,
    Widget page,
    String symbol,
    Color color,
  ) {
    return SettingsRow(
      title: title,
      icon: SettingsIcon(symbol, color: color),
      showChevron: true,
      onTap: () => Navigator.of(
        context,
      ).push(CupertinoPageRoute(builder: (_) => page, title: 'Back')),
    );
  }
}
