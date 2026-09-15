import 'dart:ui' as ui;

import 'package:flutter/cupertino.dart';
import 'package:flutter/rendering.dart'
    show OverScrollHeaderStretchConfiguration;

import 'cupertino_native_button.dart';
import 'models/cupertino_native_button_style.dart';
import 'models/cupertino_native_button_extra_options.dart';
import 'cupertino_native_glass_container.dart';
import 'cupertino_native_tab_bar.dart' show CupertinoScrollEdgeEffectStyle;
import 'cupertino_native_text_field.dart';
import 'cupertino_scroll_edge_effect.dart';
import 'cupertino_symbol_image.dart';
import 'internal/ios_version.dart';
import 'models/cupertino_native_icon.dart';
import 'models/cupertino_symbols.dart';
import 'search_row_visibility.dart';

export 'search_row_visibility.dart' show CupertinoSearchRowVisibility;

/// An iOS 26-style navigation bar drawn in Flutter.
///
/// SwiftUI's navigation title can't be hosted standalone in Flutter, so these
/// widgets recreate the iOS 26 look: no solid background or hairline — the
/// bar floats on a [CupertinoScrollEdgeEffect]; the large title collapses
/// with the system blur-morph; [leading]/[trailing] take any widget — a
/// `.glass` [CupertinoNativeButton] is the iOS 26 bar button, but a [Text] or
/// anything else works; the title sits centered ([centerTitle], the
/// default) or right after [leading], with an optional [subtitle].
///
/// The default constructor takes an optional [bottom] widget under the large
/// title that stays visible when scrolling. [CupertinoNativeSliverNavigationBar.search]
/// builds the search bar itself (a `CupertinoNativeTextField` configured with
/// [searchPlaceholder]/[searchStyle]/[searchPrefixIcon]/[searchSuffixIcon],
/// filled by default and glass via [searchGlass]): tapping it morphs the field to the top with a glass
/// ✕, and [bottomMode] — only available there — decides whether the row
/// collapses with the scroll ([NavigationBarBottomMode.automatic], the
/// default: consumed *before* the page starts scrolling, shrinking while its
/// content fades) or stays visible ([NavigationBarBottomMode.always]).
///
/// Below iOS 26 it falls back to Flutter's [CupertinoSliverNavigationBar]
/// (its `.search` variant with a [CupertinoSearchTextField] for the search
/// constructor), ignoring the iOS 26-only styling.
class CupertinoNativeSliverNavigationBar extends StatefulWidget {
  const CupertinoNativeSliverNavigationBar({
    super.key,
    required this.largeTitle,
    this.subtitle,
    this.centerTitle = true,
    this.expandedTitle = true,
    this.collapseTitle = true,
    this.leading,
    this.trailing = const [],
    this.bottom,
    this.bottomHeight = 44,
    this.scrollEdgeEffect = CupertinoScrollEdgeEffectStyle.soft,
    this.tintColor,
  }) : searchPlaceholder = null,
       searchStyle = null,
       searchPrefixIcon = null,
       searchSuffixIcon = null,
       searchGlass = false,
       scrollToTopOnSearch = true,
       bottomMode = NavigationBarBottomMode.always,
       onSearchChanged = null,
       onSearchActiveChanged = null,
       _searchable = false;

  /// A bar whose bottom row is a built-in search bar — the system's filled
  /// capsule, backed by a native `UITextField` (pass [searchGlass] for the
  /// Liquid Glass variant). Focus, the top-dock morph and the glass ✕ are
  /// managed internally; listen to [onSearchChanged] for the
  /// query and [onSearchActiveChanged] to swap the page content.
  const CupertinoNativeSliverNavigationBar.search({
    super.key,
    required this.largeTitle,
    this.subtitle,
    this.centerTitle = true,
    this.expandedTitle = true,
    this.collapseTitle = true,
    this.leading,
    this.trailing = const [],
    this.searchPlaceholder,
    this.searchStyle,
    this.searchPrefixIcon,
    this.searchSuffixIcon,
    this.searchGlass = false,
    this.scrollToTopOnSearch = true,
    double searchFieldHeight = 44,
    this.bottomMode = NavigationBarBottomMode.automatic,
    this.onSearchChanged,
    this.onSearchActiveChanged,
    this.scrollEdgeEffect = CupertinoScrollEdgeEffectStyle.soft,
    this.tintColor,
  }) : bottom = null,
       bottomHeight = searchFieldHeight,
       _searchable = true;

  final String largeTitle;

  /// Whether the expanded (large) title row exists. When false the bar is
  /// inline-only: the title is always in the bar and nothing collapses.
  final bool expandedTitle;

  /// Whether the large title collapses into the bar on scroll. False keeps it
  /// expanded for good — the header never shrinks and no inline title appears,
  /// like the iOS apps whose title stays large — while the scroll edge effect
  /// still comes up at the point the collapse would have fired. iOS 26+ only;
  /// the pre-26 fallback bar always collapses.
  final bool collapseTitle;

  /// Secondary line — under the large title (like Photos' "3,356 Items") and
  /// under the inline title when collapsed.
  final String? subtitle;

  /// Whether the inline title (and subtitle) sits centered in the bar
  /// (true, the default) or right after [leading].
  final bool centerTitle;

  /// Leading bar content — any widget, e.g. a `CupertinoNativeButton.glass`.
  final Widget? leading;

  /// Trailing bar content, laid out in a row with 10pt between entries. Group
  /// several into one glass capsule by passing a single
  /// [CupertinoNativeGlassContainer] holding them.
  final List<Widget> trailing;

  /// Widget under the large title (default constructor only). Unlike the
  /// search row, it is **always visible** — when scrolling, the large title
  /// collapses but the bottom stays pinned, like
  /// [NavigationBarBottomMode.always].
  final Widget? bottom;

