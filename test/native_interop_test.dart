import 'package:cupertino_native_ui/cupertino_native_ui.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('isSupportedSync is false off iOS, and isSupported agrees', () async {
    expect(CupertinoNativeGlassContainer.isSupportedSync, isFalse);
    expect(await CupertinoNativeGlassContainer.isSupported, isFalse);
  });
}
