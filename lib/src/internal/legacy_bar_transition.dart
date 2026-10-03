import 'package:flutter/cupertino.dart';

import '../cupertino_symbol_image.dart';

/// The iOS 15–18 bar's page transition, as `UINavigationBar` plays it between
/// two pages that both have one: the page underneath's title, large or
/// inline, flies up into the new page's back button and turns into its
/// label, while the new back button's chevron fades in. Everything else
/// rides with its page: the new large title slides in, the search field and
/// the material go with their pages, the bar items fade.
///
/// A [Hero] shared by the two bars carries the flying parts; each bar keeps
/// a [LegacyBarFlight] the flight reads its parts from.
class LegacyBarFlight {
  final largeTitleKey = GlobalKey();
  final middleKey = GlobalKey();
  final backChevronKey = GlobalKey();
  final backLabelKey = GlobalKey();

  /// Whether the large title is up; the inline title otherwise.
  bool showsLargeTitle = true;

  /// The bar's title, the text that flies.
  String? title;

  /// Whether the bar shows the system back button, and its label.
  bool hasBackButton = false;
  String? backLabel;

  /// The back button's label when the route names none: the previous bar's
  /// title, handed over as the transition to this page starts.
  final ValueNotifier<String?> inheritedBackTitle = ValueNotifier(null);

  TextStyle largeTitleStyle = const TextStyle(inherit: false);
  TextStyle middleStyle = const TextStyle(inherit: false);
  TextStyle backStyle = const TextStyle(inherit: false);
  Color chevronColor = const Color(0xFF007AFF);

  void dispose() => inheritedBackTitle.dispose();
}

/// The system's back button label: the previous page's title, or "Back" when
/// that is too long (Flutter's `CupertinoNavigationBarBackButton` rule).
String? legacyBackLabel(String? title) =>
    title == null || title.length <= 12 ? title : 'Back';

/// Wraps the bar's content in the [Hero] the transition flies.
Widget legacyBarHero({
  required BuildContext context,
  required LegacyBarFlight flight,
  required Widget child,
}) {
  final navigator = Navigator.maybeOf(context);
  if (navigator == null) return child;
  return Hero(
    tag: _BarHeroTag(navigator),
    transitionOnUserGestures: true,
    // The bars sit at the top of their pages: the flight does not travel.
    createRectTween: (begin, end) => _HoldRect(begin!.expandToInclude(end!)),
    flightShuttleBuilder: _shuttle,
    // The bars stay in their pages during the flight; only the parts that
    // fly hide (see [LegacyBarFlyingPart]).
    placeholderBuilder: (context, size, child) => _InFlight(child: child),
    child: _FlightSource(flight: flight, child: child),
  );
}

/// Which side of a page transition a bar is on.
enum LegacyBarRole {
  /// The page coming in (a push) or going (a pop).
  top,

  /// The page it covers.
  bottom,
}

LegacyBarRole? _role(ModalRoute<dynamic>? route) {
  bool moving(Animation<double>? a) =>
      a != null &&
      (a.status == AnimationStatus.forward ||
          a.status == AnimationStatus.reverse);
  if (route == null) return null;
  if (moving(route.secondaryAnimation)) return LegacyBarRole.bottom;
  if (moving(route.animation)) return LegacyBarRole.top;
  return null;
}

/// A part the transition draws itself while it flies: hidden in the page
/// meanwhile, on the side it flies from.
class LegacyBarFlyingPart extends StatelessWidget {
  const LegacyBarFlyingPart({
    super.key,
    required this.flyingAs,
    required this.child,
  });

  final LegacyBarRole flyingAs;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final hidden =
        _InFlight.isIn(context) && _role(ModalRoute.of(context)) == flyingAs;
    return Opacity(opacity: hidden ? 0 : 1, child: child);
  }
}

/// A bar item fading with the page transition: out over the first 40% on
/// the page being covered, in over the last 60% on the page coming in.
class LegacyBarRouteFade extends StatelessWidget {
  const LegacyBarRouteFade({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final route = ModalRoute.of(context);
    final primary = route?.animation;
    final secondary = route?.secondaryAnimation;
    if (primary == null || secondary == null) return child;
    return AnimatedBuilder(
      animation: Listenable.merge([primary, secondary]),
      child: child,
      builder: (context, child) => Opacity(
        opacity: switch (_role(route)) {
          LegacyBarRole.bottom => (1 - secondary.value / 0.4).clamp(0.0, 1.0),
          LegacyBarRole.top => ((primary.value - 0.4) / 0.6).clamp(0.0, 1.0),
          null => 1.0,
        },
        child: child,
      ),
    );
  }
}

/// The back button's chevron: the native `chevron.backward` in a 17×22 box.
class LegacyBackChevron extends StatelessWidget {
  const LegacyBackChevron({super.key, required this.color});

  final Color color;

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: 17,
      height: 22,
      child: Center(
        child: CupertinoSymbolImage(
          'chevron.backward',
          size: 17,
          // Large: UIKit's back indicator, measured 11×18.4pt on an iPhone
          // 8 Plus.
          scale: CupertinoSymbolScale.large,
          weight: FontWeight.w600,
          color: color,
        ),
      ),
    );
  }
}

class _BarHeroTag {
  const _BarHeroTag(this.navigator);

  final NavigatorState navigator;

  @override
  bool operator ==(Object other) =>
      other is _BarHeroTag && other.navigator == navigator;

  @override
  int get hashCode => navigator.hashCode;
}

class _HoldRect extends RectTween {
  _HoldRect(Rect rect) : super(begin: rect, end: rect);

  @override
  Rect lerp(double t) => begin!;
}

class _FlightSource extends StatelessWidget {
  const _FlightSource({required this.flight, required this.child});

