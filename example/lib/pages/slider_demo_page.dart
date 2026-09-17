import 'package:flutter/cupertino.dart';
import 'package:cupertino_widgets/cupertino_widgets.dart';

import '../widgets/settings_ui.dart';

/// [CupertinoNativeSlider] presented as a "Sounds & Haptics"-style settings
/// page: the rows are native list cells and each slider is lowered straight
/// into SwiftUI as the row's trailing control — a real native UISlider, with
/// the live value in the row's trailing text.
class SliderDemoPage extends StatefulWidget {
  const SliderDemoPage({super.key});

  @override
  State<SliderDemoPage> createState() => _SliderDemoPageState();
}

class _SliderDemoPageState extends State<SliderDemoPage> {
  double _volume = 0.55;
  double _brightness = 0.8;
  double _alertVolume = 0.6;

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Slider',
      children: [
        CupertinoNativeList(
          sections: [
            CupertinoNativeListSection(
              header: 'Ringtone and Alerts',
              footer:
                  'The slider is a native UISlider — drag it and the value '
                  'streams back to Flutter live.',
              children: [
                CupertinoNativeListTile(
                  id: 'volume',
                  title: 'Volume',
                  additionalInfo: '${(_volume * 100).round()}%',
                  trailing: CupertinoNativeSlider(
                    value: _volume,
                    onChanged: (v) => setState(() => _volume = v),
                  ),
                ),
              ],
            ),
            CupertinoNativeListSection(
              header: 'Display',
              footer: 'activeColor tints the filled track.',
              children: [
                CupertinoNativeListTile(
                  id: 'brightness',
                  title: 'Brightness',
                  additionalInfo: '${(_brightness * 100).round()}%',
                  trailing: CupertinoNativeSlider(
                    value: _brightness,
                    activeColor: CupertinoColors.systemOrange,
                    onChanged: (v) => setState(() => _brightness = v),
                  ),
                ),
              ],
            ),
            CupertinoNativeListSection(
              header: 'Alert Volume',
              footer: 'divisions: 10 snaps the thumb to discrete steps.',
              children: [
                CupertinoNativeListTile(
                  id: 'alerts',
                  title: 'Alerts',
                  additionalInfo: '${(_alertVolume * 100).round()}%',
                  trailing: CupertinoNativeSlider(
                    value: _alertVolume,
                    divisions: 10,
                    onChanged: (v) => setState(() => _alertVolume = v),
                  ),
                ),
              ],
            ),
            CupertinoNativeListSection(
              header: 'Managed',
              footer: 'onChanged: null renders the native disabled appearance.',
              children: [
                const CupertinoNativeListTile(
                  id: 'media',
                  title: 'Media Volume',
                  additionalInfo: 'Locked',
                  trailing: CupertinoNativeSlider(value: 0.35, onChanged: null),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
