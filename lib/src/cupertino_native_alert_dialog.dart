import 'package:flutter/material.dart' show Theme;
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'cupertino_native_text_field.dart';
import 'internal/text_field_wire.dart';

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
    'com.example.cupertino_native_ui/alert',
  );

  /// [textFields] puts UIKit's own fields in the alert, as in a rename or a
  /// sign-in prompt. Each is read, not mounted: its `controller` (the
  /// starting text, and what was typed by the time an action's `onPressed`
  /// runs), `placeholder`, `obscureText`, `keyboardType`,
  /// `textCapitalization`, `autocorrect` and `textContentType`. The alert
  /// draws them in its own style, so the rest is ignored.
  static Future<void> show({
    required BuildContext context,
    required String title,
    String? content,
    List<CupertinoNativeTextField> textFields = const [],
    required List<CupertinoNativeDialogAction> actions,
  }) async {
    try {
      // The tapped action's index; with text fields, also what was typed.
      final reply = await _channel.invokeMethod<Object?>('showAlert', {
        'title': title,
        'message': content,
        'textFields': textFields.map(_fieldMap).toList(),
        'actions': actions.map((a) => a.toMap()).toList(),
        // Follows the app's own (possibly forced) theme, not the device's
        // system appearance: same convention as every other native surface.
        'isDark': Theme.of(context).brightness == Brightness.dark,
      });

      final index = switch (reply) {
        final int i => i,
        {'index': final int i, 'texts': final List<Object?> texts} => () {
          for (final (n, field) in textFields.indexed) {
            if (n < texts.length && texts[n] is String) {
              field.controller?.text = texts[n]! as String;
            }
          }
          return i;
        }(),
        _ => null,
      };
      if (index != null && index >= 0 && index < actions.length) {
        actions[index].onPressed?.call();
      }
    } on PlatformException catch (e) {
      // Handle error or print
      debugPrint("Failed to show alert: ${e.message}");
    }
  }

  static Map<String, dynamic> _fieldMap(CupertinoNativeTextField field) => {
    'text': field.controller?.text ?? '',
    'placeholder': field.placeholder,
    'obscureText': field.obscureText,
    'keyboardType': keyboardTypeName(field.keyboardType),
    'textCapitalization': field.textCapitalization.name,
    'autocorrect': field.autocorrect,
    'textContentType': field.textContentType,
  };
}
