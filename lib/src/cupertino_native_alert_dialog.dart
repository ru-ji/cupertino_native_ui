import 'package:flutter/material.dart' show Theme;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

class CupertinoNativeAlertAction {
  final String title;
  final bool isDestructive;
  final bool isCancel;
  final VoidCallback? onPressed;

  const CupertinoNativeAlertAction({
    required this.title,
    this.isDestructive = false,
    this.isCancel = false,
    this.onPressed,
  });

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'isDestructive': isDestructive,
      'isCancel': isCancel,
    };
  }
}

class CupertinoNativeAlert {
  static const MethodChannel _channel = MethodChannel(
    'com.example.cupertino_widgets/alert',
  );

  static Future<void> show({
    required BuildContext context,
    required String title,
    String? message,
    required List<CupertinoNativeAlertAction> actions,
  }) async {
    try {
      final int? index = await _channel.invokeMethod<int>('showAlert', {
        'title': title,
        'message': message,
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
