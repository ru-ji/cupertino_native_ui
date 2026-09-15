import 'cupertino_native_icon.dart';

/// The kind of a [CupertinoNativeListRow], which decides how it renders inside
/// the native SwiftUI `List`/`Form` row.
enum CupertinoNativeListRowType {
  /// A plain row: leading icon, title/subtitle, optional trailing [value] and
  /// disclosure chevron. Reports taps via `onRowTap`.
  label,

  /// A row with a trailing native `Toggle`. Reports flips via `onToggle`.
  toggle,

  /// A row rendered as a tappable `Button` (tinted title). Reports taps via
  /// `onRowTap`.
  button,
}

/// A single row in a [CupertinoNativeListSection].
class CupertinoNativeListRow {
  /// Stable identifier reported back in `onRowTap` / `onToggle`.
  final String id;
  final String title;
  final String? subtitle;

  /// Leading icon (SF Symbol or Flutter glyph).
  final CupertinoNativeIcon? icon;

  /// Trailing detail text (right-aligned, secondary color). Ignored for
  /// [CupertinoNativeListRowType.toggle].
  final String? value;

  /// Show a trailing disclosure chevron (`chevron.right`). Ignored for toggle
  /// rows.
  final bool showChevron;

  final CupertinoNativeListRowType type;

  /// Initial on/off state for [CupertinoNativeListRowType.toggle] rows.
  final bool toggleValue;

  final bool enabled;

  const CupertinoNativeListRow({
    required this.id,
    required this.title,
    this.subtitle,
    this.icon,
    this.value,
    this.showChevron = false,
    this.type = CupertinoNativeListRowType.label,
    this.toggleValue = false,
    this.enabled = true,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'icon': icon?.toMap(),
      'value': value,
      'showChevron': showChevron,
      'type': type.name,
      'toggleValue': toggleValue,
      'enabled': enabled,
    };
  }
}
