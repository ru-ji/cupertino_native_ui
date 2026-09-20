import 'package:flutter/cupertino.dart';

/// Search tab body. Under the native scaffold this sits below a real
/// search-role tab (the system search field); here it lists trending queries.
///
/// Drawn Flutter rows, not [CupertinoNativeList]: the scaffold body is already
/// inside a native platform view, and a platform view nested in another renders
/// blank.
class SearchTabPage extends StatelessWidget {
  const SearchTabPage({super.key});

  static const _trending = [
    ('Liquid Glass', 'Design'),
    ('SwiftUI interop', 'Development'),
    ('SF Symbols 7', 'Design'),
    ('Platform views', 'Flutter'),
    ('NavigationStack', 'Development'),
  ];

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 20, 32, 8),
          // Explicit: without a DefaultTextStyle above it, a bare Text falls
          // back to the framework's black, invisible in dark mode.
          child: Text(
            'TRENDING',
            style: TextStyle(
              fontSize: 13,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
        ),
        // Flutter-drawn, like the search body: this runs inside a native
        // view, where a nested native list renders blank.
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
              context,
            ),
            borderRadius: BorderRadius.circular(26),
          ),
          child: Column(
            children: [
              for (final (query, category) in _trending)
                Container(
                  constraints: const BoxConstraints(minHeight: 46),
                  padding: const EdgeInsets.symmetric(
                    horizontal: 16,
                    vertical: 8,
                  ),
                  child: Row(
                    children: [
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Text(
                              query,
                              style: CupertinoTheme.of(context)
                                  .textTheme
                                  .textStyle,
                            ),
                            Text(
                              category,
                              style: TextStyle(
                                fontSize: 13,
                                color: CupertinoColors.secondaryLabel
                                    .resolveFrom(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        CupertinoIcons.chevron_right,
                        size: 14,
                        color: CupertinoColors.tertiaryLabel.resolveFrom(
                          context,
                        ),
                      ),
                    ],
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
