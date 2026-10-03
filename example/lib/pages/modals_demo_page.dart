import 'package:cupertino_native_ui/cupertino_native_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart'
    show Material, TextField, InputDecoration, showModalBottomSheet;

/// Flutter's own modals over a page full of native views: the case where a
/// platform view can show through (a glass halo over the scrim) or draw over
/// the modal (the tab bar above a sheet's field). Open each one and look for
/// native pixels where only the modal should be.
class ModalsDemoPage extends StatefulWidget {
  const ModalsDemoPage({super.key});

  @override
  State<ModalsDemoPage> createState() => _ModalsDemoPageState();
}

class _ModalsDemoPageState extends State<ModalsDemoPage> {
  bool _on = true;
  double _value = 0.5;
  int _segment = 0;
  int _tab = 0;
  final _name = TextEditingController(text: 'Holiday photos');

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: Stack(
        children: [
          CustomScrollView(
            slivers: [
              CupertinoNativeSliverNavigationBar(
                largeTitle: 'Modals',
                trailing: [
                  CupertinoNativeButton.icon(
                    CupertinoSymbols.squareAndArrowUp,
                    onPressed: () => _popup(context),
                  ),
                ],
              ),
              SliverToBoxAdapter(child: _nativeViews()),
              SliverToBoxAdapter(
                child: CupertinoNativeList(
                  onRowTap: (id) => _open(context, id),
                  sections: [
                    CupertinoNativeListSection(
                      header: 'Flutter modals',
                      footer:
                          'Each opens over the native views above and the tab '
                          'bar below. Nothing native should show through the '
                          'scrim or draw over the modal, and the field in the '
                          'bottom sheet should stay visible over the keyboard.',
                      children: [
                        _row('popup', 'Modal popup', 'showCupertinoModalPopup'),
                        _row('dialog', 'Dialog', 'showCupertinoDialog'),
                        _row('sheet', 'Sheet', 'showCupertinoSheet'),
                        _row(
                          'bottomSheet',
                          'Bottom sheet with a field',
                          'showModalBottomSheet',
                        ),
                        _row(
                          'fullscreen',
                          'Full-screen page',
                          'CupertinoPageRoute(fullscreenDialog: true)',
                        ),
                      ],
                    ),
                    CupertinoNativeListSection(
                      header: 'Native, for comparison',
                      children: [
                        _row(
                          'alert',
                          'Alert with a text field',
                          'Album: ${_name.text}',
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              SliverToBoxAdapter(
                child: SizedBox(
                  height: MediaQuery.paddingOf(context).bottom + 96,
                ),
              ),
            ],
          ),
          Align(
            alignment: Alignment.bottomCenter,
            child: CupertinoNativeTabBar(
              currentIndex: _tab,
              onTap: (i) => setState(() => _tab = i),
              items: const [
                CupertinoNativeTab(
                  id: 'home',
                  title: 'Home',
                  icon: CupertinoNativeIcon.named('house.fill'),
                ),
                CupertinoNativeTab(
                  id: 'starred',
                  title: 'Starred',
                  icon: CupertinoNativeIcon.asset('assets/icons/star.png'),
                ),
                CupertinoNativeTab(
                  id: 'likes',
                  title: 'Likes',
                  icon: CupertinoNativeIcon.iconData(CupertinoIcons.heart_fill),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The native views a modal must cover: glass with a halo, controls, a
  /// field.
  Widget _nativeViews() {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 8),
      child: Column(
        spacing: 16,
        children: [
          CupertinoNativeGlassContainer(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                const Expanded(child: Text('Liquid Glass')),
                CupertinoNativeSwitch(
                  value: _on,
                  onChanged: (v) => setState(() => _on = v),
                ),
              ],
            ),
          ),
          Row(
            spacing: 12,
            children: [
              CupertinoNativeButton.glass(
                onPressed: () {},
                child: const Text('Glass'),
              ),
              CupertinoNativeButton.glassProminent(
                onPressed: () {},
                child: const Text('Prominent'),
              ),
              CupertinoNativeButton.icon(
                CupertinoSymbols.heart,
                onPressed: () {},
              ),
            ],
          ),
          CupertinoNativeSlider(
            value: _value,
            onChanged: (v) => setState(() => _value = v),
          ),
          CupertinoNativeSlidingSegmentedControl<int>(
            groupValue: _segment,
            onValueChanged: (v) => setState(() => _segment = v ?? 0),
            children: const {0: Text('Day'), 1: Text('Week'), 2: Text('Month')},
          ),
          CupertinoNativeTextField(placeholder: 'A native field'),
        ],
      ),
    );
  }

  static CupertinoNativeListTile _row(String id, String title, String api) {
    return CupertinoNativeListTile(
      id: id,
      title: title,
      subtitle: api,
      showChevron: true,
    );
  }

  void _open(BuildContext context, String id) {
    switch (id) {
      case 'popup':
        _popup(context);
      case 'dialog':
        showCupertinoDialog<void>(
          context: context,
          builder: (context) => CupertinoAlertDialog(
            title: const Text('A Flutter dialog'),
            content: const Text('Drawn by Flutter over the native views.'),
            actions: [
              CupertinoDialogAction(
                isDefaultAction: true,
                onPressed: () => Navigator.pop(context),
                child: const Text('OK'),
              ),
            ],
          ),
        );
      case 'sheet':
        showCupertinoSheet<void>(
          context: context,
          scrollableBuilder: (context, controller) => CupertinoPageScaffold(
            navigationBar: const CupertinoNavigationBar(
              middle: Text('A Flutter sheet'),
            ),
            child: ListView.builder(
              controller: controller,
              itemCount: 30,
              itemBuilder: (context, i) =>
                  CupertinoListTile(title: Text('Row ${i + 1}')),
            ),
          ),
        );
      case 'bottomSheet':
        showModalBottomSheet<void>(
          context: context,
          isScrollControlled: true,
          builder: (context) => Padding(
            padding: EdgeInsets.fromLTRB(
              20,
              20,
              20,
              MediaQuery.viewInsetsOf(context).bottom + 40,
            ),
            child: const Material(
              color: Color(0x00000000),
              child: TextField(
                autofocus: true,
                decoration: InputDecoration(labelText: 'A Flutter field'),
              ),
            ),
          ),
        );
      case 'fullscreen':
        Navigator.of(context).push(
          CupertinoPageRoute<void>(
            fullscreenDialog: true,
            builder: (context) => CupertinoPageScaffold(
              navigationBar: CupertinoNavigationBar(
                middle: const Text('A Flutter page'),
                leading: CupertinoButton(
                  padding: EdgeInsets.zero,
                  onPressed: () => Navigator.pop(context),
                  child: const Text('Close'),
                ),
              ),
              child: const Center(child: Text('Nothing native here.')),
            ),
          ),
        );
      case 'alert':
        CupertinoNativeAlertDialog.show(
          context: context,
          title: 'Rename Album',
          textFields: [
            CupertinoNativeTextField(controller: _name, placeholder: 'Name'),
          ],
          actions: [
            const CupertinoNativeDialogAction(child: Text('Cancel')),
            CupertinoNativeDialogAction(
              isDefaultAction: true,
              onPressed: () => setState(() {}),
              child: const Text('Save'),
            ),
          ],
        );
    }
  }

  void _popup(BuildContext context) {
    showCupertinoModalPopup<void>(
      context: context,
      builder: (context) => CupertinoActionSheet(
        title: const Text('A Flutter action sheet'),
        actions: [
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Share'),
          ),
          CupertinoActionSheetAction(
            onPressed: () => Navigator.pop(context),
            child: const Text('Duplicate'),
          ),
        ],
        cancelButton: CupertinoActionSheetAction(
          onPressed: () => Navigator.pop(context),
          child: const Text('Cancel'),
        ),
      ),
    );
  }
}
