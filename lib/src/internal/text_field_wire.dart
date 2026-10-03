/// Translations between Flutter's enums and the string cases the Swift side
/// expects. Kept out of the barrel so they stay private to the package, but
/// importable by `test/`.
///
/// The Swift end (`Models/TextFieldConfig.swift`) is the contract: changing a
/// string here silently changes native behaviour, so both are covered by
/// `test/text_field_wire_test.dart`.
library;

import 'package:flutter/cupertino.dart' show OverlayVisibilityMode;
import 'package:flutter/services.dart' show TextInputType;
import 'package:flutter/widgets.dart' show TextAlignVertical;

/// `UITextField.ViewMode` case names. Flutter and UIKit spell the two
/// editing-dependent states differently, so map rather than use `.name`.
/// A [TextInputType] as the native side names it: `TextInputType` is not an
/// enum, its JSON name is like `TextInputType.emailAddress`.
String keyboardTypeName(TextInputType type) {
  final name = type.toJson()['name'];
  return name is String ? name.split('.').last : 'text';
}

String clearButtonModeName(OverlayVisibilityMode mode) => switch (mode) {
  OverlayVisibilityMode.never => 'never',
  OverlayVisibilityMode.editing => 'whileEditing',
  OverlayVisibilityMode.notEditing => 'unlessEditing',
  OverlayVisibilityMode.always => 'always',
};

/// Snap the continuous [TextAlignVertical.y] onto the three positions
/// `UIControl.contentVerticalAlignment` offers.
String verticalAlignmentName(TextAlignVertical alignment) {
  if (alignment.y < 0) return 'top';
  if (alignment.y > 0) return 'bottom';
  return 'center';
}
