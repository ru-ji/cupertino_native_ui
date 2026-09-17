import 'package:flutter/widgets.dart';
import 'package:cupertino_widgets/cupertino_widgets.dart';

/// Search tab body. Under the native scaffold this sits below a real
/// search-role tab (the system search field); here it lists trending queries.
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
        const Padding(
          padding: EdgeInsets.fromLTRB(32, 20, 32, 8),
          child: Text('TRENDING'),
        ),
        CupertinoNativeList(
          sections: [
            CupertinoNativeListSection(
              children: [
                for (final (query, category) in _trending)
                  CupertinoNativeListTile(
                    id: query,
                    title: query,
                    subtitle: category,
                    showChevron: true,
                  ),
              ],
            ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }
}
