import 'package:flutter/cupertino.dart' show CupertinoColors;
import 'package:flutter/widgets.dart';
import 'package:cupertino_widgets/cupertino_widgets.dart';

/// Content of the native sheet demo — a "New Event" form. Runs in its own
/// FlutterEngine hosted in the sheet's native ScrollView, so it must be a
/// self-sized Column (same contract as scaffold bodies); the sheet's title,
/// ✕/Add buttons, search field and segmented control are native chrome
/// configured from `CupertinoNativeSheet.show`. Tall on purpose — scroll it
/// under the pinned bar.
class NewEventSheetBody extends StatelessWidget {
  const NewEventSheetBody({super.key});

  @override
  Widget build(BuildContext context) {
    final background = CupertinoColors.systemGroupedBackground.resolveFrom(
      context,
    );

    return ColoredBox(
      color: background,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const CupertinoNativeList(
            sections: [
              CupertinoNativeListSection(
                children: [
                  CupertinoNativeListTile(id: 'title', title: 'Team Standup'),
                  CupertinoNativeListTile(
                    id: 'location',
                    title: 'Location',
                    additionalInfo: 'Cupertino HQ',
                  ),
                ],
              ),
              CupertinoNativeListSection(
                children: [
                  CupertinoNativeListTile(
                    id: 'allDay',
                    title: 'All-day',
                    additionalInfo: 'Off',
                  ),
                  CupertinoNativeListTile(
                    id: 'starts',
                    title: 'Starts',
                    additionalInfo: 'Jul 12, 9:41 AM',
                  ),
                  CupertinoNativeListTile(
                    id: 'ends',
                    title: 'Ends',
                    additionalInfo: 'Jul 12, 10:00 AM',
                  ),
                  CupertinoNativeListTile(
                    id: 'travelTime',
                    title: 'Travel Time',
                    additionalInfo: 'None',
                    showChevron: true,
                  ),
                ],
              ),
              CupertinoNativeListSection(
                children: [
                  CupertinoNativeListTile(
                    id: 'repeat',
                    title: 'Repeat',
                    additionalInfo: 'Never',
                    showChevron: true,
                  ),
                  CupertinoNativeListTile(
                    id: 'calendar',
                    title: 'Calendar',
                    additionalInfo: 'Work',
                    showChevron: true,
                  ),
                  CupertinoNativeListTile(
                    id: 'invitees',
                    title: 'Invitees',
                    additionalInfo: '3',
                    showChevron: true,
                  ),
                ],
              ),
              CupertinoNativeListSection(
                children: [
                  CupertinoNativeListTile(
                    id: 'alert',
                    title: 'Alert',
                    additionalInfo: '10 min before',
                    showChevron: true,
                  ),
                  CupertinoNativeListTile(
                    id: 'secondAlert',
                    title: 'Second Alert',
                    additionalInfo: 'None',
                    showChevron: true,
                  ),
                  CupertinoNativeListTile(
                    id: 'showAs',
                    title: 'Show As',
                    additionalInfo: 'Busy',
                    showChevron: true,
                  ),
                ],
              ),
              CupertinoNativeListSection(
                footer:
                    'This whole form is Flutter inside a real UIKit sheet: '
                    'the bar stays pinned while you scroll, and pulling down at '
                    'the top drags the sheet itself.',
                children: [
                  CupertinoNativeListTile(
                    id: 'url',
                    title: 'URL',
                    additionalInfo: 'None',
                  ),
                  CupertinoNativeListTile(
                    id: 'notes',
                    title: 'Notes',
                    additionalInfo: 'None',
                  ),
                  CupertinoNativeListTile(
                    id: 'attachments',
                    title: 'Attachments',
                    additionalInfo: 'None',
                    showChevron: true,
                  ),
                ],
              ),
            ],
          ),
          CupertinoNativeList(
            onRowTap: (id) {
              if (id == 'dismiss') CupertinoNativeSheet.pop();
            },
            sections: const [
              CupertinoNativeListSection(
                children: [
                  CupertinoNativeListTile(
                    id: 'dismiss',
                    title: 'Dismiss from Flutter',
                    type: CupertinoNativeListTileType.button,
                  ),
                ],
              ),
            ],
          ),
          const SizedBox(height: 40),
        ],
      ),
    );
  }
}
