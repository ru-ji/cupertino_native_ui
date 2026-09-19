import 'package:flutter/cupertino.dart';
import 'package:cupertino_widgets/cupertino_widgets.dart';

import '../widgets/settings_ui.dart';

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
    return DemoScaffold(
      title: 'Text Field',
      children: [
        SettingsSection(
          header: 'Liquid Glass',
          footer:
              'A CupertinoGlass wraps the native field in the iOS 26 '
              'UIGlassEffect — with a prefix SF Symbol via the native '
              'leftView slot. Its variant picks regular or clear glass; '
              'interactive toggles the touch shimmer.',
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: CupertinoNativeTextField(
                placeholder: 'Search or enter text…',
                glass: CupertinoGlass(
                  cornerRadius: 16,
                  variant: _glassClear
                      ? CupertinoGlassVariant.clear
                      : CupertinoGlassVariant.regular,
                  interactive: _glassInteractive,
                ),
                height: 48,
                prefix: CupertinoNativeIcon.symbol(
                  CupertinoSymbols.magnifyingglass,
                ),
                clearButtonMode: OverlayVisibilityMode.editing,
              ),
            ),
            SettingsRow(
              title: 'Clear variant',
              subtitle: 'More transparent glass',
              trailing: CupertinoNativeSwitch(
                value: _glassClear,
                onChanged: (v) => setState(() => _glassClear = v),
              ),
            ),
            SettingsRow(
              title: 'Interactive',
              subtitle: 'Shimmer on touch',
              trailing: CupertinoNativeSwitch(
                value: _glassInteractive,
                onChanged: (v) => setState(() => _glassInteractive = v),
              ),
            ),
          ],
        ),
        SettingsSection(
          header: 'Account',
          footer: _email.isEmpty
              ? 'Native UITextFields: real iOS autofill, keyboard types and '
                    'QuickType.'
              : 'Signing in as $_email',
          children: [
            _FieldRow(
              child: CupertinoNativeTextField(
                placeholder: 'Email',
                keyboardType: TextInputType.emailAddress,
                textCapitalization: TextCapitalization.none,
                autocorrect: false,
                textContentType: 'emailAddress',
                textInputAction: TextInputAction.next,
                onChanged: (v) => setState(() => _email = v),
              ),
            ),
            const _FieldRow(
              child: CupertinoNativeTextField(
                placeholder: 'Password',
                obscureText: true,
                textContentType: 'password',
                textInputAction: TextInputAction.done,
              ),
            ),
          ],
        ),
        SettingsSection(
          header: 'Profile',
          footer:
              'The name field is controller-driven; the clear button is '
              'the native one.',
          children: [
            _FieldRow(
              label: 'Name',
              child: CupertinoNativeTextField(
                controller: _nameController,
                clearButtonMode: OverlayVisibilityMode.editing,
                textAlign: TextAlign.end,
              ),
            ),
            const _FieldRow(
              label: 'Handle',
              child: CupertinoNativeTextField(
                placeholder: '@username',
                maxLength: 16,
                autocorrect: false,
                textCapitalization: TextCapitalization.none,
                textAlign: TextAlign.end,
              ),
            ),
          ],
        ),
        SettingsSection(
          header: 'Keyboard Toolbar',
          footer:
              'Focus the field: the bar above the keyboard is the field\'s '
              'own UIKit input accessory. The chevrons move between the two '
              'fields and grey out at the ends, like the system bar.',
          children: [
            _FieldRow(
              child: CupertinoNativeTextField(
                key: const Key('toolbar-field'),
                focusNode: _toolbarFields[0],
                placeholder: 'Focus me — the bar appears above the keyboard',
                toolbarActions: _keyboardToolbar(0),
              ),
            ),
            _FieldRow(
              child: CupertinoNativeTextField(
                focusNode: _toolbarFields[1],
                placeholder: 'The chevron lands here',
                toolbarActions: _keyboardToolbar(1),
              ),
            ),
          ],
        ),
        SettingsSection(
          children: [
            Padding(
              padding: const EdgeInsets.all(16),
              child: CupertinoNativeButton.filled(
                expand: true,
                sizeStyle: CupertinoNativeControlSize.large,
                onPressed: () => _nameController.text = 'Signed in!',
                child: Text('Sign In'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

/// A form cell: optional leading label with the borderless field filling the
/// remaining width.
class _FieldRow extends StatelessWidget {
  const _FieldRow({this.label, required this.child});

  final String? label;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 46),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 4),
      child: Row(
        children: [
          if (label != null) ...[
            SizedBox(
              width: 90,
              child: Text(label!, style: rowTitleStyle(context)),
            ),
            const SizedBox(width: 8),
          ],
          Expanded(child: child),
        ],
      ),
    );
  }
}
