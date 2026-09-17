import 'package:flutter/cupertino.dart';
import 'package:cupertino_widgets/cupertino_widgets.dart';

import '../widgets/settings_ui.dart';

/// Profile tab body — shared with the native scaffold. The rows are native
/// list cells.
class ProfileTabPage extends StatelessWidget {
  const ProfileTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        const SizedBox(height: 24),
        Container(
          width: 88,
          height: 88,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            gradient: LinearGradient(
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
              colors: [
                CupertinoColors.systemBlue.resolveFrom(context),
                CupertinoColors.systemIndigo.resolveFrom(context),
              ],
            ),
          ),
          child: const Text(
            'CR',
            style: TextStyle(
              fontSize: 34,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.white,
            ),
          ),
        ),
        const SizedBox(height: 12),
        Text(
          'Casey Rivera',
          style: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.w700,
            color: CupertinoColors.label.resolveFrom(context),
          ),
        ),
        Text('casey@example.com', style: footnoteStyle(context)),
        const SizedBox(height: 8),
        const CupertinoNativeList(
          sections: [
            CupertinoNativeListSection(
              children: [
                CupertinoNativeListTile(
                  id: 'name',
                  title: 'Name',
                  additionalInfo: 'Casey Rivera',
                ),
                CupertinoNativeListTile(
                  id: 'phone',
                  title: 'Phone',
                  additionalInfo: '+1 (555) 010-9265',
                ),
                CupertinoNativeListTile(
                  id: 'memberSince',
                  title: 'Member Since',
                  additionalInfo: 'July 2024',
                ),
              ],
            ),
            CupertinoNativeListSection(
              children: [
                CupertinoNativeListTile(
                  id: 'subscription',
                  title: 'Subscription',
                  additionalInfo: 'Pro',
                  showChevron: true,
                ),
                CupertinoNativeListTile(
                  id: 'devices',
                  title: 'Devices',
                  additionalInfo: '3',
                  showChevron: true,
                ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
