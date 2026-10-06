import 'package:cupertino_native_ui/cupertino_native_ui.dart';
import 'package:cupertino_native_ui/src/internal/widget_lowering.dart';
import 'package:flutter/cupertino.dart' show CupertinoDynamicColor;
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  test('menu segmented lowering dispatches the tapped key', () {
    int? got;
    final widget = CupertinoNativeSlidingSegmentedControl<int>.menu(
      children: const {0: Text('None'), 1: Text('Blue'), 2: Text('Pink')},
      groupValue: 0,
      onValueChanged: (v) => got = v,
    );
    final trailing = LoweredTrailing(widget);
    expect(trailing.node, isNotNull);
    final map = trailing.node!.toMap(isDark: false);
    expect(map['type'], 'segmented');
    expect((map['segmented'] as Map)['style'], 'menu');
    expect((map['segmented'] as Map)['selectedIndex'], 0);
    trailing.dispatch('item0', 2);
    expect(got, 2);
    trailing.dispatch('item0', 1);
    expect(got, 1);
  });

  test('a segmented control with nothing picked selects no segment', () {
    final trailing = LoweredTrailing(
      CupertinoNativeSlidingSegmentedControl<int>(
        children: const {0: Text('A'), 1: Text('B')},
        groupValue: null,
        onValueChanged: (_) {},
      ),
    );
    final map = trailing.node!.toMap(isDark: false);
    expect((map['segmented'] as Map)['selectedIndex'], -1);
  });

  test(
    'a transcribed field\'s keyboard bar takes the brightness it is sent with',
    () {
      const color = CupertinoDynamicColor.withBrightness(
        color: Color(0xFF000001),
        darkColor: Color(0xFF000002),
      );
      final trailing = LoweredTrailing(
        CupertinoNativeTextField(
          toolbarActions: [
            CupertinoNativeButton(
              onPressed: () {},
              color: color,
              child: const Text('Done'),
            ),
          ],
        ),
      );
      Object? barColor(bool isDark) {
        final field = trailing.node!.toMap(isDark: isDark)['textField'] as Map;
        final item = (field['keyboardToolbar'] as List).single as Map;
        return (item['button'] as Map)['color'];
      }

      expect(barColor(false), 0xFF000001);
      expect(barColor(true), 0xFF000002);
    },
  );
}
