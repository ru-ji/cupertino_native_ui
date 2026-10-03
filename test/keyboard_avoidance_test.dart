import 'package:cupertino_native_ui/src/internal/keyboard_avoidance.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

/// The reveal for a field transcribed into a list runs on *every* rising
/// metrics tick of the keyboard's animation: that is the real-time tracking,
/// and it is what `EditableText` does too ("the metrics change signal from
/// engine will come here every frame"). The row's rectangle therefore has to
/// be expressed in a frame that does not itself move as the reveal scrolls the
/// page, or each tick asks for more travel than the last.
void main() {
  group('rowInViewCoordinates', () {
    // A field 300pt down inside a 600pt-tall list that starts at window
    // y = 200, so the row reports window y = 500.
    const rowInWindow = Rect.fromLTWH(0, 500, 200, 22);
    const viewInWindow = Rect.fromLTWH(0, 200, 400, 600);

    test('is stable while the page scrolls', () {
      final captured = rowInViewCoordinates(
        rowInWindow: rowInWindow,
        viewInWindow: viewInWindow,
      );
      expect(captured.top, 300);
      expect(captured.height, 22);

      // The keyboard's animation scrolls the page 120pt up. The row and the
      // list move together, so the row's offset inside the list, the only
      // thing the reveal should be using, does not move.
      expect(
        rowInViewCoordinates(
          rowInWindow: rowInWindow.translate(0, -120),
          viewInWindow: viewInWindow.translate(0, -120),
        ),
        captured,
      );
    });

    test('re-measuring a frozen row against the moved view drifts', () {
      // The shape of the bug this replaced: the row was captured in window
      // coordinates and the view's *current* position subtracted on every
      // reveal tick. By the second tick the row appeared 120pt further down
      // than it was, so the list was asked to scroll 120pt more, and it kept
      // going until the platform view left the viewport, which detaches it and
      // closes the keyboard. Pinned so the mistake cannot come back.
      final drifted = rowInWindow.top - viewInWindow.translate(0, -120).top;
      expect(drifted, 420);
      expect(drifted, isNot(rowInWindow.top - viewInWindow.top));
    });

    test('carries the row vertical extent and nothing horizontal', () {
      // Only top and height are meaningful: `showOnScreen` is handed a rect
      // inflated downwards, and the width comes from the platform view at
      // reveal time. A width borrowed from the row's window rect would be
      // meaningless once the page scrolls horizontally.
      final rect = rowInViewCoordinates(
        rowInWindow: const Rect.fromLTWH(40, 500, 200, 22),
        viewInWindow: const Rect.fromLTWH(0, 200, 400, 600),
      );
      expect(rect.width, 0);
      expect(rect.height, 22);
      expect(rect.top, 300);
    });
  });
}
