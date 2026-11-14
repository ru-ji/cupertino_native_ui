import 'dart:async';

import 'package:cupertino_ui/cupertino_ui.dart';
import 'package:cupertino_native_ui/cupertino_native_ui.dart';

/// Self-playing promo material, recorded from the simulator and composed into
/// the package video. Run with `--dart-define=SHOWCASE=true`, plus
/// `--dart-define=SCENE=screen` for the Photos-like screen instead of the
/// widget grid. Every glass here is the real native one.
class ShowcasePage extends StatelessWidget {
  const ShowcasePage({super.key});

  @override
  Widget build(BuildContext context) =>
      const String.fromEnvironment('SCENE') == 'screen'
      ? const _PhotosScreen()
      : const _WidgetGrid();
}

/// Runs [step] every [period], forever.
mixin _Looping<T extends StatefulWidget> on State<T> {
  Timer? _timer;
  int tick = 0;

  void loop(Duration period) => _timer = Timer.periodic(
    period,
    (_) => setState(() => tick++),
  );

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }
}

/// Isolated widgets on white panels, one per card of the video. Panels sit
/// at fixed spots so the composer can crop each one out.
class _WidgetGrid extends StatefulWidget {
  const _WidgetGrid();

  @override
  State<_WidgetGrid> createState() => _WidgetGridState();
}

class _WidgetGridState extends State<_WidgetGrid> with _Looping {
  @override
  void initState() {
    super.initState();
    loop(const Duration(milliseconds: 1100));
  }

  static const _blue = Color(0xFF8EC5FF);
  static const _hero = [
    (Color(0xFF8EC5FF), 'pencil', 'Compose'),
    (Color(0xFFC3A6FF), 'paperplane.fill', 'Send'),
    (Color(0xFF8FE3C8), 'checkmark', 'Done'),
  ];

  Widget _panel(double height, Widget child) => Container(
    height: height,
    margin: const EdgeInsets.only(bottom: 8),
    color: CupertinoColors.white,
    alignment: Alignment.center,
    child: child,
  );

