import 'package:flutter/foundation.dart' show ValueListenable;
import 'package:flutter/widgets.dart';

/// Exposes the enclosing `CupertinoNativeSliverNavigationBar`'s search-row visibility to
/// the hosted search field: 1 at rest, falling to 0 as the scroll consumes
/// the row (`NavigationBarBottomMode.automatic`), back to 1 when search is
/// active.
///
/// Flutter's `Opacity` can't fade the pixels of an embedded platform view,
/// so native fields (like `CupertinoNativeTextField`) listen to this and fade
/// their content natively instead. Drawn fields can ignore it — the slot
/// already applies a Flutter-side fade.
class CupertinoSearchRowVisibility extends InheritedWidget {
  const CupertinoSearchRowVisibility({
    super.key,
    required this.listenable,
    required super.child,
  });

  /// 1 = fully visible, 0 = fully collapsed under the scroll.
  final ValueListenable<double> listenable;

  static ValueListenable<double>? maybeOf(BuildContext context) => context
      .getInheritedWidgetOfExactType<CupertinoSearchRowVisibility>()
      ?.listenable;

  @override
  bool updateShouldNotify(covariant CupertinoSearchRowVisibility oldWidget) =>
      listenable != oldWidget.listenable;
}
