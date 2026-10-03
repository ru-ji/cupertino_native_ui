import 'dart:io' show Platform;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart';
import 'package:cupertino_native_ui/cupertino_native_ui.dart';

/// Below iOS 26 there is no Liquid Glass: a glass capsule floating in the
/// input accessory reads as a small pill in empty space, not a bar. Below
/// that line this page skips the native accessory entirely (an empty
/// `toolbarActions` list) and draws the classic solid keyboard bar itself,
/// flush against the keyboard. Same parse `isIOS26OrLater` uses internally;
/// not exported by the package, so mirrored here rather than reached into.
final bool _isIOS26OrLater = _computeIsIOS26OrLater();

bool _computeIsIOS26OrLater() {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return false;
  final match = RegExp(r'\d+').firstMatch(Platform.operatingSystemVersion);
  final major = match == null ? null : int.tryParse(match.group(0)!);
  return major != null && major >= 26;
}

/// [CupertinoNativeTextField] presented as a sign-in / profile form. The
/// fields are borderless native UITextFields sitting in grouped cells, the way
/// iOS renders form input.
class TextFieldDemoPage extends StatefulWidget {
  const TextFieldDemoPage({super.key});

  @override
  State<TextFieldDemoPage> createState() => _TextFieldDemoPageState();
}

class _TextFieldDemoPageState extends State<TextFieldDemoPage> {
  final _nameController = TextEditingController(text: 'Casey Rivera');
  String _email = '';
  String _notes = '';
  bool _glassClear = false;

  /// The two fields that share a keyboard bar, so its chevrons can move the
  /// focus between them and grey out at the ends.
  final List<FocusNode> _toolbarFields = [FocusNode(), FocusNode()];

  /// Which of [_toolbarFields] is focused, or null. Only tracked for the
  /// legacy bar below iOS 26; the native accessory (26+) needs no Flutter
  /// state, it comes and goes with the field's own first-responder status.
  int? _focusedToolbarField;

