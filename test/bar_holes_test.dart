import 'package:cupertino_native_ui/src/internal/bar_holes.dart';
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
              // A wide native item whose glass is only part of it: a tab
              // bar's pill inside its frame: the pill is cut, not the frame.
              const Positioned(
                left: 0,
                top: 60,
                child: BarHole(
                  rects: [Rect.fromLTWH(40, 4, 200, 50)],
                  child: SizedBox(
                    width: 300,
                    height: 80,
                    child: UiKitView(viewType: 'tabbar'),
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
    expect(holes.rects, [10.0, 5.0, 44.0, 44.0, 40.0, 44.0, 200.0, 50.0]);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));
}
