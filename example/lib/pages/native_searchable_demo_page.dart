import 'package:flutter/material.dart';
import 'package:cupertino_widgets/cupertino_widgets.dart';

/// Single-page native scaffold with a SwiftUI `.searchable` search field,
/// mirroring:
///
/// ```swift
/// NavigationView {
///     List { ... }
///         .navigationTitle("CodeSpeedy")
/// }
/// .searchable(text: $searchBar,
///             placement: .navigationBarDrawer(displayMode: .always))
/// ```
///
/// The list, suggestions, results and loader below the bar are rendered by the
/// Flutter body (see `SearchBody`), driven by
/// [CupertinoNativePageScaffold.searchState].
class NativeSearchableDemoPage extends StatelessWidget {
  const NativeSearchableDemoPage({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: CupertinoNativePageScaffold(
        body: 'searchBody',
        navigationBar: const CupertinoNativeScaffoldNavigationBar(
          title: 'CodeSpeedy',
          titleDisplayMode: CupertinoNativeToolbarTitleDisplayMode.large,
          search: CupertinoNativeSearchField(
            placeholder: 'Search languages',
            placement: CupertinoNativeSearchPlacement.navigationBarDrawerAlways,
          ),
        ),
        onSearchChanged: (route, query) =>
            debugPrint('Search changed: "$query"'),
        onSearchSubmitted: (route, query) =>
            debugPrint('Search submitted: "$query"'),
        onSearchActiveChanged: (route, active) =>
            debugPrint('Search active: $active'),
      ),
    );
  }
}
