import 'package:flutter/widgets.dart';

import 'cupertino_native_icon.dart';

/// The kind of a [CupertinoNativeListTile], which decides how it renders inside
/// the native SwiftUI `List`/`Form` row.
enum CupertinoNativeListTileType {
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
class CupertinoNativeListTile {
  /// Stable identifier reported back in `onRowTap` / `onToggle`.
  final String id;
  final String title;
  final String? subtitle;

  /// Leading icon (SF Symbol or Flutter glyph).
  final CupertinoNativeIcon? leading;

  /// Trailing detail text (right-aligned, secondary color), like
  /// [CupertinoListTile.additionalInfo]. Ignored for
  /// [CupertinoNativeListTileType.toggle].
  final String? additionalInfo;

  /// Show a trailing disclosure chevron (`chevron.right`). Ignored for toggle
  /// rows.
  final bool showChevron;

  final CupertinoNativeListTileType type;

  /// Initial on/off state for [CupertinoNativeListTileType.toggle] rows.
  final bool toggleValue;

  final bool enabled;

  /// A trailing control, transcribed straight into SwiftUI — the same
  /// lowering a `toolbarActions` item goes through, so
  /// `CupertinoNativeSwitch`, `CupertinoNativeSlider`,
  /// `CupertinoNativeButton`, `CupertinoNativeSlidingSegmentedControl` and
  /// friends keep their own callbacks and cost no engine. **Read, not
  /// mounted**: the row is built natively, so only transcribable widgets are
  /// accepted; Flutter content goes through a `CupertinoNativeFlutterView`
  /// island.
  final Widget? trailing;

  const CupertinoNativeListTile({
    required this.id,
    required this.title,
    this.subtitle,
    this.leading,
    this.additionalInfo,
    this.showChevron = false,
    this.type = CupertinoNativeListTileType.label,
    this.toggleValue = false,
    this.enabled = true,
    this.trailing,
  });

  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'title': title,
      'subtitle': subtitle,
      'icon': leading?.toMap(),
      'value': additionalInfo,
      'showChevron': showChevron,
      'type': type.name,
      'toggleValue': toggleValue,
      'enabled': enabled,
    };
  }
}
