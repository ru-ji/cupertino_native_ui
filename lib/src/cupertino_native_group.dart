import 'package:flutter/widgets.dart';

import 'cupertino_native_glass_container.dart';

/// Renders its children as **one** native view.
///
/// A native control dropped into a Flutter layout is a platform view: a real
/// UIView sitting on the Flutter surface. Anything Flutter paints above it
/// needs a separate composited layer, so a form of Flutter labels and native
/// fields ends up as a stack of alternating layers — measured at 26 on a
/// six-row page — and the engine has to keep them all in step. During a route
/// transition it does not always manage it.
///
/// Wrapping the group here removes the alternation: the children are
/// transcribed into SwiftUI and rendered inside a single platform view, the
/// way they would read if you had written them in SwiftUI directly.
///
/// ```dart
/// CupertinoNativeGroup(
///   child: Row(
///     children: [
///       const Text('Notifications'),
///       const Spacer(),
///       CupertinoNativeSwitch(value: on, onChanged: (v) => setState(...)),
///     ],
///   ),
/// )
/// ```
///
/// **The children are read, not mounted.** Only what the transcription
/// accepts can go in — the package's own controls, `Text`, `Row`, `Column`,
/// `Padding`, `SizedBox`, `Spacer` — and a `CupertinoNativeFlutterView` for
/// anything else, which costs an engine. An unsupported widget asserts with
/// that list.
///
/// For a settings-style form, [CupertinoNativeList] is the same idea with the
/// grouped card and rows already built.
class CupertinoNativeGroup extends StatelessWidget {
  const CupertinoNativeGroup({
    super.key,
    required this.child,
    this.padding = EdgeInsets.zero,
    this.width,
    this.height,
  });

  /// The tree to transcribe.
  final Widget child;

  /// Inset between the group's edge and its content.
  final EdgeInsets padding;

  /// Explicit size. Null lets the group hug its content.
  final double? width;
  final double? height;

  @override
  Widget build(BuildContext context) {
    // The glass container is already "one platform view holding a transcribed
    // tree"; `none` is that machinery with no material painted.
    return CupertinoNativeGlassContainer(
      variant: CupertinoGlassVariant.none,
      padding: padding,
      width: width,
      height: height,
      child: child,
    );
  }
}
