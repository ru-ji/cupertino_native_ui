import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cupertino_scroll_edge_effect.dart';
import 'internal/bar_holes.dart';
import 'internal/ios_version.dart';
import 'models/cupertino_native_icon.dart';
import 'models/cupertino_native_tab.dart';
import 'internal/native_color.dart';

/// iOS 26 tab-view bottom accessory: a persistent view shown above the tab bar
/// (like the Music mini-player). Only takes effect inside
/// `CupertinoNativePageScaffold` on iOS 26+. It adapts between the system's
/// `.inline` (single line) and `.expanded` (shows [subtitle]) placements. Taps
/// report through the scaffold's `onToolbarAction` with [actionId] and the current
/// tab's route.
class CupertinoNativeTabBarAccessory {
  final String title;
  final String? subtitle;
  final CupertinoNativeIcon? icon;
  final String actionId;

  const CupertinoNativeTabBarAccessory({
    required this.title,
    this.subtitle,
    this.icon,
    this.actionId = 'accessory',
  });

  Map<String, dynamic> toMap({bool isDark = false}) {
    return {
      'title': title,
      'subtitle': subtitle,
      'icon': icon?.toMap(isDark: isDark),
      'actionId': actionId,
    };
  }
}

/// Mirrors SwiftUI's `tabBarMinimizeBehavior`. Only takes effect inside
/// `CupertinoNativePageScaffold` (iOS 26+), where the scroll view is native.
enum CupertinoNativeTabBarMinimizeBehavior {
  automatic,
  onScrollDown,
  onScrollUp,
  never,
}

/// A native iOS tab bar rendered by a bare `UITabBar` in a transparent
/// container — no UITabBarController, so Flutter content stays visible
/// around and behind the bar.
///
/// Best used as a `Stack` overlay (`Align(alignment: Alignment.bottomCenter)`)
/// over your content rather than in `Scaffold.bottomNavigationBar`, so the
/// bar can hug its intrinsic width ([shrinkCentered]) and float like the
/// iOS 26 pill. With [split] the trailing [rightCount] tabs (e.g. a search
/// tab) render in their own detached bar.
class CupertinoNativeTabBar extends StatefulWidget {
  final List<CupertinoNativeTab> items;

  /// Index of the selected tab in [items], like [CupertinoTabBar.currentIndex].
  final int currentIndex;

  /// Called with the tapped tab's index.
  final ValueChanged<int>? onTap;
  final Color? activeColor;
  final Color? backgroundColor;

  /// Fixed height; when null the native bar's intrinsic height is used.
  final double? height;

  /// Splits the trailing [rightCount] tabs into a detached bar.
  final bool split;
  final int rightCount;
  final double splitSpacing;

  /// When not split, size the bar to its content width (floating pill).
  final bool shrinkCentered;

  /// Only meaningful when this config is passed to `CupertinoNativePageScaffold`.
  final CupertinoNativeTabBarMinimizeBehavior minimizeBehavior;

  /// iOS 26 Liquid Glass scroll-edge-effect style for the bar's background.
  /// `soft`/`automatic` use the translucent default; `hard` uses an opaque
  /// background. No effect below iOS 26.
  final CupertinoScrollEdgeEffectStyle scrollEdgeEffect;

  /// iOS 26 bottom accessory shown above the tab bar. Only meaningful inside
  /// `CupertinoNativePageScaffold`.
  final CupertinoNativeTabBarAccessory? accessory;

  const CupertinoNativeTabBar({
    super.key,
    required this.items,
    this.currentIndex = 0,
    this.onTap,
    this.activeColor,
    this.backgroundColor,
    this.height,
    this.split = false,
    this.rightCount = 1,
    this.splitSpacing = 8.0,
    this.shrinkCentered = true,
    this.minimizeBehavior = CupertinoNativeTabBarMinimizeBehavior.automatic,
    this.scrollEdgeEffect = CupertinoScrollEdgeEffectStyle.automatic,
    this.accessory,
  });