  /// Height of the [bottom] slot — or of the built-in search field for
  /// [CupertinoNativeSliverNavigationBar.search] (where it's named `searchFieldHeight`).
  /// Defaults to 44 — the iOS 26 glass capsule (same height as the system
  /// bar buttons).
  final double bottomHeight;

  /// Placeholder ("hint") text of the built-in search field.
  final String? searchPlaceholder;

  /// Text style of the built-in search field (`fontSize`, `fontWeight` and
  /// `color` are forwarded natively).
  final TextStyle? searchStyle;

  /// Leading SF Symbol inside the built-in search field. Defaults to the
  /// system magnifying glass.
  final CupertinoNativeIcon? searchPrefixIcon;

  /// Trailing SF Symbol inside the built-in search field.
  final CupertinoNativeIcon? searchSuffixIcon;

  /// Whether opening the search scrolls the page to the top (cancelling
  /// restores the offset). Set false when the search filters content in place.
  final bool scrollToTopOnSearch;

  /// Whether the built-in search field rests on Liquid Glass. False (the
  /// default) rests it on the system's plain filled capsule.
  ///
  /// Either way, on iOS 26 the field turns to glass while the search is open,
  /// and — with [NavigationBarBottomMode.always] — as soon as the title
  /// collapses and the row starts floating over content, like the system's.
  final bool searchGlass;

  /// Whether the search row collapses with the scroll (`automatic`) or stays
  /// visible (`always`). Only settable on [CupertinoNativeSliverNavigationBar.search]; the
  /// default constructor's [bottom] always behaves as `always`.
  final NavigationBarBottomMode bottomMode;

  /// Fires on every keystroke in the built-in search field.
  final ValueChanged<String>? onSearchChanged;

  /// Fires when the search activates/deactivates, so the page can swap its
  /// content for a search view. Focus is managed internally.
  final ValueChanged<bool>? onSearchActiveChanged;

  /// True for [CupertinoNativeSliverNavigationBar.search].
  final bool _searchable;

  final CupertinoScrollEdgeEffectStyle scrollEdgeEffect;

  /// Tint of the edge effect. Defaults to the system background.
  final Color? tintColor;

  @override
  State<CupertinoNativeSliverNavigationBar> createState() =>
      _CupertinoSliverAppBarState();
}

