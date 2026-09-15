import 'package:flutter/cupertino.dart';
import 'package:cupertino_widgets/cupertino_widgets.dart';

import '../widgets/settings_ui.dart';

/// [CupertinoNativeSlidingSegmentedControl] as iOS uses it: straight on the
/// page, not inside a card. [CupertinoNativePicker] is its menu variant.
class SegmentedControlDemoPage extends StatefulWidget {
  const SegmentedControlDemoPage({super.key});

  @override
  State<SegmentedControlDemoPage> createState() =>
      _SegmentedControlDemoPageState();
}

class _SegmentedControlDemoPageState extends State<SegmentedControlDemoPage> {
  static const _ranges = ['Day', 'Week', 'Month', 'Year'];
  static const _filters = ['All', 'Missed'];
  static const _sorts = ['Date', 'Name', 'Size'];

  int _range = 1;
  int _filter = 0;
  int _tinted = 0;
  int _sort = 0;

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Segmented Control',
      children: [
        _group(
          context,
          'Standard',
          CupertinoNativeSlidingSegmentedControl(
            children: {for (final (i, l) in _ranges.indexed) i: Text(l)},
            groupValue: _range,
            onValueChanged: (v) => setState(() => _range = v!),
          ),
        ),
        _group(
          context,
          'Two segments',
          Center(
            child: SizedBox(
              width: 200,
              child: CupertinoNativeSlidingSegmentedControl(
                children: {for (final (i, l) in _filters.indexed) i: Text(l)},
                groupValue: _filter,
                onValueChanged: (v) => setState(() => _filter = v!),
              ),
            ),
          ),
        ),
        _group(
          context,
          'Thumb color',
          CupertinoNativeSlidingSegmentedControl(
            children: {for (final (i, l) in _ranges.indexed) i: Text(l)},
            groupValue: _tinted,
            thumbColor: CupertinoColors.systemPurple,
            onValueChanged: (v) => setState(() => _tinted = v!),
          ),
        ),
        SettingsSection(
          header: 'Picker',
          children: [
            SettingsRow(
              title: 'Sort By',
              trailing: CupertinoNativePicker<int>(
                children: {for (final (i, l) in _sorts.indexed) i: Text(l)},
                groupValue: _sort,
                onValueChanged: (v) => setState(() => _sort = v!),
              ),
            ),
          ],
        ),
      ],
    );
  }

  Widget _group(BuildContext context, String header, Widget control) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 20, 16, 0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
            child: Text(header.toUpperCase(), style: footnoteStyle(context)),
          ),
          control,
        ],
      ),
    );
  }
}
