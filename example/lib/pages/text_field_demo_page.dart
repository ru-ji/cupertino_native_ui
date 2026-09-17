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

  @override
  void dispose() {
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
              'Focus the field: the bar above the keyboard is SwiftUI\'s '
              'own ToolbarItemGroup(placement: .keyboard), filled with the '
              'toolbarActions — native buttons transcribed into SwiftUI. '
              'The chevrons move focus between the two fields; Done '
              'dismisses the keyboard.',
          children: [
            Padding(
              padding: const EdgeInsets.all(12),
              child: CupertinoNativeTextField(
                placeholder: 'Focus me — the bar appears above the keyboard',
                height: 48,
                toolbarActions: [
                  CupertinoNativeButton(
                    onPressed: () {},
                    child: CupertinoSymbolImage.symbol(
                      CupertinoSymbols.chevronUp,
                    ),
                  ),
                  CupertinoNativeButton(
                    onPressed: () {},
                    child: CupertinoSymbolImage.symbol(
                      CupertinoSymbols.chevronDown,
                    ),
                  ),
                  const Spacer(),
                  CupertinoNativeButton(
                    onPressed: () =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    child: const Text('Done'),
                  ),
                ],
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(12),
              child: CupertinoNativeTextField(
                placeholder: 'The chevron lands here',
                height: 48,
                toolbarActions: [
                  CupertinoNativeButton(
                    onPressed: () {},
                    child: CupertinoSymbolImage.symbol(
                      CupertinoSymbols.chevronUp,
                    ),
                  ),
                  const Spacer(),
                  CupertinoNativeButton(
                    onPressed: () =>
                        FocusManager.instance.primaryFocus?.unfocus(),
                    child: const Text('Done'),
                  ),
                ],
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
