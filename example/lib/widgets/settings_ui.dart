import 'package:cupertino_widgets/cupertino_widgets.dart';
import 'package:flutter/cupertino.dart'
    show CupertinoColors, CupertinoDynamicColor, CupertinoTheme;
import 'package:flutter/material.dart' show Scaffold;
import 'package:flutter/services.dart' show SystemUiOverlayStyle;
import 'package:flutter/widgets.dart';

/// Shared demo page scaffolding: a [CupertinoNativeSliverNavigationBar] page
/// with inset-grouped sections.

/// Inset-grouped card corner radius, matching iOS 26's Settings app (and the
/// plugin's native list/form default on iOS 26+).
const double kCardCornerRadius = 26;

/// A white page under a [CupertinoNativeSliverNavigationBar], which brings its own back
/// button, Liquid Glass actions, scroll edge effect and title collapse.
class DemoScaffold extends StatelessWidget {
  const DemoScaffold({
    super.key,
    required this.title,
    required this.children,
    this.largeTitle = false,
    this.bottomBar,
  });

  final String title;
  final List<Widget> children;

  /// Whether the title starts as a 34pt heading and collapses into the bar on
  /// scroll (iOS Settings style). False keeps it inline, for screens whose
  /// content is the hero and needs the room.
  final bool largeTitle;

  /// Optional widget floated at the bottom center (e.g. a native tab bar).
  final Widget? bottomBar;

  @override
  Widget build(BuildContext context) {
    final body = CustomScrollView(
      slivers: [
        CupertinoNativeSliverNavigationBar(
          largeTitle: title,
          expandedTitle: largeTitle,
          leading: Navigator.canPop(context)
              ? CupertinoNativeButton.glass(
                  borderShape: CupertinoNativeButtonBorderShape.circle,
                  onPressed: () => Navigator.pop(context),
                  child: CupertinoSymbolImage.symbol(
                    CupertinoSymbols.chevronBackward,
                  ),
                )
              : null,
          tintColor: CupertinoColors.systemGroupedBackground,
        ),
        SliverPadding(
          padding: EdgeInsets.only(
            bottom:
                MediaQuery.paddingOf(context).bottom +
                (bottomBar != null ? 88 : 40),
          ),
          sliver: SliverList.list(children: children),
        ),
      ],
    );

    // Follows the APP theme (incl. the home toggle's forced mode), not the
    // device setting — platformBrightnessOf would ignore a forced ThemeMode.
    final isDark = CupertinoTheme.brightnessOf(context) == Brightness.dark;

    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: isDark ? SystemUiOverlayStyle.light : SystemUiOverlayStyle.dark,
      child: Scaffold(
        backgroundColor: CupertinoColors.systemGroupedBackground.resolveFrom(
          context,
        ),
        body: DefaultTextStyle(
          style: rowTitleStyle(context),
          child: bottomBar == null
              ? body
              : Stack(
                  children: [
                    body,
                    Align(alignment: Alignment.bottomCenter, child: bottomBar!),
                  ],
                ),
        ),
      ),
    );
  }
}

/// One inset-grouped section: uppercase footnote header, rounded card with
/// hairline-separated rows, footnote footer.
class SettingsSection extends StatelessWidget {
  const SettingsSection({
    super.key,
    this.header,
    this.footer,
    required this.children,
    this.separatorIndent = 16,
  });

  final String? header;
  final String? footer;
  final List<Widget> children;
  final double separatorIndent;

