import 'package:flutter/cupertino.dart';
import 'package:cupertino_widgets/cupertino_widgets.dart';

import '../widgets/settings_ui.dart';

/// [CupertinoNativeAlertDialog] presented as tappable settings rows, like the
/// confirmation flows in Settings.
class AlertDemoPage extends StatefulWidget {
  const AlertDemoPage({super.key});

  @override
  State<AlertDemoPage> createState() => _AlertDemoPageState();
}

class _AlertDemoPageState extends State<AlertDemoPage> {
  String _lastChoice = 'None yet';

  void _chose(String choice) => setState(() => _lastChoice = choice);

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Alert',
      children: [
        CupertinoNativeList(
          onRowTap: (id) {
            if (id == 'mobileData') _showMobileData(context);
            if (id == 'erase') _showErase(context);
          },
          sections: [
            CupertinoNativeListSection(
              header: 'Examples',
              footer: 'Last choice: $_lastChoice',
              children: const [
                CupertinoNativeListTile(
                  id: 'mobileData',
                  title: 'Mobile Data Is Off',
                  showChevron: true,
                ),
                CupertinoNativeListTile(
                  id: 'erase',
                  title: 'Erase All Content…',
                  showChevron: true,
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  void _showMobileData(BuildContext context) {
    CupertinoNativeAlertDialog.show(
      context: context,
      title: 'Mobile Data is Off',
      content: 'Turn on mobile data or use Wi-Fi to access data.',
      actions: [
        CupertinoNativeDialogAction(
          child: Text('Settings'),
          onPressed: () => _chose('Settings'),
        ),
        CupertinoNativeDialogAction(
          child: Text('OK'),
          onPressed: () => _chose('OK'),
        ),
      ],
    );
  }

  void _showErase(BuildContext context) {
    CupertinoNativeAlertDialog.show(
      context: context,
      title: 'Erase All Content and Settings?',
      content:
          'This cannot be undone. All media, data and settings '
          'will be erased.',
      actions: [
        CupertinoNativeDialogAction(
          child: Text('Cancel'),
          onPressed: () => _chose('Cancel'),
        ),
        CupertinoNativeDialogAction(
          child: Text('Erase'),
          isDestructiveAction: true,
          onPressed: () => _chose('Erase'),
        ),
      ],
    );
  }
}
