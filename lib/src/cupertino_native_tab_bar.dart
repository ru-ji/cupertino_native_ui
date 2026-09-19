import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cupertino_scroll_edge_effect.dart';
import 'internal/ios_version.dart';
import 'models/cupertino_native_icon.dart';
import 'models/cupertino_native_tab.dart';

/// iOS 26 tab-view bottom accessory: a persistent view shown above the tab bar
/// (like the Music mini-player). Only takes effect inside
/// `CupertinoNativePageScaffold` on iOS 26+. It adapts between the system's
/// `.inline` (single line) and `.expanded` (shows [subtitle]) placements. Taps
/// report through the scaffold's `onBarAction` with [actionId] and the current
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

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'subtitle': subtitle,
      'icon': icon?.toMap(),
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

/// iOS 26 Liquid Glass scroll-edge-effect style. Used both by the standalone
/// [CupertinoNativeTabBar] (mapped to the bar's background material) and by
/// `CupertinoNativePageScaffold`'s native scroll views. No effect below iOS 26.
enum CupertinoScrollEdgeEffectStyle { automatic, soft, hard }

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
  Map<String, dynamic> toMap() {
    return {
      'tabs': items.map((e) => e.toMap()).toList(),
      'selection': items[currentIndex.clamp(0, items.length - 1)].id,
      'accentColor': activeColor?.toARGB32(),
      'minimizeBehavior': minimizeBehavior.name,
      'scrollEdgeEffect': scrollEdgeEffect.name,
      'accessory': accessory?.toMap(),
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
  bool? _lastSplit;
  int? _lastRightCount;
  double? _lastSplitSpacing;

  // The APP's brightness (its Material theme), so the native bar matches the
  // app rather than the device. Re-synced dynamically on theme change.
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  int get _selectedIndex {
    return widget.currentIndex.clamp(0, widget.items.length - 1);
  }

  List<String> get _labels => widget.items.map((t) => t.title).toList();
  List<String> get _symbols =>
      widget.items.map((t) => t.resolvedSymbolName ?? '').toList();

  /// Full icon configs for SwiftUI rendering (supports both SF Symbols and
  /// Flutter glyphs). The standalone UITabBar ignores this and falls back
  /// to the raw SF Symbol strings in [_symbols].
  List<Map<String, dynamic>?> get _iconConfigs =>
      widget.items.map((t) => t.icon?.toMap()).toList();

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
    _channel?.setMethodCallHandler(null);
    super.dispose();
  }

  void _onPlatformViewCreated(int id) {
    final channel = MethodChannel('cupertino_widgets/tabbar_$id');
    _channel = channel;
    channel.setMethodCallHandler(_handleMethodCall);
    _lastIndex = _selectedIndex;
    _lastTint = widget.activeColor?.toARGB32();
    _lastBg = widget.backgroundColor?.toARGB32();
    _lastScrollEdgeEffect = widget.scrollEdgeEffect.name;
    _lastIsDark = _isDark;
    _lastLabels = _labels;
    _lastSymbols = _symbols;
    _lastSplit = widget.split;
    _lastRightCount = widget.rightCount;
    _lastSplitSpacing = widget.splitSpacing;
    _requestIntrinsicSize();
  }

  Future<dynamic> _handleMethodCall(MethodCall call) async {
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
        widget.activeColor?.toARGB32() ?? theme.colorScheme.primary.toARGB32();
    final bg = widget.backgroundColor?.toARGB32();
    final labels = _labels;
    final symbols = _symbols;

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
        !listEquals(_lastSymbols, symbols)) {
      await channel.invokeMethod('setItems', {
        'labels': labels,
        'sfSymbols': symbols,
        'selectedIndex': idx,
      });
      _lastLabels = labels;
      _lastSymbols = symbols;
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
      await channel.invokeMethod('setBrightness', {'isDark': isDark});
      _lastIsDark = isDark;
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
      'icons': _iconConfigs,
      'selectedIndex': _selectedIndex,
      'isDark': _isDark,
      'tint':
          widget.activeColor?.toARGB32() ??
          theme.colorScheme.primary.toARGB32(),
      'backgroundColor': widget.backgroundColor?.toARGB32(),
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
    // requested (iOS 26+).
    if (isIOS26OrLater &&
        widget.scrollEdgeEffect != CupertinoScrollEdgeEffectStyle.automatic) {
      final bottomInset = MediaQuery.paddingOf(context).bottom;
      bar = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            // One bar height above the bar, like the top edge.
            top: -h,
            // Down to the physical screen edge, home indicator area included.
            bottom: -bottomInset,
            child: CupertinoScrollEdgeEffect(
              edge: CupertinoScrollEdgeEffectEdge.bottom,
              style: widget.scrollEdgeEffect,
            ),
          ),
          // Painted after the effect: the bar sits on it.
          bar,
        ],
      );
    }
    return bar;
  }
}
