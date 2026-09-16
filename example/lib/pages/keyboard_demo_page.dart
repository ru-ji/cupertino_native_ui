import 'package:cupertino_widgets/cupertino_widgets.dart';
import 'package:flutter/cupertino.dart';

import '../widgets/settings_ui.dart';

/// The keyboard toolbar, and the live keyboard position.
///
/// The bar is `CupertinoNativeTextField.keyboardToolbar`, which fills the real
/// `ToolbarItemGroup(placement: .keyboard)`. That is Safari's form bar: the
/// capsule, its height, its Liquid Glass and — above all — its movement are
/// the system's. You only fill it.
///
/// The metrics at the top are a different tool: the keyboard's real position
/// every frame, for content that has to resize with it. They are not how the
/// bar is placed — the bar is placed by UIKit.
class KeyboardDemoPage extends StatefulWidget {
  const KeyboardDemoPage({super.key});

  @override
  State<KeyboardDemoPage> createState() => _KeyboardDemoPageState();
}

class _KeyboardDemoPageState extends State<KeyboardDemoPage> {
  final _safariFocus = FocusNode();
  final _safariNextFocus = FocusNode();
  final _controlsFocus = FocusNode();
  final _islandFocus = FocusNode();
  final _flutterBarFocus = FocusNode();

  int _emphasis = 1;

  @override
  void dispose() {
    for (final node in [
      _safariFocus,
      _safariNextFocus,
      _controlsFocus,
      _islandFocus,
      _flutterBarFocus,
    ]) {
      node.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Stack(
      children: [
        DemoScaffold(
          title: 'Keyboard',
          largeTitle: true,
          children: [
            const SettingsSection(
              header: 'Live metrics',
              footer:
                  'The real keyboard position, every frame, while it animates '
                  'or while you drag it down. Flutter only ever reports the '
                  'final height — compare the two rows.',
              children: [_MetricsRows()],
            ),

            // ── The system bar ───────────────────────────────────────────
            SettingsSection(
              header: 'System bar',
              footer:
                  "SwiftUI's ToolbarItemGroup(placement: .keyboard). This is "
                  "Safari's form bar — the system draws the capsule, you fill "
                  'it. Each item keeps its own onPressed.',
              children: [
                _FieldRow(
                  label: 'Safari-style',
                  child: CupertinoNativeTextField(
                    focusNode: _safariFocus,
                    placeholder: 'Focus me',
                    keyboardToolbar: [
                      CupertinoNativeButton(
                        onPressed: () {},
                        child: CupertinoSymbolImage.symbol(
                          CupertinoSymbols.chevronUp,
                        ),
                      ),
                      CupertinoNativeButton(
                        onPressed: _safariNextFocus.requestFocus,
                        child: CupertinoSymbolImage.symbol(
                          CupertinoSymbols.chevronDown,
                        ),
                      ),
                      const Spacer(),
                      CupertinoNativeButton(
                        onPressed: _safariFocus.unfocus,
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
                _FieldRow(
                  label: 'Next field',
                  child: CupertinoNativeTextField(
                    focusNode: _safariNextFocus,
                    placeholder: 'The chevron lands here',
                    keyboardToolbar: [
                      CupertinoNativeButton(
                        onPressed: _safariFocus.requestFocus,
                        child: CupertinoSymbolImage.symbol(
                          CupertinoSymbols.chevronUp,
                        ),
                      ),
                      const Spacer(),
                      CupertinoNativeButton(
                        onPressed: _safariNextFocus.unfocus,
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
                _FieldRow(
                  label: 'Controls',
                  child: CupertinoNativeTextField(
                    focusNode: _controlsFocus,
                    placeholder: 'Not only buttons',
                    keyboardToolbar: [
                      CupertinoNativePicker(
                        selectedIndex: _emphasis,
                        style: CupertinoNativePickerStyle.segmented,
                        onChanged: (i) => setState(() => _emphasis = i),
                        items: const [
                          CupertinoNativePickerItem(title: 'B'),
                          CupertinoNativePickerItem(title: 'I'),
                          CupertinoNativePickerItem(title: 'U'),
                        ],
                      ),
                      const Spacer(),
                      CupertinoNativeSymbol(
                        'sparkles',
                        size: 20,
                        effect: CupertinoNativeSymbolEffect.bounce,
                        trigger: _emphasis,
                      ),
                      CupertinoNativeButton(
                        onPressed: _controlsFocus.unfocus,
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
                _FieldRow(
                  label: 'Flutter inside',
                  child: CupertinoNativeTextField(
                    focusNode: _islandFocus,
                    placeholder: 'Hosts an engine',
                    keyboardToolbar: [
                      const CupertinoNativeFlutterView('keyboardIsland'),
                      const Spacer(),
                      CupertinoNativeButton(
                        onPressed: _islandFocus.unfocus,
                        child: const Text('Done'),
                      ),
                    ],
                  ),
                ),
              ],
            ),

            // ── What the bar does NOT cover ──────────────────────────────
            SettingsSection(
              header: 'No bar',
              footer:
                  "The toolbar is the field's own inputAccessoryView, so a "
                  'field the package does not own gets none. There is no bar '
                  'here, and drawing one in Flutter would not move with the '
                  'keyboard the way UIKit moves this one.',
              children: [
                _FieldRow(
                  label: 'Native field',
                  child: CupertinoNativeTextField(
                    focusNode: _flutterBarFocus,
                    placeholder: 'No toolbar set',
                  ),
                ),
                const _FieldRow(
                  label: 'Flutter field',
                  child: CupertinoTextField(placeholder: 'A plain TextField'),
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }
}

/// A labelled row, so the sections read like Settings rather than a pile of
/// fields.
class _FieldRow extends StatelessWidget {
  const _FieldRow({required this.label, required this.child});

  final String label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 10, 16, 10),
      child: Row(
        children: [
          SizedBox(width: 104, child: Text(label)),
          Expanded(child: child),
        ],
      ),
    );
  }
}

class _MetricsRows extends StatelessWidget {
  const _MetricsRows();

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<CupertinoKeyboardMetrics>(
      valueListenable: CupertinoNativeKeyboard.metrics,
      builder: (context, keyboard, _) {
        final flutterInset = MediaQuery.viewInsetsOf(context).bottom;
        return Column(
          children: [
            _row(
              'Native height',
              keyboard.height.toStringAsFixed(1),
              highlight: true,
            ),
            _row('Flutter viewInsets', flutterInset.toStringAsFixed(1)),
            _row('Progress', keyboard.progress.toStringAsFixed(3)),
            _row('Animating', keyboard.isAnimating ? 'yes' : 'no'),
          ],
        );
      },
    );
  }

  Widget _row(String label, String value, {bool highlight = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 9),
      child: Row(
        children: [
          Expanded(child: Text(label)),
          Text(
            value,
            style: TextStyle(
              fontFeatures: const [FontFeature.tabularFigures()],
              color: highlight
                  ? CupertinoColors.activeBlue
                  : CupertinoColors.systemGrey,
            ),
          ),
        ],
      ),
    );
  }
}
