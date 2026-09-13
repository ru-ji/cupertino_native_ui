import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import 'cupertino_scroll_edge_effect.dart';
import 'internal/bar_snapshots.dart';
import 'internal/edge_effect_coverage.dart';
import 'internal/ios_version.dart';
import 'models/cupertino_native_icon.dart';
import 'models/cupertino_native_tab.dart';

/// iOS 26 tab-view bottom accessory: a persistent view shown above the tab bar
/// (like the Music mini-player). Only takes effect inside
/// `CupertinoNativeScaffold` on iOS 26+. It adapts between the system's
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
/// `CupertinoNativeScaffold` (iOS 26+), where the scroll view is native.
enum CupertinoNativeTabBarMinimizeBehavior {
  automatic,
  onScrollDown,
  onScrollUp,
  never,
}

/// iOS 26 Liquid Glass scroll-edge-effect style. Used both by the standalone
/// [CupertinoNativeTabBar] (mapped to the bar's background material) and by
/// `CupertinoNativeScaffold`'s native scroll views. No effect below iOS 26.
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
  final List<CupertinoNativeTab> tabs;

  /// Id of the selected tab (see [CupertinoNativeTab.id]).
  final String value;
  final ValueChanged<String>? onChanged;
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

  /// Only meaningful when this config is passed to `CupertinoNativeScaffold`.
  final CupertinoNativeTabBarMinimizeBehavior minimizeBehavior;

  /// iOS 26 Liquid Glass scroll-edge-effect style for the bar's background.
  /// `soft`/`automatic` use the translucent default; `hard` uses an opaque
  /// background. No effect below iOS 26.
  final CupertinoScrollEdgeEffectStyle scrollEdgeEffect;

  /// iOS 26 bottom accessory shown above the tab bar. Only meaningful inside
  /// `CupertinoNativeScaffold`.
  final CupertinoNativeTabBarAccessory? accessory;

  const CupertinoNativeTabBar({
    super.key,
    required this.tabs,
    required this.value,
    this.onChanged,
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

  /// Serialized form consumed by `CupertinoNativeScaffold` (which renders its
  /// own SwiftUI tab bar; standalone rendering uses different params).
  Map<String, dynamic> toMap() {
    return {
      'tabs': tabs.map((e) => e.toMap()).toList(),
      'selection': value,
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
    final idx = widget.tabs.indexWhere((t) => t.id == widget.value);
    return idx < 0 ? 0 : idx;
  }

  List<String> get _labels => widget.tabs.map((t) => t.title).toList();
  List<String> get _symbols =>
      widget.tabs.map((t) => t.resolvedSymbolName ?? '').toList();

  /// Full icon configs for SwiftUI rendering (supports both SF Symbols and
  /// Flutter glyphs). The standalone UITabBar ignores this and falls back
  /// to the raw SF Symbol strings in [_symbols].
  List<Map<String, dynamic>?> get _iconConfigs =>
      widget.tabs.map((t) => t.icon?.toMap()).toList();

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
      if (idx != null && idx != _lastIndex && idx < widget.tabs.length) {
        _lastIndex = idx;
        widget.onChanged?.call(widget.tabs[idx].id);
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
            for (var i = 0; i < widget.tabs.length; i++)
              GestureDetector(
                onTap: () => widget.onChanged?.call(widget.tabs[i].id),
                child: Text(
                  widget.tabs[i].title,
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

    // SwiftUI's scroll-edge effect is bound to native scroll views, so a
    // standalone bar can't get it from the system. On iOS 26+ draw the
    // Flutter recreation behind the floating bar when the effect is
    // explicitly requested: it reaches above the bar and down through the
    // home-indicator area, melting Flutter content into the screen edge.
    if (isIOS26OrLater &&
        widget.scrollEdgeEffect != CupertinoScrollEdgeEffectStyle.automatic) {
      final bottomInset = MediaQuery.paddingOf(context).bottom;
      bar = Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: 0,
            right: 0,
            // Mirrors the top edge's rule — the effect fades out over one
            // bar height past the bar's own extent — so it tracks the tab
            // bar's real height (50 on iOS 26, or whatever `height` sets)
            // instead of a hardcoded 64.
            top: -h,
            // Down to the physical screen edge: the bar floats above the home
            // indicator, and the strip it leaves is part of the span, exactly
            // as the top effect starts at the notch / Dynamic Island inset
            // rather than under it.
            bottom: -bottomInset,
            // The three pieces of the effect share ONE rectangle, which is
            // this Positioned: the shader, the band of native pixels drawn
            // under it, and the rectangle published to the platform side must
            // agree on where the cut is or they draw a seam. Mirrors the app
            // bar's stack, `atTop` flipped.
            child: Stack(
              fit: StackFit.expand,
              children: [
                // Under the shader, so the shader can reach it: a backdrop
                // filter cannot touch a platform view, so a control that has
                // scrolled under the tab bar hands over a bitmap of its
                // covered band and is cut on the same line. Without this the
                // control comes back up crisp through the wash.
                const BarSnapshotSurface(),
                CupertinoScrollEdgeEffect(
                  edge: CupertinoScrollEdgeEffectEdge.bottom,
                  style: widget.scrollEdgeEffect,
                ),
                const CupertinoEdgeEffectCoverage(
                  atTop: false,
                  child: IgnorePointer(child: SizedBox.expand()),
                ),
              ],
            ),
          ),
          // The bar is chrome sitting ON the effect, not content passing
          // under it — and the native mask is geometric, so it cannot tell
          // the two apart. Exempt or it dissolves itself.
          CupertinoEdgeEffectExempt(child: bar),
        ],
      );
    }
    return bar;
  }
}
