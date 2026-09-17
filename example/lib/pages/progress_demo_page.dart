import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:cupertino_widgets/cupertino_widgets.dart';

import '../widgets/settings_ui.dart';

/// [CupertinoNativeProgressIndicator] presented as a Downloads page: a live
/// determinate download, indeterminate activity, and a storage gauge.
class ProgressDemoPage extends StatefulWidget {
  const ProgressDemoPage({super.key});

  @override
  State<ProgressDemoPage> createState() => _ProgressDemoPageState();
}

class _ProgressDemoPageState extends State<ProgressDemoPage> {
  static const double _totalMb = 348;
  double _downloadedMb = 96;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 120), (_) {
      setState(() {
        _downloadedMb += 2.5;
        if (_downloadedMb >= _totalMb) _downloadedMb = 0;
      });
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final percent = (_downloadedMb / _totalMb * 100).round();

    return DemoScaffold(
      title: 'Progress',
      children: [
        SettingsSection(
          header: 'Downloads',
          footer:
              'A determinate native ProgressView driven from Flutter — '
              'value updates stream to the platform view.',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Xcode 26.pkg',
                          style: rowTitleStyle(context),
                        ),
                      ),
                      Text(
                        '${_downloadedMb.round()} of ${_totalMb.round()} MB · '
                        '$percent%',
                        style: footnoteStyle(context),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  CupertinoNativeLinearActivityIndicator(
                    progress: _downloadedMb / _totalMb,
                  ),
                ],
              ),
            ),
          ],
        ),
        CupertinoNativeList(
          sections: [
            CupertinoNativeListSection(
              header: 'Activity',
              footer: 'value: null loops the native indeterminate spinner.',
              children: [
                const CupertinoNativeListTile(
                  id: 'updates',
                  title: 'Checking for Updates…',
                  trailing: CupertinoNativeActivityIndicator(),
                ),
                const CupertinoNativeListTile(
                  id: 'photos',
                  title: 'Syncing Photos',
                  subtitle: '1,204 items remaining',
                  trailing: CupertinoNativeActivityIndicator(
                    color: CupertinoColors.systemPink,
                  ),
                ),
              ],
            ),
          ],
        ),
        SettingsSection(
          header: 'Storage',
          footer: 'A tinted determinate bar with a native label.',
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 12, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'iPhone — 205 GB of 256 GB used',
                    style: footnoteStyle(context),
                  ),
                  const SizedBox(height: 8),
                  const CupertinoNativeLinearActivityIndicator(
                    progress: 205 / 256,
                    color: CupertinoColors.systemOrange,
                  ),
                ],
              ),
            ),
          ],
        ),
      ],
    );
  }
}
