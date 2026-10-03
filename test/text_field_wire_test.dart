import 'package:cupertino_native_ui/src/internal/text_field_wire.dart';
import 'package:flutter/cupertino.dart' show OverlayVisibilityMode;
import 'package:flutter/widgets.dart' show TextAlignVertical;
import 'package:flutter_test/flutter_test.dart';

void main() {
  // These strings are the contract with Models/TextFieldConfig.swift. If one
  // changes, the native side silently stops honouring the property.
  test('clearButtonMode maps to UITextField.ViewMode case names', () {
    expect(clearButtonModeName(OverlayVisibilityMode.never), 'never');
    expect(clearButtonModeName(OverlayVisibilityMode.editing), 'whileEditing');
    expect(
      clearButtonModeName(OverlayVisibilityMode.notEditing),
      'unlessEditing',
    );
    expect(clearButtonModeName(OverlayVisibilityMode.always), 'always');
  });

  test('verticalAlignment snaps onto the three UIControl positions', () {
    expect(verticalAlignmentName(TextAlignVertical.top), 'top');
    expect(verticalAlignmentName(TextAlignVertical.center), 'center');
    expect(verticalAlignmentName(TextAlignVertical.bottom), 'bottom');

    // Continuous values in between still have to land somewhere valid.
    expect(verticalAlignmentName(const TextAlignVertical(y: -0.3)), 'top');
    expect(verticalAlignmentName(const TextAlignVertical(y: 0.3)), 'bottom');
  });
}
