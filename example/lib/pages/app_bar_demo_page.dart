import 'package:flutter/cupertino.dart'
    show CupertinoColors, CupertinoDynamicColor, NavigationBarBottomMode;
import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter/widgets.dart';
import 'package:cupertino_widgets/cupertino_widgets.dart';

import '../widgets/settings_ui.dart';

/// A music library, built the way an iOS app builds one — and a full workout
/// for [CupertinoNativeSliverNavigationBar].
///
/// Everything here is Flutter-drawn on purpose: artwork gradients are what
/// make the scroll edge effect legible, since its blur samples the Flutter
/// scene (a native list, being a UIKit view, gives it nothing to read).
/// Scroll and watch the large title blur-morph into the inline one over that
/// effect, the search row lift off the page and turn to glass as it goes, and
/// the field morph to the top with a glass ✕ when tapped.
class AppBarDemoPage extends StatefulWidget {
  const AppBarDemoPage({super.key});

  @override
  State<AppBarDemoPage> createState() => _AppBarDemoPageState();
}

class _AppBarDemoPageState extends State<AppBarDemoPage> {
  static const _hero = _Album(
    'Chill Mix',
    'Updated Wednesday',
    Color(0xFF3A1C71),
    Color(0xFFD76D77),
  );

  static const _recent = <_Album>[
    _Album(
      'Midnight Drive',
      'Kite Season',
      Color(0xFF0F2027),
      Color(0xFF2C5364),
    ),
    _Album('Golden Hour', 'Mara Lune', Color(0xFFF7971E), Color(0xFFFFD200)),
    _Album('Paper Boats', 'Hollow Coast', Color(0xFF11998E), Color(0xFF38EF7D)),
    _Album('Neon Fields', 'Ruby Atlas', Color(0xFF7F00FF), Color(0xFFE100FF)),
    _Album('Slow Burn', 'The Ember Set', Color(0xFFCB356B), Color(0xFFBD3F32)),
    _Album('Winter Static', 'Nils Havre', Color(0xFF232526), Color(0xFF6D7B8D)),
  ];

  static const _playlists = <_Album>[
    _Album(
      'Focus Flow',
      '48 songs · 3 hr 12 min',
      Color(0xFF1A2980),
      Color(0xFF26D0CE),
    ),
    _Album(
      'Sunday Morning',
      '32 songs · 2 hr 04 min',
      Color(0xFFFFB75E),
      Color(0xFFED8F03),
    ),
    _Album(
      'Late Night Drive',
      '61 songs · 4 hr 27 min',
      Color(0xFF41295A),
      Color(0xFF2F0743),
    ),
    _Album(
      'Kitchen Radio',
      '25 songs · 1 hr 38 min',
      Color(0xFF56AB2F),
      Color(0xFFA8E063),
    ),
    _Album(
      'Rainy Day Jazz',
      '40 songs · 2 hr 51 min',
      Color(0xFF2C3E50),
      Color(0xFF4CA1AF),
    ),
    _Album(
      'Running Club',
      '18 songs · 1 hr 06 min',
      Color(0xFFFF512F),
      Color(0xFFDD2476),
    ),
  ];

  static const _recentSearches = [
    'Mara Lune',
    'Focus Flow',
    'Paper Boats',
    'Ambient',
  ];

  bool _searching = false;
  String _query = '';

