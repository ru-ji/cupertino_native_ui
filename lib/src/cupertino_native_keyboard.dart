import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Where the keyboard is, right now.
@immutable
class CupertinoKeyboardMetrics {
  const CupertinoKeyboardMetrics({
    this.height = 0,
    this.progress = 0,
    this.isAnimating = false,
    this.targetHeight = 0,
    this.isTracking = false,
  });

  /// Visible keyboard height in logical pixels, *this frame* — mid-animation
  /// and mid-drag, not just at rest.
  final double height;

  /// [height] as a fraction of [targetHeight], 0 to 1.
  final double progress;

  /// Whether the keyboard is moving (animating or being dragged).
  final bool isAnimating;

  /// Height the current transition is heading for. 0 while hiding.
  final double targetHeight;

  /// Whether the native side has reported anything yet. False for the frame
  /// or two between the first listener attaching and the first event, where
  /// [height] is 0 because nothing has been measured — not because the
  /// keyboard is down.
  final bool isTracking;

  bool get isVisible => height > 0;

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      (other is CupertinoKeyboardMetrics &&
          other.height == height &&
          other.progress == progress &&
          other.isAnimating == isAnimating &&
          other.targetHeight == targetHeight &&
          other.isTracking == isTracking);

  @override
  int get hashCode =>
      Object.hash(height, progress, isAnimating, targetHeight, isTracking);

  @override
  String toString() =>
      'CupertinoKeyboardMetrics(height: $height, progress: $progress, '
      'isAnimating: $isAnimating)';
}

/// The keyboard's live position, frame by frame.
///
/// Flutter only learns the keyboard's *end* state — `MediaQuery.viewInsets`
/// jumps straight to the final height — and then animates over it on a curve
/// of its own. Anything that moves with the keyboard therefore drifts out of
/// step with it, and a keyboard dragged down with a finger doesn't move it at
/// all.
///
/// This listenable follows the real keyboard: a `CADisplayLink` reads the
/// presentation layer of a view pinned to the host's `keyboardLayoutGuide`
/// while UIKit animates it, and KVO catches the steps of an interactive drag.
/// (The technique is the one `react-native-keyboard-controller` uses; on iOS
/// 26 it needs no private API.)
///
/// ```dart
/// ValueListenableBuilder(
///   valueListenable: CupertinoNativeKeyboard.metrics,
///   builder: (context, kb, child) =>
///       Padding(padding: EdgeInsets.only(bottom: kb.height), child: child!),
///   child: composer,
/// )
/// ```
///
/// Or let [CupertinoKeyboardAvoider] do that for you.
///
/// Observation starts with the first listener and stops with the last, so it
/// costs nothing when nobody is watching. While the keyboard moves it delivers
/// one platform message per frame (up to 120/s); it is idle otherwise.
///
/// iOS only — elsewhere [metrics] stays at zero and never notifies.
abstract final class CupertinoNativeKeyboard {
  static const _channel = MethodChannel('cupertino_widgets/keyboard');
  static const _control = MethodChannel('com.example.cupertino_widgets/alert');

  static final _KeyboardNotifier _notifier = _KeyboardNotifier();

  /// The live metrics. Listening to it starts native observation.
  static ValueListenable<CupertinoKeyboardMetrics> get metrics => _notifier;

  /// The current value without subscribing. Zero until something listens —
  /// nothing is being observed before that.
  static CupertinoKeyboardMetrics get value => _notifier.value;
}

class _KeyboardNotifier extends ValueNotifier<CupertinoKeyboardMetrics> {
  _KeyboardNotifier() : super(const CupertinoKeyboardMetrics());

  int _listeners = 0;
  bool _handlerInstalled = false;

  @override
  void addListener(VoidCallback listener) {
    super.addListener(listener);
    _listeners++;
    if (_listeners == 1) _start();
  }

  @override
  void removeListener(VoidCallback listener) {
    super.removeListener(listener);
    _listeners--;
    if (_listeners == 0) _stop();
  }

  void _start() {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    if (!_handlerInstalled) {
      _handlerInstalled = true;
      CupertinoNativeKeyboard._channel.setMethodCallHandler(_handle);
    }
    CupertinoNativeKeyboard._control.invokeMethod<void>(
      'startKeyboardObserver',
    );
  }

  void _stop() {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    CupertinoNativeKeyboard._control.invokeMethod<void>('stopKeyboardObserver');
    value = const CupertinoKeyboardMetrics();
  }