  @override
  Widget build(BuildContext context) {
    final separator = Container(
      margin: EdgeInsetsDirectional.only(start: separatorIndent),
      height: 0.5,
      color: CupertinoColors.separator.resolveFrom(context),
    );

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 20),
        if (header != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 0, 32, 8),
            child: Text(header!.toUpperCase(), style: footnoteStyle(context)),
          ),
        Container(
          margin: const EdgeInsets.symmetric(horizontal: 16),
          clipBehavior: Clip.antiAlias,
          decoration: BoxDecoration(
            color: CupertinoDynamicColor.resolve(
              CupertinoColors.secondarySystemGroupedBackground,
              context,
            ),
            borderRadius: BorderRadius.circular(kCardCornerRadius),
          ),
          child: Column(
            children: [
              for (var i = 0; i < children.length; i++) ...[
                children[i],
                if (i < children.length - 1) separator,
              ],
            ],
          ),
        ),
        if (footer != null)
          Padding(
            padding: const EdgeInsets.fromLTRB(32, 8, 32, 0),
            child: Text(footer!, style: footnoteStyle(context)),
          ),
      ],
    );
  }
}

/// A standard settings row: title/subtitle, optional trailing value text,
/// custom trailing widget (toggle, menu, …) and disclosure chevron. Tappable
/// rows highlight like native cells.
class SettingsRow extends StatefulWidget {
  const SettingsRow({
    super.key,
    required this.title,
    this.icon,
    this.subtitle,
    this.value,
    this.trailing,
    this.showChevron = false,
    this.onTap,
    this.titleColor,
  });

  final String title;

  /// The rounded colored tile at the row's start (see [SettingsIcon]).
  final Widget? icon;

  final String? subtitle;
  final String? value;
  final Widget? trailing;
  final bool showChevron;
  final VoidCallback? onTap;
  final Color? titleColor;

  @override
  State<SettingsRow> createState() => _SettingsRowState();
}

class _SettingsRowState extends State<SettingsRow> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final row = Container(
      constraints: const BoxConstraints(minHeight: 46),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      color: _pressed
          ? CupertinoColors.systemGrey4
                .resolveFrom(context)
                .withValues(alpha: 0.5)
          : const Color(0x00000000),
      child: Row(
        children: [
          if (widget.icon != null) ...[widget.icon!, const SizedBox(width: 12)],
          Expanded(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  widget.title,
                  style: rowTitleStyle(context, color: widget.titleColor),
                ),
                if (widget.subtitle != null) ...[
                  const SizedBox(height: 2),
                  Text(widget.subtitle!, style: footnoteStyle(context)),
                ],
              ],
            ),
          ),
          if (widget.value != null)
            Text(widget.value!, style: rowValueStyle(context)),
          if (widget.trailing != null) ...[
            const SizedBox(width: 8),
            widget.trailing!,
          ],
          if (widget.showChevron) ...[
            const SizedBox(width: 10),
            const DisclosureChevron(),
          ],
        ],
      ),
    );

    if (widget.onTap == null) return row;
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: row,
    );
  }
}

/// A row's leading SF Symbol, drawn by [CupertinoSymbolImage] in Flutter's
/// layer tree.
class SettingsIcon extends StatelessWidget {
  const SettingsIcon(this.symbol, {super.key, required this.color});

  final String symbol;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return CupertinoSymbolImage(
      symbol,
      color: CupertinoDynamicColor.resolve(color, context),
    );
  }
}

/// A drawn iOS-style pill button for contexts where the plugin's native
/// button can't render (native scaffold bodies run inside a platform view).
class PillButton extends StatefulWidget {
  const PillButton({
    super.key,
    required this.label,
    required this.onTap,
    this.filled = true,
  });

  final String label;
  final VoidCallback onTap;
  final bool filled;

  @override
  State<PillButton> createState() => _PillButtonState();
}

class _PillButtonState extends State<PillButton> {
  bool _pressed = false;

