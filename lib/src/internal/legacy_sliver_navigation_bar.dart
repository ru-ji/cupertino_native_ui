import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/foundation.dart' show defaultTargetPlatform;
import 'package:flutter/services.dart';

import '../cupertino_native_button.dart' show CupertinoNativeButton, ButtonLabel;
import '../cupertino_symbol_image.dart';

import 'package:flutter/rendering.dart'
    show OverScrollHeaderStretchConfiguration, PlatformViewHitTestBehavior;

/// Geometry of the iOS 15–18 navigation bar, in points, from Apple's iOS 18
/// UI kit (`Navigation Bar - iPhone (Compact Size Class)`, the `Default` and
/// `Large` styles) and cross-checked against Flutter's own
/// `CupertinoSliverNavigationBar`.
///
/// ```
/// status bar        safe-area top          (54 on a Dynamic Island phone)
/// bar row           44    leading · inline title · trailing
/// large title       52    3 above, 41 of text (34pt, line 41), 8 below
/// search row        52    1 above, 36 field, 15 below
/// ```
abstract final class LegacyBarMetrics {
  static const double barHeight = 44;
  static const double largeTitleHeight = 52;
  static const double searchRowHeight = 52;
  static const double searchFieldHeight = 36;
  static const double searchFieldTopGap = 1;
  static const double searchFieldBottomGap = 15;
  static const double searchFieldRadius = 10;

  /// Points of scroll before the large title is fully collapsed at which the
  /// inline title takes over. Flutter's `_kNavBarShowLargeTitleThreshold`.
  static const double showLargeTitleThreshold = 10;

  /// Points of scroll, once the bar has collapsed, over which the material and
  /// the hairline come in. Flutter's `_kNavBarScrollUnderAnimationExtent`,
  /// which it eyeballed on the system Settings app.
  static const double scrollUnderExtent = 10;

  /// How long the large title and the inline title take to trade places.
  static const Duration titleFade = Duration(milliseconds: 150);

  /// The search field's content stays opaque for the first few points it
  /// shrinks by, then fades out over the next few while the capsule keeps
  /// shrinking.
  static const double searchFadeStart = 5;
  static const double searchFadeEnd = 13;
}

/// The bar's glass: what `UINavigationBar` draws once content scrolls under it.
///
/// Light is Apple's `Materials/Chrome` from the iOS 18 UI kit: a 25 blur behind
/// a `rgba(255,255,255,0.75)` fill blended with `hard-light`, over a 0.333pt
/// `rgba(0,0,0,0.3)` bottom border. The kit only publishes the light values;
/// dark is measured off a screen recording of the Notes app on iOS 16 (a bar
/// of about `#262626` over black, its hairline about `#363636`) and is meant
/// to be tuned by eye.
@immutable
class LegacyBarMaterialStyle {
  const LegacyBarMaterialStyle({
    required this.blurSigma,
    required this.saturation,
    required this.tint,
    required this.blendMode,
    required this.border,
  });

  /// Gaussian standard deviation of the blur. Figma's 25 is a blur amount, whose
  /// standard deviation is half of it.
  final double blurSigma;

  /// Colour saturation applied to the blurred backdrop: the system material
  /// makes what passes behind it more vivid, as well as blurred.
  final double saturation;

  final Color tint;
  final BlendMode blendMode;
  final Color border;

  static const LegacyBarMaterialStyle light = LegacyBarMaterialStyle(
    blurSigma: 12.5,
    saturation: 1.8,
    tint: Color(0xBFFFFFFF),
    blendMode: BlendMode.hardLight,
    border: Color(0x4D000000),
  );

  static const LegacyBarMaterialStyle dark = LegacyBarMaterialStyle(
    blurSigma: 12.5,
    saturation: 1.8,
    tint: Color(0xBF333333),
    blendMode: BlendMode.srcOver,
    border: Color(0x59545458),
  );

  static LegacyBarMaterialStyle of(BuildContext context) =>
      CupertinoTheme.brightnessOf(context) == Brightness.dark ? dark : light;

  /// The backdrop filter: blur first, then saturate what it blurred.
  ui.ImageFilter get filter => ui.ImageFilter.compose(
    outer: ColorFilter.matrix(_saturationMatrix(saturation)),
    inner: ui.ImageFilter.blur(
      sigmaX: blurSigma,
      sigmaY: blurSigma,
      tileMode: TileMode.clamp,
    ),
  );