class _CupertinoSliverAppBarState
    extends State<CupertinoNativeSliverNavigationBar>
    with TickerProviderStateMixin {
  // 380ms ease-in-out, like the system search morph.
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 380),
  );

  /// The morph progress every piece of the bar's geometry is driven by.
  late final CurvedAnimation _searchT = CurvedAnimation(
    parent: _controller,
    curve: Curves.easeInOut,
    reverseCurve: Curves.easeInOut.flipped,
  );

  /// The large-title → inline-title collapse. Unlike the header's height
  /// (which a sliver ties to the scroll), this is *triggered*, not scrubbed:
  /// crossing [_collapseTrigger] starts it and it runs to the end on its own
  /// clock, whether the scroll continues, stops, or is lifted. Crossing back
  /// the other way while it is still running reverses it from wherever it
  /// got to — [AnimationController.forward]/[reverse] do exactly that.
  /// 400ms on [Curves.ease], like the system title collapse.
  late final AnimationController _titleCollapse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 400),
  );

  late final CurvedAnimation _titleT = CurvedAnimation(
    parent: _titleCollapse,
    curve: Curves.ease,
    // Flipped, so coming back decelerates the same way going did.
    reverseCurve: Curves.ease.flipped,
  );

  /// Which side of [_collapseTrigger] the scroll was on last tick.
  bool _collapsed = false;

  /// True from the instant the open animation starts until the instant the
  /// close animation starts — the window in which the framework hides the
  /// bar chrome (leading/trailing/title) outright, not gradually.
  bool _searchActive = false;
  ScrollableState? _scrollableState;

  /// Search-row visibility (1 → 0 as the scroll consumes it), published to
  /// the hosted field via [CupertinoSearchRowVisibility] so native fields can
  /// fade their content natively. Updated from the delegate's build.
  final ValueNotifier<double> _searchRowVisibility = ValueNotifier<double>(1);

  /// What the edge effect's adaptive wash reports behind the bar; the inline
  /// title follows it. Null until the first measurement.
  Brightness? _effectBehind;

  /// Focus of the built-in search field — driven by the morph (focused on
  /// open, unfocused on close).
  final FocusNode _searchFocusNode = FocusNode(
    debugLabel: 'CupertinoNativeSliverNavigationBar.search',
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _detachScrollListeners();
    _scrollableState = Scrollable.maybeOf(context);
    _scrollableState?.position.isScrollingNotifier.addListener(
      _handleScrollChange,
    );
    _scrollableState?.position.addListener(_handleScrollTick);
    // Adopt the current scroll instead of animating into it — but never
    // mid-flight, nor during the search (the keyboard's inset change would
    // read as expanded).
    if (!_titleCollapse.isAnimating && !_searchMorphing) {
      _collapsed = _isPastTrigger;
      _titleCollapse.value = _collapsed ? 1.0 : 0.0;
    }
  }

  void _detachScrollListeners() {
    _scrollableState?.position.isScrollingNotifier.removeListener(
      _handleScrollChange,
    );
    _scrollableState?.position.removeListener(_handleScrollTick);
  }

  @override
  void dispose() {
    _detachScrollListeners();
    _searchRowVisibility.dispose();
    _searchFocusNode.dispose();
    _searchT.dispose();
    _controller.dispose();
    _titleT.dispose();
    _titleCollapse.dispose();
    super.dispose();
  }

  /// Scroll offset at which the collapse fires. The middle of the large-title
  /// region — the same point the snap below resolves towards, so a light
  /// scroll can still peek at the title instead of collapsing it outright —
  /// plus [_triggerSlack], so it takes that much more travel to fire.
  double get _collapseTrigger =>
      _bottomScrollOffset + _largeTitleHeight / 2 + _triggerSlack;

  /// Extra travel past the halfway point before the collapse fires.
  static const double _triggerSlack = 19;

  double get _bottomScrollOffset =>
      widget._searchable &&
          widget.bottomMode == NavigationBarBottomMode.automatic
      ? _IOS26SliverAppBarDelegate._searchRowHeight(widget.bottomHeight)
      : 0.0;

  double get _largeTitleHeight => _IOS26SliverAppBarDelegate._largeTitleH(
    expandedTitle: widget.expandedTitle,
    hasSubtitle: widget.subtitle != null,
  );

  bool get _isPastTrigger {
    final position = _scrollableState?.position;
    if (position == null || !position.hasPixels) return false;
    return position.pixels > _collapseTrigger;
  }

  /// True while the search morph moves the page's scroll (to the top on
  /// open, back on cancel). The collapse state is frozen meanwhile.
  bool get _searchMorphing => _searchActive || _controller.value > 0;

  void _handleScrollTick() {
    if (_searchMorphing) return;
    final past = _isPastTrigger;
    if (past != _collapsed) {
      // setState, not a bare assignment: the search field is built in this
      // State's build (outside the header's AnimatedBuilder), and whether it
      // is glass reads [_collapsed].
      if (mounted) {
        setState(() => _collapsed = past);
      } else {
        _collapsed = past;
      }
      past ? _titleCollapse.forward() : _titleCollapse.reverse();
    }
  }

  /// iOS snap, mirroring CupertinoSliverNavigationBar's _handleScrollChange:
  /// when the scroll settles inside the search-row region (bottomMode
  /// .automatic) or the large-title region, animate the scroll position to
  /// the nearest edge so the bar never rests half-collapsed.
  void _handleScrollChange() {
    // Below iOS 26 the fallback CupertinoSliverNavigationBar snaps itself.
    if (!isIOS26OrLater) return;
    final ScrollPosition? position = _scrollableState?.position;
    if (position == null || !position.hasPixels || position.pixels <= 0.0) {
      return;
    }
    // During the search morph the header extents are driven by _controller,
    // and the active search view should scroll freely.
    if (_controller.value > 0.0) return;

    final double bottomScrollOffset = _bottomScrollOffset;
    final double largeTitleHeight = _largeTitleHeight;

    double? target;
    if (bottomScrollOffset > 0.0 && position.pixels < bottomScrollOffset) {
      // Shifted by the dead zone: collapsing fully requires that much more
      // travel, so a light scroll settles back to the expanded state.
      target =
          position.pixels >
              bottomScrollOffset / 2 +
                  _IOS26SliverAppBarDelegate._collapseDeadZone
          ? bottomScrollOffset
          : 0.0;
    } else if (widget.collapseTitle &&
        position.pixels > bottomScrollOffset &&
        position.pixels < bottomScrollOffset + largeTitleHeight) {
      target = position.pixels > bottomScrollOffset + largeTitleHeight / 2
          ? bottomScrollOffset + largeTitleHeight
          : bottomScrollOffset;
    }

    if (target != null && target <= position.maxScrollExtent) {
      position.animateTo(
        target,
        duration: const Duration(milliseconds: 300),
        curve: Curves.fastEaseInToSlowEaseOut,
      );
    }
  }

  /// Where the page was before the search opened, to put it back on cancel.
  double? _offsetBeforeSearch;

  /// Puts the page back at [target] once the page's own content is back.
  ///
  /// Not on this frame: closing the search hands the app back its list through
  /// [onSearchActiveChanged], and until that content is laid out the position's
  /// maxScrollExtent is still the search view's — usually much shorter — so an
  /// immediate jump lands clamped at the top, which reads as the page having
  /// been reset.
  void _restoreOffsetAfterLayout(double target) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      final position = _scrollableState?.position;
      if (!mounted || position == null || !position.hasPixels) return;
      final clamped = target.clamp(
        position.minScrollExtent,
        position.maxScrollExtent,
      );
      if (position.pixels != clamped) position.jumpTo(clamped);
    });
  }

  void _setSearchActive(bool active) {
    setState(() => _searchActive = active);
    // The search view is its own thing: it opens at the top rather than
    // inheriting however far the page underneath happened to be scrolled
    // (which shows up as suggestions that start mid-list). Cancelling puts
    // the page back where it was.
    final position = _scrollableState?.position;
    if (widget.scrollToTopOnSearch && position != null && position.hasPixels) {
      if (active) {
        _offsetBeforeSearch = position.pixels;
        if (position.pixels != 0) position.jumpTo(0);
      } else {
        final restore = _offsetBeforeSearch;
        _offsetBeforeSearch = null;
        if (restore != null) _restoreOffsetAfterLayout(restore);
      }
    }
    if (active) {
      _controller.forward();
      // Next frame, not this one: until the rebuild lands the field still sits
      // under the slot's AbsorbPointer, and a native UITextField whose view is
      // not live refuses first responder — the keyboard simply never comes up.
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted && _searchActive) _searchFocusNode.requestFocus();
      });
    } else {
      _controller.reverse();
      _searchFocusNode.unfocus();
    }
    widget.onSearchActiveChanged?.call(active);
  }

  @override
  Widget build(BuildContext context) {
    if (!isIOS26OrLater) {
      final trailingRow = widget.trailing.isEmpty
          ? null
          : Row(mainAxisSize: MainAxisSize.min, children: widget.trailing);
      if (widget._searchable) {
        // Pre-iOS 26 look: Flutter's own search bar; the iOS 26-only glass
        // icon properties don't apply here and are ignored.
        return CupertinoSliverNavigationBar.search(
          searchField: CupertinoSearchTextField(
            placeholder: widget.searchPlaceholder,
            style: widget.searchStyle,
            onChanged: widget.onSearchChanged,
          ),
          bottomMode: widget.bottomMode,
          largeTitle: Text(widget.largeTitle),
          leading: widget.leading,
          trailing: trailingRow,
        );
      }
      return CupertinoSliverNavigationBar(
        largeTitle: Text(widget.largeTitle),
        leading: widget.leading,
        trailing: trailingRow,
        bottom: widget.bottom == null
            ? null
            : PreferredSize(
                preferredSize: Size.fromHeight(widget.bottomHeight),
                child: widget.bottom!,
              ),
        bottomMode: widget.bottom == null
            ? null
            : NavigationBarBottomMode.always,
      );
    }
    final theme = CupertinoTheme.of(context);
    final leading = widget.leading;
    final trailing = widget.trailing.isEmpty
        ? null
        : Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 10,
            children: widget.trailing,
          );
    final closeButton = !widget._searchable
        ? null
        : CupertinoNativeButton.glass(
            borderShape: CupertinoNativeButtonBorderShape.circle,
            sizeStyle: CupertinoNativeControlSize.large,
            onPressed: () => _setSearchActive(false),
            child: CupertinoSymbolImage.symbol(
              CupertinoSymbols.xmark,
              size: 16,
            ),
          );
    // The bottom slot. The field turns to glass while the search is open
    // and, in `always` mode, once the title has collapsed.
    final glassy =
        isIOS26OrLater &&
        (widget.searchGlass ||
            _searchActive ||
            _controller.value > 0 ||
            (widget.bottomMode == NavigationBarBottomMode.always &&
                _collapsed));
    final Widget? bottomSlot = widget._searchable
        ? CupertinoNativeTextField(
            placeholder: widget.searchPlaceholder,
            style: widget.searchStyle,
            glass: glassy
                ? CupertinoGlass(cornerRadius: widget.bottomHeight / 2)
                : null,
            backgroundColor: glassy
                ? null
                : CupertinoColors.tertiarySystemFill.resolveFrom(context),
            cornerRadius: widget.bottomHeight / 2,
            height: widget.bottomHeight,
            // The capsule adopts the slot's height, so it physically
            // squeezes with the collapse instead of being clipped.
            fillHeight: true,
            focusNode: _searchFocusNode,
            textInputAction: TextInputAction.search,
            prefix:
                widget.searchPrefixIcon ??
                CupertinoNativeIcon.symbol(
                  CupertinoSymbols.magnifyingglass,
                  size: 20,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
            suffix: widget.searchSuffixIcon,
            clearButtonMode: OverlayVisibilityMode.editing,
            onChanged: widget.onSearchChanged,
          )
        : widget.bottom;

    // The inline title follows the edge effect's wash: white over its dark
    // levels, like the system's bar items, on the wash's own ~0.5s.
    final secondaryLabel = CupertinoColors.secondaryLabel.resolveFrom(context);
    return TweenAnimationBuilder<double>(
      tween: Tween(end: _effectBehind == Brightness.dark ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, washT, _) => AnimatedBuilder(
        animation: Listenable.merge([_searchT, _titleT]),
        builder: (context, _) => SliverPersistentHeader(
          pinned: true,
          delegate: _IOS26SliverAppBarDelegate(
            largeTitle: widget.largeTitle,
            subtitle: widget.subtitle,
            centerTitle: widget.centerTitle,
            expandedTitle: widget.expandedTitle,
            collapseTitle: widget.collapseTitle,
            leading: leading,
            trailing: trailing,
            searchField: bottomSlot,
            searchable: widget._searchable,
            fieldHeight: widget.bottomHeight,
            bottomMode: widget.bottomMode,
            closeButton: closeButton,
            edgeEffect: RepaintBoundary(
              child: CupertinoScrollEdgeEffect(
                edge: CupertinoScrollEdgeEffectEdge.top,
                style: widget.scrollEdgeEffect,
                color: widget.tintColor,
                intensity: _titleT.value,
                onBrightnessChanged: (behind) {
                  if (mounted && behind != _effectBehind) {
                    setState(() => _effectBehind = behind);
                  }
                },
              ),
            ),
            searchRowVisibility: _searchRowVisibility,
            searchT: _searchT.value,
            titleT: widget.collapseTitle ? _titleT.value : 0.0,
            searchActive: _searchActive,
            morphing: _controller.isAnimating,
            onSearchOpen: () => _setSearchActive(true),
            topPadding: MediaQuery.paddingOf(context).top,
            // Native Flutter Cupertino nav bar text styles.
            inlineTitleStyle: theme.textTheme.navTitleTextStyle.copyWith(
              decoration: TextDecoration.none,
              color: Color.lerp(
                theme.textTheme.navTitleTextStyle.color,
                CupertinoColors.white,
                washT,
              ),
            ),
            largeTitleStyle: theme.textTheme.navLargeTitleTextStyle.copyWith(
              decoration: TextDecoration.none,
            ),
            subtitleStyle: theme.textTheme.tabLabelTextStyle.copyWith(
              fontSize: 13,
              decoration: TextDecoration.none,
              color: secondaryLabel,
            ),
            inlineSubtitleColor: Color.lerp(
              secondaryLabel,
              const Color(0x99FFFFFF),
              washT,
            )!,
          ),
        ),
      ),
    );
  }
}