  @override
  Widget build(BuildContext context) {
    final blue = CupertinoColors.activeBlue.resolveFrom(context);
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) => setState(() => _pressed = true),
      onTapCancel: () => setState(() => _pressed = false),
      onTapUp: (_) => setState(() => _pressed = false),
      onTap: widget.onTap,
      child: AnimatedOpacity(
        opacity: _pressed ? 0.55 : 1,
        duration: const Duration(milliseconds: 80),
        child: Container(
          height: 46,
          padding: const EdgeInsets.symmetric(horizontal: 22),
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: widget.filled ? blue : blue.withValues(alpha: 0.15),
            borderRadius: BorderRadius.circular(23),
          ),
          child: Text(
            widget.label,
            style: TextStyle(
              fontSize: 17,
              fontWeight: FontWeight.w600,
              letterSpacing: -0.43,
              color: widget.filled ? CupertinoColors.white : blue,
            ),
          ),
        ),
      ),
    );
  }
}

/// A drawn iOS-style activity spinner (8 fading spokes), for engine-restricted
/// contexts where the plugin's native progress view can't render.
class ActivitySpinner extends StatefulWidget {
  const ActivitySpinner({super.key, this.size = 24});

  final double size;

  @override
  State<ActivitySpinner> createState() => _ActivitySpinnerState();
}

class _ActivitySpinnerState extends State<ActivitySpinner>
    with SingleTickerProviderStateMixin {
  late final AnimationController _controller = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 900),
  )..repeat();

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final color = CupertinoColors.secondaryLabel.resolveFrom(context);
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) => CustomPaint(
        size: Size.square(widget.size),
        painter: _SpinnerPainter(progress: _controller.value, color: color),
      ),
    );
  }
}

class _SpinnerPainter extends CustomPainter {
  const _SpinnerPainter({required this.progress, required this.color});

  final double progress;
  final Color color;

  static const _spokes = 8;

  @override
  void paint(Canvas canvas, Size size) {
    final center = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    final active = (progress * _spokes).floor();
    final paint = Paint()
      ..strokeWidth = radius * 0.28
      ..strokeCap = StrokeCap.round;

    for (var i = 0; i < _spokes; i++) {
      final fade = ((i - active) % _spokes) / _spokes;
      paint.color = color.withValues(alpha: 0.25 + 0.75 * (1 - fade));
      final angle = i * 2 * 3.1415926 / _spokes;
      final direction = Offset.fromDirection(angle);
      canvas.drawLine(
        center + direction * radius * 0.45,
        center + direction * radius,
        paint,
      );
    }
  }

  @override
  bool shouldRepaint(_SpinnerPainter oldDelegate) =>
      oldDelegate.progress != progress || oldDelegate.color != color;
}

/// The iOS disclosure chevron, drawn.
class DisclosureChevron extends StatelessWidget {
  const DisclosureChevron({super.key});

  @override
  Widget build(BuildContext context) {
    return CustomPaint(
      size: const Size(7, 12),
      painter: _ChevronPainter(
        color: CupertinoColors.tertiaryLabel.resolveFrom(context),
      ),
    );
  }
}

class _ChevronPainter extends CustomPainter {
  const _ChevronPainter({required this.color});

  final Color color;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final path = Path()
      ..moveTo(0.5, 0.5)
      ..lineTo(size.width - 0.5, size.height / 2)
      ..lineTo(0.5, size.height - 0.5);
    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_ChevronPainter oldDelegate) => oldDelegate.color != color;
}

// All styles pin `decoration: none`: outside a Material ancestor, an inherited
// decoration would otherwise fall back to MaterialApp's yellow debug underline.
TextStyle rowTitleStyle(BuildContext context, {Color? color}) => TextStyle(
  fontSize: 17,
  letterSpacing: -0.43,
  decoration: TextDecoration.none,
  color: color ?? CupertinoColors.label.resolveFrom(context),
);

TextStyle rowValueStyle(BuildContext context) => TextStyle(
  fontSize: 17,
  letterSpacing: -0.43,
  decoration: TextDecoration.none,
  color: CupertinoColors.secondaryLabel.resolveFrom(context),
);

TextStyle footnoteStyle(BuildContext context) => TextStyle(
  fontSize: 13,
  letterSpacing: -0.08,
  decoration: TextDecoration.none,
  color: CupertinoColors.secondaryLabel.resolveFrom(context),
);