  Future<dynamic> _handle(MethodCall call) async {
    if (call.method != 'keyboard') return null;
    final args = (call.arguments as Map).cast<String, dynamic>();
    final event = args['event'] as String? ?? '';
    final height = (args['height'] as num?)?.toDouble() ?? 0;
    final progress = (args['progress'] as num?)?.toDouble() ?? 0;

    switch (event) {
      case 'willChange':
        // The height reported here is where the keyboard is GOING, not where
        // it is — publishing it as the current height is exactly the jump
        // this class exists to avoid.
        value = CupertinoKeyboardMetrics(
          height: value.height,
          progress: value.progress,
          isAnimating: true,
          targetHeight: height,
          isTracking: true,
        );
      case 'didChange':
        value = CupertinoKeyboardMetrics(
          height: height,
          progress: progress,
          isAnimating: false,
          targetHeight: height,
          isTracking: true,
        );
      case 'move':
      case 'interactive':
        value = CupertinoKeyboardMetrics(
          height: height,
          progress: progress,
          isAnimating: true,
          targetHeight: value.targetHeight,
          isTracking: true,
        );
    }
    return null;
  }
}

/// Pads its child by the keyboard's live height, so it rides the real
/// keyboard instead of Flutter's approximation of it.
///
/// Off iOS it falls back to `MediaQuery.viewInsets.bottom`, so the same tree
/// still behaves sensibly everywhere.
class CupertinoKeyboardAvoider extends StatelessWidget {
  const CupertinoKeyboardAvoider({
    super.key,
    required this.child,
    this.offset = 0,
    this.ignoreBottomSafeArea = false,
  });

  final Widget child;

  /// Extra gap kept between the child and the keyboard.
  final double offset;

  /// The keyboard covers the home indicator, so its height already includes
  /// that area. When the child is inside a `SafeArea` the bottom inset is
  /// counted twice; set this to subtract it back out.
  final bool ignoreBottomSafeArea;

  @override
  Widget build(BuildContext context) {
    final safeBottom = ignoreBottomSafeArea
        ? MediaQuery.paddingOf(context).bottom
        : 0.0;

    if (defaultTargetPlatform != TargetPlatform.iOS) {
      return Padding(
        padding: EdgeInsets.only(
          bottom:
              (MediaQuery.viewInsetsOf(context).bottom - safeBottom + offset)
                  .clamp(0.0, double.infinity),
        ),
        child: child,
      );
    }

    return ValueListenableBuilder<CupertinoKeyboardMetrics>(
      valueListenable: CupertinoNativeKeyboard.metrics,
      builder: (context, keyboard, child) => Padding(
        padding: EdgeInsets.only(
          bottom:
              (keyboard.height - safeBottom + (keyboard.isVisible ? offset : 0))
                  .clamp(0.0, double.infinity),
        ),
        child: child,
      ),
      child: child,
    );
  }
}

/// Replaces `MediaQuery.viewInsets.bottom` with the keyboard's **live**
/// height for everything below it.
///
/// This is the automatic path: wrap it once and nothing else in the tree has
/// to know this package exists. Every widget that already reacts to
/// `viewInsets` — `Scaffold.resizeToAvoidBottomInset`, `CupertinoPageScaffold`,
/// bottom sheets, `Scrollable`'s scroll-into-view — starts following the real
/// keyboard instead of the value Flutter publishes once the animation is over.
///
/// ```dart
/// MaterialApp(
///   builder: (context, child) =>
///       CupertinoNativeKeyboardScope(child: child!),
///   home: const HomePage(),
/// )
/// ```
///
/// Bodies of a [CupertinoNativePageScaffold] already have it: the package
/// owns their root, so there it needs no wrapping at all.
///
/// Off iOS it returns [child] untouched, so the tree is unchanged.
class CupertinoNativeKeyboardScope extends StatelessWidget {
  const CupertinoNativeKeyboardScope({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    if (defaultTargetPlatform != TargetPlatform.iOS) return child;
    return ValueListenableBuilder<CupertinoKeyboardMetrics>(
      valueListenable: CupertinoNativeKeyboard.metrics,
      builder: (context, keyboard, child) {
        final media = MediaQuery.of(context);
        // Until the first native event lands, `height` is 0 because nothing
        // has been measured yet — publishing it would tell the tree the
        // keyboard is down when it may not be. Flutter's own value stands in.
        final bottom = keyboard.isTracking
            ? keyboard.height
            : media.viewInsets.bottom;
        return MediaQuery(
          data: media.copyWith(
            viewInsets: media.viewInsets.copyWith(bottom: bottom),
          ),
          child: child!,
        );
      },
      child: child,
    );
  }
}
