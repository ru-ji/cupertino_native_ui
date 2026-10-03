import 'package:flutter/cupertino.dart';
import 'package:flutter/material.dart' show Scaffold, Theme;
import 'package:cupertino_native_ui/cupertino_native_ui.dart';

/// The App Store, built the way an iOS app builds one: the native navigation
/// bar on top and the standalone native tab bar at the bottom, a workout for
/// [CupertinoNativeSliverNavigationBar] and [CupertinoNativeTabBar] together.
///
/// Every tab is its own page with its own bar: Today, Games, Apps, and Search
/// as the split-off search-role tab with the bar's native search field. The
/// content is Flutter-drawn on purpose: colourful artwork is what makes the
/// scroll edge effect under the bars legible.
class BarsDemoPage extends StatefulWidget {
  const BarsDemoPage({super.key});

  @override
  State<BarsDemoPage> createState() => _BarsDemoPageState();
}

enum _Tab {
  today('Today'),
  games('Games'),
  apps('Apps'),
  search('Search');

  const _Tab(this.title);

  final String title;
}

class _BarsDemoPageState extends State<BarsDemoPage> {
  _Tab _tab = _Tab.today;
  String _query = '';

  @override
  Widget build(BuildContext context) {
    // The App Store's white page, as the page's default background rather
    // than a colour of its own, so the scroll edge effect keeps adapting.
    return Theme(
      data: Theme.of(context).copyWith(
        scaffoldBackgroundColor: CupertinoColors.systemBackground.resolveFrom(
          context,
        ),
      ),
      child: Scaffold(
        body: Stack(
          children: [
            DefaultTextStyle(
              style: CupertinoTheme.of(context).textTheme.textStyle,
              // One page per tab: its own scroll position and its own bar.
              child: CustomScrollView(
                key: ValueKey(_tab),
                slivers: [
                  _navigationBar(),
                  ...switch (_tab) {
                    _Tab.today => _todaySlivers(),
                    _Tab.games => _storeSlivers(_games, 'Games'),
                    _Tab.apps => _storeSlivers(_apps, 'Apps'),
                    _Tab.search => _searchSlivers(),
                  },
                  // Room for the tab bar floating over the end of the page.
                  SliverToBoxAdapter(
                    child: SizedBox(
                      height: MediaQuery.paddingOf(context).bottom + 96,
                    ),
                  ),
                ],
              ),
            ),
            Align(
              alignment: Alignment.bottomCenter,
              child: CupertinoNativeTabBar(
                currentIndex: _tab.index,
                scrollEdgeEffect: CupertinoScrollEdgeEffectStyle.soft,
                // The search tab splits off into its own glass, as in the App
                // Store.
                split: true,
                rightCount: 1,
                items: const [
                  CupertinoNativeTab(
                    id: 'today',
                    title: 'Today',
                    icon: CupertinoNativeIcon.named('doc.text.image'),
                  ),
                  CupertinoNativeTab(
                    id: 'games',
                    title: 'Games',
                    icon: CupertinoNativeIcon.named('gamecontroller.fill'),
                  ),
                  CupertinoNativeTab(
                    id: 'apps',
                    title: 'Apps',
                    icon: CupertinoNativeIcon.named('square.stack.3d.up.fill'),
                    badge: '3',
                  ),
                  CupertinoNativeTab(
                    id: 'search',
                    title: '',
                    icon: CupertinoNativeIcon.named('magnifyingglass'),
                    role: CupertinoNativeTabRole.search,
                  ),
                ],
                onTap: (i) => setState(() {
                  _tab = _Tab.values[i];
                  _query = '';
                }),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The account button every App Store tab carries.
  Widget get _account => CupertinoNativeButton.glass(
    borderShape: CupertinoNativeButtonBorderShape.circle,
    onPressed: () {},
    child: const CupertinoSymbolImage('person.crop.circle'),
  );

  Widget _navigationBar() {
    if (_tab == _Tab.search) {
      return CupertinoNativeSliverNavigationBar.search(
        largeTitle: 'Search',
        trailing: [_account],
        searchPlaceholder: 'Games, Apps, Stories and More',
        bottomMode: NavigationBarBottomMode.always,
        onSearchChanged: (q) => setState(() => _query = q),
        onSearchActiveChanged: (active) {
          if (!active) setState(() => _query = '');
        },
      );
    }
    return CupertinoNativeSliverNavigationBar(
      largeTitle: _tab.title,
      subtitle: _tab == _Tab.today ? _today() : null,
      trailing: [_account],
    );
  }

  static String _today() {
    const days = [
      'Monday',
      'Tuesday',
      'Wednesday',
      'Thursday',
      'Friday',
      'Saturday',
      'Sunday',
    ];
    const months = [
      'January',
      'February',
      'March',
      'April',
      'May',
      'June',
      'July',
      'August',
      'September',
      'October',
      'November',
      'December',
    ];
    final now = DateTime.now();
    return '${days[now.weekday - 1]}, ${months[now.month - 1]} ${now.day}';
  }

  // ---------------------------------------------------------------- Today

  List<Widget> _todaySlivers() => [
    SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
      sliver: SliverList.list(
        children: [
          _StoryCard(
            eyebrow: 'APP OF THE DAY',
            title: 'Stillwater',
            subtitle: 'Sleep sounds that fade with you',
            app: _apps[2],
          ),
          const SizedBox(height: 28),
          _ListCard(
            eyebrow: 'OUR FAVORITES',
            title: 'Apps We Love Right Now',
            apps: [_apps[0], _apps[4], _apps[1], _apps[5]],
          ),
          const SizedBox(height: 28),
          _StoryCard(
            eyebrow: 'GAME OF THE DAY',
            title: 'Lumen Drift',
            subtitle: 'Bend light through a living maze',
            app: _games[0],
          ),
          const SizedBox(height: 28),
          _StoryCard(
            eyebrow: 'GET STARTED',
            title: 'Make Your Mornings Count',
            subtitle: 'Five apps for a calmer start to the day',
            app: _apps[3],
          ),
        ],
      ),
    ),
  ];

  // ---------------------------------------------------------------- Games / Apps

  List<Widget> _storeSlivers(List<_App> apps, String kind) => [
    SliverToBoxAdapter(
      child: SizedBox(
        height: 300,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          itemCount: 3,
          separatorBuilder: (_, _) => const SizedBox(width: 12),
          itemBuilder: (context, i) => _Banner(
            eyebrow: const ['NEW', 'MAJOR UPDATE', 'NOW AVAILABLE'][i],
            app: apps[i],
          ),
        ),
      ),
    ),
    _SectionHeader(
      kind == 'Games' ? 'Must-Play Games' : 'Essential Apps',
      kind == 'Games' ? 'Picked by our editors' : 'Everyday favourites',
    ),
    SliverToBoxAdapter(
      child: SizedBox(
        height: 3 * 76,
        child: ListView.separated(
          scrollDirection: Axis.horizontal,
          padding: const EdgeInsets.symmetric(horizontal: 20),
          itemCount: 2,
          separatorBuilder: (_, _) => const SizedBox(width: 16),
          itemBuilder: (context, column) => SizedBox(
            width: MediaQuery.sizeOf(context).width - 72,
            child: Column(
              children: [
                for (var row = 0; row < 3; row++)
                  _AppRow(
                    app: apps[(column * 3 + row) % apps.length],
                    showSeparator: row != 2,
                  ),
              ],
            ),
          ),
        ),
      ),
    ),
    const _SectionHeader('Top Free', null),
    SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 20),
      sliver: SliverList.builder(
        itemCount: apps.length,
        itemBuilder: (context, i) => _AppRow(
          app: apps[i],
          rank: i + 1,
          showSeparator: i != apps.length - 1,
        ),
      ),
    ),
  ];

  // ---------------------------------------------------------------- Search

  List<Widget> _searchSlivers() {
    final q = _query.trim().toLowerCase();
    if (q.isNotEmpty) {
      final results = [
        ..._apps,
        ..._games,
      ].where((a) => '${a.name} ${a.category}'.toLowerCase().contains(q));
      return [
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 0),
          sliver: SliverList.list(
            children: [
              if (results.isEmpty)
                Padding(
                  padding: const EdgeInsets.only(top: 60),
                  child: Center(
                    child: Text(
                      'No Results for “$_query”',
                      style: TextStyle(
                        fontSize: 17,
                        color: CupertinoColors.secondaryLabel.resolveFrom(
                          context,
                        ),
                      ),
                    ),
                  ),
                ),
              for (final (i, app) in results.indexed)
                _AppRow(app: app, showSeparator: i != results.length - 1),
            ],
          ),
        ),
      ];
    }
    const discover = [
      'sleep sounds',
      'puzzle games',
      'photo editor',
      'habit tracker',
      'offline maps',
    ];
    return [
      const _SectionHeader('Discover', null),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverList.list(
          children: [
            for (final (i, term) in discover.indexed)
              _SuggestionRow(
                term: term,
                showSeparator: i != discover.length - 1,
              ),
          ],
        ),
      ),
      const _SectionHeader('Suggested', null),
      SliverPadding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        sliver: SliverList.list(
          children: [
            for (final (i, app) in [_apps[1], _games[2], _apps[5]].indexed)
              _AppRow(app: app, showSeparator: i != 2),
          ],
        ),
      ),
    ];
  }
}

