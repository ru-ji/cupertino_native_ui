import 'package:cupertino_widgets/cupertino_widgets.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Scaffold;
import 'package:haze/haze.dart';

import '../widgets/settings_ui.dart';

/// Every platform view the package ships, on one page, so a single push shows
/// which of them strand over the incoming page.
///
/// Each control is right-aligned on purpose. A `CupertinoPageRoute` push slides
/// the outgoing page left by a third of the width while the incoming page
/// covers from the right, so only the outgoing page's right third ever ends up
/// underneath it — which is why the bar's trailing button leaves a square and
/// its back button does not. Anything parked on the left would be untestable.
///
/// The push row is repeated top and bottom: trigger it from the top to watch
/// the controls above the fold, and from the bottom for the rest.
class NativeZooProbePage extends StatefulWidget {
  const NativeZooProbePage({super.key});

  @override
  State<NativeZooProbePage> createState() => _NativeZooProbePageState();
}

class _NativeZooProbePageState extends State<NativeZooProbePage> {
  bool _toggle = true;
  double _slider = 0.5;
  int _segment = 0;
  String _tab = 'a';
  DateTime _date = DateTime(2026, 8, 30);

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Native Zoo',
      largeTitle: false,
      children: [
        SettingsSection(
          header: 'Push',
          footer:
              'Watch the blank page slide in and note which controls stay '
              'painted over it. Only the right third of this page passes '
              'under the incoming one.',
          children: [_pushRow(context)],
        ),
        // Does the native content stay inside the box Flutter built for it?
        // The zoo's rows are flush to the screen edge, so an overflow there is
        // indistinguishable from the screen clipping it. These two are inset
        // and sit on a tinted box that IS the Flutter box, so the answer is
        // just "does the switch stick out of the colour".
        //
        //  * Sticks out of BOTH  -> SwiftUI draws past the frame it is given,
        //    and the container needs to clip.
        //  * Sticks out of the 51 only -> the Dart-side default is stale and
        //    the box is simply too small until the measurement lands.
        _header('Sizing'),
        // The one that matters now. No outer box at all, so the colour IS the
        // widget's own box — the size it asked for. Tight around the switch
        // means the native measurement arrived and was applied; loose or
        // overflowing means the widget is still on its Dart-side default.
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Row(
            children: [
              const _BoxedSwitchLabel('Its own box (measured)'),
              ColoredBox(
                color: const Color(0x330000FF),
                child: CupertinoNativeSwitch(
                  value: _toggle,
                  onChanged: (v) => setState(() => _toggle = v),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
          child: Row(
            children: [
              const _BoxedSwitchLabel('Default box (51)'),
              ColoredBox(
                color: const Color(0x3300FF00),
                child: SizedBox(
                  width: 51,
                  height: 31,
                  child: CupertinoNativeSwitch(
                    value: _toggle,
                    onChanged: (v) => setState(() => _toggle = v),
                  ),
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Row(
            children: [
              const _BoxedSwitchLabel('Roomy box (80)'),
              ColoredBox(
                color: const Color(0x33FF0000),
                child: SizedBox(
                  width: 80,
                  height: 44,
                  child: CupertinoNativeSwitch(
                    value: _toggle,
                    onChanged: (v) => setState(() => _toggle = v),
                  ),
                ),
              ),
            ],
          ),
        ),
        _header('Controls'),
        ...[
          _row(
            'Button (filled)',
            SizedBox(
              width: 96,
              child: CupertinoNativeButton(
                title: 'Tap',
                style: CupertinoNativeButtonStyle.filled,
                borderShape: CupertinoNativeButtonBorderShape.capsule,
                onPressed: () {},
              ),
            ),
          ),
          _row(
            'Button (glass)',
            CupertinoNativeButton(
              title: 'Glass',
              style: CupertinoNativeButtonStyle.glassProminent,
              borderShape: CupertinoNativeButtonBorderShape.capsule,
              onPressed: () {},
            ),
          ),
          _row(
            'Switch',
            CupertinoNativeSwitch(
              value: _toggle,
              onChanged: (v) => setState(() => _toggle = v),
            ),
          ),
          _row(
            'Slider',
            SizedBox(
              width: 140,
              child: CupertinoNativeSlider(
                value: _slider,
                onChanged: (v) => setState(() => _slider = v),
              ),
            ),
          ),
          _row(
            'Segmented',
            SizedBox(
              width: 160,
              child: CupertinoNativeSegmentedControl(
                children: const ['A', 'B'],
                groupValue: _segment,
                onChanged: (v) => setState(() => _segment = v),
              ),
            ),
          ),
          _row(
            'Progress',
            const SizedBox(
              width: 120,
              child: CupertinoNativeProgressIndicator(
                value: 0.6,
                style: CupertinoNativeProgressStyle.linear,
              ),
            ),
          ),
          _row(
            'Menu (glass)',
            SizedBox(
              width: 120,
              child: CupertinoNativeMenu(
                title: 'Menu',
                style: CupertinoNativeButtonStyle.glass,
                items: const [
                  CupertinoNativeMenuAction(title: 'One', actionId: 'one'),
                  CupertinoNativeMenuAction(title: 'Two', actionId: 'two'),
                ],
                onAction: (_, _) {},
              ),
            ),
          ),
          _row(
            'Date picker',
            SizedBox(
              width: 150,
              child: CupertinoNativeDatePicker(
                value: _date,
                onChanged: (d) => setState(() => _date = d),
              ),
            ),
          ),
        ],
        _header('Fields and glass'),
        ...[
          _row(
            'Text field',
            const SizedBox(
              width: 170,
              child: CupertinoNativeTextField(placeholder: 'Plain'),
            ),
          ),
          _row(
            'Glass field',
            SizedBox(
              width: 170,
              child: CupertinoNativeTextField(
                placeholder: 'Glass',
                glass: const CupertinoGlass(cornerRadius: 16),
                height: 44,
                prefixIcon: CupertinoNativeIcon.symbol(
                  CupertinoSymbols.magnifyingglass,
                ),
              ),
            ),
          ),
          // The glass-container form of a bar button, for comparison
          // with the real button an app bar now takes.
          _row(
            'Bar action (glass circle)',
            CupertinoNativeGlassContainer(
              shape: CupertinoGlassShape.circle,
              interactive: true,
              width: 44,
              height: 44,
              icon: CupertinoNativeIcon.named('moon').withDefaultSize(20),
              onPressed: () {},
            ),
          ),
          _row(
            'Glass capsule + label',
            CupertinoNativeButton(
              title: 'Edit',
              style: CupertinoNativeButtonStyle.glass,
              borderShape: CupertinoNativeButtonBorderShape.capsule,
              onPressed: () {},
            ),
          ),
          _row(
            'Context menu',
            CupertinoNativeContextMenu(
              items: const [
                CupertinoNativeMenuAction(title: 'Copy', actionId: 'copy'),
              ],
              child: Container(
                width: 88,
                height: 44,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: CupertinoColors.systemGrey5.resolveFrom(context),
                  borderRadius: BorderRadius.circular(10),
                ),
                child: Text('Long-press', style: footnoteStyle(context)),
              ),
            ),
          ),
          // Which of the two boxes does the effect actually reach?
          //
          // A Flutter effect painted over a native view lands in an overlay
          // render target that was cleared to transparent, so a BackdropFilter
          // up there has no backdrop to sample: it reaches the Flutter box and
          // cannot touch the native button, which keeps drawing on top of it.
          // A native effect is a UIView composited after the button's own
          // UIView, so it samples the whole hierarchy below — Flutter surface
          // and native controls alike.
          _blurProbe(
            context,
            'Haze (Flutter shader)',
            Haze(
              edge: HazeEdge.top,
              sigma: 50,
              falloff: 1,
              plateau: .3,
              tint: CupertinoDynamicColor.resolve(
                CupertinoColors.systemBackground,
                context,
              ),
              tintOpacity: .8,
            ),
          ),
          _blurProbe(
            context,
            'Glass container (native)',
            const CupertinoNativeGlassContainer(cornerRadius: 0),
          ),
          _blurProbe(
            context,
            'Scroll edge effect',
            const CupertinoScrollEdgeEffect(),
          ),
        ],
        // Full-width hosts: these cover the right third on their own.
        SettingsSection(
          header: 'List (native)',
          children: [
            const SizedBox(
              height: 132,
              child: CupertinoNativeList(
                sections: [
                  CupertinoNativeListSection(
                    rows: [
                      CupertinoNativeListRow(id: 'r1', title: 'Row one'),
                      CupertinoNativeListRow(id: 'r2', title: 'Row two'),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
        SettingsSection(
          header: 'Tab bar (native)',
          children: [
            SizedBox(
              height: 64,
              child: CupertinoNativeTabBar(
                value: _tab,
                onChanged: (id) => setState(() => _tab = id),
                tabs: [
                  CupertinoNativeTab(
                    title: 'One',
                    icon: CupertinoNativeIcon.symbol(
                      CupertinoSymbols.houseFill,
                    ),
                    id: 'a',
                  ),
                  CupertinoNativeTab(
                    title: 'Two',
                    icon: CupertinoNativeIcon.symbol(CupertinoSymbols.gear),
                    id: 'b',
                  ),
                ],
              ),
            ),
          ],
        ),
        SettingsSection(
          header: 'Push (again)',
          footer: 'Same push, reachable from the bottom of the page.',
          children: [_pushRow(context)],
        ),
      ],
    );
  }

  Widget _pushRow(BuildContext context) => SettingsRow(
    title: 'Push the blank page',
    titleColor: CupertinoColors.activeBlue.resolveFrom(context),
    onTap: () => Navigator.of(context).push(
      CupertinoPageRoute(title: 'Back', builder: (_) => const _BlankTarget()),
    ),
  );

  /// Label left, control right — the control has to sit in the right third to
  /// pass under the incoming page at all.
  /// One native control and one Flutter box, both under [effect].
  ///
  /// The only question it answers is which of the two the effect reaches. If
  /// the blue Flutter box goes soft and the glass button stays crisp on top,
  /// the effect never saw the native view.
  Widget _blurProbe(BuildContext context, String label, Widget effect) =>
      Padding(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(label, style: rowTitleStyle(context)),
            const SizedBox(height: 8),
            SizedBox(
              height: 160,
              child: Stack(
                children: [
                  Positioned(
                    top: 12,
                    left: 0,
                    child: CupertinoNativeButton(
                      title: 'Native',
                      style: CupertinoNativeButtonStyle.glassProminent,
                      borderShape: CupertinoNativeButtonBorderShape.capsule,
                      onPressed: () {},
                    ),
                  ),
                  Positioned(
                    top: 12,
                    right: 0,
                    child: Container(
                      height: 44,
                      width: 110,
                      alignment: Alignment.center,
                      color: CupertinoColors.activeBlue,
                      child: const Text(
                        'Flutter',
                        style: TextStyle(color: CupertinoColors.white),
                      ),
                    ),
                  ),
                  Positioned.fill(child: effect),
                ],
              ),
            ),
          ],
        ),
      );

  Widget _header(String text) => Padding(
    padding: const EdgeInsets.fromLTRB(16, 24, 16, 6),
    child: Builder(
      builder: (context) =>
          Text(text.toUpperCase(), style: footnoteStyle(context)),
    ),
  );

  /// Label left, control 16pt from the screen edge — the same inset the app
  /// bar gives its trailing button, so these sit exactly where the button that
  /// leaks sits. Not flush: a native view draws a little wider than the box
  /// Flutter hands it, and at zero inset it spills off screen.
  Widget _row(String label, Widget native) => Padding(
    padding: EdgeInsets.zero,
    child: Row(
      children: [
        Expanded(
          child: Builder(
            builder: (context) => Text(label, style: rowTitleStyle(context)),
          ),
        ),
        native,
      ],
    ),
  );
}

class _BoxedSwitchLabel extends StatelessWidget {
  const _BoxedSwitchLabel(this.text);

  final String text;

  @override
  Widget build(BuildContext context) =>
      Expanded(child: Text(text, style: rowTitleStyle(context)));
}

/// Blank: anything visible over it during the push came from the
/// page being left.
class _BlankTarget extends StatelessWidget {
  const _BlankTarget();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
      body: DefaultTextStyle(
        style: rowTitleStyle(context),
        child: CustomScrollView(
          slivers: [
            CupertinoSliverAppBar(
              largeTitle: 'Blank',
              expandedTitle: false,
              leading: CupertinoNativeButton(
                icon: CupertinoNativeIcon.symbol(
                  CupertinoSymbols.chevronBackward,
                ),
                style: CupertinoNativeButtonStyle.glass,
                borderShape: CupertinoNativeButtonBorderShape.circle,
                labelStyle: CupertinoNativeButtonLabelStyle.iconOnly,
                onPressed: () => Navigator.pop(context),
              ),
              tintColor: CupertinoColors.systemBackground,
            ),
          ],
        ),
      ),
    );
  }
}
