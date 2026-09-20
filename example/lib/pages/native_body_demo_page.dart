import 'package:cupertino_widgets/cupertino_widgets.dart';
import 'package:flutter/cupertino.dart';

/// A scaffold whose body is **SwiftUI, not Flutter**: Dart sends a
/// description and SwiftUI renders it, so every control below is a real
/// SwiftUI view in the scaffold's own tree, not a platform view.
///
/// The page is a keyboard bench. The scroll holding the notes is set to one of
/// SwiftUI's `ScrollDismissesKeyboardMode` values — focus a note, then drag
/// the list:
///
/// * **Drag** (`interactively`) — the keyboard follows the finger and comes
///   back if the drag is reversed, like Messages.
/// * **Now** (`immediately`) — it leaves as soon as the scroll starts.
/// * **Never** — it stays whatever the scroll does.
/// * **Auto** — the system decides.
class NativeBodyDemoPage extends StatefulWidget {
  const NativeBodyDemoPage({super.key});

  @override
  State<NativeBodyDemoPage> createState() => _NativeBodyDemoPageState();
}

class _NativeBodyDemoPageState extends State<NativeBodyDemoPage> {
  static const _modes = CupertinoNativeScrollDismissKeyboard.values;

  int _mode = 1; // interactively
  final _notes = <String>['', '', '', '', '', '', '', ''];

  CupertinoNativeScrollDismissKeyboard get _dismiss => _modes[_mode];

  int get _filled => _notes.where((note) => note.trim().isNotEmpty).length;

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CupertinoNativePageScaffold(
        scrollEdgeEffect: CupertinoScrollEdgeEffectStyle.soft,
        navigationBar: const CupertinoNativeScaffoldNavigationBar(
          title: 'Notes',
          subtitle: 'SwiftUI body',
          titleDisplayMode: CupertinoNativeToolbarTitleDisplayMode.large,
        ),
        onBodyEvent: _onBodyEvent,
        // Body nodes, not list rows: a row's `trailing` is only transcribed on
        // the standalone list path, so a field put there would be dropped.
        nativeBody: CupertinoNativeBody.scroll(
          spacing: 16,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 40),
          dismissKeyboard: _dismiss,
          children: [
            CupertinoNativeBody.segmented(
              id: 'mode',
              selectedIndex: _mode,
              items: [for (final mode in _modes) _shortName(mode)],
            ),
            CupertinoNativeBody.text(
              _explain(_dismiss),
              style: CupertinoNativeTextStyle.footnote,
              color: CupertinoColors.secondaryLabel,
            ),
            for (var i = 0; i < _notes.length; i++)
              CupertinoNativeBody.glass(
                cornerRadius: 18,
                interactive: true,
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                children: [
                  CupertinoNativeBody.column(
                    spacing: 6,
                    alignment: CrossAxisAlignment.start,
                    children: [
                      CupertinoNativeBody.row(
                        spacing: 8,
                        children: [
                          CupertinoNativeBody.symbol(
                            _notes[i].trim().isEmpty
                                ? 'circle'
                                : 'checkmark.circle.fill',
                            size: 16,
                          ),
                          CupertinoNativeBody.text(
                            'Note ${i + 1}',
                            style: CupertinoNativeTextStyle.headline,
                          ),
                        ],
                      ),
                      CupertinoNativeBody.textField(
                        id: 'note$i',
                        value: _notes[i],
                        placeholder: 'Type, then scroll',
                      ),
                    ],
                  ),
                ],
              ),
            CupertinoNativeBody.text(
              _filled == 0
                  ? 'Focus a note, then drag the list.'
                  : '$_filled of ${_notes.length} written.',
              style: CupertinoNativeTextStyle.footnote,
              color: CupertinoColors.secondaryLabel,
            ),
            CupertinoNativeBody.button(
              id: 'clear',
              title: 'Clear notes',
              style: CupertinoNativeButtonStyle.glassProminent,
              sizeStyle: CupertinoNativeControlSize.large,
              expand: true,
            ),
          ],
        ),
      ),
    );
  }

  String _shortName(CupertinoNativeScrollDismissKeyboard mode) =>
      switch (mode) {
        CupertinoNativeScrollDismissKeyboard.automatic => 'Auto',
        CupertinoNativeScrollDismissKeyboard.interactively => 'Drag',
        CupertinoNativeScrollDismissKeyboard.immediately => 'Now',
        CupertinoNativeScrollDismissKeyboard.never => 'Never',
      };

  String _explain(CupertinoNativeScrollDismissKeyboard mode) => switch (mode) {
    CupertinoNativeScrollDismissKeyboard.automatic =>
      'automatic — the system decides; a scroll holding a field dismisses '
          'interactively.',
    CupertinoNativeScrollDismissKeyboard.interactively =>
      'interactively — the keyboard follows the drag, and comes back if the '
          'drag is reversed.',
    CupertinoNativeScrollDismissKeyboard.immediately =>
      'immediately — the keyboard leaves as soon as the scroll starts.',
    CupertinoNativeScrollDismissKeyboard.never =>
      'never — scrolling leaves the keyboard alone.',
  };

  void _onBodyEvent(String id, Object? value) {
    setState(() {
      if (id == 'mode') {
        _mode = (value as num?)?.toInt() ?? 0;
      } else if (id == 'clear') {
        _notes.fillRange(0, _notes.length, '');
      } else if (id.startsWith('note')) {
        final index = int.tryParse(id.substring(4));
        if (index != null) _notes[index] = value as String? ?? '';
      }
    });
  }
}