// ------------------------------------------------------------------ data

class _App {
  const _App(this.name, this.category, this.icon, this.start, this.end);

  final String name;
  final String category;
  final IconData icon;
  final Color start;
  final Color end;
}

const _apps = <_App>[
  _App(
    'Pocket Budget',
    'Finance',
    CupertinoIcons.money_euro_circle_fill,
    Color(0xFF11998E),
    Color(0xFF38EF7D),
  ),
  _App(
    'Canvas Studio',
    'Graphics & Design',
    CupertinoIcons.paintbrush_fill,
    Color(0xFFFF5F6D),
    Color(0xFFFFC371),
  ),
  _App(
    'Stillwater',
    'Health & Fitness',
    CupertinoIcons.moon_stars_fill,
    Color(0xFF1A2980),
    Color(0xFF26D0CE),
  ),
  _App(
    'Sunrise Habits',
    'Productivity',
    CupertinoIcons.sunrise_fill,
    Color(0xFFF7971E),
    Color(0xFFFFD200),
  ),
  _App(
    'Trailhead',
    'Navigation',
    CupertinoIcons.map_fill,
    Color(0xFF56AB2F),
    Color(0xFFA8E063),
  ),
  _App(
    'Lingo Loop',
    'Education',
    CupertinoIcons.chat_bubble_2_fill,
    Color(0xFF8E2DE2),
    Color(0xFF4A00E0),
  ),
];

