import 'package:flutter/cupertino.dart' show CupertinoColors;
import 'package:flutter/widgets.dart';
import 'package:cupertino_widgets/cupertino_widgets.dart';

import '../widgets/settings_ui.dart';

/// [CupertinoNativeContextMenu] — long-press any card for a real
/// `UIContextMenuInteraction`: system lift, blur and haptics, with menu items
/// built from the same model as the popup menu. The "Sunset ride" card also
/// sets a custom [CupertinoNativeContextMenu.preview], so the lifted view
/// differs from the card itself while the menu is open.
class ContextMenuDemoPage extends StatefulWidget {
  const ContextMenuDemoPage({super.key});

  @override
  State<ContextMenuDemoPage> createState() => _ContextMenuDemoPageState();
}

class _ContextMenuDemoPageState extends State<ContextMenuDemoPage> {
  static const _photos = [
    ('Sunset ride', Color(0xFFFF512F), Color(0xFFDD2476)),
    ('Harbor walk', Color(0xFF1A2980), Color(0xFF26D0CE)),
    ('Golden hour', Color(0xFFF7B733), Color(0xFFFC4A1A)),
    ('City lights', Color(0xFF41295A), Color(0xFF2F0743)),
  ];

  String? _lastAction;
  bool _menuOpen = false;
  bool _blur = true;

  List<CupertinoNativeMenuItem> _itemsFor(String title) => [
    CupertinoNativeMenuAction(
      title: 'Share',
      systemImage: 'square.and.arrow.up',
      actionId: 'share:$title',
    ),
    CupertinoNativeMenuAction(
      title: 'Favorite',
      systemImage: 'heart',
      actionId: 'favorite:$title',
    ),
    CupertinoNativeSubmenu(
      title: 'Add to Album',
      systemImage: 'rectangle.stack.badge.plus',
      items: [
        CupertinoNativeMenuAction(
          title: 'Recents',
          actionId: 'album-recents:$title',
        ),
        CupertinoNativeMenuAction(
          title: 'Travel',
          actionId: 'album-travel:$title',
        ),
      ],
    ),
    CupertinoNativeMenuSection(
      items: [
        CupertinoNativeMenuAction(
          title: 'Delete',
          systemImage: 'trash',
          isDestructive: true,
          actionId: 'delete:$title',
        ),
      ],
    ),
  ];

  void _onAction(String id, dynamic _) {
    setState(() => _lastAction = id.replaceFirst(':', ' — '));
  }

  @override
  Widget build(BuildContext context) {
    return DemoScaffold(
      title: 'Context Menu',
      children: [
        const SizedBox(height: 20),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16),
          child: Column(
            children: [
              for (var i = 0; i < _photos.length; i += 2) ...[
                Row(
                  children: [
                    Expanded(child: _tile(_photos[i], custom: i == 0)),
                    const SizedBox(width: 12),
                    Expanded(child: _tile(_photos[i + 1])),
                  ],
                ),
                const SizedBox(height: 12),
              ],
            ],
          ),
        ),
        CupertinoNativeList(
          sections: [
            CupertinoNativeListSection(
              header: 'Menu',
              footer:
                  'Touch and hold a photo — the system lifts it with the '
                  'native blur and haptic, and the menu is a real UIMenu. '
                  '"Sunset ride" shows a custom preview (a different view) '
                  'while its menu is open.',
              children: [
                CupertinoNativeListTile(
                  id: 'blur',
                  title: 'Blur background',
                  trailing: CupertinoNativeSwitch(
                    value: _blur,
                    onChanged: (v) => setState(() => _blur = v),
                  ),
                ),
                CupertinoNativeListTile(
                  id: 'menuOpen',
                  title: 'Menu open',
                  additionalInfo: _menuOpen ? 'Yes' : 'No',
                ),
                CupertinoNativeListTile(
                  id: 'lastAction',
                  title: 'Last action',
                  additionalInfo: _lastAction ?? 'None',
                ),
              ],
            ),
          ],
        ),
      ],
    );
  }

  Widget _tile((String, Color, Color) photo, {bool custom = false}) {
    final (title, start, end) = photo;
    return CupertinoNativeContextMenu(
      actions: _itemsFor(title),
      onAction: _onAction, // Blurs the whole page (root overlay), not just this subtree.
      blurBackground: _blur,
      onOpenChanged: (open) => setState(
        () => _menuOpen = open,
      ), // A DIFFERENT view while the menu is open: the photo enlarged with a
      // caption bar, instead of the grid tile.
      preview: custom
          ? SizedBox(
              width: 280,
              height: 300,
              child: Column(
                children: [
                  Expanded(child: _artwork(start, end)),
                  Container(
                    height: 56,
                    alignment: Alignment.centerLeft,
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    color: CupertinoColors.systemBackground.resolveFrom(
                      context,
                    ),
                    child: Text(title, style: rowTitleStyle(context)),
                  ),
                ],
              ),
            )
          : null,
      child: SizedBox(
        height: 160,
        child: Stack(
          fit: StackFit.expand,
          children: [
            ClipRRect(
              borderRadius: BorderRadius.circular(14),
              child: _artwork(start, end),
            ),
            Positioned(
              left: 12,
              bottom: 10,
              child: Text(
                title,
                style: const TextStyle(
                  fontSize: 15,
                  fontWeight: FontWeight.w600,
                  decoration: TextDecoration.none,
                  color: Color(0xFFFFFFFF),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _artwork(Color start, Color end) {
    return DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [start, end],
        ),
      ),
    );
  }
}
