import 'package:cupertino_widgets/cupertino_widgets.dart';
import 'package:flutter/cupertino.dart';

/// Shared by the two glass-transition pages: the default one and the custom
/// one. Nothing here is a transition — it is the stage they are played on.
///
/// One card per change: what it is, the glass doing it over a backdrop worth
/// refracting, a sentence on what makes it happen, and the button that plays
/// it. The card is a fixed size and the glass is centred on a hairline, so one
/// state can be held against the other without the page having moved
/// underneath.
class GlassDemoStage extends StatelessWidget {
  const GlassDemoStage({
    super.key,
    required this.title,
    required this.arrow,
    required this.blurb,
    required this.buttonLabel,
    required this.onPressed,
    required this.child,
  });

  /// What the change is called.
  final String title;

  /// The change in item counts — `0 → 1` and the like.
  final String arrow;

  /// One sentence on what makes it happen.
  final String blurb;

  final String buttonLabel;
  final VoidCallback onPressed;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final labels = CupertinoColors.secondaryLabel.resolveFrom(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 26),
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
            context,
          ),
          borderRadius: BorderRadius.circular(26),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 16, 18, 12),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.baseline,
                textBaseline: TextBaseline.alphabetic,
                children: [
                  Expanded(
                    child: Text(
                      title,
                      style: const TextStyle(
                        fontSize: 17,
                        fontWeight: FontWeight.w600,
                        letterSpacing: -0.2,
                      ),
                    ),
                  ),
                  Text(
                    arrow,
                    style: TextStyle(
                      fontSize: 15,
                      color: labels,
                      fontFeatures: const [FontFeature.tabularFigures()],
                    ),
                  ),
                ],
              ),
            ),
            // The stage itself, inset so the card's corner frames it.
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: SizedBox(
                height: 190,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(18),
                  child: Stack(
                    children: [
                      const Positioned.fill(child: _Backdrop()),
                      Align(
                        child: SizedBox(
                          width: 230,
                          height: 1,
                          child: ColoredBox(
                            color: CupertinoColors.white.withValues(alpha: 0.3),
                          ),
                        ),
                      ),
                      Center(child: child),
                    ],
                  ),
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 0),
              child: Text(
                blurb,
                style: TextStyle(fontSize: 13, height: 1.35, color: labels),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(18, 14, 18, 16),
              child: CupertinoNativeButton.tinted(
                expand: true,
                onPressed: onPressed,
                child: Text(buttonLabel),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// Vivid Flutter-drawn artwork for the glass to refract. Busy on purpose: a
/// glass over a flat colour shows almost nothing of what it does.
class _Backdrop extends StatelessWidget {
  const _Backdrop();

  @override
  Widget build(BuildContext context) {
    return const DecoratedBox(
      decoration: BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A2980), Color(0xFF26D0CE)],
        ),
      ),
      child: Stack(
        children: [
          _Blob(top: -50, left: -40, size: 190, color: Color(0xFFFF6B9D)),
          _Blob(bottom: -60, right: -50, size: 210, color: Color(0xFFFFC371)),
          _Blob(top: 40, right: 30, size: 120, color: Color(0xFF7B61FF)),
        ],
      ),
    );
  }
}

class _Blob extends StatelessWidget {
  const _Blob({
    this.top,
    this.left,
    this.right,
    this.bottom,
    required this.size,
    required this.color,
  });

  final double? top, left, right, bottom;
  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Positioned(
      top: top,
      left: left,
      right: right,
      bottom: bottom,
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          gradient: RadialGradient(colors: [color, color.withValues(alpha: 0)]),
        ),
      ),
    );
  }
}
