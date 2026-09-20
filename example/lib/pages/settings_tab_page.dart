import 'package:flutter/widgets.dart';
import 'package:cupertino_widgets/cupertino_widgets.dart';

/// Settings tab body — shared with the native scaffold. A native list, so the
/// rows are real SwiftUI cells.
class SettingsTabPage extends StatelessWidget {
  const SettingsTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return const Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        CupertinoNativeList(
          sections: [
            CupertinoNativeListSection(
              header: 'Preferences',
              children: [
                CupertinoNativeListTile(
                  id: 'notifications',
                  title: 'Notifications',
                  additionalInfo: 'On',
                  showChevron: true,
                ),
                CupertinoNativeListTile(
                  id: 'sounds',
                  title: 'Sounds & Haptics',
                  showChevron: true,
                ),
                CupertinoNativeListTile(
                  id: 'focus',
                  title: 'Focus',
                  showChevron: true,
                ),
              ],
            ),
            CupertinoNativeListSection(
              header: 'Privacy',
              children: [
                CupertinoNativeListTile(
                  id: 'location',
                  title: 'Location Services',
                  additionalInfo: 'While Using',
                  showChevron: true,
                ),
                CupertinoNativeListTile(
                  id: 'tracking',
                  title: 'Tracking',
                  showChevron: true,
                ),
              ],
            ),
            CupertinoNativeListSection(
              footer: 'Cupertino Widgets 1.0.0',
              children: [
                CupertinoNativeListTile(
                  id: 'about',
                  title: 'About',
                  showChevron: true,
                ),
                CupertinoNativeListTile(
                  id: 'legal',
                  title: 'Legal & Regulatory',
                  showChevron: true,
                ),
              ],
            ),
          ],
        ),
        SizedBox(height: 24),
      ],
    );
  }
}