  // Luminance weights are Rec. 601's, as in the CSS `saturate()` filter.
  static List<double> _saturationMatrix(double s) => <double>[
    0.213 + 0.787 * s, 0.715 - 0.715 * s, 0.072 - 0.072 * s, 0, 0, //
    0.213 - 0.213 * s, 0.715 + 0.285 * s, 0.072 - 0.072 * s, 0, 0, //
    0.213 - 0.213 * s, 0.715 - 0.715 * s, 0.072 + 0.928 * s, 0, 0, //
    0, 0, 0, 1, 0,
  ];
}

/// The blurred, tinted fill behind the bar, fading in with [progress]
/// (0 = nothing, the page shows through; 1 = full material).
class LegacyBarMaterial extends StatelessWidget {
  const LegacyBarMaterial({super.key, required this.progress, this.style});

  final double progress;
  final LegacyBarMaterialStyle? style;

  @override
  Widget build(BuildContext context) {
    if (progress <= 0) return const SizedBox.shrink();
    // On iOS the material is native — see [_NativeBarMaterial].
    if (defaultTargetPlatform == TargetPlatform.iOS && style == null) {
      return _NativeBarMaterial(progress: progress);
    }
    final resolved = style ?? LegacyBarMaterialStyle.of(context);
    return Opacity(
      opacity: progress.clamp(0.0, 1.0),
      child: ClipRect(
        child: BackdropFilter(
          filter: resolved.filter,
          blendMode: resolved.blendMode,
          child: ColoredBox(
            color: resolved.tint,
            child: const SizedBox.expand(),
          ),
        ),
      ),
    );
  }
}

/// The system chrome blur and hairline as a platform view, so the blur samples
/// native content too. No Flutter opacity or clip around it: a composited clip
/// would cut the native views painted before it.
class _NativeBarMaterial extends StatefulWidget {
  const _NativeBarMaterial({required this.progress});

  final double progress;

  @override
  State<_NativeBarMaterial> createState() => _NativeBarMaterialState();
}

class _NativeBarMaterialState extends State<_NativeBarMaterial> {
  MethodChannel? _channel;

  Map<String, Object?> _params(bool isDark) => {
    'progress': widget.progress.clamp(0.0, 1.0),
    'isDark': isDark,
  };

  @override
  void didUpdateWidget(covariant _NativeBarMaterial old) {
    super.didUpdateWidget(old);
    _channel?.invokeMethod<void>(
      'update',
      _params(CupertinoTheme.brightnessOf(context) == Brightness.dark),
    );
  }

  @override
  Widget build(BuildContext context) {
    final params = _params(
      CupertinoTheme.brightnessOf(context) == Brightness.dark,
    );
    return IgnorePointer(
      child: UiKitView(
        viewType: 'com.example.cupertino_widgets/cupertino_native_bar_material',
        layoutDirection: TextDirection.ltr,
        creationParams: params,
        creationParamsCodec: const StandardMessageCodec(),
        hitTestBehavior: PlatformViewHitTestBehavior.transparent,
        onPlatformViewCreated: (id) =>
            _channel = MethodChannel('cupertino_widgets/bar_material_$id'),
      ),
    );
  }
}

/// The bar's bottom border: one device pixel, drawn *above* the material, so it
/// takes the colour of whatever the material is showing along its length.
class LegacyBarHairline extends StatelessWidget {
  const LegacyBarHairline({super.key, required this.progress, this.style});

  final double progress;
  final LegacyBarMaterialStyle? style;

  @override
  Widget build(BuildContext context) {
    // The native material draws its own hairline.
    if (progress <= 0 ||
        (defaultTargetPlatform == TargetPlatform.iOS && style == null)) {
      return const SizedBox.shrink();
    }
    final resolved = style ?? LegacyBarMaterialStyle.of(context);
    return Opacity(
      opacity: progress.clamp(0.0, 1.0),
      child: SizedBox(
        height: 1 / MediaQuery.devicePixelRatioOf(context),
        child: ColoredBox(
          color: resolved.border,
          child: const SizedBox.expand(),
        ),
      ),
    );
  }
}

/// A pinned, collapsing iOS 15–18 navigation bar for a [CustomScrollView].
///
/// Transparent while the page rests at its top; once content scrolls under it
/// it turns to the system's material — a blur, a tint and a hairline. The large
/// title collapses into a centred inline title and, in
/// [NavigationBarBottomMode.automatic], the search row goes first, squeezing and
/// fading before the page itself moves. A pull past the top stretches the
/// header, so the title and the search field follow it down.
class LegacySliverNavigationBar extends StatefulWidget {
  const LegacySliverNavigationBar({
    super.key,
    required this.largeTitle,
    this.middle,
    this.leading,
    this.automaticallyImplyLeading = true,
    this.previousPageTitle,
    this.trailing,
    this.searchField,
    this.bottomMode = NavigationBarBottomMode.automatic,
    this.materialStyle,
  });

