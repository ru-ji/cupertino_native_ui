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
/// title that stays visible when scrolling. [CupertinoSliverAppBar.search]
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
class CupertinoSliverAppBar extends StatefulWidget {
  const CupertinoSliverAppBar({
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
  const CupertinoSliverAppBar.search({
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

  /// Leading bar content — anything. A [CupertinoNativeButton] with
  /// `style: glass, borderShape: circle` is the iOS 26 bar button; a plain
  /// [Text] or a [CupertinoNativeGlassContainer] works just as well. The bar
  /// positions it and stays out of its way.
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
  /// [CupertinoSliverAppBar.search] (where it's named `searchFieldHeight`).
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

  /// Whether opening the search sends the page back to the top (and cancelling
  /// puts it back where it was).
  ///
  /// True (the default) suits a search that *replaces* the page's content —
  /// suggestions, then results: the new, usually shorter body would otherwise
  /// come up mid-list, at whatever offset the page was left at.
  ///
  /// Set it false when the search leaves the content in place — the common
  /// case of filtering the list or grid already on screen. Nothing about the
  /// bar forces a separate results view; opening the search only runs the
  /// morph, and what (if anything) changes below is entirely yours.
  final bool scrollToTopOnSearch;

  /// Whether the built-in search field rests on Liquid Glass. False (the
  /// default) rests it on the system's plain filled capsule.
  ///
  /// Either way, on iOS 26 the field turns to glass while the search is open,
  /// and — with [NavigationBarBottomMode.always] — as soon as the title
  /// collapses and the row starts floating over content, like the system's.
  final bool searchGlass;

  /// Whether the search row collapses with the scroll (`automatic`) or stays
  /// visible (`always`). Only settable on [CupertinoSliverAppBar.search]; the
  /// default constructor's [bottom] always behaves as `always`.
  final NavigationBarBottomMode bottomMode;

  /// Fires on every keystroke in the built-in search field.
  final ValueChanged<String>? onSearchChanged;

  /// Fires when the search activates/deactivates, so the page can swap its
  /// content for a search view. Focus is managed internally.
  final ValueChanged<bool>? onSearchActiveChanged;

  /// True for [CupertinoSliverAppBar.search].
  final bool _searchable;

  final CupertinoScrollEdgeEffectStyle scrollEdgeEffect;

  /// Tint of the edge effect. Defaults to the system background.
  final Color? tintColor;

  @override
  State<CupertinoSliverAppBar> createState() => _CupertinoSliverAppBarState();
}

class _CupertinoSliverAppBarState extends State<CupertinoSliverAppBar>
    with TickerProviderStateMixin {
  // 380ms on an ease-in-out, measured off a 60fps capture of the system
  // search morph (the field's travel to the top, tracked frame by frame:
  // 0.16 of the distance at a quarter of the way, 0.52 at half, 0.87 at three
  // quarters — a symmetric S). Flutter's own nav bar runs 300ms linear
  // (_kNavBarSearchDuration), which arrives noticeably early and flat.
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
  /// 450ms on [Curves.ease]: measured off a 60fps capture of an iOS 26 app's
  /// title collapse (frame-by-frame opacity of the inline title, fitted
  /// against candidate curves — cubic-bezier(0.25, 0.1, 0.25, 1) over ~467ms
  /// tracked it to an RMS of 0.01, every other curve/duration pair fit worse).
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
    debugLabel: 'CupertinoSliverAppBar.search',
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
    // Adopt the current scroll rather than animating into it: a header that
    // is rebuilt while already scrolled past the trigger starts collapsed.
    // Never mid-flight though — an inset change (rotation, keyboard) must not
    // snap a collapse that is still running. And never during the search: the
    // keyboard coming up IS an inset change, so this runs right after the page
    // was parked at the top for the search, and would read that as "expanded"
    // — killing the scroll edge effect until the page comes back.
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

  /// Fires the collapse (or the expansion) the moment the scroll crosses
  /// [_collapseTrigger]. Nothing else about the scroll matters after that:
  /// the animation owns its own progress until the trigger is crossed again.
  /// The search owns the page's scroll for the length of its morph — parked
  /// at the top on open, put back on cancel. Those jumps are not the user
  /// collapsing or expanding the header, so the collapse state (and with it
  /// the scroll edge effect) is frozen while this is true. Without the freeze
  /// the effect drops to nothing on open and ramps back up over 450ms on the
  /// way back, which reads as a flash the moment the page lands.
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
        // Same timing as Flutter's nav bar, eyeballed on an iOS simulator.
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
        : CupertinoNativeButton(
            icon: CupertinoNativeIcon.symbol(CupertinoSymbols.xmark, size: 20),
            style: CupertinoNativeButtonStyle.glass,
            borderShape: CupertinoNativeButtonBorderShape.circle,
            labelStyle: CupertinoNativeButtonLabelStyle.iconOnly,
            controlSize: CupertinoNativeControlSize.large,
            onPressed: () => _setSearchActive(false),
          );
    // The bottom slot: the built-in search field (.search) or the user's
    // always-visible bottom widget.
    // When the field is glass. Besides the opt-in resting look, iOS 26 puts it
    // on glass whenever it stops sitting on the page: while the search is open
    // (the whole morph, both directions — it turns on as the open starts and
    // off only once the close has landed, never mid-slide), and, in `always`
    // mode, from the moment the title collapses and the row starts floating
    // over content.
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
            // Both looks are drawn by the native field itself — the capsule is
            // a UIKit background with a radius, not a Flutter box behind a
            // transparent platform view.
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
            prefixIcon:
                widget.searchPrefixIcon ??
                // 20pt in the primary label colour, like the system field:
                // the glyph reads brighter and larger than the placeholder
                // next to it, not as another piece of grey text.
                CupertinoNativeIcon.symbol(
                  CupertinoSymbols.magnifyingglass,
                  size: 20,
                  color: CupertinoColors.label.resolveFrom(context),
                ),
            suffixIcon: widget.searchSuffixIcon,
            clearButtonMode: OverlayVisibilityMode.editing,
            onChanged: widget.onSearchChanged,
          )
        : widget.bottom;

    // The inline title follows the edge effect's wash: white over its dark
    // levels, like the system's bar items, on the wash's own ~0.5s.
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(
        end: _effectBehind == Brightness.dark
            ? CupertinoColors.white
            : theme.textTheme.navTitleTextStyle.color,
      ),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, inlineTitleColor, _) => AnimatedBuilder(
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
                // The system effect is not on at rest — blur and scrim both come
                // up from zero at the moment the collapse fires, which is why a
                // slow scroll shows the first rows darkening slightly before any
                // blur is noticeable (a small sigma simply doesn't read yet).
                // Tied to the trigger, not to the collapse itself, so it still
                // happens with [collapseTitle] off.
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
              color: inlineTitleColor,
            ),
            largeTitleStyle: theme.textTheme.navLargeTitleTextStyle.copyWith(
              decoration: TextDecoration.none,
            ),
            subtitleStyle: theme.textTheme.tabLabelTextStyle.copyWith(
              fontSize: 13,
              decoration: TextDecoration.none,
              color: CupertinoColors.secondaryLabel.resolveFrom(context),
            ),
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
  });

