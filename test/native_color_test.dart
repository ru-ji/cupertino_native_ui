import 'package:cupertino_native_ui/src/internal/native_color.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('a dynamic colour ships the variant for the app brightness', () {
    const label = CupertinoColors.label;
    expect(nativeArgb(label, isDark: false), label.color.toARGB32());
    expect(nativeArgb(label, isDark: true), label.darkColor.toARGB32());
  });

  test('a plain colour and null pass through', () {
    const red = Color(0xFFFF0000);
    expect(nativeArgb(red, isDark: true), red.toARGB32());
    expect(nativeArgb(null, isDark: true), isNull);
  });
}
