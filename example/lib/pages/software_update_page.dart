import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:cupertino_widgets/cupertino_widgets.dart';

enum _Stage { checking, available, downloading, ready, installing, upToDate }

/// Settings › General › Software Update, end to end: the spinner while it
/// checks, a progress bar while it downloads, gauges for what the install
/// needs, the terms checkbox, the system alert that confirms the install and
/// the action sheet that puts it off.
class SoftwareUpdatePage extends StatefulWidget {
  const SoftwareUpdatePage({super.key, required this.onInstalled});

  /// The update went in: Settings drops its "Software Update Available" row.
  final VoidCallback onInstalled;

  @override
  State<SoftwareUpdatePage> createState() => _SoftwareUpdatePageState();
}

class _SoftwareUpdatePageState extends State<SoftwareUpdatePage> {
  static const double _sizeMb = 1400;

  _Stage _stage = _Stage.checking;
  double _downloadedMb = 0;
  bool _agreed = false;
  String? _later;
  bool _autoDownload = true;
  bool _autoInstall = false;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _timer = Timer(
      const Duration(milliseconds: 1500),
      () => setState(() => _stage = _Stage.available),
    );
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  void _download() {
    setState(() {
      _stage = _Stage.downloading;
      _later = null;
    });
    _timer = Timer.periodic(const Duration(milliseconds: 80), (timer) {
      setState(() {
        _downloadedMb += 14;
        if (_downloadedMb >= _sizeMb) {
          timer.cancel();
          _stage = _Stage.ready;
        }
      });
    });
  }

  void _install() {
    setState(() => _stage = _Stage.installing);
    _timer = Timer(const Duration(milliseconds: 2500), () {
      setState(() => _stage = _Stage.upToDate);
      widget.onInstalled();
    });
  }

  void _onRowTap(String id) {
    switch (id) {
      case 'now':
        _download();
      case 'later':
        CupertinoNativeActionSheet.show(
          context: context,
          title: 'iOS 26.1 can be installed later.',
          actions: [
            CupertinoNativeDialogAction(
              child: const Text('Update Tonight'),
              onPressed: () => setState(() => _later = 'Tonight'),
            ),
            CupertinoNativeDialogAction(
              child: const Text('Remind Me Tomorrow'),
              onPressed: () => setState(() => _later = 'Tomorrow'),
            ),
            const CupertinoNativeDialogAction(
              isDefaultAction: true,
              child: Text('Cancel'),
            ),
          ],
        );
      case 'install':
        CupertinoNativeAlertDialog.show(
          context: context,
          title: 'Install iOS 26.1?',
          content: 'Your iPhone will restart to finish the installation.',
          actions: [
            const CupertinoNativeDialogAction(child: Text('Cancel')),
            CupertinoNativeDialogAction(
              isDefaultAction: true,
              onPressed: _install,
              child: const Text('Install'),
            ),
          ],
        );
    }
  }

  List<CupertinoNativeListTile> _statusRows() {
    const update = CupertinoNativeListTile(
      id: 'version',
      title: 'iOS 26.1',
      subtitle: 'Apple Inc. · 1.4 GB',
      leading: CupertinoNativeIcon.named(
        'gear.badge',
        size: 32,
        color: CupertinoColors.systemGrey,
      ),
    );
    return switch (_stage) {
      _Stage.checking => const [
        CupertinoNativeListTile(
          id: 'checking',
          title: 'Checking for Update…',
          trailing: CupertinoNativeActivityIndicator(),
        ),
      ],
      _Stage.available => [
        update,
        CupertinoNativeListTile(
          id: 'now',
          title: 'Update Now',
          type: CupertinoNativeListTileType.button,
        ),
        CupertinoNativeListTile(
          id: 'later',
          title: switch (_later) {
            null => 'Update Later…',
            final later => 'Scheduled: $later',
          },
          type: CupertinoNativeListTileType.button,
        ),
      ],
      _Stage.downloading => [
        update,
        CupertinoNativeListTile(
          id: 'downloading',
          title: 'Downloading…',
          additionalInfo:
              '${_downloadedMb.round()} MB of ${_sizeMb.round()} MB',
          trailing: CupertinoNativeLinearActivityIndicator(
            progress: _downloadedMb / _sizeMb,
          ),
        ),
      ],
      _Stage.ready => [
        update,
        CupertinoNativeListTile(
          id: 'terms',
          title: 'I agree to the Terms and Conditions',
          trailing: CupertinoNativeCheckbox(
            value: _agreed,
            onChanged: (v) => setState(() => _agreed = v),
          ),
        ),
        CupertinoNativeListTile(
          id: 'install',
          title: 'Install Now',
          type: CupertinoNativeListTileType.button,
          enabled: _agreed,
        ),
      ],
      _Stage.installing => [
        update,
        const CupertinoNativeListTile(
          id: 'installing',
          title: 'Installing…',
          trailing: CupertinoNativeActivityIndicator(),
        ),
      ],
      _Stage.upToDate => const [
        CupertinoNativeListTile(
          id: 'done',
          title: 'iOS 26.1',
          subtitle: 'iOS is up to date',
          leading: CupertinoNativeIcon.named(
            'checkmark.seal.fill',
            size: 32,
            color: CupertinoColors.systemGreen,
          ),
        ),
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: CustomScrollView(
        slivers: [
          CupertinoNativeSliverNavigationBar(
            largeTitle: 'Software Update',
            expandedTitle: false,
          ),
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom + 40,
            ),
            sliver: SliverList.list(
              children: [
                CupertinoNativeForm(
                  onToggle: (id, value) => setState(() {
                    if (id == 'autoDownload') _autoDownload = value;
                    if (id == 'autoInstall') _autoInstall = value;
                  }),
                  sections: [
                    CupertinoNativeListSection(
                      header: 'Automatic Updates',
                      children: [
                        CupertinoNativeListTile(
                          id: 'autoDownload',
                          title: 'Download iOS Updates',
                          type: CupertinoNativeListTileType.toggle,
                          toggleValue: _autoDownload,
                        ),
                        CupertinoNativeListTile(
                          id: 'autoInstall',
                          title: 'Install iOS Updates',
                          type: CupertinoNativeListTileType.toggle,
                          toggleValue: _autoInstall,
                          enabled: _autoDownload,
                        ),
                      ],
                    ),
                  ],
                ),
                CupertinoNativeList(
                  onRowTap: _onRowTap,
                  sections: [
                    CupertinoNativeListSection(
                      footer: _stage == _Stage.upToDate
                          ? null
                          : 'iOS 26.1 brings bug fixes and security updates '
                                'for your iPhone.',
                      children: _statusRows(),
                    ),
                    CupertinoNativeListSection(
                      header: 'Requirements',
                      footer:
                          'The update needs 4.2 GB of free space and 50% '
                          'battery, or a charger.',
                      children: const [
                        CupertinoNativeListTile(
                          id: 'battery',
                          title: 'Battery',
                          subtitle: 'Charging',
                          trailing: CupertinoNativeGauge(
                            value: 0.82,
                            currentValueLabel: '82',
                            style: CupertinoNativeGaugeStyle.circularCapacity,
                            color: CupertinoColors.systemGreen,
                          ),
                        ),
                        CupertinoNativeListTile(
                          id: 'storage',
                          title: 'iPhone Storage',
                          subtitle: '205 GB of 256 GB used',
                          trailing: CupertinoNativeGauge(
                            value: 205 / 256,
                            style: CupertinoNativeGaugeStyle.linearCapacity,
                            color: CupertinoColors.systemOrange,
                          ),
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
