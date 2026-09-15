import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:cupertino_widgets/cupertino_widgets.dart';

import '../widgets/settings_ui.dart';

/// Verifies that standard Flutter effect widgets apply to the plugin's
/// native (Swift) views: the stage hosts a button and a `UISwitch`, and the
/// rows below wrap them in `Opacity`, `Visibility`, `Offstage` and
/// `Transform` (translate / scale / rotate). All of these reach the
/// underlying `UIView` through Flutter's platform-view mutators.
///
/// Known iOS caveat: a Liquid Glass / material background
/// (`UIVisualEffectView`) keeps rendering its effect at full intensity under
/// an inherited alpha — `Opacity` fades the button's label before its glass.
/// Prefer `Visibility`/`Offstage` to fully hide glass surfaces.
class EffectsDemoPage extends StatefulWidget {
  const EffectsDemoPage({super.key});

  @override
  State<EffectsDemoPage> createState() => _EffectsDemoPageState();
}

class _EffectsDemoPageState extends State<EffectsDemoPage> {
  static const _opacities = [1.0, 0.66, 0.33, 0.0];
  static const _scales = [1.0, 0.75, 1.3];
  static const _rotations = [0, 15, 45, 180];
  static const _translations = [0.0, 24.0, -24.0];

  int _opacityIndex = 0;
  int _scaleIndex = 0;
  int _rotationIndex = 0;
  int _translationIndex = 0;
  bool _visible = true;
  bool _offstage = false;
  bool _toggleValue = true;

  @override
  Widget build(BuildContext context) {
    // The wrapped natives: a glass button (material background) and a plain
    // UISwitch, so both a Liquid Glass surface and a regular control are
    // covered by every effect.
    Widget stage = Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        CupertinoNativeButton.glass(onPressed: () {}, child: Text('Glass')),
        const SizedBox(width: 20),
        CupertinoNativeSwitch(
          value: _toggleValue,
          onChanged: (v) => setState(() => _toggleValue = v),
        ),
      ],
    );

    stage = Transform.translate(
      offset: Offset(_translations[_translationIndex], 0),
      child: Transform.rotate(
        angle: _rotations[_rotationIndex] * math.pi / 180,
        child: Transform.scale(
          scale: _scales[_scaleIndex],
          child: Opacity(opacity: _opacities[_opacityIndex], child: stage),
        ),
      ),
    );
    // Plain Visibility: removes the platform views from the tree entirely —
    // re-showing recreates them.
    stage = Visibility(visible: _visible, child: stage);
    // Offstage keeps them alive but unpainted.
    stage = Offstage(offstage: _offstage, child: stage);

    return DemoScaffold(
      title: 'Widget Effects',
      children: [
        // Fixed-height stage so hiding the natives doesn't reflow the page.
        SizedBox(height: 140, child: Center(child: stage)),
        SettingsSection(
          header: 'Effects',
          footer:
              'Every effect reaches the UIView through platform-view '
              'mutators. Note: an inherited Opacity fades the glass button\'s '
              'label but iOS keeps rendering the glass material itself — use '
              'Visibility or Offstage to fully hide glass surfaces.',
          children: [
            SettingsRow(
              title: 'Opacity',
              value: '${(_opacities[_opacityIndex] * 100).round()}%',
              onTap: () => setState(
                () => _opacityIndex = (_opacityIndex + 1) % _opacities.length,
              ),
            ),
            SettingsRow(
              title: 'Visibility',
              value: _visible ? 'visible' : 'hidden',
              onTap: () => setState(() => _visible = !_visible),
            ),
            SettingsRow(
              title: 'Offstage',
              value: _offstage ? 'offstage' : 'on stage',
              onTap: () => setState(() => _offstage = !_offstage),
            ),
            SettingsRow(
              title: 'Scale',
              value: '×${_scales[_scaleIndex]}',
              onTap: () => setState(
                () => _scaleIndex = (_scaleIndex + 1) % _scales.length,
              ),
            ),
            SettingsRow(
              title: 'Rotation',
              value: '${_rotations[_rotationIndex]}°',
              onTap: () => setState(
                () => _rotationIndex = (_rotationIndex + 1) % _rotations.length,
              ),
            ),
            SettingsRow(
              title: 'Translate',
              value: '${_translations[_translationIndex].round()}px',
              onTap: () => setState(
                () => _translationIndex =
                    (_translationIndex + 1) % _translations.length,
              ),
            ),
          ],
        ),
      ],
    );
  }
}
