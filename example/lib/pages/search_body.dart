import 'dart:async';

import 'package:flutter/cupertino.dart';
import 'package:cupertino_widgets/cupertino_widgets.dart';

import '../widgets/settings_ui.dart';

/// Body for the searchable scaffold demo. It runs in its own FlutterEngine
/// inside the native SwiftUI ScrollView and listens to
/// [CupertinoNativePageScaffold.searchState] — the live snapshot of the native
/// `.searchable` field — to decide what to render below the search bar:
///
///  * idle          → the full list
///  * active, empty → search suggestions
///  * active, typing→ a loading spinner, then filtered results (or "no results")
///
/// The native search bar (placeholder, placement, expand-and-hide-title
/// behavior) is owned by SwiftUI; everything below it is plain Flutter that we
/// customize here.
class SearchBody extends StatefulWidget {
  const SearchBody({super.key});

  @override
  State<SearchBody> createState() => _SearchBodyState();
}

class _SearchBodyState extends State<SearchBody> {
  static const _all = <(String, String)>[
    ('SwiftUI', 'Apple platforms'),
    ('Swift', 'Apple platforms'),
    ('Objective-C', 'Apple platforms'),
    ('Python', 'General purpose'),
    ('JavaScript', 'Web'),
    ('TypeScript', 'Web'),
    ('Dart', 'Flutter'),
    ('Kotlin', 'Android'),
    ('Java', 'JVM'),
    ('Rust', 'Systems'),
    ('Go', 'Backend'),
    ('C++', 'Systems'),
    ('Ruby', 'Web'),
    ('PHP', 'Web'),
  ];

  /// Popular queries to hint while the field is focused but empty.
  static const _suggestions = <String>['Swift', 'Python', 'JavaScript', 'Dart'];

  bool _active = false;
  bool _loading = false;
  String _query = '';
  List<(String, String)> _results = const [];
  Timer? _debounce;

  @override
  void initState() {
    super.initState();
    CupertinoNativePageScaffold.searchState.addListener(_onSearchChanged);
  }

  @override
  void dispose() {
    _debounce?.cancel();
    CupertinoNativePageScaffold.searchState.removeListener(_onSearchChanged);
    super.dispose();
  }

  void _onSearchChanged() {
    final state = CupertinoNativePageScaffold.searchState.value;
    _debounce?.cancel();

    if (state.isActive && state.query.isNotEmpty) {
      // Simulate an async lookup so the loader is visible; a real app would
      // hit a database or network here.
      setState(() {
        _active = true;
        _query = state.query;
        _loading = true;
      });
      _debounce = Timer(const Duration(milliseconds: 500), () {
        if (!mounted) return;
        final q = state.query.toLowerCase();
        setState(() {
          _results = _all.where((e) => e.$1.toLowerCase().contains(q)).toList();
          _loading = false;
        });
      });
    } else {
      setState(() {
        _active = state.isActive;
        _query = state.query;
        _loading = false;
        _results = const [];
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    // The body engine hands the root a height snapped to whole device pixels,
    // so content whose natural height lands on a fraction (947.5 here) misses
    // its slot by a third of a point and a bare Column reports an overflow.
    // A scroll view takes the content unbounded instead; the native ScrollView
    // above still owns the actual scrolling.
    return SingleChildScrollView(
      physics: const NeverScrollableScrollPhysics(),
      child: _body(context),
    );
  }

  Widget _body(BuildContext context) {
    if (!_active) {
      return _list('Languages', _all);
    }
    if (_query.isEmpty) {
      return _suggestionsView();
    }
    if (_loading) {
      return _loader();
    }
    if (_results.isEmpty) {
      return _empty();
    }
    return _list('Results', _results);
  }

  Widget _list(String header, List<(String, String)> items) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 16, 32, 8),
          child: Text(header.toUpperCase(), style: footnoteStyle(context)),
        ),
        SettingsSection(
          children: [
            for (final (name, category) in items)
              SettingsRow(
                title: name,
                subtitle: category,
                showChevron: true,
                onTap: () {},
              ),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _suggestionsView() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(32, 16, 32, 8),
          child: Text('SUGGESTED', style: footnoteStyle(context)),
        ),
        SettingsSection(
          children: [
            for (final s in _suggestions) SettingsRow(title: s, onTap: () {}),
          ],
        ),
        const SizedBox(height: 24),
      ],
    );
  }

  Widget _loader() {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(child: ActivitySpinner(size: 28)),
    );
  }

  Widget _empty() {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Text('No results for "$_query"', style: footnoteStyle(context)),
      ),
    );
  }
}