  final LegacyBarFlight flight;
  final Widget child;

  @override
  Widget build(BuildContext context) => child;
}

class _InFlight extends InheritedWidget {
  const _InFlight({required super.child});

  static bool isIn(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_InFlight>() != null;

  @override
  bool updateShouldNotify(_InFlight oldWidget) => false;
}

Widget _shuttle(
  BuildContext flightContext,
  Animation<double> animation,
  HeroFlightDirection direction,
  BuildContext fromHero,
  BuildContext toHero,
) {
  final from = (fromHero.widget as Hero).child as _FlightSource;
  final to = (toHero.widget as Hero).child as _FlightSource;
  final push = direction == HeroFlightDirection.push;
  final bottom = push ? from.flight : to.flight;
  final top = push ? to.flight : from.flight;
  // The page underneath names the new page's back button, as UIKit's does.
  // After this frame: it rebuilds the bar.
  if (push && top.inheritedBackTitle.value == null) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (top.inheritedBackTitle.value == null) {
        top.inheritedBackTitle.value = bottom.title;
      }
    });
  }
  return _BarFlightShuttle(
    animation: animation,
    bottom: bottom,
    top: top,
    bottomHero: push ? fromHero : toHero,
    topHero: push ? toHero : fromHero,
    // A swipe drives the pages linearly; a tap runs them on the page curve.
    linear: Navigator.of(flightContext).userGestureInProgress,
  );
}

class _BarFlightShuttle extends StatelessWidget {
  const _BarFlightShuttle({
    required this.animation,
    required this.bottom,
    required this.top,
    required this.bottomHero,
    required this.topHero,
    required this.linear,
  });

  final Animation<double> animation;
  final LegacyBarFlight bottom;
  final LegacyBarFlight top;
  final BuildContext bottomHero;
  final BuildContext topHero;
  final bool linear;

  /// Where [key]'s part sits in its own bar: the bars sit at the top of
  /// their pages, so in the flight's box too.
  static Rect? _rect(GlobalKey key, BuildContext hero) {
    final box = key.currentContext?.findRenderObject();
    final bar = hero.findRenderObject();
    if (box is! RenderBox || bar is! RenderBox) return null;
    if (!box.attached || !box.hasSize || !bar.attached) return null;
    return box.localToGlobal(Offset.zero, ancestor: bar) & box.size;
  }

  @override
  Widget build(BuildContext context) {
    return DefaultTextStyle(
      style: CupertinoTheme.of(context).textTheme.textStyle
          .copyWith(decoration: TextDecoration.none),
      child: AnimatedBuilder(
        animation: animation,
        builder: (context, _) {
          final t = animation.value;
          // The page curve, so the parts keep up with the pages.
          final curve = linear
              ? Curves.linear
              : animation.status == AnimationStatus.reverse
              ? Curves.fastEaseInToSlowEaseOut.flipped
              : Curves.fastEaseInToSlowEaseOut;
          final c = curve.transform(t);

          final from = _rect(
            bottom.showsLargeTitle ? bottom.largeTitleKey : bottom.middleKey,
            bottomHero,
          );
          final fromStyle = bottom.showsLargeTitle
              ? bottom.largeTitleStyle
              : bottom.middleStyle;
          final chevron = top.hasBackButton
              ? _rect(top.backChevronKey, topHero)
              : null;
          var label = top.hasBackButton
              ? _rect(top.backLabelKey, topHero)
              : null;
          // Until the handed-over title is laid out: where it will be, 6pt
          // after the chevron.
          if (chevron != null && (label == null || label.width == 0)) {
            label = Rect.fromLTWH(chevron.right + 6, chevron.top, 0, 21);
          }
          final backText = top.backLabel ?? legacyBackLabel(bottom.title);

          return Stack(
            clipBehavior: Clip.none,
            children: [
              // The title underneath, flying into the back button and
              // fading out by 60% of the way.
              if (from != null && bottom.title != null)
                _text(
                  bottom.title!,
                  anchor: label == null
                      ? from.bottomLeft
                      : Offset.lerp(from.bottomLeft, label.bottomLeft, c)!,
                  style: label == null
                      ? fromStyle
                      : TextStyle.lerp(fromStyle, top.backStyle, c)!,
                  opacity: 1 - (t / 0.6).clamp(0.0, 1.0),
                ),
              // The back label, along the same path, fading in from 40%.
              if (label != null && backText != null)
                _text(
                  backText,
                  anchor: from == null
                      ? label.bottomLeft
                      : Offset.lerp(from.bottomLeft, label.bottomLeft, c)!,
                  style: from == null
                      ? top.backStyle
                      : TextStyle.lerp(fromStyle, top.backStyle, c)!,
                  opacity: ((t - 0.4) / 0.6).clamp(0.0, 1.0),
                ),
              // The new chevron, fading in where it stands.
              if (chevron != null)
                Positioned.fromRect(
                  rect: chevron,
                  child: Opacity(
                    opacity: ((t - 0.4) / 0.6).clamp(0.0, 1.0),
                    child: LegacyBackChevron(color: top.chevronColor),
                  ),
                ),
            ],
          );
        },
      ),
    );
  }

  /// [text] with its bottom-left corner at [anchor]: the two ends of a
  /// flight are lined up on their baselines rather than their tops.
  static Widget _text(
    String text, {
    required Offset anchor,
    required TextStyle style,
    required double opacity,
  }) {
    return Positioned(
      left: anchor.dx,
      top: anchor.dy,
      child: FractionalTranslation(
        translation: const Offset(0, -1),
        child: Opacity(
          opacity: opacity,
          child: Text(
            text,
            style: style,
            maxLines: 1,
            softWrap: false,
            overflow: TextOverflow.visible,
          ),
        ),
      ),
    );
  }
}
