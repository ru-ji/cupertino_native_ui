import 'package:flutter/cupertino.dart';
import 'package:cupertino_widgets/cupertino_widgets.dart';

import '../widgets/settings_ui.dart';

/// [CupertinoNativeSwitch] presented as a settings page: each row carries a
/// bare native UISwitch as its trailing control, exactly like Settings.
class SwitchDemoPage extends StatefulWidget {
  const SwitchDemoPage({super.key});

  @override
  State<SwitchDemoPage> createState() => _SwitchDemoPageState();
}

class _SwitchDemoPageState extends State<SwitchDemoPage> {
  bool _airplane = false;
  bool _wifi = true;
  bool _bluetooth = true;
  bool _notifications = true;
  bool _critical = false;

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Switch',
      children: [
        SettingsSection(
          header: 'Connectivity',
          footer: _airplane
              ? 'Airplane Mode is on — wireless radios are disabled.'
              : 'Each switch is a native UISwitch; press-and-slide works.',
          children: [
            SettingsRow(
              title: 'Airplane Mode',
              trailing: CupertinoNativeSwitch(
                value: _airplane,
                onChanged: (v) => setState(() => _airplane = v),
              ),
            ),
            SettingsRow(
              title: 'Wi-Fi',
              subtitle: _wifi ? 'FlutterNet' : 'Off',
              trailing: CupertinoNativeSwitch(
                value: _wifi && !_airplane,
                onChanged: _airplane ? null : (v) => setState(() => _wifi = v),
              ),
            ),
            SettingsRow(
              title: 'Bluetooth',
              trailing: CupertinoNativeSwitch(
                value: _bluetooth && !_airplane,
                onChanged: _airplane
                    ? null
                    : (v) => setState(() => _bluetooth = v),
              ),
            ),
          ],
        ),
        SettingsSection(
          header: 'Notifications',
          footer: 'activeColor swaps the standard green for any tint.',
          children: [
            SettingsRow(
              title: 'Allow Notifications',
              trailing: CupertinoNativeSwitch(
                value: _notifications,
                onChanged: (v) => setState(() => _notifications = v),
              ),
            ),
            SettingsRow(
              title: 'Critical Alerts',
              subtitle: 'Delivered even while muted',
              trailing: CupertinoNativeSwitch(
                value: _critical,
                activeTrackColor: CupertinoColors.systemRed,
                onChanged: _notifications
                    ? (v) => setState(() => _critical = v)
                    : null,
              ),
            ),
          ],
        ),
        const SettingsSection(
          header: 'Managed',
          footer: 'onChanged: null renders the native disabled appearance.',
          children: [
            SettingsRow(
              title: 'Managed by Profile',
              trailing: CupertinoNativeSwitch(value: true, onChanged: null),
            ),
          ],
        ),
      ],
    );
  }
}
