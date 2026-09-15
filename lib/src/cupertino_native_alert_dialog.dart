import 'package:flutter/material.dart' show Theme;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// A button of a [CupertinoNativeAlertDialog], shaped like Flutter's
/// [CupertinoDialogAction]. [child] is a [Text]: UIKit draws the label.
class CupertinoNativeDialogAction {
  const CupertinoNativeDialogAction({
    required this.child,
    this.onPressed,
    this.isDefaultAction = false,
    this.isDestructiveAction = false,
  });

  final Text child;
  final VoidCallback? onPressed;

  /// Bold, UIKit's cancel style.
  final bool isDefaultAction;
  final bool isDestructiveAction;

  Map<String, dynamic> toMap() {
    return {
      'title': child.data ?? '',
      'isDestructive': isDestructiveAction,
      'isCancel': isDefaultAction,
    };
  }
}

class CupertinoNativeAlertDialog {
  static const MethodChannel _channel = MethodChannel(
    'com.example.cupertino_widgets/alert',
  );

  static Future<void> show({
    required BuildContext context,
    required String title,
    String? content,
    required List<CupertinoNativeDialogAction> actions,
  }) async {
    try {
      final int? index = await _channel.invokeMethod<int>('showAlert', {
        'title': title,
        'message': content,
        'actions': actions.map((a) => a.toMap()).toList(),
        // Follows the app's own (possibly forced) theme, not the device's
        // system appearance — same convention as every other native surface.
        'isDark': Theme.of(context).brightness == Brightness.dark,
      });

      if (index != null && index >= 0 && index < actions.length) {
        actions[index].onPressed?.call();
      }
    } on PlatformException catch (e) {
      // Handle error or print
      debugPrint("Failed to show alert: ${e.message}");
    }
  }
}