class _IOS26SliverAppBarDelegate extends SliverPersistentHeaderDelegate {
  const _IOS26SliverAppBarDelegate({
    required this.largeTitle,
    required this.subtitle,
    required this.centerTitle,
    required this.expandedTitle,
    required this.collapseTitle,
    required this.leading,
    required this.trailing,
    required this.searchField,
    required this.searchable,
    required this.fieldHeight,
    required this.bottomMode,
    required this.closeButton,
    required this.edgeEffect,
    required this.searchRowVisibility,
    required this.searchT,
    required this.titleT,
    required this.searchActive,
    required this.morphing,
    required this.onSearchOpen,
    required this.topPadding,
    required this.inlineTitleStyle,
    required this.largeTitleStyle,
    required this.subtitleStyle,
    required this.inlineSubtitleColor,
  });

  // Geometry mirrors Flutter's CupertinoSliverNavigationBar
  // (_kNavBarLargeTitleHeightExtension = 52, _kNavBarBottomPadding = 8),
  // except the search field height, which is configurable and defaults to the
  // iOS 26 44pt capsule instead of Flutter's 36.
  static const double _barH = 44;
  static const double _largeExtension = 59;
  static const double _bottomPadding = 8;

  // The native search bar's fade window, in points of *height reduction*:
  // the hint text and prefix/suffix icons stay fully opaque for the first
  // 5pt of squeeze, then fade to nothing by 13pt — while the capsule itself
  // keeps shrinking, tracking the scroll (and the snap) proportionally.
  static const double _fadeStartShrink = 5;
  static const double _fadeEndShrink = 13;

