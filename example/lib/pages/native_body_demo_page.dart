import 'package:cupertino_widgets/cupertino_widgets.dart';
import 'package:flutter/cupertino.dart';

/// A scaffold whose body is **SwiftUI, not Flutter**.
///
/// Compare with the Native Scaffold demo: there the body is a route in its own
/// FlutterEngine, so a native control inside it would be a platform view
/// nested in an already-native hierarchy — Flutter → SwiftUI → FlutterView →
/// SwiftUI. Here Dart sends a description and SwiftUI renders it, so the
/// field, the toggle and the button below are real SwiftUI views in the
/// scaffold's own tree.
///
/// The trade is visible in the code: the body is built from
/// `CupertinoNativeBody.*` descriptions, not from Flutter widgets. Nothing in
/// it can be an arbitrary Flutter widget — that is the price of removing the
/// nesting.
class NativeBodyDemoPage extends StatefulWidget {
  const NativeBodyDemoPage({super.key});

  @override
  State<NativeBodyDemoPage> createState() => _NativeBodyDemoPageState();
}

class _NativeBodyDemoPageState extends State<NativeBodyDemoPage> {
  String _name = '';
  bool _notify = true;
  double _volume = 0.4;
  int _style = 0;
  String _lastAction = 'none';

  @override
  Widget build(BuildContext context) {
    return SizedBox.expand(
      child: CupertinoNativePageScaffold(
        scrollEdgeEffect: CupertinoScrollEdgeEffectStyle.soft,
        interactiveKeyboardDismiss: true,
        navigationBar: const CupertinoNativeScaffoldNavigationBar(
          title: 'Native Body',
          subtitle: 'Rendered by SwiftUI',
          titleDisplayMode: CupertinoNativeToolbarTitleDisplayMode.large,
        ),
        onBodyEvent: _onBodyEvent,
        nativeBody: CupertinoNativeBody.column(
          spacing: 18,
          padding: const EdgeInsets.fromLTRB(20, 12, 20, 40),
          children: [
            CupertinoNativeBody.text(
              'Every control below is a SwiftUI view in this scaffold, not a '
              'platform view inside an embedded FlutterEngine.',
              style: CupertinoNativeTextStyle.footnote,
              color: CupertinoColors.secondaryLabel,
            ),
            CupertinoNativeBody.text(
              'Account',
              style: CupertinoNativeTextStyle.headline,
            ),
            CupertinoNativeBody.textField(
              id: 'name',
              value: _name,
              placeholder: 'Your name',
            ),
            CupertinoNativeBody.toggle(
              id: 'notify',
              label: 'Notifications',
              value: _notify,
            ),
            CupertinoNativeBody.divider(),
            CupertinoNativeBody.text(
              'Volume',
              style: CupertinoNativeTextStyle.headline,
            ),
            CupertinoNativeBody.slider(id: 'volume', value: _volume),
            CupertinoNativeBody.picker(
              id: 'style',
              selectedIndex: _style,
              style: CupertinoNativePickerStyle.segmented,
              items: const [
                CupertinoNativePickerItem(title: 'Off'),
                CupertinoNativePickerItem(title: 'Low'),
                CupertinoNativePickerItem(title: 'High'),
              ],
            ),
            CupertinoNativeBody.divider(),
            CupertinoNativeBody.row(
              spacing: 12,
              children: [
                CupertinoNativeBody.symbol(
                  'bell.badge',
                  size: 22,
                  effect: CupertinoNativeSymbolEffect.bounce,
                  trigger: _style,
                ),
                CupertinoNativeBody.text(
                  'name "$_name" · notify $_notify · '
                  'vol ${_volume.toStringAsFixed(2)} · last $_lastAction',
                  style: CupertinoNativeTextStyle.caption,
                  color: CupertinoColors.secondaryLabel,
                ),
              ],
            ),
            CupertinoNativeBody.button(
              id: 'save',
              title: 'Save',
              style: CupertinoNativeButtonStyle.glassProminent,
              sizeStyle: CupertinoNativeControlSize.large,
              expand: true,
            ),
          ],
        ),
      ),
    );
  }

  void _onBodyEvent(String id, Object? value) {
    setState(() {
      switch (id) {
        case 'name':
          _name = value as String? ?? '';
        case 'notify':
          _notify = value as bool? ?? false;
        case 'volume':
          _volume = (value as num?)?.toDouble() ?? 0;
        case 'style':
          _style = (value as num?)?.toInt() ?? 0;
        case 'save':
          _lastAction = 'save';
      }
    });
  }
}
