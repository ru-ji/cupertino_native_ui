import 'package:cupertino_widgets/cupertino_widgets.dart';
import 'package:cupertino_widgets/src/internal/widget_lowering.dart';
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
}