  /// One field's bar: previous / next / done, in a glass capsule, the shape
  /// the system bar uses on iOS 26.
  ///
  /// The items are `label`, resolved here: the glass sits over the keyboard,
  /// which follows the app's brightness (light keyboard, dark items, and the
  /// other way round). Resolved, because the bar is built by SwiftUI from an
  /// ARGB value and an unresolved `CupertinoDynamicColor` ships its light one.
  List<Widget> _keyboardToolbar(int index) {
    // No Liquid Glass below iOS 26: an empty accessory here means the native
    // side never creates one (see `syncAccessory`: a nil `keyboardToolbar`
    // is a nil `inputAccessoryView`), so the page's own `_legacyKeyboardToolbar`
    // sits flush against the keyboard instead, with nothing native behind it.
    if (!_isIOS26OrLater) return const [];
    void moveTo(int target) => _toolbarFields[target].requestFocus();
    final itemColor = CupertinoColors.label.resolveFrom(context);
    return [
      // The bar takes the height of what it is given, so the room around the
      // capsule is this padding: nothing is added natively.
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        child: CupertinoNativeGlassContainer(
          shape: CupertinoGlassShape.capsule,
          interactive: true,
          padding: const EdgeInsets.symmetric(horizontal: 12),
          height: 50,
          child: Row(
            children: [
              CupertinoNativeButton(
                onPressed: index > 0 ? () => moveTo(index - 1) : null,
                color: itemColor,
                child: CupertinoSymbolImage.symbol(
                  CupertinoSymbols.chevronUp,
                  color: itemColor,
                ),
              ),
              CupertinoNativeButton(
                onPressed: index < _toolbarFields.length - 1
                    ? () => moveTo(index + 1)
                    : null,
                color: itemColor,
                child: CupertinoSymbolImage.symbol(
                  CupertinoSymbols.chevronDown,
                  color: itemColor,
                ),
              ),
              const Spacer(),
              CupertinoNativeButton(
                onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
                color: itemColor,
                child: CupertinoSymbolImage.symbol(
                  CupertinoSymbols.checkmark,
                  color: itemColor,
                ),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  @override
  void initState() {
    super.initState();
    if (!_isIOS26OrLater) {
      for (var i = 0; i < _toolbarFields.length; i++) {
        _toolbarFields[i].addListener(() => _onToolbarFocusChanged(i));
      }
    }
  }

  void _onToolbarFocusChanged(int index) {
    final focused = _toolbarFields[index].hasFocus;
    setState(() => _focusedToolbarField = focused ? index : null);
  }

  @override
  void dispose() {
    for (final node in _toolbarFields) {
      node.dispose();
    }
    _nameController.dispose();
    super.dispose();
  }

  /// The classic solid input-accessory bar: chevrons on the left, Done on
  /// the right, flush against the keyboard, no gap, no glass, since there
  /// is none to have below iOS 26. `systemGrey5`/`systemGrey6` are the
  /// keyboard's own toolbar colours in light/dark.
  Widget _legacyKeyboardToolbar(int index) {
    void moveTo(int target) => _toolbarFields[target].requestFocus();
    return Container(
      height: 45,
      color: CupertinoColors.secondarySystemBackground,
      child: Row(
        children: [
          const SizedBox(width: 4),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onPressed: index > 0 ? () => moveTo(index - 1) : null,
            child: Icon(
              CupertinoIcons.chevron_up,
              size: 20,
              color: index > 0
                  ? null
                  : CupertinoColors.quaternaryLabel.resolveFrom(context),
            ),
          ),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 12),
            onPressed: index < _toolbarFields.length - 1
                ? () => moveTo(index + 1)
                : null,
            child: Icon(
              CupertinoIcons.chevron_down,
              size: 20,
              color: index < _toolbarFields.length - 1
                  ? null
                  : CupertinoColors.quaternaryLabel.resolveFrom(context),
            ),
          ),
          const Spacer(),
          CupertinoButton(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
            child: const Text(
              'Done',
              style: TextStyle(fontWeight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    // No shared shell: a page is a CupertinoPageScaffold with the native
    // navigation bar and a list.
    //
    // `resizeToAvoidBottomInset: false` is load-bearing here, not a detail.
    // UIKit puts a field's `inputAccessoryView` *inside* the keyboard's frame:
    // it makes the keyboard taller rather than floating a bar over it, so
    // `viewInsets.bottom` covers the toolbar's strip too. A scaffold that
    // shrinks for the keyboard therefore ends the page exactly at the top of
    // the bar, and the only thing left behind that strip is the scaffold's own
    // background colour: an opaque slab with the glass capsule sitting on it.
    // Full height instead, and what shows behind the bar is the page.
    //
    // The keyboard inset then pads the scroll content, as the comment on the
    // sliver below says, which is also only true with the flag set, since
    // `CupertinoPageScaffold` zeroes `viewInsets` for its child when it
    // consumes them.
    return Stack(
      children: [
        CupertinoPageScaffold(
          backgroundColor: CupertinoColors.systemGroupedBackground,
          resizeToAvoidBottomInset: false,
          child: CustomScrollView(
            slivers: [
              CupertinoNativeSliverNavigationBar(largeTitle: 'Text Field'),
              SliverPadding(
                padding: EdgeInsets.only(
                  bottom:
                      MediaQuery.paddingOf(context).bottom +
                      MediaQuery.viewInsetsOf(context).bottom +
                      40,
                ),
                sliver: SliverList.list(
                  children: [
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 20, 32, 6),
                      child: Text(
                        'LIQUID GLASS',
                        style: TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.secondaryLabel.resolveFrom(
                            context,
                          ),
                        ),
                      ),
                    ),
                    // Full width and on its own, in a grouped card like the
                    // sections around it.
                    _Card(
                      child: CupertinoNativeTextField(
                        placeholder: 'Search or enter text…',
                        height: 48,
                        prefix: CupertinoNativeIcon.symbol(
                          CupertinoSymbols.magnifyingglass,
                        ),
                        clearButtonMode: OverlayVisibilityMode.editing,
                        cornerRadius: 16,
                        glass: _glassClear
                            ? CupertinoNativeGlass.clear
                            : CupertinoNativeGlass.regular,
                      ),
                    ),
                    // Account and Profile are one native list: card, rows and fields in a
                    // single platform view, with no Flutter content interleaved.
                    CupertinoNativeList(
                      style: CupertinoNativeListStyle.insetGrouped,
                      onToggle: (id, value) => setState(() {
                        if (id == 'glassClear') _glassClear = value;
                      }),
                      sections: [
                        CupertinoNativeListSection(
                          footer:
                              'Glass.regular or Glass.clear, always '
                              'interactive: touch it for the shimmer.',
                          children: [
                            CupertinoNativeListTile(
                              id: 'glassClear',
                              title: 'Clear variant',
                              subtitle: 'More transparent glass',
                              type: CupertinoNativeListTileType.toggle,
                              toggleValue: _glassClear,
                            ),
                          ],
                        ),
                        CupertinoNativeListSection(
                          header: 'Account',
                          footer: _email.isEmpty
                              ? 'Native UITextFields: real iOS autofill, keyboard types '
                                    'and QuickType.'
                              : 'Signing in as $_email',
                          children: [
                            CupertinoNativeListTile(
                              id: 'email',
                              title: 'Email',
                              trailing: CupertinoNativeTextField(
                                placeholder: 'you@example.com',
                                keyboardType: TextInputType.emailAddress,
                                textCapitalization: TextCapitalization.none,
                                autocorrect: false,
                                textContentType: 'emailAddress',
                                textInputAction: TextInputAction.next,
                                textAlign: TextAlign.end,
                                onChanged: (v) => setState(() => _email = v),
                              ),
                            ),
                            CupertinoNativeListTile(
                              id: 'password',
                              title: 'Password',
                              trailing: CupertinoNativeTextField(
                                placeholder: 'Required',
                                obscureText: true,
                                textContentType: 'password',
                                textInputAction: TextInputAction.done,
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                        CupertinoNativeListSection(
                          header: 'Profile',
                          footer:
                              'The name field is controller-driven; the clear button is '
                              'the native one.',
                          children: [
                            CupertinoNativeListTile(
                              id: 'name',
                              title: 'Name',
                              trailing: CupertinoNativeTextField(
                                controller: _nameController,
                                clearButtonMode: OverlayVisibilityMode.editing,
                                textAlign: TextAlign.end,
                              ),
                            ),
                            CupertinoNativeListTile(
                              id: 'handle',
                              title: 'Handle',
                              trailing: CupertinoNativeTextField(
                                placeholder: '@username',
                                maxLength: 16,
                                autocorrect: false,
                                textCapitalization: TextCapitalization.none,
                                textAlign: TextAlign.end,
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    CupertinoNativeList(
                      sections: [
                        CupertinoNativeListSection(
                          header: 'Keyboard Toolbar',
                          footer:
                              'Focus a field: the bar above the keyboard is the '
                              'field\'s own UIKit input accessory. The chevrons '
                              'move between the two fields and grey out at the '
                              'ends.',
                          children: [
                            CupertinoNativeListTile(
                              id: 'toolbar0',
                              title: 'First',
                              trailing: CupertinoNativeTextField(
                                focusNode: _toolbarFields[0],
                                placeholder: 'Focus me',
                                textAlign: TextAlign.end,
                                toolbarActions: _keyboardToolbar(0),
                              ),
                            ),
                            CupertinoNativeListTile(
                              id: 'toolbar1',
                              title: 'Second',
                              trailing: CupertinoNativeTextField(
                                focusNode: _toolbarFields[1],
                                placeholder: 'The chevron lands here',
                                textAlign: TextAlign.end,
                                toolbarActions: _keyboardToolbar(1),
                              ),
                            ),
                          ],
                        ),
                      ],
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 20, 32, 6),
                      child: Text(
                        'TEXT EDITOR',
                        style: TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.secondaryLabel.resolveFrom(
                            context,
                          ),
                        ),
                      ),
                    ),
                    // Multi-line native TextEditor: it scrolls inside its
                    // own height, controlled by echoing onChanged back.
                    // No card padding: the editor's own, so the text scrolls
                    // up to the card's edges.
                    _Card(
                      padding: EdgeInsets.zero,
                      child: CupertinoNativeTextEditor(
                        text: _notes,
                        placeholder: 'Notes…',
                        height: 140,
                        maxLength: 1000,
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 8,
                        ),
                        cursorColor: CupertinoColors.systemOrange,
                        onChanged: (v) => setState(() => _notes = v),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.fromLTRB(32, 6, 32, 0),
                      child: Text(
                        '${_notes.length} / 1000',
                        style: TextStyle(
                          fontSize: 13,
                          color: CupertinoColors.secondaryLabel.resolveFrom(
                            context,
                          ),
                        ),
                      ),
                    ),
                    Padding(
                      padding: const EdgeInsets.all(16),
                      child: CupertinoNativeButton.filled(
                        expand: true,
                        sizeStyle: CupertinoNativeControlSize.large,
                        onPressed: () => _nameController.text = 'Signed in!',
                        child: const Text('Sign In'),
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        if (!_isIOS26OrLater && _focusedToolbarField != null)
          Positioned(
            left: 0,
            right: 0,
            bottom: MediaQuery.viewInsetsOf(context).bottom,
            child: _legacyKeyboardToolbar(_focusedToolbarField!),
          ),
      ],
    );
  }
}

/// The grouped card a standalone native control sits in, so it matches the
/// native list sections around it.
class _Card extends StatelessWidget {
  const _Card({
    required this.child,
    this.padding = const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
  });

  final Widget child;
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: padding,
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
          context,
        ),
        borderRadius: BorderRadius.circular(26),
      ),
      child: child,
    );
  }
}
