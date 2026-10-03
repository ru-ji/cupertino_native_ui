import 'package:cupertino_widgets/src/internal/bar_holes.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a bar cuts its wash out under the items holding a native view', (
    tester,
  ) async {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(SystemChannels.platform_views, (_) async {
          return null;
        });
    final holes = BarHoles();
    final effect = GlobalKey();
    holes.origin = () =>
        effect.currentContext?.findRenderObject() as RenderBox?;
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: BarHolesScope(
          holes: holes,
          child: Stack(
            children: [
              Positioned(
                left: 0,
                top: 20,
                width: 300,
                height: 100,
                child: SizedBox(key: effect),
              ),
              // A native item: cut out, in the effect's points.
              const Positioned(
                left: 10,
                top: 25,
                child: BarHole(
                  child: SizedBox(
                    width: 44,
                    height: 44,
                    child: UiKitView(viewType: 'glass'),
                  ),
                ),
              ),
              // Flutter-drawn: keeps the wash behind it.
              const Positioned(
                left: 100,
                top: 25,
                child: BarHole(child: SizedBox(width: 60, height: 44)),
              ),
            ],
          ),
        ),
      ),
    );
    await tester.pump();
    expect(holes.rects, [10.0, 5.0, 44.0, 44.0]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