  // Scroll dead zone before the capsule starts squeezing: the first points
  // of a scroll are absorbed by the row's padding, so a light scroll doesn't
  // instantly deform the search bar.
  static const double _collapseDeadZone = 10;

  /// How far below the header the edge effect keeps fading.
  static const double _effectOverhang = 44;

  /// The search row: the field, 14pt above it and the bottom padding.
  static double _searchRowHeight(double fieldHeight) =>
      fieldHeight + _bottomPadding + _searchRowTopGap;

  static const double _searchRowTopGap = 14;

  final String largeTitle;
  final String? subtitle;
  final bool centerTitle;
  final bool expandedTitle;
  final bool collapseTitle;
  final Widget? leading;
  final Widget? trailing;

  /// The bottom-slot widget: the built-in search field (permanently mounted —
  /// platform views must never be created mid-animation) or the user's
  /// always-visible `bottom`.
  final Widget? searchField;

  /// Whether [searchField] is the built-in search bar (tap-to-morph, glass ✕)
  /// rather than a plain always-visible bottom widget.
  final bool searchable;

  /// Height of the bottom slot (see [CupertinoNativeSliverNavigationBar.bottomHeight]).
  final double fieldHeight;
  final NavigationBarBottomMode bottomMode;
  final Widget? closeButton;
  final Widget edgeEffect;

  /// Published search-row visibility, driven from [build] as the scroll
  /// consumes the row — native fields fade their content from it.
  final ValueNotifier<double> searchRowVisibility;

  /// 0 = resting, 1 = search active (field docked at the top). Linear —
  /// straight off the controller, like the framework's height tweens.
  final double searchT;

  /// Collapse progress, 0 (large title) → 1 (inline title). Driven by the
  /// state's trigger animation, NOT by [shrinkOffset]: the fade runs to
  /// completion once fired, instead of being scrubbed by the finger.
  final double titleT;

  /// True from open-animation start until close-animation start. The
  /// framework hides leading/trailing outright in this window (no fade).
  final bool searchActive;

  /// True while the morph is running (either direction). The framework
  /// additionally blanks the inline title during this window.
  final bool morphing;

  final VoidCallback onSearchOpen;

  final double topPadding;
  final TextStyle inlineTitleStyle;
  final TextStyle largeTitleStyle;
  final TextStyle subtitleStyle;

  /// The inline subtitle's color, following the edge wash like the title.
  final Color inlineSubtitleColor;

  bool get _hasSearch => searchField != null;
  bool get _collapsibleSearch =>
      _hasSearch && bottomMode == NavigationBarBottomMode.automatic;
  double get _searchRowH => _searchRowHeight(fieldHeight);
  double get _largeH =>
      _largeTitleH(expandedTitle: expandedTitle, hasSubtitle: subtitle != null);

  static double _largeTitleH({
    required bool expandedTitle,
    required bool hasSubtitle,
  }) => !expandedTitle
      ? 0
      : (hasSubtitle ? _largeExtension + 20 : _largeExtension);

  double get _restingMax =>
      topPadding + _barH + _largeH + (_hasSearch ? _searchRowH : 0);
  double get _restingMin => !collapseTitle
      // Nothing collapses: the header keeps its full height and the content
      // scrolls under it.
      ? _restingMax
      : topPadding +
            _barH +
            (_hasSearch && bottomMode == NavigationBarBottomMode.always
                ? _searchRowH
                : 0);
  double get _activeExtent => topPadding + fieldHeight + 12;

  @override
  double get minExtent => ui.lerpDouble(_restingMin, _activeExtent, searchT)!;

  @override
  double get maxExtent {
    final value = ui.lerpDouble(_restingMax, _activeExtent, searchT)!;
    return value < minExtent ? minExtent : value;
  }

  /// Lets the header grow with an over-scroll, so the title and the search
  /// row follow a pull-down like in a SwiftUI `NavigationStack`.
  @override
  // No stretch once the search opens: the header is pinned at a fixed
  // extent, and a stretch would drag the bottom-anchored field down with it.
  OverScrollHeaderStretchConfiguration? get stretchConfiguration =>
      searchT > 0 ? null : _stretchConfiguration;

