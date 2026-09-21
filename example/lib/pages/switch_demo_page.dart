import 'package:flutter/cupertino.dart';
import 'package:cupertino_widgets/cupertino_widgets.dart';

/// [CupertinoNativeSwitch] presented as a settings page: the rows are native
/// list cells and each switch is lowered straight into SwiftUI as the row's
/// trailing control — a real native UISwitch, exactly like Settings.
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

  bool _agree = false;
  bool _backup = true;
  String _color = 'blue';
  String _appearance = 'dark';
  final Set<String> _allergies = {'peanuts', 'gluten'};

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoNativeSliverNavigationBar(
            largeTitle: 'Switch',
            leading: Navigator.canPop(context)
                ? CupertinoNativeButton.glass(
                    borderShape: CupertinoNativeButtonBorderShape.circle,
                    onPressed: () => Navigator.pop(context),
                    child: CupertinoSymbolImage.symbol(
                      CupertinoSymbols.chevronBackward,
                      weight: FontWeight.w600,
                    ),
                  )
                : null,
          ),
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
                  onRowTap: (id) {
                    if (const ['light', 'dark', 'system'].contains(id)) {
                      setState(() => _appearance = id);
                    } else if (id.startsWith('allergy_')) {
                      final key = id.substring(8);
                      setState(
                        () => _allergies.contains(key)
                            ? _allergies.remove(key)
                            : _allergies.add(key),
                      );
                    }
                  },
                  sections: [
                    CupertinoNativeListSection(
                      header: 'Connectivity',
                      footer: _airplane
                          ? 'Airplane Mode is on — wireless radios are disabled.'
                          : 'Each switch is a native UISwitch; press-and-slide works.',
                      children: [
                        CupertinoNativeListTile(
                          id: 'airplane',
                          title: 'Airplane Mode',
                          trailing: CupertinoNativeSwitch(
                            value: _airplane,
                            onChanged: (v) => setState(() => _airplane = v),
                          ),
                        ),
                        CupertinoNativeListTile(
                          id: 'wifi',
                          title: 'Wi-Fi',
                          subtitle: _wifi ? 'FlutterNet' : 'Off',
                          trailing: CupertinoNativeSwitch(
                            value: _wifi && !_airplane,
                            onChanged: _airplane
                                ? null
                                : (v) => setState(() => _wifi = v),
                          ),
                        ),
                        CupertinoNativeListTile(
                          id: 'bluetooth',
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
                    CupertinoNativeListSection(
                      header: 'Notifications',
                      footer:
                          'activeColor swaps the standard green for any tint.',
                      children: [
                        CupertinoNativeListTile(
                          id: 'notifications',
                          title: 'Allow Notifications',
                          trailing: CupertinoNativeSwitch(
                            value: _notifications,
                            onChanged: (v) =>
                                setState(() => _notifications = v),
                          ),
                        ),
                        CupertinoNativeListTile(
                          id: 'critical',
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
                    CupertinoNativeListSection(
                      header: 'Managed',
                      footer: 'onChanged: null renders the native disabled appearance.',
                      children: [
                        const CupertinoNativeListTile(
                          id: 'managed',
                          title: 'Managed by Profile',
                          trailing: CupertinoNativeSwitch(
                            value: true,
                            onChanged: null,
                          ),
                        ),
                      ],
                    ),
                    CupertinoNativeListSection(
                      header: 'Checkbox',
                      footer:
                          'CupertinoNativeCheckbox — SwiftUI-drawn, lowered into '
                          'the row like the switches above.',
                      children: [
                        CupertinoNativeListTile(
                          id: 'agree',
                          title: 'I agree to the terms',
                          subtitle: 'Squared box, springy checkmark',
                          trailing: CupertinoNativeCheckbox(
                            value: _agree,
                            onChanged: (v) => setState(() => _agree = v),
                          ),
                        ),
                        CupertinoNativeListTile(
                          id: 'backup',
                          title: 'Back up to iCloud',
                          trailing: CupertinoNativeCheckbox(
                            value: _backup,
                            activeColor: CupertinoColors.systemGreen,
                            onChanged: (v) => setState(() => _backup = v),
                          ),
                        ),
                        const CupertinoNativeListTile(
                          id: 'locked',
                          title: 'Locked by admin',
                          trailing: CupertinoNativeCheckbox(
                            value: true,
                            onChanged: null,
                          ),
                        ),
                      ],
                    ),
                    CupertinoNativeListSection(
                      header: 'Radio',
                      footer:
                          'CupertinoNativeRadio — one selection per group; '
                          'managing the group state is the app\'s job.',
                      children: [
                        for (final (id, name) in const [
                          ('blue', 'Blue'),
                          ('green', 'Green'),
                          ('orange', 'Orange'),
                        ])
                          CupertinoNativeListTile(
                            id: 'radio_$id',
                            title: name,
                            trailing: CupertinoNativeRadio(
                              value: _color == id,
                              activeColor: id == 'green'
                                  ? CupertinoColors.systemGreen
                                  : id == 'orange'
                                  ? CupertinoColors.systemOrange
                                  : null,
                              onChanged: (_) => setState(() => _color = id),
                            ),
                          ),
                      ],
                    ),
                    CupertinoNativeListSection(
                      header: 'Appearance',
                      footer:
                          'One row selected at a time, like an inline Picker.',
                      children: [
                        for (final (id, name) in const [
                          ('light', 'Light'),
                          ('dark', 'Dark'),
                          ('system', 'System Default'),
                        ])
                          CupertinoNativeListTile(
                            id: id,
                            title: name,
                            selected: _appearance == id,
                          ),
                      ],
                    ),
                    CupertinoNativeListSection(
                      header: 'Allergies',
                      footer: 'Several rows can be selected: each tap flips its checkmark.',
                      children: [
                        for (final (id, name) in const [
                          ('peanuts', 'Peanuts'),
                          ('shellfish', 'Shellfish'),
                          ('gluten', 'Gluten'),
                        ])
                          CupertinoNativeListTile(
                            id: 'allergy_$id',
                            title: name,
                            selected: _allergies.contains(id),
                          ),
                      ],
                    ),
                  ],
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
