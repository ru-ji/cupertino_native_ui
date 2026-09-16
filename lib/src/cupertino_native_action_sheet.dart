import 'package:flutter/material.dart' show Theme;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'cupertino_native_alert_dialog.dart';

/// The system sheet of choices that rises from the bottom of the screen —
/// UIKit's `UIAlertController(preferredStyle: .actionSheet)`, which is what
/// SwiftUI's `.confirmationDialog` presents.
///
/// Not a widget: like [CupertinoNativeAlertDialog] it is presented by UIKit
/// over the whole window, so it is a static call rather than something you
/// put in the tree. It shares the action type with the dialog.
///
/// ```dart
/// await CupertinoNativeActionSheet.show(
///   context: context,
///   title: 'Move to…',
///   actions: [
///     CupertinoNativeDialogAction(
///       child: const Text('Delete'),
///       isDestructiveAction: true,
///       onPressed: _delete,
///     ),
///     CupertinoNativeDialogAction(
///       child: const Text('Cancel'),
///       isDefaultAction: true,
///     ),
///   ],
/// );
/// ```
///
/// Mark the dismissing choice `isDefaultAction: true` — that maps to UIKit's
/// `.cancel` style, which pins it to its own capsule at the bottom.
class CupertinoNativeActionSheet {
  const CupertinoNativeActionSheet._();

  static const MethodChannel _channel = MethodChannel(
    'com.example.cupertino_widgets/alert',
  );

  /// Presents the sheet and awaits the choice, calling that action's
  /// `onPressed`. Dismissing without choosing calls nothing.
  ///
  /// [anchor] is only read on iPad and Mac, where UIKit presents an action
  /// sheet as a popover: pass the global rect of the control that opened it
  /// (see [anchorOf]) so the popover points at it. Without one the popover is
  /// centred and arrowless.
  static Future<void> show({
    required BuildContext context,
    String? title,
    String? message,
    required List<CupertinoNativeDialogAction> actions,
    Rect? anchor,
  }) async {
    try {
      final int? index = await _channel.invokeMethod<int>('showActionSheet', {
        'title': title ?? '',
        'message': message,
        'actions': actions.map((a) => a.toMap()).toList(),
        // Follows the app's own (possibly forced) theme, not the device's
        // system appearance — same convention as every other native surface.
        'isDark': Theme.of(context).brightness == Brightness.dark,
        if (anchor != null)
          'sourceRect': {
            'x': anchor.left,
            'y': anchor.top,
            'width': anchor.width,
            'height': anchor.height,
          },
      });

      if (index != null && index >= 0 && index < actions.length) {
        actions[index].onPressed?.call();
      }
    } on PlatformException catch (e) {
      debugPrint('Failed to show action sheet: ${e.message}');
    }
  }

  /// The global rect of the widget behind [context], for [anchor]. Returns
  /// null before that widget has been laid out.
  static Rect? anchorOf(BuildContext context) {
    final box = context.findRenderObject() as RenderBox?;
    if (box == null || !box.hasSize) return null;
    return box.localToGlobal(Offset.zero) & box.size;
  }
}