  static final OverScrollHeaderStretchConfiguration _stretchConfiguration =
      OverScrollHeaderStretchConfiguration();

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    // The real box: a stretch makes it taller than `maxExtent - shrink`.
    return LayoutBuilder(
      builder: (context, constraints) =>
          _build(context, shrinkOffset, constraints.maxHeight),
    );
  }

  Widget _build(BuildContext context, double shrinkOffset, double boxHeight) {
    final height = boxHeight.isFinite
        ? boxHeight
        : (maxExtent - shrinkOffset).clamp(minExtent, maxExtent);
    // Scroll the header has absorbed beyond its own collapse (a pinned sliver
    // keeps reporting it; see [consumedBySearch]).
    final margin = _barMargin(context);
    final titleOvershoot = !collapseTitle
        ? 0.0
        : (shrinkOffset - (maxExtent - minExtent)).clamp(0.0, double.infinity);

    // Sequenced collapse, like Flutter's bottomMode.automatic: the scroll
    // consumes the search row FIRST (it shrinks and fades to nothing before
    // the page moves), then the large title collapses.
    // Once the search is open the pinned header ignores shrinkOffset, which
    // a pinned sliver keeps reporting.
    final consumedBySearch = _collapsibleSearch
        ? shrinkOffset.clamp(0.0, _searchRowH) * (1 - searchT)
        : 0.0;
    final searchCollapseT = _collapsibleSearch
        ? consumedBySearch / _searchRowH
        : 0.0;
    final tTitle = _largeH <= 0 ? 1.0 : titleT;

    // Framework behavior (CupertinoSliverNavigationBar.search): the glass
    // actions vanish the instant the morph starts and return the instant the
    // close starts — no fade; the inline title additionally stays hidden
    // while the morph is running in either direction.
    final actionsVisible = !searchActive;
    final titleVisible = !searchActive && !morphing;
    // The subtitle trails the title slightly through the collapse morph: its
    // progress runs off a lagged copy of the title's.
    final tTitleSub = (tTitle - 0.12).clamp(0.0, 1.0);
    final largeOpacity = !expandedTitle
        ? 0.0
        : (1 - tTitle / 0.75).clamp(0.0, 1.0);
    final largeSubOpacity = !expandedTitle
        ? 0.0
        : (1 - tTitleSub / 0.75).clamp(0.0, 1.0);
    // The inline title follows the collapse from its first frame.
    final inlineT = !expandedTitle ? 1.0 : tTitle;
    final inlineSubT = !expandedTitle ? 1.0 : tTitleSub;
    final inlineSigma = (1 - inlineT) * 8;

    // Search slot geometry: shrinks with the collapse, travels on activation.
    // The capsule itself starts squeezing only past the dead zone — the
    // row's padding absorbs the first few points of scroll.
    final fieldConsumed = (consumedBySearch - _collapseDeadZone).clamp(
      0.0,
      fieldHeight,
    );
    final restFieldH = fieldHeight - fieldConsumed;
    final fieldH = ui
        .lerpDouble(restFieldH, fieldHeight, searchT)!
        .clamp(0.1, fieldHeight);
    // Bottom-anchored, like the framework's search bottom slot: the field
    // doesn't travel on its own — the collapsing header carries it to the
    // top. (At searchT == 1 the header is topPadding + fieldHeight + 12, so
    // this lands at topPadding + 4.)
    final fieldTop = height - fieldH - _bottomPadding * (1 - searchCollapseT);
    // The field narrows as it rises, making room for the ✕.
    final fieldRight = ui.lerpDouble(margin, margin + 44 + 12, searchT)!;
    // Content fade driven by how many points of height the capsule has lost
    // (see _fadeStartShrink/_fadeEndShrink), not by the row fraction — the
    // native look: brief full-opacity squeeze, quick fade, bare capsule
    // continues shrinking to nothing.
    final fieldShrink = fieldHeight - restFieldH;
    final contentFade = searchT > 0
        ? 1.0
        : 1 -
              ((fieldShrink - _fadeStartShrink) /
                      (_fadeEndShrink - _fadeStartShrink))
                  .clamp(0.0, 1.0);
    // Let the hosted field react natively (Opacity can't fade platform-view
    // pixels). Listeners only push over a channel — no setState — so writing
    // during this build is safe.
    searchRowVisibility.value = contentFade;

    // Blur-morph + translate-from-below, like the system collapse. Title and
    // subtitle fade/travel on their own (lagged) progress so the subtitle
    // arrives just after the title.
    Widget inlineFade(Widget child, double t) => Opacity(
      opacity: titleVisible ? t : 0.0,
      child: Transform.translate(offset: Offset(0, (1 - t) * 20), child: child),
    );
    // With a subtitle the system inline bar drops the title to 15pt (and the
    // subtitle to 12pt) so both lines read as one compact block.
    Widget inlineTitleBlock = subtitle == null
        ? inlineFade(Text(largeTitle, style: inlineTitleStyle), inlineT)
        : Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: centerTitle
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            children: [
              inlineFade(
                Text(
                  largeTitle,
                  style: inlineTitleStyle.copyWith(fontSize: 15),
                ),
                inlineT,
              ),
              inlineFade(
                Text(
                  subtitle!,
                  style: subtitleStyle.copyWith(
                    fontSize: 12,
                    color: inlineSubtitleColor,
                  ),
                ),
                inlineSubT,
              ),
            ],
          );
    if (inlineSigma > 0.1) {
      inlineTitleBlock = ImageFiltered(
        imageFilter: ui.ImageFilter.blur(
          sigmaX: inlineSigma,
          sigmaY: inlineSigma,
        ),
        child: inlineTitleBlock,
      );
    }

    // Fixed height: resizing the native blur every scroll frame re-renders
    // its masks and makes it lag.
    final effectH = topPadding + _barH + _effectOverhang;

    return Stack(
      clipBehavior: Clip.none,
      fit: StackFit.expand,
      children: [
        // A native blur, composited above the page: it samples the native
        // controls passing under the bar live, along with the Flutter content.
        Positioned(
          top: 0,
          left: 0,
          right: 0,
          height: effectH,
          child: edgeEffect,
        ),
        // The bar absorbs taps over its own extent; below it, the effect's
        // overhang leaves the page its taps.
        const AbsorbPointer(child: SizedBox.expand()),
        // No clip: on iOS a composited clip also applies to every native view
        // painted before it, and would cut the edge blur.
        ClipRect(
          clipBehavior: Clip.none,
          child: Stack(
            // Clip.none: an overflowing Stack would clip the same way.
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              // Painted before the bar row, so the glass buttons refract the title.
              // It holds still while the scroll consumes the search row, then
              // collapses.
              Positioned(
                left: margin,
                right: margin,
                // At rest: 8pt above the search FIELD's top edge. Falls with
                // the consumed scroll point-for-point, floored at the plain
                // bottom padding for the title-collapse phase.
                bottom:
                    (_hasSearch
                        ? (fieldHeight + _bottomPadding - consumedBySearch)
                              .clamp(0.0, double.infinity)
                        : 0) +
                    _bottomPadding,
                // Past the header's collapse the title keeps moving with the scroll
                // instead of freezing at the pinned height.
                child: Transform.translate(
                  offset: Offset(0, -titleOvershoot),
                  child: AnimatedOpacity(
                    opacity: searchActive ? 0.0 : 1.0,
                    duration: const Duration(milliseconds: 150),
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Opacity(
                          opacity: largeOpacity,
                          child: Text(
                            largeTitle,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: largeTitleStyle,
                          ),
                        ),
                        if (subtitle != null)
                          Opacity(
                            opacity: largeSubOpacity,
                            child: Text(subtitle!, style: subtitleStyle),
                          ),
                      ],
                    ),
                  ),
                ),
              ),
              if (_hasSearch) ...[
                // The search field, permanently mounted: it shrinks with the collapse
                // and moves to the top when activated.
                Positioned(
                  left: margin,
                  right: fieldRight,
                  top: fieldTop,
                  height: fieldH,
                  child: _SearchSlot(
                    // A plain bottom widget receives its touches directly; the
                    // search field starts absorbing them the moment the search
                    // opens, not a few frames into the morph — the native view
                    // has to be live to take first responder.
                    interactive: !searchable || searchActive,
                    onTap: onSearchOpen,
                    child: CupertinoSearchRowVisibility(
                      listenable: searchRowVisibility,
                      child: searchField!,
                    ),
                  ),
                ),
                // Glass ✕ — permanently mounted. It rides with the field: same
                // height the whole way up, sliding in as the field narrows so
                // it stays 12pt from the field's right edge.
                if (closeButton != null)
                  Positioned(
                    top: fieldTop + (fieldH - 44) / 2,
                    right: margin,
                    width: 44,
                    height: 44,
                    child: Transform.translate(
                      offset: Offset(margin + 44 + 12 - fieldRight, 0),
                      child: Transform.scale(
                        scale: 0.7 + 0.3 * searchT,
                        child: closeButton!,
                      ),
                    ),
                  ),
              ],
            ],
          ),
        ),
        // Inline bar row, painted after the large title. Offstage while the
        // search is active, so the glass buttons stay alive.
        Positioned(
          top: topPadding,
          left: 0,
          right: 0,
          height: _barH,
          child: Offstage(
            offstage: !actionsVisible,
            child: !centerTitle
                ? Padding(
                    padding: EdgeInsets.only(left: margin, right: margin),
                    child: Row(
                      children: [
                        if (leading != null) ...[
                          leading!,
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: inlineTitleBlock,
                          ),
                        ),
                        ?trailing,
                      ],
                    ),
                  )
                : Stack(
                    // No clip: an overflow would make it a composited clip
                    // the engine also applies to the native buttons.
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      // Buttons first, collapsed title last, so the title stays above the
                      // native views.
                      if (leading != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(left: margin),
                            child: leading!,
                          ),
                        ),
                      if (trailing != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: EdgeInsets.only(right: margin),
                            child: trailing!,
                          ),
                        ),
                      inlineTitleBlock,
                    ],
                  ),
          ),
        ),
      ],
    );
  }

  @override
  bool shouldRebuild(_IOS26SliverAppBarDelegate oldDelegate) => true;
}