  List<_Album> get _results {
    final q = _query.trim().toLowerCase();
    if (q.isEmpty) return const [];
    return [..._recent, ..._playlists]
        .where((a) => '${a.title} ${a.subtitle}'.toLowerCase().contains(q))
        .toList();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: CupertinoColors.systemBackground.resolveFrom(context),
      body: DefaultTextStyle(
        style: rowTitleStyle(context),
        child: CustomScrollView(
          slivers: [
            CupertinoNativeSliverNavigationBar.search(
              largeTitle: 'Library',
              subtitle: '128 albums',
              centerTitle: true,
              leading: CupertinoNativeButton.glass(
                borderShape: CupertinoNativeButtonBorderShape.circle,
                onPressed: () => Navigator.pop(context),
                child: CupertinoSymbolImage.symbol(
                  CupertinoSymbols.chevronBackward,
                ),
              ),
              trailing: [
                // Icon-only actions sharing one glass, like a toolbar group.
                CupertinoNativeGlassGroup(
                  spacing: 0,
                  onAction: (_) {},
                  items: [
                    CupertinoNativeGlassGroupItem(
                      actionId: 'sort',
                      icon: CupertinoNativeIcon.symbol(
                        CupertinoSymbols.arrowUpArrowDown,
                      ),
                    ),
                    CupertinoNativeGlassGroupItem(
                      actionId: 'more',
                      icon: CupertinoNativeIcon.named('ellipsis'),
                    ),
                  ],
                ),
              ],
              searchPlaceholder: 'Artists, Songs, Albums',
              // Kept on screen while the page scrolls: on iOS 26 the row lifts
              // off the content as the title collapses, and turns to glass.
              bottomMode: NavigationBarBottomMode.always,
              onSearchChanged: (q) => setState(() => _query = q),
              onSearchActiveChanged: (active) => setState(() {
                _searching = active;
                if (!active) _query = '';
              }),
            ),
            if (_searching)
              ..._searchSlivers(context)
            else
              ..._librarySlivers(),
          ],
        ),
      ),
    );
  }

  List<Widget> _librarySlivers() => [
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
        child: _HeroCard(album: _hero),
      ),
    ),
    const SliverToBoxAdapter(child: _SectionHeader('Recently Played')),
    SliverToBoxAdapter(
      child: SizedBox(
        height: 208,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: _recent.length,
          separatorBuilder: (_, _) => const SizedBox(width: 14),
          itemBuilder: (context, i) => _ArtCard(album: _recent[i]),
        ),
      ),
    ),
    const SliverToBoxAdapter(child: _SectionHeader('Your Playlists')),
    SliverList.builder(
      itemCount: _playlists.length,
      itemBuilder: (context, i) => _LibraryRow(
        album: _playlists[i],
        showSeparator: i != _playlists.length - 1,
      ),
    ),
    SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 24, 16, 48),
        child: Builder(
          builder: (context) => Text(
            '${_playlists.length} playlists · Synced just now',
            style: footnoteStyle(context),
          ),
        ),
      ),
    ),
  ];

  List<Widget> _searchSlivers(BuildContext context) {
    if (_query.trim().isEmpty) {
      return [
        const SliverToBoxAdapter(child: _SectionHeader('Recent Searches')),
        SliverList.builder(
          itemCount: _recentSearches.length,
          itemBuilder: (context, i) => _SearchTermRow(
            term: _recentSearches[i],
            showSeparator: i != _recentSearches.length - 1,
          ),
        ),
      ];
    }
    final results = _results;
    if (results.isEmpty) {
      return [
        SliverToBoxAdapter(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 72, 16, 0),
            child: Column(
              children: [
                Text(
                  'No Results',
                  style: rowTitleStyle(context)
                      .copyWith(fontSize: 20, fontWeight: FontWeight.w600),
                ),
                const SizedBox(height: 6),
                Text(
                  'Try a different artist, song or album.',
                  style: footnoteStyle(context),
                ),
              ],
            ),
          ),
        ),
      ];
    }
    return [
      const SliverToBoxAdapter(child: _SectionHeader('Results')),
      SliverList.builder(
        itemCount: results.length,
        itemBuilder: (context, i) => _LibraryRow(
          album: results[i],
          showSeparator: i != results.length - 1,
        ),
      ),
    ];
  }
}

/// Title, subtitle and the two gradient stops of one piece of artwork.
class _Album {
  const _Album(this.title, this.subtitle, this.start, this.end);

  final String title;
  final String subtitle;
  final Color start;
  final Color end;
}

/// Rounded gradient artwork — the stand-in for a cover image.
class _Artwork extends StatelessWidget {
  const _Artwork({required this.album, required this.size, this.radius = 10});

  final _Album album;
  final double size;
  final double radius;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(radius),
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [album.start, album.end],
        ),
      ),
    );
  }
}

/// The featured card: full-width artwork with its label over it and a Liquid
/// Glass play button — clear glass, the variant iOS uses over media.
class _HeroCard extends StatelessWidget {
  const _HeroCard({required this.album});

