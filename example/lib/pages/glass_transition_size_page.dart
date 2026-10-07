import 'package:cupertino_native_ui/cupertino_native_ui.dart';
import 'package:flutter/cupertino.dart';

/// Every glass transition on one backdrop, a row each: tap a glass to play
/// it.
class GlassTransitionSizePage extends StatefulWidget {
  const GlassTransitionSizePage({super.key});

  @override
  State<GlassTransitionSizePage> createState() =>
      _GlassTransitionSizePageState();
}

class _GlassTransitionSizePageState extends State<GlassTransitionSizePage> {
  bool _shown = true;
  bool _swapped = false;
  bool _selecting = false;
  bool _split = false;
  bool _playing = false;
  bool _united = true;

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      navigationBar: const CupertinoNavigationBar(
        middle: Text('Glass Transitions'),
      ),
      child: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 32),
          children: [
            // One backdrop for every row: the glasses refract the same
            // continuous colour, and the rows are wide enough for any of them.
            DecoratedBox(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(24),
                gradient: const LinearGradient(
                  begin: Alignment.topLeft,
                  end: Alignment.bottomRight,
                  colors: [Color(0xFF1A2980), Color(0xFF26D0CE)],
                ),
              ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  children: [
                    _Row(
                      title: 'Arrive',
                      subtitle: 'Materialize',
                      action: _shown
                          ? null
                          : () => setState(() => _shown = true),
                      child: CupertinoNativeGlassGroup(
                        alignment: Alignment.centerRight,
                        transition: CupertinoGlassTransition.materialize,
                        onAction: (_) => setState(() => _shown = false),
                        items: [
                          CupertinoNativeGlassGroupItem(
                            actionId: 'back',
                            glassVisible: _shown,
                            icon: const CupertinoNativeIcon.named(
                              'chevron.backward',
                            ),
                          ),
                        ],
                      ),
                    ),
                    _Row(
                      title: 'Swap',
                      subtitle: 'A new glass in its place',
                      child: CupertinoNativeGlassGroup(
                        alignment: Alignment.centerRight,
                        onAction: (_) => setState(() => _swapped = !_swapped),
                        items: [
                          CupertinoNativeGlassGroupItem(
                            actionId: _swapped ? 'back' : 'more',
                            icon: CupertinoNativeIcon.named(
                              _swapped ? 'chevron.backward' : 'ellipsis',
                            ),
                          ),
                        ],
                      ),
                    ),
                    _Row(
                      title: 'Reshape',
                      subtitle: 'Both glasses replaced',
                      child: CupertinoNativeGlassGroup(
                        alignment: Alignment.centerRight,
                        spacing: 6,
                        onAction: (id) {
                          if (id == 'select' || id == 'close') {
                            setState(() => _selecting = !_selecting);
                          }
                        },
                        items: _selecting
                            ? const [
                                CupertinoNativeGlassGroupItem(
                                  actionId: 'menu.wide',
                                  shape: CupertinoGlassGroupShape.capsule,
                                  icon: CupertinoNativeIcon.named(
                                    'line.3.horizontal',
                                  ),
                                  title: '•••',
                                ),
                                CupertinoNativeGlassGroupItem(
                                  actionId: 'close',
                                  shape: CupertinoGlassGroupShape.capsule,
                                  icon: CupertinoNativeIcon.named('xmark'),
                                  width: 44,
                                ),
                              ]
                            : const [
                                CupertinoNativeGlassGroupItem(
                                  actionId: 'menu',
                                  shape: CupertinoGlassGroupShape.capsule,
                                  icon: CupertinoNativeIcon.named(
                                    'line.3.horizontal',
                                  ),
                                  width: 44,
                                ),
                                CupertinoNativeGlassGroupItem(
                                  actionId: 'select',
                                  shape: CupertinoGlassGroupShape.capsule,
                                  title: 'Select',
                                ),
                              ],
                      ),
                    ),
                    _Row(
                      title: '1 → 2',
                      subtitle: 'A second glass joins',
                      child: CupertinoNativeGlassGroup(
                        alignment: Alignment.centerRight,
                        spacing: 0,
                        onAction: (_) => setState(() => _split = !_split),
                        items: [
                          CupertinoNativeGlassGroupItem(
                            actionId: 'back',
                            icon: const CupertinoNativeIcon.named(
                              'chevron.left',
                            ),
                            width: _split ? 39 : 48,
                            height: 48,
                          ),
                          if (_split)
                            const CupertinoNativeGlassGroupItem(
                              actionId: 'forward',
                              icon: CupertinoNativeIcon.named('chevron.right'),
                              width: 39,
                              height: 48,
                            ),
                        ],
                      ),
                    ),
                    _Row(
                      title: 'Photos',
                      subtitle: 'Out of its neighbour',
                      child: CupertinoNativeGlassGroup(
                        alignment: Alignment.centerRight,
                        spacing: 12,
                        onAction: (_) => setState(() => _playing = !_playing),
                        items: [
                          if (_playing)
                            const CupertinoNativeGlassGroupItem(
                              actionId: 'play',
                              icon: CupertinoNativeIcon.named('play.fill'),
                            ),
                          const CupertinoNativeGlassGroupItem(
                            actionId: 'more',
                            icon: CupertinoNativeIcon.named('ellipsis'),
                          ),
                        ],
                      ),
                    ),
                    _Row(
                      title: 'Union',
                      subtitle: 'One shape, then two',
                      last: true,
                      child: CupertinoNativeGlassGroup(
                        alignment: Alignment.centerRight,
                        spacing: 8,
                        mergeDistance: 4,
                        onAction: (_) => setState(() => _united = !_united),
                        items: [
                          for (final id in ['bold', 'italic'])
                            CupertinoNativeGlassGroupItem(
                              actionId: id,
                              shape: CupertinoGlassGroupShape.capsule,
                              icon: CupertinoNativeIcon.named(id),
                              unionId: _united ? 'style' : null,
                            ),
                        ],
                      ),
                    ),
                  ],
                ),
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 0),
              child: Text(
                'Tap a glass to play its transition, and again to undo it.',
                style: TextStyle(
                  fontSize: 13,
                  color: CupertinoColors.secondaryLabel.resolveFrom(context),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// One transition: its name on the left, its glass on the right, a hairline
/// under it unless it is the last.
class _Row extends StatelessWidget {
  const _Row({
    required this.title,
    required this.subtitle,
    required this.child,
    this.action,
    this.last = false,
  });

  final String title;
  final String subtitle;
  final Widget child;

  /// Brings the glass back, for a transition whose glass leaves.
  final VoidCallback? action;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return Container(
      constraints: const BoxConstraints(minHeight: 84),
      decoration: BoxDecoration(
        border: last
            ? null
            : Border(
                bottom: BorderSide(
                  color: CupertinoColors.white.withValues(alpha: 0.25),
                  width: 0.5,
                ),
              ),
      ),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: CupertinoColors.white,
                    fontSize: 17,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: TextStyle(
                    color: CupertinoColors.white.withValues(alpha: 0.7),
                    fontSize: 13,
                  ),
                ),
              ],
            ),
          ),
          if (action != null)
            CupertinoButton(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              onPressed: action,
              child: const Text(
                'Bring back',
                style: TextStyle(color: CupertinoColors.white, fontSize: 15),
              ),
            ),
          child,
        ],
      ),
    );
  }
}
