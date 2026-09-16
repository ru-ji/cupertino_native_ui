import 'package:flutter/widgets.dart';

import 'cupertino_native_scaffold_navigation_bar.dart';
import 'cupertino_native_sheet.dart';

/// A native popover: a Flutter route presented in a floating card that points
/// at the control it came from (`UIPopoverPresentationController`).
///
/// Same machinery as [CupertinoNativeSheet] — the body is a route from the
/// scaffold's route table, running in its own engine, and it can carry the
/// same native chrome. The difference is the presentation: anchored and
/// arrow-pointed rather than rising from the bottom, and it stays a popover
/// on iPhone instead of adapting back into a sheet.
///
/// ```dart
/// final key = GlobalKey();
/// ...
/// CupertinoNativeButton(key: key, onPressed: () {
///   CupertinoNativePopover.show(
///     route: 'filters',
///     anchor: CupertinoNativePopover.anchorOf(key.currentContext!)!,
///     preferredSize: const Size(320, 240),
///   );
/// }, child: const Text('Filters'));
/// ```
///
/// Dismiss it with [CupertinoNativeSheet.dismiss] (or [CupertinoNativeSheet.pop]
/// from inside the body) — a popover is the same presentation underneath, so
/// it shares those.
abstract final class CupertinoNativePopover {
  /// Presents the popover and completes when it has been dismissed.
  ///
  /// [anchor] is in global (window) coordinates — see [anchorOf].
  /// [preferredSize] sizes the card; without one UIKit sizes it to the
  /// content, which for a Flutter body means the screen.
  static Future<void> show({
    required String route,
    required Rect anchor,
    Size? preferredSize,
    CupertinoNativeScaffoldNavigationBar? appBar,
    Color? backgroundColor,
    bool? showLoadingIndicator,
    bool? isDark,
    void Function(String actionId)? onBarAction,
    ValueChanged<String>? onSearchChanged,
    ValueChanged<String>? onSearchSubmitted,
  }) {
    return CupertinoNativeSheet.show(
      route: route,
      anchor: anchor,
      preferredSize: preferredSize,
      appBar: appBar,
      backgroundColor: backgroundColor,
      showLoadingIndicator: showLoadingIndicator,
      isDark: isDark,
      onBarAction: onBarAction,
      onSearchChanged: onSearchChanged,
      onSearchSubmitted: onSearchSubmitted,
    );
  }

  /// The global rect of the widget behind [context], for [show]'s `anchor`.
  /// Null before that widget has been laid out.
  static Rect? anchorOf(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}