const _games = <_App>[
  _App(
    'Lumen Drift',
    'Puzzle',
    CupertinoIcons.lightbulb_fill,
    Color(0xFF7F00FF),
    Color(0xFFE100FF),
  ),
  _App(
    'Skyline Racers',
    'Racing',
    CupertinoIcons.car_detailed,
    Color(0xFFCB356B),
    Color(0xFFBD3F32),
  ),
  _App(
    'Tiny Kingdoms',
    'Strategy',
    CupertinoIcons.house_fill,
    Color(0xFF00B4DB),
    Color(0xFF0083B0),
  ),
  _App(
    'Word Garden',
    'Word',
    CupertinoIcons.textformat_abc,
    Color(0xFF56AB2F),
    Color(0xFFA8E063),
  ),
  _App(
    'Orbit Pop',
    'Arcade',
    CupertinoIcons.circle_grid_hex_fill,
    Color(0xFFF953C6),
    Color(0xFFB91D73),
  ),
  _App(
    'Deep Tide',
    'Adventure',
    CupertinoIcons.drop_fill,
    Color(0xFF141E30),
    Color(0xFF243B55),
  ),
];

// ------------------------------------------------------------------ pieces

LinearGradient _gradient(_App app) => LinearGradient(
  begin: Alignment.topLeft,
  end: Alignment.bottomRight,
  colors: [app.start, app.end],
);