/// iOS's layout margin: 20pt on phones 414pt wide or more, 16pt otherwise.
/// Bar buttons, titles and the search field all sit on it.
double _barMargin(BuildContext context) =>
    MediaQuery.sizeOf(context).width >= 414 ? 20 : 16;

/// Hosts the bottom-slot widget: passes the slot's (shrinking) height
/// straight to the child — so a `fillHeight` native field physically
/// squeezes with the collapse, proportional to the scroll and the snap —
/// and intercepts taps at rest to trigger the morph.
///
/// Deliberately applies NO Flutter-side opacity: only the field's *content*
/// (text, hint, icons) fades, natively via [CupertinoSearchRowVisibility] —
/// never the capsule/glass container itself.
class _SearchSlot extends StatelessWidget {
  const _SearchSlot({
    required this.interactive,
    required this.onTap,
    required this.child,
  });

  final bool interactive;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    // Same widgets in the same order whether the slot is interactive or not,
    // toggled by their properties. Adding/removing the GestureDetector and
    // AbsorbPointer instead changes the shape of the subtree, so Flutter tears
    // the child down and rebuilds it — which for a platform view means the
    // native UITextField is destroyed and recreated the moment the search
    // opens, losing both its channel (a pending 'focus' call goes nowhere, so
    // the keyboard never comes up) and its first-responder state.
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: interactive ? null : onTap,
      child: AbsorbPointer(
        absorbing: !interactive,
        // Unclipped: a clip would cut the field's shadow.
        child: child,
      ),
    );
  }
}

