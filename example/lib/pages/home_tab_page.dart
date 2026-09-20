import 'package:flutter/cupertino.dart';

/// Home tab body. Shared between the standalone tab bar demo and the native
/// scaffold — the scaffold's body engine lives inside a platform view, so this
/// page (like all tab pages) uses only drawn Flutter widgets.
class HomeTabPage extends StatelessWidget {
  const HomeTabPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Good Morning',
            style: TextStyle(
              fontSize: 28,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.36,
              color: CupertinoColors.label.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Thursday, July 10',
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 16),
          const _HomeCard(
            title: 'Native everywhere',
            subtitle:
                'This Flutter page sits behind a real UIKit tab bar — '
                'Liquid Glass, split search tab and all.',
            color: CupertinoColors.systemBlue,
          ),
          const SizedBox(height: 12),
          const _HomeCard(
            title: 'Switch tabs below',
            subtitle:
                'Selection changes are reported back to Flutter, which '
                'swaps this body.',
            color: CupertinoColors.systemPurple,
          ),
          const SizedBox(height: 12),
          const _HomeCard(
            title: 'Try the search tab',
            subtitle:
                'The trailing tab has the native search role and floats '
                'in its own glass capsule.',
            color: CupertinoColors.systemTeal,
          ),
        ],
      ),
    );
  }
}

class _HomeCard extends StatelessWidget {
  const _HomeCard({
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
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: resolved.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              color: resolved,
            ),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: CupertinoTheme.of(context).textTheme.textStyle),
        ],
      ),
    );
  }
}
