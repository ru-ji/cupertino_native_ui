import 'package:cupertino_native_ui/cupertino_native_ui.dart';
import 'package:flutter/cupertino.dart';
import 'package:flutter/services.dart' show HapticFeedback;

/// Content of the native sheet demo: a "New Event" composer drawn by
/// Flutter, in its own engine, under the sheet's native chrome (title, ✕ /
/// Add, search field and segmented control, configured from
/// `CupertinoNativeSheet.show`).
///
/// It shows what only a Flutter child can: a preview card, a colour row and
/// a week strip that animate together, and a timeline whose slot is dragged
/// and resized by hand. A self-sized Column (same contract as scaffold
/// bodies): the sheet's native ScrollView owns the scrolling.
class NewEventSheetBody extends StatefulWidget {
  const NewEventSheetBody({super.key});

  @override
  State<NewEventSheetBody> createState() => _NewEventSheetBodyState();
}

class _Calendar {
  const _Calendar(this.name, this.color);

  final String name;
  final Color color;
}

const _calendars = [
  _Calendar('Work', Color(0xFF0A84FF)),
  _Calendar('Personal', Color(0xFF30D158)),
  _Calendar('Family', Color(0xFFFF9F0A)),
  _Calendar('Fitness', Color(0xFFFF375F)),
  _Calendar('Travel', Color(0xFFBF5AF2)),
  _Calendar('Focus', Color(0xFF5AC8FA)),
];

const _weekdays = ['Mon', 'Tue', 'Wed', 'Thu', 'Fri', 'Sat', 'Sun'];
const _months = [
  'Jan',
  'Feb',
  'Mar',
  'Apr',
  'May',
  'Jun',
  'Jul',
  'Aug',
  'Sep',
  'Oct',
  'Nov',
  'Dec',
];

/// The timeline's span and step, in hours.
const double _firstHour = 7;
const double _lastHour = 21;
const double _step = 0.25;

String _time(double hours) {
  final minutes = (hours * 60).round();
  return '${minutes ~/ 60}:${(minutes % 60).toString().padLeft(2, '0')}';
}

class _NewEventSheetBodyState extends State<NewEventSheetBody> {
  int _calendar = 0;
  late final List<DateTime> _week;
  late int _day;
  double _start = 9.5;
  double _end = 10.25;

  @override
  void initState() {
    super.initState();
    final now = DateTime.now();
    _week = [
      for (var i = 0; i < 7; i++)
        DateTime(now.year, now.month, now.day - (now.weekday - 1) + i),
    ];
    _day = now.weekday - 1;
  }