  @override
  Widget build(BuildContext context) {
    final hero = _hero[tick ~/ 2 % _hero.length];
    final toolbarOpen = tick % 4 >= 2;
    final playing = tick % 2 == 1;
    return CupertinoPageScaffold(
      backgroundColor: const Color(0xFFE5E5EA),
      child: Padding(
        padding: const EdgeInsets.only(top: 60),
        child: Column(
          children: [
            // 1. Hero tinted glass pill.
            _panel(
              170,
              CupertinoNativeGlassContainer(
                shape: CupertinoGlassShape.capsule,
                tint: hero.$1.withValues(alpha: 0.75),
                animateChanges: true,
                width: 320,
                height: 104,
                child: Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CupertinoSymbolImage(
                      hero.$2,
                      size: 30,
                      color: const Color(0xFF1C3D5A),
                    ),
                    const SizedBox(width: 16),
                    Text(
                      hero.$3,
                      style: const TextStyle(
                        fontSize: 36,
                        fontWeight: FontWeight.w600,
                        color: Color(0xFF1C3D5A),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            // 2. Morphing toolbar.
            _panel(
              120,
              CupertinoNativeGlassGroup(
                spacing: 10,
                tint: const Color(0xFFD9C6FF),
                items: [
                  const CupertinoNativeGlassGroupItem(
                    actionId: 'share',
                    width: 60,
                    height: 60,
                    icon: CupertinoNativeIcon.named(
                      'square.and.arrow.up',
                      size: 22,
                    ),
                  ),
                  if (toolbarOpen) ...const [
                    CupertinoNativeGlassGroupItem(
                      actionId: 'message',
                      width: 60,
                      height: 60,
                      icon: CupertinoNativeIcon.named('message', size: 22),
                    ),
                    CupertinoNativeGlassGroupItem(
                      actionId: 'heart',
                      width: 60,
                      height: 60,
                      icon: CupertinoNativeIcon.named('heart', size: 22),
                    ),
                  ],
                  const CupertinoNativeGlassGroupItem(
                    actionId: 'more',
                    width: 60,
                    height: 60,
                    icon: CupertinoNativeIcon.named('ellipsis', size: 22),
                  ),
                ],
              ),
            ),
            // 3 and 4. Small tiles: play/pause and end call.
            Row(
              children: [
                Expanded(
                  child: _panel(
                    150,
                    CupertinoNativeGlassGroup(
                      tint: const Color(0xFF9EE6CF),
                      interactive: false,
                      items: [
                        CupertinoNativeGlassGroupItem(
                          actionId: playing ? 'pause' : 'play',
                          width: 84,
                          height: 84,
                          icon: CupertinoNativeIcon.named(
                            playing ? 'pause.fill' : 'play.fill',
                            size: 30,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _panel(
                    150,
                    CupertinoNativeGlassContainer(
                      shape: CupertinoGlassShape.capsule,
                      tint: const Color(0xFFFF8A80).withValues(alpha: 0.8),
                      width: 110,
                      height: 70,
                      icon: const CupertinoNativeIcon.named(
                        'phone.down.fill',
                        size: 28,
                        color: CupertinoColors.white,
                      ),
                    ),
                  ),
                ),
              ],
            ),
            // 5. Controls.
            _panel(
              150,
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: 40),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    CupertinoNativeSlidingSegmentedControl<int>(
                      children: const {
                        0: Text('Day'),
                        1: Text('Week'),
                        2: Text('Month'),
                      },
                      groupValue: tick % 3,
                      onValueChanged: (_) {},
                    ),
                    const SizedBox(height: 22),
                    Row(
                      children: [
                        CupertinoNativeSwitch(
                          value: tick % 2 == 0,
                          onChanged: (_) {},
                        ),
                        const SizedBox(width: 20),
                        Expanded(
                          child: CupertinoNativeSlider(
                            value: [0.3, 0.8, 0.55, 0.2][tick % 4],
                            activeColor: _blue,
                            onChanged: (_) {},
                          ),
                        ),
                      ],
                    ),
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

/// A Photos-like library: real photos scrolling under the glass buttons and
/// the glass tab bar, the "Select" capsule reshaping as in Photos.
class _PhotosScreen extends StatefulWidget {
  const _PhotosScreen();

  @override
  State<_PhotosScreen> createState() => _PhotosScreenState();
}

class _PhotosScreenState extends State<_PhotosScreen> with _Looping {
  final _scroll = ScrollController();

  @override
  void initState() {
    super.initState();
    loop(const Duration(milliseconds: 1600));
    // Slow drift down the library and back, so content moves under the glass.
    Future<void> drift() async {
      while (mounted) {
        await Future<void>.delayed(const Duration(seconds: 2));
        if (!mounted || !_scroll.hasClients) continue;
        await _scroll.animateTo(
          _scroll.offset < 100 ? 900 : 0,
          duration: const Duration(seconds: 6),
          curve: Curves.easeInOut,
        );
      }
    }

    drift();
  }

  @override
  void dispose() {
    _scroll.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pad = MediaQuery.paddingOf(context);
    final selecting = tick % 4 >= 2;
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.white,
      child: Stack(
        children: [
          GridView.builder(
            controller: _scroll,
            padding: EdgeInsets.only(top: pad.top + 120, bottom: 140),
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              mainAxisSpacing: 2,
              crossAxisSpacing: 2,
            ),
            itemCount: 90,
            itemBuilder: (_, i) => Image.network(
              'https://picsum.photos/seed/cn$i/300/300',
              fit: BoxFit.cover,
            ),
          ),
          Positioned(
            top: pad.top + 4,
            left: 20,
            right: 16,
            child: Row(
              children: [
                const Text(
                  'Library',
                  style: TextStyle(
                    fontSize: 34,
                    fontWeight: FontWeight.w700,
                    color: CupertinoColors.white,
                    shadows: [Shadow(blurRadius: 12, color: Color(0x66000000))],
                  ),
                ),
                const Spacer(),
                CupertinoNativeGlassGroup(
                  spacing: 6,
                  items: selecting
                      ? const [
                          CupertinoNativeGlassGroupItem(
                            actionId: 'menu.wide',
                            shape: CupertinoGlassGroupShape.capsule,
                            icon: CupertinoNativeIcon.named(
                              'square.and.arrow.up',
                            ),
                            title: '3 Selected',
                          ),
                          CupertinoNativeGlassGroupItem(
                            actionId: 'close',
                            shape: CupertinoGlassGroupShape.capsule,
                            width: 44,
                            icon: CupertinoNativeIcon.named('xmark'),
                          ),
                        ]
                      : const [
                          CupertinoNativeGlassGroupItem(
                            actionId: 'menu',
                            shape: CupertinoGlassGroupShape.capsule,
                            width: 44,
                            icon: CupertinoNativeIcon.named(
                              'line.3.horizontal',
                            ),
                          ),
                          CupertinoNativeGlassGroupItem(
                            actionId: 'select',
                            shape: CupertinoGlassGroupShape.capsule,
                            title: 'Select',
                          ),
                        ],
                ),
              ],
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: CupertinoNativeTabBar(
              split: true,
              currentIndex: tick ~/ 2 % 3,
              items: const [
                CupertinoNativeTab(
                  id: 'library',
                  title: 'Library',
                  icon: CupertinoNativeIcon.named('photo.fill.on.rectangle.fill'),
                ),
                CupertinoNativeTab(
                  id: 'collections',
                  title: 'Collections',
                  icon: CupertinoNativeIcon.named('rectangle.stack.fill'),
                ),
                CupertinoNativeTab(
                  id: 'shared',
                  title: 'Shared',
                  icon: CupertinoNativeIcon.named('person.2.fill'),
                ),
                CupertinoNativeTab(
                  id: 'search',
                  title: 'Search',
                  icon: CupertinoNativeIcon.named('magnifyingglass'),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
