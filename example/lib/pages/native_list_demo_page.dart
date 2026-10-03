import 'package:flutter/cupertino.dart';
import 'package:cupertino_native_ui/cupertino_native_ui.dart';

import 'software_update_page.dart';

/// What [CupertinoNativeList] does, one kind of list per section: basic rows,
/// a single and a multiple choice, expandable rows, and a list that
/// swipes, selects and reorders in edit mode. Every list is a SwiftUI `List`
/// and self-sizes, so it drops straight into this Flutter scroll view.
class NativeListDemoPage extends StatefulWidget {
  const NativeListDemoPage({super.key});

  @override
  State<NativeListDemoPage> createState() => _NativeListDemoPageState();
}

class _NativeListDemoPageState extends State<NativeListDemoPage> {
  bool _updateAvailable = true;
  bool _airplane = false;
  String _appearance = 'automatic';
  final Set<String> _alerts = {'lockScreen', 'center'};
  bool _summary = true;
  int _summaries = 2;

  bool _editing = false;
  Set<String> _picked = {};
  final List<(String, String)> _keyboards = [
    ('English (US)', 'QWERTY'),
    ('Français', 'AZERTY'),
    ('Emoji', ''),
  ];

  static const _appearances = {
    'light': 'Light',
    'dark': 'Dark',
    'automatic': 'Automatic',
  };
  static const _alertKinds = {
    'lockScreen': 'Lock Screen',
    'center': 'Notification Center',
    'banners': 'Banners',
  };

  void _onRowTap(String id) {
    if (id == 'update') {
      Navigator.of(context).push(
        CupertinoPageRoute(
          builder: (_) => SoftwareUpdatePage(
            onInstalled: () => setState(() => _updateAvailable = false),
          ),
        ),
      );
    } else if (_appearances.containsKey(id)) {
      setState(() => _appearance = id);
    } else if (_alertKinds.containsKey(id)) {
      setState(
        () => _alerts.contains(id) ? _alerts.remove(id) : _alerts.add(id),
      );
    }
  }

  void _onToggle(String id, bool value) => setState(() {
    if (id == 'summary') _summary = value;
    if (id == 'airplane') _airplane = value;
  });

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: CustomScrollView(
        slivers: [
          CupertinoNativeSliverNavigationBar(
            largeTitle: 'List',
            trailing: [
              // A bar button: Liquid Glass on iOS 26, plain tinted text in
              // the iOS 15–18 bar.
              CupertinoNativeButton.glass(
                onPressed: () => setState(() {
                  _editing = !_editing;
                  _picked = {};
                }),
                child: Text(_editing ? 'Done' : 'Edit'),
              ),
            ],
          ),
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom + 40,
            ),
            sliver: SliverList.list(
              children: [
                CupertinoNativeList(
                  onRowTap: _onRowTap,
                  onToggle: _onToggle,
                  sections: [
                    CupertinoNativeListSection(
                      header: 'Basic',
                      children: [
                        CupertinoNativeListTile(
                          id: 'update',
                          title: 'Software Update',
                          badge: _updateAvailable ? '1' : null,
                          leading: const CupertinoNativeIcon.named(
                            'gear.badge',
                            color: CupertinoColors.systemGrey,
                          ),
                          showChevron: true,
                        ),
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
                          additionalInfo: _airplane ? 'Off' : 'FlutterNet',
                          leading: CupertinoNativeIcon.symbol(
                            CupertinoSymbols.wifi,
                            color: CupertinoColors.systemBlue,
                          ),
                          showChevron: true,
                        ),
                        const CupertinoNativeListTile(
                          id: 'general',
                          title: 'General',
                          leading: CupertinoNativeIcon.named(
                            'gear',
                            color: CupertinoColors.systemGrey,
                          ),
                          showChevron: true,
                        ),
                      ],
                    ),
                    CupertinoNativeListSection(
                      header: 'Single Choice',
                      children: [
                        for (final MapEntry(key: id, value: name)
                            in _appearances.entries)
                          CupertinoNativeListTile(
                            id: id,
                            title: name,
                            selected: _appearance == id,
                          ),
                      ],
                    ),
                    CupertinoNativeListSection(
                      header: 'Multiple Choice',
                      children: [
                        for (final MapEntry(key: id, value: name)
                            in _alertKinds.entries)
                          CupertinoNativeListTile(
                            id: id,
                            title: name,
                            selected: _alerts.contains(id),
                          ),
                      ],
                    ),
                    CupertinoNativeListSection(
                      header: 'Expandable',
                      children: [
                        CupertinoNativeListTile(
                          id: 'notifications',
                          title: 'Notifications',
                          leading: const CupertinoNativeIcon.named(
                            'bell.badge.fill',
                            color: CupertinoColors.systemRed,
                          ),
                          children: [
                            CupertinoNativeListTile(
                              id: 'summary',
                              title: 'Scheduled Summary',
                              type: CupertinoNativeListTileType.toggle,
                              toggleValue: _summary,
                            ),
                            CupertinoNativeListTile(
                              id: 'summaries',
                              title: 'Summaries per Day',
                              additionalInfo: '$_summaries',
                              enabled: _summary,
                              trailing: CupertinoNativeStepper(
                                value: _summaries.toDouble(),
                                min: 1,
                                max: 12,
                                onChanged: _summary
                                    ? (v) =>
                                          setState(() => _summaries = v.round())
                                    : null,
                              ),
                            ),
                          ],
                        ),
                        const CupertinoNativeListTile(
                          id: 'privacy',
                          title: 'Privacy & Security',
                          leading: CupertinoNativeIcon.named(
                            'hand.raised.fill',
                            color: CupertinoColors.systemBlue,
                          ),
                          children: [
                            CupertinoNativeListTile(
                              id: 'location',
                              title: 'Location Services',
                              additionalInfo: 'On',
                              showChevron: true,
                            ),
                            CupertinoNativeListTile(
                              id: 'tracking',
                              title: 'Tracking',
                              showChevron: true,
                            ),
                            CupertinoNativeListTile(
                              id: 'analytics',
                              title: 'Analytics & Improvements',
                              showChevron: true,
                            ),
                          ],
                        ),
                      ],
                    ),
                  ],
                ),
                CupertinoNativeList(
                  editing: _editing,
                  selection: _picked,
                  onSelectionChanged: (ids) => setState(() => _picked = ids),
                  onReorder: (_, from, to) => setState(
                    () => _keyboards.insert(to, _keyboards.removeAt(from)),
                  ),
                  onSwipeAction: (id, _) =>
                      setState(() => _keyboards.removeWhere((k) => k.$1 == id)),
                  sections: [
                    CupertinoNativeListSection(
                      header: 'Edit, Reorder & Swipe',
                      footer: _editing
                          ? '${_picked.length} selected · drag to reorder.'
                          : 'Swipe a keyboard to remove it, or tap Edit to '
                                'select and reorder.',
                      children: [
                        for (final (name, layout) in _keyboards)
                          CupertinoNativeListTile(
                            id: name,
                            title: name,
                            subtitle: layout.isEmpty ? null : layout,
                            leading: const CupertinoNativeIcon.named(
                              'keyboard',
                              color: CupertinoColors.systemGrey,
                            ),
                            swipeActions: const [
                              CupertinoNativeMenuAction(
                                title: 'Delete',
                                actionId: 'delete',
                                systemImage: 'trash',
                                isDestructive: true,
                              ),
                            ],
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