  /// The large title, usually a [Text]. Also the inline title unless [middle]
  /// is given.
  final Widget largeTitle;

  /// The inline title, when it should differ from [largeTitle].
  final Widget? middle;

  /// Shown at the leading edge. Null draws the system back button when the
  /// route can pop and [automaticallyImplyLeading] allows it.
  final Widget? leading;
  final bool automaticallyImplyLeading;

  /// Label of the implied back button; by default the previous page's title.
  final String? previousPageTitle;

  final Widget? trailing;

  /// The field of the search row, [LegacyBarMetrics.searchFieldHeight] tall,
  /// with a transparent background: the bar draws the capsule itself.
  final Widget? searchField;

  /// Whether the search row collapses with the scroll (`automatic`) or stays
  /// pinned under the bar (`always`).
  final NavigationBarBottomMode bottomMode;

  /// Overrides the material, which otherwise follows the theme's brightness.
  final LegacyBarMaterialStyle? materialStyle;

  bool get _collapsibleSearch =>
      searchField != null && bottomMode == NavigationBarBottomMode.automatic;

  @override
  State<LegacySliverNavigationBar> createState() =>
      _LegacySliverNavigationBarState();
}

class _LegacySliverNavigationBarState extends State<LegacySliverNavigationBar> {
  ScrollableState? _scrollable;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _scrollable?.position.isScrollingNotifier.removeListener(_snap);
    _scrollable = Scrollable.maybeOf(context);
    _scrollable?.position.isScrollingNotifier.addListener(_snap);
  }

  @override
  void dispose() {
    _scrollable?.position.isScrollingNotifier.removeListener(_snap);
    super.dispose();
  }

  void _snap() {
    final position = _scrollable?.position;
    if (position == null || !position.hasPixels) return;
    // Not while a finger holds the page: see the iOS 26 bar's snap.
    // ignore: invalid_use_of_protected_member, invalid_use_of_visible_for_testing_member
    final held = position.activity is! IdleScrollActivity;
    if (position.isScrollingNotifier.value || held) return;
    final target = legacyBarSnapTarget(
      position.pixels,
      collapsibleSearch: widget._collapsibleSearch,
    );
    if (target == null || target > position.maxScrollExtent) return;
    position.animateTo(
      target,
      duration: const Duration(milliseconds: 300),
      curve: Curves.fastEaseInToSlowEaseOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return SliverPersistentHeader(
      pinned: true,
      delegate: _LegacyBarDelegate(
        widget: widget,
        topPadding: MediaQuery.paddingOf(context).top,
        margin: _barMargin(context),
        theme: CupertinoTheme.of(context),
      ),
    );
  }
}

/// Where a scroll that came to rest at [pixels] settles: the bar never rests
/// half collapsed, so the search row and then the large title snap to whichever
/// of their two edges is nearer. Null when [pixels] is already on one.
@visibleForTesting
double? legacyBarSnapTarget(double pixels, {required bool collapsibleSearch}) {
  final row = collapsibleSearch ? LegacyBarMetrics.searchRowHeight : 0.0;
  const large = LegacyBarMetrics.largeTitleHeight;
  if (row > 0 && pixels > 0 && pixels < row) {
    return pixels > row / 2 ? row : 0.0;
  }
  if (pixels > row && pixels < row + large) {
    return pixels > row + large / 2 ? row + large : row;
  }
  return null;
}