  /// Serialized form consumed by `CupertinoNativePageScaffold` (which renders its
  /// own SwiftUI tab bar; standalone rendering uses different params).
  Map<String, dynamic> toMap({bool isDark = false}) {
    return {
      'tabs': items.map((e) => e.toMap(isDark: isDark)).toList(),
      'selection': items[currentIndex.clamp(0, items.length - 1)].id,
      'accentColor': nativeArgb(activeColor, isDark: isDark),
      'minimizeBehavior': minimizeBehavior.name,
      'scrollEdgeEffect': scrollEdgeEffect.name,
      'accessory': accessory?.toMap(isDark: isDark),
    };
  }

  @override
  State<CupertinoNativeTabBar> createState() => _CupertinoNativeTabBarState();
}

class _CupertinoNativeTabBarState extends State<CupertinoNativeTabBar> {
  MethodChannel? _channel;
  double? _intrinsicHeight;
  double? _intrinsicWidth;
  int? _lastIndex;
  int? _lastTint;
  int? _lastBg;
  String? _lastScrollEdgeEffect;
  bool? _lastIsDark;
  List<String>? _lastLabels;
  List<String>? _lastSymbols;
  List<String>? _lastBadges;
  bool? _lastSplit;
  int? _lastRightCount;
  double? _lastSplitSpacing;

  /// The bar's glass pills cut out of its scroll edge effect's wash, so
  /// their glass sees the content under them and turns light or dark with it
  /// by itself, as the navigation bars' items do (see [BarHoles]).
  final BarHoles _holes = BarHoles();

  /// The pills, measured natively in the bar's own points: its frame holds
  /// more than the pill. Empty until reported.
  List<Rect> _platters = const [];

  // The APP's brightness (its Material theme), so the native bar matches the
  // app rather than the device. Re-synced on theme change.
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  int get _selectedIndex {
    return widget.currentIndex.clamp(0, widget.items.length - 1);
  }

  List<String> get _labels => widget.items.map((t) => t.title).toList();
  List<String> get _badges => widget.items.map((t) => t.badge ?? '').toList();
  List<String> get _symbols =>
      widget.items.map((t) => t.resolvedSymbolName ?? '').toList();

  /// Full icon configs for SwiftUI rendering (supports both SF Symbols and
  /// Flutter glyphs). The standalone UITabBar ignores this and falls back
  /// to the raw SF Symbol strings in [_symbols].
  List<Map<String, dynamic>?> get _iconConfigs =>
      widget.items.map((t) => t.icon?.toMap(isDark: _isDark)).toList();

  @override
  void didUpdateWidget(covariant CupertinoNativeTabBar oldWidget) {
    super.didUpdateWidget(oldWidget);
    _syncPropsToNative();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncBrightness();
    _syncPropsToNative();
  }

