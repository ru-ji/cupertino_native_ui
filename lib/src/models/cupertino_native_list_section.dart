import 'package:flutter/painting.dart' show EdgeInsets;

import 'cupertino_native_list_tile.dart';

/// A `Section` of a [CupertinoNativeList] or [CupertinoNativeForm], with an
/// optional header/footer and its rows — mirroring SwiftUI's
/// `Section(header:footer:) { ... }`.
///
/// Every spacing metric is optional: left null, SwiftUI decides it from the
/// list style and the system's own metrics (the same values the Settings app
/// uses). Set one only when you want to override that.
class CupertinoNativeListSection {
  final String? header;
  final String? footer;
  final List<CupertinoNativeListTile> children;

  /// Horizontal inset of the section card (inset-grouped/sidebar only).
  /// Null lets SwiftUI decide.
  final double? cardInset;

  /// Padding inside each row. Null lets SwiftUI decide the row's own padding.
  final EdgeInsets? rowPadding;

  /// Gap between sections in the stack. Null lets SwiftUI decide.
  final double? sectionSpacing;

  /// Top+bottom padding around the entire sections stack. Null lets SwiftUI
  /// decide.
  final double? stackPadding;

  /// Minimum row height. Null lets SwiftUI decide.
  final double? minHeight;

  const CupertinoNativeListSection({
    this.header,
    this.footer,
    this.children = const [],
    this.cardInset,
    this.rowPadding,
    this.sectionSpacing,
    this.stackPadding,
    this.minHeight,
  });

  Map<String, dynamic> toMap({bool isDark = false}) {
    return {
      'header': header,
      'footer': footer,
      'rows': children.map((r) => r.toMap(isDark: isDark)).toList(),
      if (cardInset != null) 'cardInset': cardInset,
      if (rowPadding != null)
        'rowPadding': {
          'left': rowPadding!.left,
          'top': rowPadding!.top,
          'right': rowPadding!.right,
          'bottom': rowPadding!.bottom,
        },
      if (sectionSpacing != null) 'sectionSpacing': sectionSpacing,
      if (stackPadding != null) 'stackPadding': stackPadding,
      if (minHeight != null) 'minHeight': minHeight,
    };
  }
}