  // Geometry mirrors Flutter's CupertinoSliverNavigationBar
  // (_kNavBarLargeTitleHeightExtension = 52, _kNavBarBottomPadding = 8),
  // except the search field height, which is configurable and defaults to the
  // iOS 26 44pt capsule instead of Flutter's 36.
  static const double _barH = 44;
  // 52 is UIKit's large-title band height, but its title label sits lower in
  // the band than ours does: the visible gap under the leading row runs ~1.5x
  // ours. The extra 5pt is bottom-anchored, so it lands entirely in that gap.
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

  /// How far past the bar's own extent the effect keeps fading.
  ///
  /// Measured from the header's own bottom edge, the row's bottom padding
  /// included — UIKit's search band is the capsule plus 8pt above and below,
  /// and the effect covers the band, not just the capsule. The header's top
  /// already starts at the safe-area inset, so the notch / Dynamic Island
  /// (20 / 47 / 59pt) is inside this span with nothing to add.
  ///
  /// One bar height, and measured rather than picked: on the probe page the
  /// system effect dies out around 150pt from the top of the screen while the
  /// bar it belongs to ends at 103 (a 59pt inset plus 44). Ending 17pt below
  /// the bar made the wash stop while it was still visibly on.
  static const double _effectOverhang = 44;

  /// The row the search field lives in: the field, the gap above it (14 —
  /// measured off the system's own floating search row, between the toolbar
  /// button's bottom edge and the capsule's top) and the padding below.
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