  @override
  Widget build(BuildContext context) {
    final calendar = _calendars[_calendar];
    final theme = CupertinoTheme.of(context);
    return ColoredBox(
      color: CupertinoColors.systemGroupedBackground.resolveFrom(context),
      child: DefaultTextStyle(
        style: theme.textTheme.textStyle.copyWith(
          color: CupertinoColors.label.resolveFrom(context),
        ),
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 12, 16, 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _PreviewCard(
                calendar: calendar,
                day: _week[_day],
                start: _start,
                end: _end,
              ),
              const _Header('Calendar'),
              _ColorRow(
                selected: _calendar,
                onSelected: (i) => setState(() => _calendar = i),
              ),
              const _Header('Day'),
              _DayStrip(
                week: _week,
                selected: _day,
                color: calendar.color,
                onSelected: (i) => setState(() => _day = i),
              ),
              const _Header('Time'),
              _Timeline(
                start: _start,
                end: _end,
                color: calendar.color,
                onChanged: (start, end) => setState(() {
                  _start = start;
                  _end = end;
                }),
              ),
              const SizedBox(height: 28),
              CupertinoButton.filled(
                color: calendar.color,
                borderRadius: BorderRadius.circular(14),
                onPressed: CupertinoNativeSheet.pop,
                child: const Text(
                  'Dismiss from Flutter',
                  style: TextStyle(fontWeight: FontWeight.w600),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Header extends StatelessWidget {
  const _Header(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(4, 28, 4, 10),
    child: Text(
      text.toUpperCase(),
      style: TextStyle(
        fontSize: 13,
        letterSpacing: 0.4,
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
    ),
  );
}

/// The event as it will look, in its calendar's colour.
class _PreviewCard extends StatelessWidget {
  const _PreviewCard({
    required this.calendar,
    required this.day,
    required this.start,
    required this.end,
  });

  final _Calendar calendar;
  final DateTime day;
  final double start;
  final double end;

  @override
  Widget build(BuildContext context) {
    const white = CupertinoColors.white;
    final when =
        '${_weekdays[day.weekday - 1]} ${day.day} ${_months[day.month - 1]}'
        '  ·  ${_time(start)} – ${_time(end)}';
    return TweenAnimationBuilder<Color?>(
      tween: ColorTween(end: calendar.color),
      duration: const Duration(milliseconds: 450),
      curve: Curves.easeOutCubic,
      builder: (context, color, _) {
        final c = color!;
        return Container(
          height: 200,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(26),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: [
                Color.lerp(c, white, 0.28)!,
                c,
                Color.lerp(c, CupertinoColors.black, 0.3)!,
              ],
            ),
            boxShadow: [
              BoxShadow(
                color: c.withValues(alpha: 0.35),
                blurRadius: 28,
                offset: const Offset(0, 12),
              ),
            ],
          ),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(26),
            child: Stack(
              children: [
                const Positioned.fill(
                  child: CustomPaint(painter: _RingsPainter()),
                ),
                Padding(
                  padding: const EdgeInsets.all(22),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      AnimatedSwitcher(
                        duration: const Duration(milliseconds: 250),
                        child: Text(
                          calendar.name.toUpperCase(),
                          key: ValueKey(calendar.name),
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.4,
                            color: white.withValues(alpha: 0.8),
                          ),
                        ),
                      ),
                      const Spacer(),
                      const Text(
                        'Team Standup',
                        style: TextStyle(
                          fontSize: 30,
                          fontWeight: FontWeight.w700,
                          letterSpacing: -0.6,
                          color: white,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        when,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(
                          fontSize: 15,
                          fontWeight: FontWeight.w500,
                          color: white.withValues(alpha: 0.9),
                          fontFeatures: const [FontFeature.tabularFigures()],
                        ),
                      ),
                      const SizedBox(height: 16),
                      _Attendees(ring: c),
                    ],
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

/// Soft rings in the card's corner.
class _RingsPainter extends CustomPainter {
  const _RingsPainter();

  @override
  void paint(Canvas canvas, Size size) {
    final centre = Offset(size.width - 24, 18);
    final paint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1.5;
    for (var i = 1; i <= 5; i++) {
      paint.color = CupertinoColors.white.withValues(alpha: 0.2 - i * 0.03);
      canvas.drawCircle(centre, 34.0 * i, paint);
    }
  }

  @override
  bool shouldRepaint(_RingsPainter oldDelegate) => false;
}

/// Overlapping initials, as Calendar shows invitees.
class _Attendees extends StatelessWidget {
  const _Attendees({required this.ring});

  final Color ring;

  @override
  Widget build(BuildContext context) {
    const people = [
      ('AL', Color(0xFFFFD60A)),
      ('MK', Color(0xFF64D2FF)),
      ('JS', Color(0xFFFF9F0A)),
    ];
    return Row(
      children: [
        SizedBox(
          width: 30.0 + 20 * (people.length - 1),
          height: 30,
          child: Stack(
            children: [
              for (final (i, (initials, color)) in people.indexed)
                Positioned(
                  left: 20.0 * i,
                  child: Container(
                    width: 30,
                    height: 30,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: color,
                      shape: BoxShape.circle,
                      border: Border.all(color: ring, width: 2),
                    ),
                    child: Text(
                      initials,
                      style: const TextStyle(
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                        color: Color(0xFF1C1C1E),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
        const SizedBox(width: 8),
        Flexible(
          child: Text(
            '+2 invited',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: TextStyle(
              fontSize: 13,
              fontWeight: FontWeight.w600,
              color: CupertinoColors.white.withValues(alpha: 0.85),
            ),
          ),
        ),
      ],
    );
  }
}

/// One dot per calendar; the chosen one wears a ring and a check.
class _ColorRow extends StatelessWidget {
  const _ColorRow({required this.selected, required this.onSelected});

  final int selected;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 14),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
          context,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          for (final (i, calendar) in _calendars.indexed)
            Semantics(
              button: true,
              selected: i == selected,
              label: calendar.name,
              child: GestureDetector(
                onTap: () {
                  HapticFeedback.selectionClick();
                  onSelected(i);
                },
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 220),
                  curve: Curves.easeOut,
                  width: 42,
                  height: 42,
                  padding: EdgeInsets.all(i == selected ? 3 : 0),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    border: Border.all(
                      color: i == selected
                          ? calendar.color
                          : const Color(0x00000000),
                      width: 2.5,
                    ),
                  ),
                  child: DecoratedBox(
                    decoration: BoxDecoration(
                      color: calendar.color,
                      shape: BoxShape.circle,
                    ),
                    child: AnimatedScale(
                      scale: i == selected ? 1 : 0,
                      duration: const Duration(milliseconds: 220),
                      curve: Curves.easeOutBack,
                      child: const Icon(
                        CupertinoIcons.checkmark_alt,
                        size: 18,
                        color: CupertinoColors.white,
                      ),
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}

/// The week, one pill a day; the chosen day fills with the calendar colour.
class _DayStrip extends StatelessWidget {
  const _DayStrip({
    required this.week,
    required this.selected,
    required this.color,
    required this.onSelected,
  });

  final List<DateTime> week;
  final int selected;
  final Color color;
  final ValueChanged<int> onSelected;

  @override
  Widget build(BuildContext context) {
    final card = CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
      context,
    );
    final label = CupertinoColors.label.resolveFrom(context);
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    final now = DateTime.now();
    return Row(
      children: [
        for (final (i, day) in week.indexed)
          Expanded(
            child: GestureDetector(
              onTap: () {
                HapticFeedback.selectionClick();
                onSelected(i);
              },
              child: AnimatedContainer(
                duration: const Duration(milliseconds: 260),
                curve: Curves.easeOutCubic,
                margin: const EdgeInsets.symmetric(horizontal: 3),
                padding: const EdgeInsets.symmetric(vertical: 10),
                decoration: BoxDecoration(
                  color: i == selected ? color : card,
                  borderRadius: BorderRadius.circular(16),
                  boxShadow: [
                    if (i == selected)
                      BoxShadow(
                        color: color.withValues(alpha: 0.4),
                        blurRadius: 12,
                        offset: const Offset(0, 4),
                      ),
                  ],
                ),
                child: Column(
                  children: [
                    Text(
                      _weekdays[day.weekday - 1].substring(0, 1),
                      style: TextStyle(
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                        color: i == selected
                            ? CupertinoColors.white.withValues(alpha: 0.85)
                            : secondary,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${day.day}',
                      style: TextStyle(
                        fontSize: 19,
                        fontWeight: FontWeight.w700,
                        color: i == selected ? CupertinoColors.white : label,
                      ),
                    ),
                    const SizedBox(height: 4),
                    // Today, as Calendar marks it.
                    Container(
                      width: 5,
                      height: 5,
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        color:
                            day.year == now.year &&
                                day.month == now.month &&
                                day.day == now.day
                            ? (i == selected ? CupertinoColors.white : color)
                            : const Color(0x00000000),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
      ],
    );
  }
}

/// The day from [_firstHour] to [_lastHour], with the event's slot on it:
/// drag the slot to move it, its right handle to resize it, or tap the track
/// to put it there. Snaps to quarter hours.
class _Timeline extends StatefulWidget {
  const _Timeline({
    required this.start,
    required this.end,
    required this.color,
    required this.onChanged,
  });

  final double start;
  final double end;
  final Color color;
  final void Function(double start, double end) onChanged;

  @override
  State<_Timeline> createState() => _TimelineState();
}

class _TimelineState extends State<_Timeline> {
  static const double _inset = 14;
  static const double _handleReach = 22;

  bool _resizing = false;
  double _grab = 0;

  double _hoursPerPoint(double width) =>
      (_lastHour - _firstHour) / (width - 2 * _inset);

  double _hoursAt(double x, double width) =>
      _firstHour + (x - _inset) * _hoursPerPoint(width);

  double _xOf(double hours, double width) =>
      _inset + (hours - _firstHour) / _hoursPerPoint(width);

  static double _snap(double hours) => (hours / _step).round() * _step;

  void _emit(double start, double end) {
    start = _snap(start);
    end = _snap(end);
    if (start == widget.start && end == widget.end) return;
    HapticFeedback.selectionClick();
    widget.onChanged(start, end);
  }

  void _moveTo(double centre) {
    final length = widget.end - widget.start;
    final start = (centre - length / 2).clamp(_firstHour, _lastHour - length);
    _emit(start, start + length);
  }

  @override
  Widget build(BuildContext context) {
    final length = widget.end - widget.start;
    final minutes = (length * 60).round();
    final duration = minutes >= 60
        ? '${minutes ~/ 60} h${minutes % 60 == 0 ? '' : ' ${minutes % 60} min'}'
        : '$minutes min';
    return Container(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 12),
      decoration: BoxDecoration(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
          context,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: _inset + 2),
            child: Row(
              children: [
                Expanded(
                  child: FittedBox(
                    fit: BoxFit.scaleDown,
                    alignment: Alignment.centerLeft,
                    child: Text(
                      '${_time(widget.start)} – ${_time(widget.end)}',
                      style: const TextStyle(
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                        letterSpacing: -0.4,
                        fontFeatures: [FontFeature.tabularFigures()],
                      ),
                    ),
                  ),
                ),
                const SizedBox(width: 12),
                Text(
                  duration,
                  style: TextStyle(
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                    color: widget.color,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 14),
          LayoutBuilder(
            builder: (context, constraints) {
              final width = constraints.maxWidth;
              return GestureDetector(
                onTapUp: (d) => _moveTo(_hoursAt(d.localPosition.dx, width)),
                onHorizontalDragStart: (d) {
                  final x = d.localPosition.dx;
                  final right = _xOf(widget.end, width);
                  _resizing = (x - right).abs() <= _handleReach;
                  _grab = _hoursAt(x, width) - widget.start;
                },
                onHorizontalDragUpdate: (d) {
                  final at = _hoursAt(d.localPosition.dx, width);
                  if (_resizing) {
                    _emit(
                      widget.start,
                      at.clamp(widget.start + _step, _lastHour),
                    );
                  } else {
                    final start = (at - _grab).clamp(
                      _firstHour,
                      _lastHour - length,
                    );
                    _emit(start, start + length);
                  }
                },
                child: CustomPaint(
                  size: Size(width, 70),
                  painter: _TimelinePainter(
                    start: widget.start,
                    end: widget.end,
                    color: widget.color,
                    inset: _inset,
                    track: CupertinoColors.tertiarySystemFill.resolveFrom(
                      context,
                    ),
                    tick: CupertinoColors.separator.resolveFrom(context),
                    label: CupertinoColors.secondaryLabel.resolveFrom(context),
                  ),
                ),
              );
            },
          ),
        ],
      ),
    );
  }
}

class _TimelinePainter extends CustomPainter {
  _TimelinePainter({
    required this.start,
    required this.end,
    required this.color,
    required this.inset,
    required this.track,
    required this.tick,
    required this.label,
  });

  final double start;
  final double end;
  final Color color;
  final double inset;
  final Color track;
  final Color tick;
  final Color label;

  @override
  void paint(Canvas canvas, Size size) {
    const top = 6.0;
    const height = 36.0;
    final span = _lastHour - _firstHour;
    double x(double hours) =>
        inset + (hours - _firstHour) / span * (size.width - 2 * inset);

    // The day.
    canvas.drawRRect(
      RRect.fromLTRBR(
        inset,
        top,
        size.width - inset,
        top + height,
        const Radius.circular(10),
      ),
      Paint()..color = track,
    );

    // Hours, and every other one named.
    final tickPaint = Paint()
      ..color = tick
      ..strokeWidth = 1;
    for (var h = _firstHour; h <= _lastHour; h++) {
      final dx = x(h);
      canvas.drawLine(
        Offset(dx, top + height - 8),
        Offset(dx, top + height - 2),
        tickPaint,
      );
      if (h.toInt().isOdd) continue;
      final text = TextPainter(
        text: TextSpan(
          text: '${h.toInt()}',
          style: TextStyle(
            fontSize: 11,
            fontWeight: FontWeight.w500,
            color: label,
          ),
        ),
        textDirection: TextDirection.ltr,
      )..layout();
      text.paint(canvas, Offset(dx - text.width / 2, top + height + 6));
      text.dispose();
    }

    // The slot, its glow and its handle.
    final slot = RRect.fromLTRBR(
      x(start),
      top,
      x(end),
      top + height,
      const Radius.circular(10),
    );
    canvas.drawRRect(
      slot.shift(const Offset(0, 4)),
      Paint()
        ..color = color.withValues(alpha: 0.35)
        ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
    );
    canvas.drawRRect(
      slot,
      Paint()
        ..shader = LinearGradient(
          colors: [Color.lerp(color, CupertinoColors.white, 0.2)!, color],
        ).createShader(slot.outerRect),
    );
    canvas.drawRRect(
      RRect.fromLTRBR(
        x(end) - 9,
        top + height / 2 - 9,
        x(end) - 5,
        top + height / 2 + 9,
        const Radius.circular(2),
      ),
      Paint()..color = CupertinoColors.white.withValues(alpha: 0.9),
    );
  }

  @override
  bool shouldRepaint(_TimelinePainter old) =>
      old.start != start ||
      old.end != end ||
      old.color != color ||
      old.track != track ||
      old.tick != tick ||
      old.label != label;
}