/// The app icon: its glyph on its gradient, in the squircle's proportions.
class _AppIcon extends StatelessWidget {
  const _AppIcon({required this.app, required this.size});

  final _App app;
  final double size;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(size * 0.225),
        gradient: _gradient(app),
        border: Border.all(
          color: CupertinoColors.separator.resolveFrom(context),
          width: 0.5,
        ),
      ),
      child: Icon(app.icon, size: size * 0.52, color: CupertinoColors.white),
    );
  }
}

/// The App Store's "Get" capsule. Flutter-drawn: a page lists dozens.
class _GetButton extends StatelessWidget {
  const _GetButton({this.onDark = false});

  final bool onDark;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 6),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(16),
        color: onDark
            ? CupertinoColors.white.withValues(alpha: 0.25)
            : CupertinoColors.tertiarySystemFill.resolveFrom(context),
      ),
      child: Text(
        'Get',
        style: TextStyle(
          fontSize: 15,
          fontWeight: FontWeight.w700,
          color: onDark
              ? CupertinoColors.white
              : CupertinoColors.systemBlue.resolveFrom(context),
        ),
      ),
    );
  }
}

/// A Today story: tall artwork with the eyebrow and title on top and the app
/// along the bottom, on a frosted strip.
class _StoryCard extends StatelessWidget {
  const _StoryCard({
    required this.eyebrow,
    required this.title,
    required this.subtitle,
    required this.app,
  });

  final String eyebrow;
  final String title;
  final String subtitle;
  final _App app;