/// iOS's layout margin: 20pt on phones 414pt wide or more, 16pt otherwise.
double _barMargin(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 414 ? 20 : 16;

class _LegacyBarDelegate extends SliverPersistentHeaderDelegate {
  const _LegacyBarDelegate({
    required this.widget,
    required this.topPadding,
    required this.margin,
    required this.theme,
  });

  final LegacySliverNavigationBar widget;
  final double topPadding;
  final double margin;
  final CupertinoThemeData theme;

  bool get _hasSearch => widget.searchField != null;
  bool get _alwaysSearch =>
      _hasSearch && widget.bottomMode == NavigationBarBottomMode.always;

  @override
  double get maxExtent =>
      topPadding +
      LegacyBarMetrics.barHeight +
      LegacyBarMetrics.largeTitleHeight +
      (_hasSearch ? LegacyBarMetrics.searchRowHeight : 0);

  @override
  double get minExtent =>
      topPadding +
      LegacyBarMetrics.barHeight +
      (_alwaysSearch ? LegacyBarMetrics.searchRowHeight : 0);

  /// A pull past the top makes the header taller than [maxExtent]: its
  /// bottom-anchored content — the title and the search row — rides down with it.
  @override
  OverScrollHeaderStretchConfiguration? get stretchConfiguration =>
      OverScrollHeaderStretchConfiguration();

  @override
  bool shouldRebuild(_LegacyBarDelegate oldDelegate) => true;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // The box actually given, which a stretch makes taller than
    // `maxExtent - shrinkOffset`.
    return LayoutBuilder(
      builder: (context, constraints) => _build(
        context,
        shrinkOffset,
        constraints.hasBoundedHeight
            ? constraints.maxHeight
            : (maxExtent - shrinkOffset).clamp(minExtent, maxExtent),
      ),
    );
  }

  Widget _build(BuildContext context, double shrinkOffset, double height) {
    final collapseRange = maxExtent - minExtent;
    final showLargeTitle =
        shrinkOffset < collapseRange - LegacyBarMetrics.showLargeTitleThreshold;
    // The material and the hairline come in over the first points scrolled
    // once everything that can collapse has.
    final scrolledUnder =
        ((shrinkOffset - collapseRange) / LegacyBarMetrics.scrollUnderExtent)
            .clamp(0.0, 1.0);

    // The search row goes first: the scroll consumes it before the title.
    final consumed = widget._collapsibleSearch
        ? shrinkOffset.clamp(0.0, LegacyBarMetrics.searchRowHeight)
        : 0.0;
    final rowHeight = !_hasSearch
        ? 0.0
        : _alwaysSearch
        ? LegacyBarMetrics.searchRowHeight
        : LegacyBarMetrics.searchRowHeight - consumed;

    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        Positioned.fill(
          child: LegacyBarMaterial(
            progress: scrolledUnder,
            style: widget.materialStyle,
          ),
        ),
        _largeTitle(rowHeight, showLargeTitle),
        if (_hasSearch) _searchField(context, height, consumed),
        _barRow(context, showLargeTitle),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: LegacyBarHairline(
            progress: scrolledUnder,
            style: widget.materialStyle,
          ),
        ),
      ],
    );
  }

  /// The large title, bottom-anchored above the search row and clipped at the
  /// bar row's lower edge, so it slides up under the bar as the header shrinks.
  Widget _largeTitle(double rowHeight, bool show) {
    return Positioned(
      top: topPadding + LegacyBarMetrics.barHeight,
      left: 0,
      right: 0,
      bottom: 0,
      child: ClipRect(
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: margin,
              right: margin,
              bottom: rowHeight,
              height: LegacyBarMetrics.largeTitleHeight,
              child: AnimatedOpacity(
                opacity: show ? 1.0 : 0.0,
                duration: LegacyBarMetrics.titleFade,
                child: Padding(
                  padding: const EdgeInsets.only(top: 3, bottom: 8),
                  child: Align(
                    alignment: AlignmentDirectional.bottomStart,
                    child: Semantics(
                      header: true,
                      child: DefaultTextStyle(
                        style: theme.textTheme.navLargeTitleTextStyle.copyWith(
                          height: 41 / 34,
                          decoration: TextDecoration.none,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        child: widget.largeTitle,
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The search field. Its row's padding absorbs the first points of scroll,
  /// then the capsule squeezes while its content fades.
  Widget _searchField(BuildContext context, double height, double consumed) {
    const bottomGap = LegacyBarMetrics.searchFieldBottomGap;
    const fieldHeight = LegacyBarMetrics.searchFieldHeight;
    final squeeze = (consumed - bottomGap).clamp(0.0, fieldHeight);
    final fieldH = (fieldHeight - squeeze).clamp(0.1, fieldHeight);
    final inset = bottomGap - consumed.clamp(0.0, bottomGap);
    final fade =
        1 -
        ((squeeze - LegacyBarMetrics.searchFadeStart) /
                (LegacyBarMetrics.searchFadeEnd -
                    LegacyBarMetrics.searchFadeStart))
            .clamp(0.0, 1.0);
    return Positioned(
      left: margin,
      right: margin,
      bottom: inset,
      height: fieldH,
      // The capsule is drawn here and keeps shrinking to nothing; only the
      // field's content (hint, icons) fades, so the field passed in must have a
      // transparent background.
      child: ClipRRect(
        borderRadius: BorderRadius.circular(LegacyBarMetrics.searchFieldRadius),
        child: ColoredBox(
          color: CupertinoColors.tertiarySystemFill.resolveFrom(context),
          child: IgnorePointer(
            ignoring: fade < 1,
            child: Opacity(
              opacity: fade,
              child: OverflowBox(
                minHeight: 0,
                maxHeight: fieldHeight,
                alignment: Alignment.center,
                child: SizedBox(height: fieldHeight, child: widget.searchField),
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _barRow(BuildContext context, bool showLargeTitle) {
    final route = ModalRoute.of(context);
    // Insets from Apple's iOS 18 kit: leading 8, trailing 16. Buttons in
    // either slot hug their glyph (see [LegacyBarSlot]).
    Widget? leading = widget.leading;
    // A bare chevron button is the iOS 26 way to write a back button. Below
    // 26 the system draws the chevron and the previous page's title (the
    // kit's `Controls Leading`), so it is swapped for that one.
    if (leading is CupertinoNativeButton &&
        ButtonLabel(leading.child).iconOnly &&
        ButtonLabel(leading.child).icon?.sfSymbol == 'chevron.backward') {
      leading = null;
    }
    if (leading == null &&
        widget.automaticallyImplyLeading &&
        (route?.canPop ?? false)) {
      leading = _BackButton(
        title:
            widget.previousPageTitle ??
            (route is CupertinoRouteTransitionMixin
                ? route.previousTitle.value
                : null),
      );
    }
    if (leading != null) {
      leading = LegacyBarSlot(
        child: Padding(
          padding: const EdgeInsetsDirectional.only(start: 8),
          child: leading,
        ),
      );
    }
    final trailing = widget.trailing == null
        ? null
        : LegacyBarSlot(
            child: Padding(
              padding: const EdgeInsetsDirectional.only(end: 16),
              child: widget.trailing,
            ),
          );
    return Positioned(
      top: topPadding,
      left: 0,
      right: 0,
      height: LegacyBarMetrics.barHeight,
      child: Stack(
        alignment: Alignment.center,
        clipBehavior: Clip.none,
        children: [
          if (leading != null)
            Align(alignment: AlignmentDirectional.centerStart, child: leading),
          if (trailing != null)
            Align(alignment: AlignmentDirectional.centerEnd, child: trailing),
          AnimatedOpacity(
            opacity: showLargeTitle ? 0.0 : 1.0,
            duration: LegacyBarMetrics.titleFade,
            child: Semantics(
              header: true,
              child: DefaultTextStyle(
                style: theme.textTheme.navTitleTextStyle.copyWith(
                  decoration: TextDecoration.none,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                child: widget.middle ?? widget.largeTitle,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Marks the iOS 15–18 bar's leading and trailing slots. An icon-only
/// [CupertinoNativeButton] inside one hugs its glyph, as a `UIBarButtonItem`
/// does, instead of centring it in a 44pt square that would push it off the
/// bar's 8pt / 16pt insets.
class LegacyBarSlot extends InheritedWidget {
  const LegacyBarSlot({super.key, required super.child});

  static bool isIn(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<LegacyBarSlot>() != null;

  @override
  bool updateShouldNotify(LegacyBarSlot oldWidget) => false;
}

/// The system back button from the iOS 18 kit: the native `chevron.backward`
/// in a 17×22 box, 6pt, then the previous title.
class _BackButton extends StatelessWidget {
  const _BackButton({this.title});

  final String? title;

  @override
  Widget build(BuildContext context) {
    final color = CupertinoTheme.of(context).primaryColor;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: () => Navigator.maybePop(context),
      child: SizedBox(
        height: LegacyBarMetrics.barHeight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          spacing: 6,
          children: [
            SizedBox(
              width: 17,
              height: 22,
              child: Center(
                child: CupertinoSymbolImage(
                  'chevron.backward',
                  size: 17,
                  // Large: UIKit's back indicator, measured 11×18.4pt on an
                  // iPhone 8 Plus.
                  scale: CupertinoSymbolScale.large,
                  weight: FontWeight.w600,
                  color: color,
                ),
              ),
            ),
            if (title != null)
              Text(
                title!,
                style: TextStyle(
                  fontSize: 17,
                  letterSpacing: -0.43,
                  color: color,
                ),
              ),
          ],
        ),
      ),
    );
  }
}
