import 'package:flutter/cupertino.dart';
import 'package:cupertino_widgets/cupertino_widgets.dart';

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
  bool _glassClear = false;
  bool _glassInteractive = true;

  /// The two fields that share a keyboard bar, so its chevrons can move the
  /// focus between them and grey out at the ends.
  final List<FocusNode> _toolbarFields = [FocusNode(), FocusNode()];

  /// One field's bar: previous / next / done, in a glass capsule — the shape
  /// the system bar uses on iOS 26.
  List<Widget> _keyboardToolbar(int index) {
    void moveTo(int target) => _toolbarFields[target].requestFocus();
    // Resolved here: the bar is built by SwiftUI from an ARGB value, so an
    // unresolved CupertinoDynamicColor would ship its light-mode black.
    final labelColor = CupertinoColors.label.resolveFrom(context);
    return [
      // The bar takes the height of what it is given, so the room around the
      // capsule is this padding — nothing is added natively.
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
                color: labelColor,
                child: CupertinoSymbolImage.symbol(CupertinoSymbols.chevronUp),
              ),
              CupertinoNativeButton(
                onPressed: index < _toolbarFields.length - 1
                    ? () => moveTo(index + 1)
                    : null,
                color: labelColor,
                child: CupertinoSymbolImage.symbol(
                  CupertinoSymbols.chevronDown,
                ),
              ),
              const Spacer(),
              CupertinoNativeButton(
                onPressed: () => FocusManager.instance.primaryFocus?.unfocus(),
                color: labelColor,
                child: CupertinoSymbolImage.symbol(CupertinoSymbols.checkmark),
              ),
            ],
          ),
        ),
      ),
    ];
  }

  @override
  void dispose() {
    for (final node in _toolbarFields) {
      node.dispose();
    }
    _nameController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    // No shared shell: a page is a CupertinoPageScaffold with the native
    // navigation bar and a list. The keyboard inset pads the scroll content
    // instead of shrinking the page, so content keeps running under the bar.
    return CupertinoPageScaffold(
      child: CustomScrollView(
        slivers: [
          CupertinoNativeSliverNavigationBar(
            largeTitle: 'Text Field',
            leading: Navigator.canPop(context)
                ? CupertinoNativeButton.glass(
                    borderShape: CupertinoNativeButtonBorderShape.circle,
                    onPressed: () => Navigator.pop(context),
                    child: CupertinoSymbolImage.symbol(
                      CupertinoSymbols.chevronBackward,
                    ),
                  )
                : null,
          ),
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
                    glass: CupertinoGlass(
                      cornerRadius: 16,
                      variant: _glassClear
                          ? CupertinoGlassVariant.clear
                          : CupertinoGlassVariant.regular,
                      interactive: _glassInteractive,
                    ),
                  ),
                ),
                // Account and Profile are one native list: card, rows and fields in a
                // single platform view, with no Flutter content interleaved.
                CupertinoNativeList(
                  style: CupertinoNativeListStyle.insetGrouped,
                  onToggle: (id, value) => setState(() {
                    if (id == 'glassClear') _glassClear = value;
                    if (id == 'glassInteractive') _glassInteractive = value;
                  }),
                  sections: [
                    CupertinoNativeListSection(
                      footer:
                          'Its variant picks regular or clear glass; '
                          'interactive toggles the touch shimmer.',
                      children: [
                        CupertinoNativeListTile(
                          id: 'glassClear',
                          title: 'Clear variant',
                          subtitle: 'More transparent glass',
                          type: CupertinoNativeListTileType.toggle,
                          toggleValue: _glassClear,
                        ),
                        CupertinoNativeListTile(
                          id: 'glassInteractive',
                          title: 'Interactive',
                          subtitle: 'Shimmer on touch',
                          type: CupertinoNativeListTileType.toggle,
                          toggleValue: _glassInteractive,
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
    );
  }
}

/// The grouped card a standalone native control sits in, so it matches the
/// native list sections around it.
class _Card extends StatelessWidget {
  const _Card({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