  /// Height of the bottom slot (see [CupertinoSliverAppBar.bottomHeight]).
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

  /// Lets the header grow into the over-scroll instead of staying pinned at
  /// its own height.
  ///
  /// This is what makes the title and the search row travel with a pull-down,
  /// the way they do in a SwiftUI `NavigationStack` — there the large title
  /// and the `.searchable` field are part of the scrolled content, and only
  /// the toolbar buttons are anchored. Without it the header holds still while
  /// the list rubber-bands underneath it, which reads as the content coming
  /// unstuck from its own title.
  ///
  /// Nothing else has to change for that: the bar row is pinned to the top of
  /// the header, while the title and the search row are anchored to its
  /// bottom, so they follow the growth on their own.
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
    // The real box, which a stretch makes taller than `maxExtent - shrink`.
    // Read rather than computed, so the over-scroll growth reaches the
    // measurements below (the search slot's position, the edge effect's
    // reach) instead of only the widgets that happen to be bottom-anchored.
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
    final titleOvershoot = !collapseTitle
        ? 0.0
        : (shrinkOffset - (maxExtent - minExtent)).clamp(0.0, double.infinity);

    // Sequenced collapse, like Flutter's bottomMode.automatic: the scroll
    // consumes the search row FIRST (it shrinks and fades to nothing before
    // the page moves), then the large title collapses.
    // Faded out by the morph: once the search is open the header is pinned at
    // a fixed extent, but a PINNED sliver still reports the page's entire
    // scrollOffset as shrinkOffset (it is not clamped to maxExtent-minExtent).
    // Left raw, any scroll while the search is open reads as "the row is fully
    // collapsed" and drops the docked field by the row's bottom padding.
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
    // The large title keeps its scroll-driven fade during the morph: the
    // shrinking, clipping header carries it out of view (the framework
    // collapses its height slot to zero — same visual).
    final largeOpacity = !expandedTitle
        ? 0.0
        : (1 - tTitle / 0.75).clamp(0.0, 1.0);
    final largeSubOpacity = !expandedTitle
        ? 0.0
        : (1 - tTitleSub / 0.75).clamp(0.0, 1.0);
    // The inline title follows the collapse from its first frame — the curve
    // measured on the system (see [_titleCollapse]). Gated at 55% it stayed
    // invisible for ~230ms after the trigger, which read as a late collapse.
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
    final fieldRight = ui.lerpDouble(16, 16 + 44 + 12, searchT)!;
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
                Text(subtitle!, style: subtitleStyle.copyWith(fontSize: 12)),
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

