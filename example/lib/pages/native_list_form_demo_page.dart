import 'package:flutter/cupertino.dart';
import 'package:cupertino_widgets/cupertino_widgets.dart';

import '../widgets/settings_ui.dart';

/// [CupertinoNativeList] and [CupertinoNativeForm] as a Settings clone. Both
/// are rendered natively (SwiftUI-style inset-grouped sections) and self-size,
/// so they drop straight into this Flutter scroll view. Section corners match
/// the running iOS version automatically (26pt on iOS 26+).
class NativeListFormDemoPage extends StatefulWidget {
  const NativeListFormDemoPage({super.key});

  @override
  State<NativeListFormDemoPage> createState() => _NativeListFormDemoPageState();
}

class _NativeListFormDemoPageState extends State<NativeListFormDemoPage> {
  String _lastTap = 'none';
  bool _airplane = false;
  bool _wifi = true;
  bool _bluetooth = true;

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'List & Form',
      children: [
        // ---- CupertinoNativeList: navigation-style rows -------------------
        CupertinoNativeList(
          style: CupertinoNativeListStyle.insetGrouped,
          onRowTap: (id) => setState(() => _lastTap = id),
          sections: [
            CupertinoNativeListSection(
              header: 'General',
              footer:
                  'Native rows: taps report the row id to Flutter '
                  '(last: $_lastTap).',
              children: [
                CupertinoNativeListTile(
                  id: 'about',
                  title: 'About',
                  leading: CupertinoNativeIcon.symbol(
                    CupertinoSymbols.infoCircleFill,
                    color: CupertinoColors.systemBlue,
                  ),
                  showChevron: true,
                ),
                CupertinoNativeListTile(
                  id: 'update',
                  title: 'Software Update',
                  additionalInfo: 'iOS 26.0',
                  leading: CupertinoNativeIcon.symbol(
                    CupertinoSymbols.gear,
                    color: CupertinoColors.systemGrey,
                  ),
                  showChevron: true,
                ),
                CupertinoNativeListTile(
                  id: 'storage',
                  title: 'iPhone Storage',
                  subtitle: '205 GB of 256 GB used',
                  leading: const CupertinoNativeIcon.named(
                    'internaldrive',
                    color: CupertinoColors.systemOrange,
                  ),
                  showChevron: true,
                ),
                const CupertinoNativeListTile(
                  id: 'legal',
                  title: 'Legal & Regulatory',
                  type: CupertinoNativeListTileType.button,
                ),
              ],
            ),
          ],
        ),

        // ---- CupertinoNativeForm: toggle rows ------------------------------
        CupertinoNativeForm(
          onToggle: (id, value) {
            setState(() {
              switch (id) {
                case 'airplane':
                  _airplane = value;
                case 'wifi':
                  _wifi = value;
                case 'bluetooth':
                  _bluetooth = value;
              }
            });
          },
          sections: [
            CupertinoNativeListSection(
              header: 'Connectivity',
              footer:
                  'Native Form with toggle rows — '
                  'Wi-Fi ${_wifi ? 'on' : 'off'} · '
                  'Bluetooth ${_bluetooth ? 'on' : 'off'} · '
                  'Airplane ${_airplane ? 'on' : 'off'}.',
              children: [
                CupertinoNativeListTile(
                  id: 'airplane',
                  title: 'Airplane Mode',
                  leading: const CupertinoNativeIcon.named(
                    'airplane',
                    color: CupertinoColors.systemOrange,
                  ),
                  type: CupertinoNativeListTileType.toggle,
                  toggleValue: _airplane,
                ),
                CupertinoNativeListTile(
                  id: 'wifi',
                  title: 'Wi-Fi',
                  subtitle: 'FlutterNet',
                  leading: CupertinoNativeIcon.symbol(
                    CupertinoSymbols.wifi,
                    color: CupertinoColors.systemBlue,
                  ),
                  type: CupertinoNativeListTileType.toggle,
                  toggleValue: _wifi,
                ),
                CupertinoNativeListTile(
                  id: 'bluetooth',
                  title: 'Bluetooth',
                  leading: const CupertinoNativeIcon.named(
                    'dot.radiowaves.left.and.right',
                    color: CupertinoColors.systemBlue,
                  ),
                  type: CupertinoNativeListTileType.toggle,
                  toggleValue: _bluetooth,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}
