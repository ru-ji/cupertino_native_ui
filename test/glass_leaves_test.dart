import 'package:cupertino_native_ui/src/internal/glass_leaves.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a glass child hands its texts to SwiftUI, through a Row only', (
    tester,
  ) async {
    List<Map<String, Object?>>? got;
    final leaves = GlassLeaves((l) => got = l);
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Center(
          child: leaves.host(
            Padding(
              padding: const EdgeInsets.all(10),
              child: leaves.split(
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const Text('Edit'),
                    const SizedBox(width: 8),
                    const Text(
                      'Red',
                      style: TextStyle(color: Color(0xFFFF0000)),
                    ),
                    // Not a layout widget: its text is its own, and Flutter's.
                    GestureDetector(onTap: () {}, child: const Text('Tap')),
                  ],
                ),
                isDark: false,
              ),
            ),
          ),
        ),
      ),
    );

    expect(got, hasLength(2));
    final edit = got![0];
    expect(edit['text'], 'Edit');
    expect(edit['x'], 10);
    expect(edit['y'], 10);
    expect(edit['singleLine'], isTrue);
    // Inherited colour: left to the native foreground, which adapts.
    expect(edit['color'], isNull);
    expect(got![1]['text'], 'Red');
    expect(got![1]['x'], (edit['x'] as double) + (edit['width'] as double) + 8);
    expect(got![1]['color'], 0xFFFF0000);

    // Laid out by Flutter, drawn natively: Flutter paints only 'Tap'.
    expect(
      tester.renderObject(find.byType(Flex)),
      paintsExactlyCountTimes(#drawParagraph, 1),
    );
  });
}