    // The effect is the header, whatever the header currently is: a bar alone,
    // a bar plus a large title, plus a search row when there is one, or — with
    // the search open, no title and no actions — just the docked field. It
    // therefore shrinks and grows with the collapse and the morph on its own,
    // with no special-casing per configuration.
    // Fixed, like the "Adaptive wash over the bands" probe: a native view resized
    // per scroll frame re-renders its masks each frame and lags the titles.
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
        // The bar's own extent absorbs taps: a bar is a surface, and a tap on
        // the empty space between the title and the actions belongs to it. The
        // effect reaches `_effectOverhang` further down only to fade out; that
        // overhang lies over the page, and the page keeps its taps. Below the
        // actions in the stack, so they are hit-tested first.
        const AbsorbPointer(child: SizedBox.expand()),
        // No clip. A composited ClipRect (any holding a native view) is pushed
        // by the iOS engine onto EVERY platform view prerolled before it in
        // the frame (PushClipRectToVisitedPlatformViews), so it cut the edge
        // blur — and the field's shadow — off square at the header's bottom.
        // It hid nothing: the pinned header starts at the top of the screen.
        ClipRect(
          clipBehavior: Clip.none,
          child: Stack(
            // Not the default hardEdge: in search mode the bottom-anchored large
            // title overflows the header's top, the Stack clips, and that clip
            // lands on the field, the ✕ and (via the engine) the edge blur.
            clipBehavior: Clip.none,
            fit: StackFit.expand,
            children: [
              // Painted BEFORE the bar row: the glass leading/trailing
              // buttons are native views, and a UIGlassEffect can only
              // refract what is *behind* it. Above them the title would just
              // sit on top of the glass — which is exactly what a plain
              // transparent container looks like.
              // Large title (+ subtitle), anchored above the search row.
              // The anchor shrinks 1:1 with the header while the scroll
              // consumes the search row — the framework's geometry (its
              // title band is pinned below the bar with its bottom inset
              // tracking the row's visible height exactly), so the title
              // sits perfectly still through that phase, then collapses.
              Positioned(
                left: 16,
                right: 16,
                // At rest: 8pt above the search FIELD's top edge. Falls with
                // the consumed scroll point-for-point, floored at the plain
                // bottom padding for the title-collapse phase.
                bottom:
                    (_hasSearch
                        ? (fieldHeight + _bottomPadding - consumedBySearch)
                              .clamp(0.0, double.infinity)
                        : 0) +
                    _bottomPadding,
                // Past the header's own collapse the title keeps travelling
                // with the scroll instead of parking at the pinned height: a
                // pinned sliver stops shrinking at minExtent, and a
                // bottom-anchored title would freeze there, in full view,
                // until the collapse animation catches up (visible on a fast
                // flick). Carried on by the leftover scroll it just slides up
                // under the bar and out, the way the content does.
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
                // The user's search field, permanently mounted in a slot that
                // shrinks/fades with the collapse and travels to the top when
                // activated. (Opacity fades drawn fields; embedded platform-view
                // pixels are clipped by the shrinking slot instead.)
                Positioned(
                  left: 16,
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
                // Glass ✕ — permanently mounted; rides in from beyond the right
                // screen edge, scaling up as it materializes next to the field.
                if (closeButton != null)
                  Positioned(
                    top: topPadding + 4,
                    right: 16,
                    width: 44,
                    height: 44,
                    child: Transform.translate(
                      offset: Offset((1 - searchT) * 140, 0),
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
        // Inline bar row. OUTSIDE the ClipRect above, and painted after it:
        // a glass action casts its shadow a few points past its own box, and
        // the clip cut that off square at the header's bottom edge — a hard
        // rectangle around the back button.
        // Still painted after the large title, which has to pass BEHIND the
        // glass to be refracted by it.
        //
        // Hidden outright while search is active —
        // the framework's Visibility treatment, not a fade/slide —
        // via Offstage so the glass-action platform views stay alive
        // instead of being destroyed and recreated per morph.
        Positioned(
          top: topPadding,
          left: 0,
          right: 0,
          height: _barH,
          child: Offstage(
            offstage: !actionsVisible,
            child: !centerTitle
                ? Padding(
                    padding: EdgeInsets.only(
                      left: leading != null ? _kBarItemMargin : 16,
                      right: _kBarItemMargin,
                    ),
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
                      // Buttons first, collapsed title LAST — the
                      // opposite of the large title below, and for the
                      // opposite reason. The large title scrolls
                      // *behind* the glass and has to be under it to be
                      // refracted; the collapsed title sits between the
                      // buttons and never passes behind them, so
                      // nothing is lost by painting it on top — and on
                      // top it stays in the Flutter surface above the
                      // native views instead of the one under them.
                      if (leading != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(
                              left: _kBarItemMargin,
                            ),
                            child: leading!,
                          ),
                        ),
                      if (trailing != null)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(
                              right: _kBarItemMargin,
                            ),
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

/// Outer margin of the bar's action items, leading and trailing.
///
/// 12, not the 16 the title and the search capsule use. UIKit's 16pt bar
/// layout margin dates from a bare glyph; in iOS 26 the item is a 44pt glass
/// capsule around that glyph, so keeping 16 pushes the glyph itself to ~31pt
/// from the edge and the back chevron stops reading as aligned with the large
/// title under it. 12 puts the capsule where the system's sits.
const double _kBarItemMargin = 12;

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
        // Unclipped: the field squeezes natively, and a clip here would cut its
        // shadow and interactive swell to a hard box (and, through the engine,
        // the edge blur under it — see the header's Stack).
        child: child,
      ),
    );
  }
}

/// One action as its own glass control: circle for icon-only, capsule
/// otherwise — sized like the iOS 26 system bars (44pt).
/// The inline (non-collapsing) variant: a pinned 44pt bar floating on the
/// scroll-edge effect, with the same glass actions, title alignment and
/// subtitle. Place it in a `Stack` over your scrollable. Falls back to
/// [CupertinoNavigationBar] below iOS 26.
class CupertinoAppBar extends StatelessWidget {
  const CupertinoAppBar({
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
    final subtitleStyle = theme.textTheme.tabLabelTextStyle.copyWith(
      fontSize: 13,
      decoration: TextDecoration.none,
      color: CupertinoColors.secondaryLabel.resolveFrom(context),
    );
    // The title follows the edge effect's wash: white over its dark levels,
    // like the system's bar items, on the wash's own ~0.5s.
    final titleBlock = TweenAnimationBuilder<Color?>(
      tween: ColorTween(
        end: behind == Brightness.dark
            ? CupertinoColors.white
            : navTitleStyle.color,
      ),
      duration: const Duration(milliseconds: 500),
      curve: Curves.easeOutCubic,
      builder: (context, titleColor, _) {
        final titleStyle = navTitleStyle.copyWith(color: titleColor);
        return subtitle == null
            ? Text(title, style: titleStyle)
            : Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: centerTitle
                    ? CrossAxisAlignment.center
                    : CrossAxisAlignment.start,
                children: [
                  Text(title, style: titleStyle),
                  Text(subtitle!, style: subtitleStyle),
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
          // Reaches past the bar's own bounds so the blur/tint fade out
          // instead of ending at the edge (see _effectOverhang). Not for
          // `hard`: that style IS an edge — an opaque background that stops
          // with the bar — so overhanging would just make the bar look 30
          // points taller.
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
                    padding: EdgeInsets.only(
                      left: leadingWidget != null ? _kBarItemMargin : 16,
                      right: _kBarItemMargin,
                    ),
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
                    // Title painted last, over the native buttons — see the
                    // collapsing bar's Stack for why.
                    children: [
                      if (leadingWidget != null)
                        Align(
                          alignment: Alignment.centerLeft,
                          child: Padding(
                            padding: const EdgeInsets.only(
                              left: _kBarItemMargin,
                            ),
                            child: leadingWidget,
                          ),
                        ),
                      if (trailing.isNotEmpty)
                        Align(
                          alignment: Alignment.centerRight,
                          child: Padding(
                            padding: const EdgeInsets.only(
                              right: _kBarItemMargin,
                            ),
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
