import 'dart:convert';

import 'package:cupertino_native_ui/cupertino_native_ui.dart';
import 'package:cupertino_native_ui/src/internal/body_echo.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  /// A body as a page builds it from its state.
  Map<String, dynamic> body({
    required double volume,
    required bool notify,
    required String name,
    required int size,
  }) => CupertinoNativeBody.column(
    children: [
      CupertinoNativeBody.slider(id: 'volume', value: volume),
      CupertinoNativeBody.row(
        children: [
          CupertinoNativeBody.toggle(id: 'notify', value: notify),
          CupertinoNativeBody.textField(id: 'name', value: name),
        ],
      ),
      CupertinoNativeBody.picker(
        id: 'size',
        items: const [
          CupertinoNativePickerItem(title: 'S'),
          CupertinoNativePickerItem(title: 'M'),
          CupertinoNativePickerItem(title: 'L'),
        ],
        selectedIndex: size,
      ),
    ],
  ).toMap(isDark: false);

  test('the page handing reported values back sends nothing new', () {
    final sent = body(volume: 0.2, notify: false, name: '', size: 0);

    // What the native controls report, as the page then rebuilds from it.
    expect(adoptBodyEvent(sent, 'volume', 0.5), isTrue);
    expect(adoptBodyEvent(sent, 'notify', true), isTrue);
    expect(adoptBodyEvent(sent, 'name', 'Ada'), isTrue);
    expect(adoptBodyEvent(sent, 'size', 2), isTrue);

    expect(
      jsonEncode(sent),
      jsonEncode(body(volume: 0.5, notify: true, name: 'Ada', size: 2)),
    );
  });

  test('a value the page refuses still goes back to the native side', () {
    final sent = body(volume: 0.2, notify: false, name: '', size: 0);
    adoptBodyEvent(sent, 'notify', true);

    // The page keeps `false`: the tree it rebuilds differs from what the
    // native toggle shows, so it is sent and the toggle is put back.
    expect(
      jsonEncode(body(volume: 0.2, notify: false, name: '', size: 0)),
      isNot(jsonEncode(sent)),
    );
  });

  test('an id the body does not hold changes nothing', () {
    final sent = body(volume: 0.2, notify: false, name: '', size: 0);
    final before = jsonEncode(sent);
    expect(adoptBodyEvent(sent, 'name.focused', true), isFalse);
    expect(jsonEncode(sent), before);
  });
}
