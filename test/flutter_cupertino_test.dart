import 'package:flutter_test/flutter_test.dart';
import 'package:cupertino_native_ui/cupertino_native_ui.dart';

void main() {
  test('CupertinoNativeMenuAction toMap', () {
    const action = CupertinoNativeMenuAction(
      title: 'Test Action',
      actionId: 'test_id',
      subtitle: 'Subtitle',
      systemImage: 'star',
      isDestructive: true,
      isDisabled: true,
    );

    final map = action.toMap();

    expect(map['type'], 'action');
    expect(map['title'], 'Test Action');
    expect(map['actionId'], 'test_id');
    expect(map['subtitle'], 'Subtitle');
    expect(map['systemImage'], 'star');
    expect(map['isDestructive'], true);
    expect(map['isDisabled'], true);
  });

  test('CupertinoNativeSubmenu toMap', () {
    const submenu = CupertinoNativeSubmenu(
      title: 'Submenu',
      items: [CupertinoNativeMenuAction(title: 'Item 1', actionId: '1')],
    );

    final map = submenu.toMap();

    expect(map['type'], 'submenu');
    expect(map['title'], 'Submenu');
    expect(map['items'], isA<List>());
    expect((map['items'] as List).length, 1);
    expect(map['items'][0]['title'], 'Item 1');
  });
}