  @override
  void dispose() {
    _holes.dispose();
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  void _onPlatformViewCreated(int id) {
    final channel = MethodChannel('cupertino_widgets/tabbar_$id');
    _channel = channel;
    channel.setMethodCallHandler(_handleMethodCall);
    _lastIndex = _selectedIndex;
    _lastTint = nativeArgb(widget.activeColor, isDark: _isDark);
    _lastBg = nativeArgb(widget.backgroundColor, isDark: _isDark);
    _lastScrollEdgeEffect = widget.scrollEdgeEffect.name;
    _lastIsDark = _isDark;
    _lastLabels = _labels;
    _lastSymbols = _symbols;
    _lastBadges = _badges;
    _lastSplit = widget.split;
    _lastRightCount = widget.rightCount;
    _lastSplitSpacing = widget.splitSpacing;
    _requestIntrinsicSize();
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
    if (call.method == 'platters') {
      final runs = [
        for (final v in call.arguments as List? ?? const [])
          (v as num).toDouble(),
      ];
      final platters = [
        for (var i = 0; i + 3 < runs.length; i += 4)
          Rect.fromLTWH(runs[i], runs[i + 1], runs[i + 2], runs[i + 3]),
      ];
      if (mounted && !listEquals(platters, _platters)) {
        setState(() => _platters = platters);
      }
      return;
    }
    if (call.method == 'valueChanged') {
      final args = call.arguments as Map?;
      final idx = (args?['index'] as num?)?.toInt();
      if (idx != null && idx != _lastIndex && idx < widget.items.length) {
        _lastIndex = idx;
        widget.onTap?.call(idx);
      }
    }
  }

  Future<void> _syncPropsToNative() async {
    final channel = _channel;
    if (channel == null) return;

    final idx = _selectedIndex;
    final theme = Theme.of(context);
    final tint =
        nativeArgb(widget.activeColor, isDark: _isDark) ??
        nativeArgb(theme.colorScheme.primary, isDark: _isDark)!;
    final bg = nativeArgb(widget.backgroundColor, isDark: _isDark);
    final labels = _labels;
    final symbols = _symbols;
    final badges = _badges;

    if (_lastIndex != idx) {
      await channel.invokeMethod('setSelectedIndex', {'index': idx});
      _lastIndex = idx;
    }

    final style = <String, dynamic>{};
    if (_lastTint != tint) {
      style['tint'] = tint;
      _lastTint = tint;
    }
    if (_lastBg != bg && bg != null) {
      style['backgroundColor'] = bg;
      _lastBg = bg;
    }
    final scrollEdge = widget.scrollEdgeEffect.name;
    if (_lastScrollEdgeEffect != scrollEdge) {
      style['scrollEdgeEffect'] = scrollEdge;
      _lastScrollEdgeEffect = scrollEdge;
    }
    if (style.isNotEmpty) {
      await channel.invokeMethod('setStyle', style);
    }

    if (!listEquals(_lastLabels, labels) ||
        !listEquals(_lastSymbols, symbols) ||
        !listEquals(_lastBadges, badges)) {
      await channel.invokeMethod('setItems', {
        'labels': labels,
        'sfSymbols': symbols,
        'badges': badges,
        'selectedIndex': idx,
      });
      _lastLabels = labels;
      _lastSymbols = symbols;
      _lastBadges = badges;
      _requestIntrinsicSize();
    }

    if (_lastSplit != widget.split ||
        _lastRightCount != widget.rightCount ||
        _lastSplitSpacing != widget.splitSpacing) {
      await channel.invokeMethod('setLayout', {
        'split': widget.split,
        'rightCount': widget.rightCount,
        'splitSpacing': widget.splitSpacing,
        'selectedIndex': idx,
      });
      _lastSplit = widget.split;
      _lastRightCount = widget.rightCount;
      _lastSplitSpacing = widget.splitSpacing;
      _requestIntrinsicSize();
    }
  }

  Future<void> _syncBrightness() async {
    final channel = _channel;
    if (channel == null) return;
    final isDark = _isDark;
    if (_lastIsDark != isDark) {
      // Recorded before the await: a second flip arriving meanwhile was
      // compared with the stale value and dropped — the bar then missed
      // every other change.
      _lastIsDark = isDark;
      await channel.invokeMethod('setBrightness', {'isDark': isDark});
    }
  }

  Future<void> _requestIntrinsicSize() async {
    if (widget.height != null) return;
    final channel = _channel;
    if (channel == null) return;
    try {
      final size = await channel.invokeMethod<Map>('getIntrinsicSize');
      final h = (size?['height'] as num?)?.toDouble();
      final w = (size?['width'] as num?)?.toDouble();
      if (!mounted) return;
      setState(() {
        if (h != null && h > 0) _intrinsicHeight = h;
        if (w != null && w > 0) _intrinsicWidth = w;
      });
    } catch (_) {
      // View may not be ready yet.
    }
  }

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) {
      // Simple fallback for non-iOS platforms.
      return SizedBox(
        height: widget.height ?? 50,
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceEvenly,
          children: [
            for (var i = 0; i < widget.items.length; i++)
              GestureDetector(
                onTap: () => widget.onTap?.call(i),
                child: Text(
                  widget.items[i].title,
                  style: TextStyle(
                    color: i == _selectedIndex
                        ? (widget.activeColor ?? const Color(0xFF007AFF))
                        : const Color(0xFF8E8E93),
                  ),
                ),
              ),
          ],
        ),
      );
    }

    final theme = Theme.of(context);
    final creationParams = <String, dynamic>{
      'labels': _labels,
      'sfSymbols': _symbols,
      'badges': _badges,
      'icons': _iconConfigs,
      'selectedIndex': _selectedIndex,
      'isDark': _isDark,
      'tint':
          nativeArgb(widget.activeColor, isDark: _isDark) ??
          nativeArgb(theme.colorScheme.primary, isDark: _isDark)!,
      'backgroundColor': nativeArgb(widget.backgroundColor, isDark: _isDark),
      'split': widget.split,
      'rightCount': widget.rightCount,
      'splitSpacing': widget.splitSpacing,
      'scrollEdgeEffect': widget.scrollEdgeEffect.name,
    };

    final platformView = UiKitView(
      viewType: 'com.example.cupertino_widgets/cupertino_native_tabbar',
      layoutDirection: TextDirection.ltr,
      creationParams: creationParams,
      creationParamsCodec: const StandardMessageCodec(),
      onPlatformViewCreated: _onPlatformViewCreated,
    );

    final h = widget.height ?? _intrinsicHeight ?? 50.0;
    Widget bar;
    if (!widget.split && widget.shrinkCentered) {
      bar = SizedBox(height: h, width: _intrinsicWidth, child: platformView);
    } else {
      bar = SizedBox(height: h, child: platformView);
    }

    // The standalone bar draws the scroll edge effect itself when one is
    // requested (iOS 26+): over the system tab bar's place, from the screen
    // edge up to where that bar stops, in either style — whatever this bar's
    // own box.
    if (isIOS26OrLater &&
        widget.scrollEdgeEffect != CupertinoScrollEdgeEffectStyle.automatic) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _measureBelow());
      bar = BarHolesScope(
        holes: _holes,
        child: Stack(
          key: _barKey,
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top:
                  h +
                  _belowBar -
                  (MediaQuery.viewPaddingOf(context).bottom +
                      (widget.scrollEdgeEffect ==
                              CupertinoScrollEdgeEffectStyle.hard
                          ? _effectBand
                          : _softBand)),
              // Down to the physical screen edge — measured, not assumed: a
              // bar that already reaches it (no SafeArea around it) took the
              // home-indicator inset again, so the strongest part of the ramp
              // fell off screen and what showed above the bar was too faint
              // to see.
              bottom: -_belowBar,
              child: CupertinoScrollEdgeEffect(
                edge: CupertinoScrollEdgeEffectEdge.bottom,
                style: widget.scrollEdgeEffect,
              ),
            ),
            // Painted after the effect: the bar sits on it, cut out of its wash.
            // `.hard` does not adapt: nothing to cut out of its band.
            if (widget.scrollEdgeEffect == CupertinoScrollEdgeEffectStyle.hard)
              bar
            else
              BarHole(rects: _platters, child: bar),
          ],
        ),
      );
    }
    return bar;
  }

  /// Where `.hard` stops, measured up from the screen's bottom edge: the
  /// system tab bar's 49pt over the home indicator (83pt on an iPhone 12 Pro
  /// Max, matched against the native `.hard` on 2026-10-03).
  static const double _effectBand = 49;

  /// Where `.soft`'s wash fades out: fitted to the system's on iOS 26 (its
  /// smootherstep reaches 0 at 133pt up on an iPhone 12 Pro Max, 2026-10-03),
  /// past the top of the bar.
  static const double _softBand = 99;

  final GlobalKey _barKey = GlobalKey();

  /// Distance from the bar's bottom to the screen's.
  double _belowBar = 0;

  void _measureBelow() {
    if (!mounted) return;
    final box = _barKey.currentContext?.findRenderObject();
    if (box is! RenderBox || !box.hasSize) return;
    final bottom = box.localToGlobal(Offset(0, box.size.height)).dy;
    final below = (MediaQuery.sizeOf(context).height - bottom).clamp(
      0.0,
      double.infinity,
    );
    if ((below - _belowBar).abs() > 0.5) setState(() => _belowBar = below);
  }
}
