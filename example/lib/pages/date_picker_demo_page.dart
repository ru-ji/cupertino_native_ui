import 'package:flutter/cupertino.dart'
    show CupertinoColors, CupertinoDatePickerMode;
import 'package:flutter/widgets.dart';
import 'package:cupertino_widgets/cupertino_widgets.dart';

import '../widgets/settings_ui.dart';

/// [CupertinoNativeDatePicker] — the compact system picker: a tappable pill
/// that pops the native calendar / time wheel over the app, exactly like
/// Settings → Alarm or Calendar's event editor.
class DatePickerDemoPage extends StatefulWidget {
  const DatePickerDemoPage({super.key});

  @override
  State<DatePickerDemoPage> createState() => _DatePickerDemoPageState();
}

class _DatePickerDemoPageState extends State<DatePickerDemoPage> {
  DateTime _starts = DateTime.now();
  DateTime _ends = DateTime.now().add(const Duration(hours: 1));
  DateTime _alarm = DateTime(2026, 1, 1, 7, 30);

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Date Picker',
      children: [
        SettingsSection(
          header: 'Event',
          footer:
              'Tap a pill — the calendar overlay is the real '
              'UIDatePicker (compact style); picks stream back to Flutter.',
          children: [
            SettingsRow(
              title: 'Starts',
              trailing: CupertinoNativeDatePicker(
                initialDateTime: _starts,
                mode: CupertinoDatePickerMode.dateAndTime,
                onDateTimeChanged: (d) => setState(() => _starts = d),
              ),
            ),
            SettingsRow(
              title: 'Ends',
              trailing: CupertinoNativeDatePicker(
                initialDateTime: _ends,
                mode: CupertinoDatePickerMode.dateAndTime,
                minimumDate: _starts,
                onDateTimeChanged: (d) => setState(() => _ends = d),
              ),
            ),
          ],
        ),
        SettingsSection(
          header: 'Alarm',
          footer:
              'time mode shows only the hour wheel; tint colors the '
              'selection.',
          children: [
            SettingsRow(
              title: 'Wake Up',
              trailing: CupertinoNativeDatePicker(
                initialDateTime: _alarm,
                mode: CupertinoDatePickerMode.time,
                activeColor: CupertinoColors.systemOrange,
                onDateTimeChanged: (d) => setState(() => _alarm = d),
              ),
            ),
          ],
        ),
        SettingsSection(
          header: 'Summary',
          children: [
            SettingsRow(
              title: 'Duration',
              value: '${_ends.difference(_starts).inMinutes} min',
            ),
          ],
        ),
      ],
    );
  }
}