/// A pinned, non-collapsing iOS 26 navigation bar. Place it in a `Stack`
/// over your content. Falls back to [CupertinoNavigationBar] below iOS 26.
class CupertinoNativeNavigationBar extends StatelessWidget {
  const CupertinoNativeNavigationBar({
    super.key,
    required this.title,
    this.subtitle,
    this.centerTitle = true,
    this.leading,
    this.trailing = const [],
    this.scrollEdgeEffect = CupertinoScrollEdgeEffectStyle.soft,
    this.tintColor,
  });

  final String title;
  final String? subtitle;
  final bool centerTitle;
  final Widget? leading;
  final List<Widget> trailing;
  final CupertinoScrollEdgeEffectStyle scrollEdgeEffect;
  final Color? tintColor;

  @override
  Widget build(BuildContext context) {
    if (!isIOS26OrLater) {
      return CupertinoNavigationBar(middle: Text(title), leading: leading);
    }
    return _EffectBrightness(builder: _buildBar);
  }

  Widget _buildBar(
    BuildContext context,
    Brightness? behind,
    ValueChanged<Brightness> onBrightnessChanged,
  ) {
    final theme = CupertinoTheme.of(context);
    final topPadding = MediaQuery.paddingOf(context).top;
    final navTitleStyle = theme.textTheme.navTitleTextStyle.copyWith(
      decoration: TextDecoration.none,
    );
    final secondaryLabel = CupertinoColors.secondaryLabel.resolveFrom(context);
    final subtitleStyle = theme.textTheme.tabLabelTextStyle.copyWith(
      fontSize: 13,
      decoration: TextDecoration.none,
    );
    // The title follows the edge effect's wash: white over its dark levels,
    // like the system's bar items, on the wash's own ~0.5s.
    final margin = _barMargin(context);
    final titleBlock = TweenAnimationBuilder<double>(
      tween: Tween(end: behind == Brightness.dark ? 1.0 : 0.0),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, washT, _) {
        final titleStyle = navTitleStyle.copyWith(
          color: Color.lerp(navTitleStyle.color, CupertinoColors.white, washT),
        );
        return subtitle == null
            ? Text(title, style: titleStyle)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: centerTitle
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  Text(title, style: titleStyle),
                  Text(
                    subtitle!,
                    style: subtitleStyle.copyWith(
                      color: Color.lerp(
                        secondaryLabel,
                        const Color(0x99FFFFFF),
                        washT,
                      ),
                    ),
                  ),
                ],
              );
      },
    );
    final leadingWidget = leading;
    final trailingRow = Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 10,
      children: trailing,
    );

    return SizedBox(
      height: topPadding + 44,
      child: Stack(
        clipBehavior: Clip.none,
        fit: StackFit.expand,
        children: [
          // Reaches past the bar so the effect fades out; not for `hard`, which
          // ends with the bar.
          Positioned(
            top: 0,
            left: 0,
            right: 0,
            height:
                topPadding +
                44 +
                (scrollEdgeEffect == CupertinoScrollEdgeEffectStyle.hard
                    ? 0
                    : _IOS26SliverAppBarDelegate._effectOverhang),
            child: RepaintBoundary(
              child: CupertinoScrollEdgeEffect(
                edge: CupertinoScrollEdgeEffectEdge.top,
                style: scrollEdgeEffect,
                color: tintColor,
                onBrightnessChanged: onBrightnessChanged,
              ),
            ),
          ),
          // The bar's own extent takes taps; the effect's overhang below it
          // lies over the page, which keeps its taps.
          const AbsorbPointer(child: SizedBox.expand()),
          // Chrome, painted over the effect.
          Positioned(
            top: topPadding,
            left: 0,
            right: 0,
            height: 44,
            child: !centerTitle
                ? Padding(
                    padding: EdgeInsets.only(left: margin, right: margin),
                    child: Row(
                      children: [
                        if (leadingWidget != null) ...[
                          leadingWidget,
                          const SizedBox(width: 12),
                        ],
                        Expanded(
                          child: Align(
                            alignment: Alignment.centerLeft,
                            child: titleBlock,
                          ),
                        ),
                        if (trailing.isNotEmpty) trailingRow,
                      ],
                    ),
                  )
                : Stack(
                    // No clip: an overflow would make it a composited clip
                    // the engine also applies to the native buttons.
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    // Title painted last, above the native buttons.
                    children: [
                      if (leadingWidget != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: EdgeInsets.only(left: margin),
                            child: leadingWidget,
                          ),
                        ),
                      if (trailing.isNotEmpty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: EdgeInsets.only(right: margin),
                            child: trailingRow,
                          ),
                        ),
                      titleBlock,
                    ],
                  ),
          ),
        ],
      ),
    );
  }
}

/// Holds what a bar's edge effect reports about the content behind it, for a
/// bar that is otherwise stateless.
class _EffectBrightness extends StatefulWidget {
  const _EffectBrightness({required this.builder});

  final Widget Function(
    BuildContext context,
    Brightness? behind,
    ValueChanged<Brightness> onBrightnessChanged,
  )
  builder;

  @override
  State<_EffectBrightness> createState() => _EffectBrightnessState();
}

class _EffectBrightnessState extends State<_EffectBrightness> {
  Brightness? _behind;

  void _report(Brightness behind) {
    if (mounted && behind != _behind) setState(() => _behind = behind);
  }

  @override
  Widget build(BuildContext context) =>
      widget.builder(context, _behind, _report);
}
