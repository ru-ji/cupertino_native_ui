import 'package:flutter/cupertino.dart';
import 'package:cupertino_widgets/cupertino_widgets.dart';

import '../widgets/settings_ui.dart';

/// Body for the scaffold's home tab. Runs in its own FlutterEngine inside the
/// native ScrollView — scrolling this content collapses the large title and
/// (with minimizeBehavior) shrinks the tab bar, all natively.
///
/// Note: use plain Flutter widgets in scaffold bodies. Platform-view widgets
/// (CupertinoNativeButton, ...) cannot render here because the body engine
/// itself already lives inside a native platform view.
class ScaffoldHomeBody extends StatelessWidget {
  const ScaffoldHomeBody({super.key});

  static const _albums = [
    ('Morning Coffee', 'Lo-fi · 24 tracks', CupertinoColors.systemBrown),
    ('Deep Focus', 'Ambient · 40 tracks', CupertinoColors.systemIndigo),
    ('Summer Drive', 'Pop · 31 tracks', CupertinoColors.systemOrange),
    ('Night Runner', 'Synthwave · 18 tracks', CupertinoColors.systemPurple),
    ('Rainy Day', 'Jazz · 26 tracks', CupertinoColors.systemTeal),
    ('Workout Mix', 'Electronic · 35 tracks', CupertinoColors.systemRed),
    ('Acoustic Sessions', 'Folk · 22 tracks', CupertinoColors.systemGreen),
    ('Study Beats', 'Instrumental · 48 tracks', CupertinoColors.systemBlue),
    ('Late Night Coding', 'Chillhop · 29 tracks', CupertinoColors.systemPink),
    ('Sunday Morning', 'Classical · 15 tracks', CupertinoColors.systemYellow),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 4),
          child: Text(
            'Scroll me — the large title collapses, the tab bar minimizes '
            'and the glass toolbar reacts, all natively.',
            style: footnoteStyle(context),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
          child: PillButton(
            label: 'Open Now Playing',
            onTap: () {
              CupertinoNativePageScaffold.push(
                CupertinoNativePageScaffoldPage(
                  route: 'details',
                  navigationBar: CupertinoNativeScaffoldNavigationBar(
                    title: 'Now Playing',
                    trailing: [
                      CupertinoNativeBarItem(
                        icon: CupertinoNativeIcon.symbol(
                          CupertinoSymbols.squareAndArrowUp,
                        ),
                        actionId: 'share_details',
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        ),
        for (final (title, subtitle, color) in _albums) ...[
          for (var repeat = 0; repeat < 3; repeat++)
            _AlbumRow(title: title, subtitle: subtitle, color: color),
        ],
        const SizedBox(height: 24),
      ],
    );
  }
}

class _AlbumRow extends StatelessWidget {
  const _AlbumRow({
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final String title;
  final String subtitle;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final resolved = CupertinoDynamicColor.resolve(color, context);
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
      child: Row(
        children: [
          Container(
            width: 52,
            height: 52,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(10),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [resolved, resolved.withValues(alpha: 0.55)],
              ),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(title, style: rowTitleStyle(context)),
                const SizedBox(height: 2),
                Text(subtitle, style: footnoteStyle(context)),
              ],
            ),
          ),
          const DisclosureChevron(),
        ],
      ),
    );
  }
}

/// Body for the pushed detail page — also its own engine. The native back
/// button and back-swipe pop it; the button here pops programmatically.
class ScaffoldDetailsBody extends StatelessWidget {
  const ScaffoldDetailsBody({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(height: 16),
          Container(
            width: 220,
            height: 220,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(24),
              gradient: LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  CupertinoColors.systemIndigo.resolveFrom(context),
                  CupertinoColors.systemPurple.resolveFrom(context),
                ],
              ),
            ),
          ),
          const SizedBox(height: 20),
          Text(
            'Deep Focus',
            style: TextStyle(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
          Text('Ambient · 40 tracks', style: footnoteStyle(context)),
          const SizedBox(height: 12),
          Text(
            'This page was pushed onto the native SwiftUI NavigationStack: '
            'the slide transition, toolbar morph and back-swipe are all '
            'system behavior.',
            textAlign: TextAlign.center,
            style: footnoteStyle(context),
          ),
          const SizedBox(height: 20),
          PillButton(
            label: 'Pop Back',
            filled: false,
            onTap: () => CupertinoNativePageScaffold.pop(),
          ),
        ],
      ),
    );
  }
}