  @override
  Widget build(BuildContext context) {
    const white = CupertinoColors.white;
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        gradient: _gradient(app),
        boxShadow: [
          BoxShadow(
            color: app.end.withValues(alpha: 0.35),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: SizedBox(
        height: 440,
        child: Stack(
          children: [
            // The artwork: the app's glyph, huge and faded.
            Positioned(
              right: -40,
              top: 90,
              child: Icon(
                app.icon,
                size: 300,
                color: white.withValues(alpha: 0.18),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 20, 20, 0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    eyebrow,
                    style: TextStyle(
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 0.4,
                      color: white.withValues(alpha: 0.75),
                    ),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    title,
                    style: const TextStyle(
                      fontSize: 30,
                      fontWeight: FontWeight.w800,
                      letterSpacing: -0.6,
                      height: 1.1,
                      color: white,
                    ),
                  ),
                ],
              ),
            ),
            Positioned(
              left: 0,
              right: 0,
              bottom: 0,
              child: Container(
                padding: const EdgeInsets.fromLTRB(16, 14, 16, 16),
                decoration: BoxDecoration(
                  borderRadius: const BorderRadius.vertical(
                    bottom: Radius.circular(22),
                  ),
                  color: CupertinoColors.black.withValues(alpha: 0.18),
                ),
                child: Row(
                  children: [
                    _AppIcon(app: app, size: 48),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            app.name,
                            style: const TextStyle(
                              fontSize: 16,
                              fontWeight: FontWeight.w600,
                              color: white,
                            ),
                          ),
                          Text(
                            subtitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              fontSize: 13,
                              color: white.withValues(alpha: 0.8),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const _GetButton(onDark: true),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// A Today collection: a plain card listing a few apps.
class _ListCard extends StatelessWidget {
  const _ListCard({
    required this.eyebrow,
    required this.title,
    required this.apps,
  });

  final String eyebrow;
  final String title;
  final List<_App> apps;

  @override
  Widget build(BuildContext context) {
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(22),
        color: CupertinoColors.secondarySystemBackground.resolveFrom(context),
      ),
      child: Padding(
        padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              eyebrow,
              style: TextStyle(
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.4,
                color: CupertinoColors.secondaryLabel.resolveFrom(context),
              ),
            ),
            const SizedBox(height: 4),
            Text(
              title,
              style: const TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w800,
                letterSpacing: -0.5,
              ),
            ),
            const SizedBox(height: 12),
            for (final (i, app) in apps.indexed)
              _AppRow(app: app, showSeparator: i != apps.length - 1),
          ],
        ),
      ),
    );
  }
}

/// A wide featured banner of the Games and Apps tabs.
class _Banner extends StatelessWidget {
  const _Banner({required this.eyebrow, required this.app});

  final String eyebrow;
  final _App app;

  @override
  Widget build(BuildContext context) {
    const white = CupertinoColors.white;
    return SizedBox(
      width: MediaQuery.sizeOf(context).width - 56,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            eyebrow,
            style: TextStyle(
              fontSize: 12,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.systemBlue.resolveFrom(context),
            ),
          ),
          Text(
            app.name,
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w600),
          ),
          Text(
            app.category,
            style: TextStyle(
              fontSize: 17,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                gradient: _gradient(app),
              ),
              child: Stack(
                children: [
                  Center(
                    child: Icon(
                      app.icon,
                      size: 110,
                      color: white.withValues(alpha: 0.3),
                    ),
                  ),
                  Positioned(
                    left: 14,
                    bottom: 14,
                    right: 14,
                    child: Row(
                      children: [
                        _AppIcon(app: app, size: 40),
                        const SizedBox(width: 10),
                        Expanded(
                          child: Text(
                            app.name,
                            style: const TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600,
                              color: white,
                            ),
                          ),
                        ),
                        const _GetButton(onDark: true),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// An app row: icon, name, category, Get, numbered in a chart.
class _AppRow extends StatelessWidget {
  const _AppRow({required this.app, required this.showSeparator, this.rank});

  final _App app;
  final bool showSeparator;
  final int? rank;

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    return SizedBox(
      height: 76,
      child: Row(
        children: [
          _AppIcon(app: app, size: 58),
          const SizedBox(width: 12),
          if (rank != null) ...[
            SizedBox(
              width: 22,
              child: Text(
                '$rank',
                style: const TextStyle(
                  fontSize: 17,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
          Expanded(
            child: DecoratedBox(
              decoration: BoxDecoration(
                border: showSeparator
                    ? Border(
                        bottom: BorderSide(
                          color: CupertinoColors.separator.resolveFrom(context),
                          width: 0.5,
                        ),
                      )
                    : null,
              ),
              child: SizedBox(
                height: 76,
                child: Row(
                  children: [
                    Expanded(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            app.name,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(fontSize: 16),
                          ),
                          Text(
                            app.category,
                            style: TextStyle(fontSize: 13, color: secondary),
                          ),
                        ],
                      ),
                    ),
                    const _GetButton(),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A Discover suggestion: the magnifying glass and the term, in blue.
class _SuggestionRow extends StatelessWidget {
  const _SuggestionRow({required this.term, required this.showSeparator});

  final String term;
  final bool showSeparator;

  @override
  Widget build(BuildContext context) {
    final blue = CupertinoColors.systemBlue.resolveFrom(context);
    return DecoratedBox(
      decoration: BoxDecoration(
        border: showSeparator
            ? Border(
                bottom: BorderSide(
                  color: CupertinoColors.separator.resolveFrom(context),
                  width: 0.5,
                ),
              )
            : null,
      ),
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Row(
          children: [
            Icon(CupertinoIcons.search, size: 18, color: blue),
            const SizedBox(width: 10),
            Text(term, style: TextStyle(fontSize: 19, color: blue)),
          ],
        ),
      ),
    );
  }
}

/// A section title, with an optional line under it.
class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.title, this.subtitle);

  final String title;
  final String? subtitle;

  @override
  Widget build(BuildContext context) {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(20, 28, 20, 8),
      sliver: SliverToBoxAdapter(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              title,
              style: const TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: -0.4,
              ),
            ),
            if (subtitle != null)
              Text(
                subtitle!,
                style: TextStyle(
                  fontSize: 15,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