  final _Album album;

  @override
  Widget build(BuildContext context) {
    const white = Color(0xFFFFFFFF);
    return ClipRRect(
      borderRadius: BorderRadius.circular(22),
      child: SizedBox(
        height: 208,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [album.start, album.end],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Expanded(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.end,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'MADE FOR YOU',
                          style: TextStyle(
                            fontSize: 12,
                            fontWeight: FontWeight.w600,
                            letterSpacing: 0.6,
                            decoration: TextDecoration.none,
                            color: white.withValues(alpha: 0.75),
                          ),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          album.title,
                          style: const TextStyle(
                            fontSize: 28,
                            fontWeight: FontWeight.w700,
                            letterSpacing: -0.5,
                            decoration: TextDecoration.none,
                            color: white,
                          ),
                        ),
                        Text(
                          album.subtitle,
                          style: TextStyle(
                            fontSize: 14,
                            decoration: TextDecoration.none,
                            color: white.withValues(alpha: 0.8),
                          ),
                        ),
                      ],
                    ),
                  ),
                  CupertinoNativeGlassContainer(
                    shape: CupertinoGlassShape.circle,
                    variant: CupertinoGlassVariant.clear,
                    interactive: true,
                    width: 52,
                    height: 52,
                    icon: CupertinoNativeIcon.symbol(
                      CupertinoSymbols.playFill,
                      size: 22,
                      color: white,
                    ),
                    onPressed: () {},
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A section heading, sized like the ones iOS puts above a shelf.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title);

  final String title;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(
            title,
            style: rowTitleStyle(context).copyWith(
              fontSize: 22,
              fontWeight: FontWeight.w700,
              letterSpacing: -0.4,
            ),
          ),
          Text(
            'See All',
            style: rowTitleStyle(
              context,
              color: CupertinoColors.systemBlue.resolveFrom(context),
            ).copyWith(fontSize: 15),
          ),
        ],
      ),
    );
  }
}

/// One item of the horizontal shelf: artwork over two lines of text.
class _ArtCard extends StatelessWidget {
  const _ArtCard({required this.album});

  final _Album album;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 150,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          _Artwork(album: album, size: 150, radius: 14),
          const SizedBox(height: 10),
          Text(
            album.title,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: rowTitleStyle(context).copyWith(fontSize: 15),
          ),
          const SizedBox(height: 2),
          Text(
            album.subtitle,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: footnoteStyle(context),
          ),
        ],
      ),
    );
  }
}

/// A playlist / result row: artwork, two lines, chevron, and a hairline inset
/// past the artwork — the iOS table row.
class _LibraryRow extends StatelessWidget {
  const _LibraryRow({required this.album, required this.showSeparator});

  final _Album album;
  final bool showSeparator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 8, 16, 8),
            child: Row(
              children: [
                _Artwork(album: album, size: 52, radius: 8),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        album.title,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: rowTitleStyle(context),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        album.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: footnoteStyle(context),
                      ),
                    ],
                  ),
                ),
                const DisclosureChevron(),
              ],
            ),
          ),
          if (showSeparator) const _Separator(inset: 64),
        ],
      ),
    );
  }
}

/// A past query, the way Music lists them under the field.
class _SearchTermRow extends StatelessWidget {
  const _SearchTermRow({required this.term, required this.showSeparator});

  final String term;
  final bool showSeparator;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(left: 16),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(0, 14, 16, 14),
            child: Row(
              children: [
                Expanded(child: Text(term, style: rowTitleStyle(context))),
                const DisclosureChevron(),
              ],
            ),
          ),
          if (showSeparator) const _Separator(inset: 0),
        ],
      ),
    );
  }
}

/// Hairline of the current appearance, one physical pixel tall.
class _Separator extends StatelessWidget {
  const _Separator({required this.inset});

  final double inset;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(left: inset),
      child: Container(
        height: 1 / MediaQuery.devicePixelRatioOf(context),
        color: CupertinoDynamicColor.resolve(
          CupertinoColors.separator,
          context,
        ),
      ),
    );
  }
}
