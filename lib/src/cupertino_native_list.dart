import 'package:flutter/widgets.dart';

import 'callbacks.dart';

import 'internal/native_collection_view.dart';
import 'models/cupertino_native_list_section.dart';

/// The visual style of a [CupertinoNativeList], mirroring SwiftUI's
/// `ListStyle`.
enum CupertinoNativeListStyle {
  automatic,
  plain,
  grouped,
  insetGrouped,
  sidebar,
}

/// A native SwiftUI `List` with `Section`s, rendered on iOS as a real
/// `UICollectionView`-backed list (grouped/inset-grouped/plain styles, native
/// row separators, headers/footers).
///
/// ```dart
/// CupertinoNativeList(
///   style: CupertinoNativeListStyle.insetGrouped,
///   sections: [
///     CupertinoNativeListSection(
///       header: 'Languages',
///       rows: [
///         CupertinoNativeListTile(id: 'swift', title: 'Swift', showChevron: true),
///         CupertinoNativeListTile(id: 'dart', title: 'Dart', showChevron: true),
///       ],
///     ),
///   ],
///   onRowTap: (id) => debugPrint('tapped $id'),
/// )
/// ```
///
/// By default the list self-sizes to its content (iOS 16+) so it can sit inside
/// a Flutter `Column`/`ListView`. Pass a [height] (optionally with
/// [scrollable]) to give it a fixed, internally-scrolling region instead.
class CupertinoNativeList extends StatelessWidget {
  final List<CupertinoNativeListSection> sections;
  final CupertinoNativeListStyle style;
  final double? height;
  final bool scrollable;
  final Color? activeColor;

  /// Corner radius of the inset-grouped section cards. Null matches the
  /// running iOS version's Settings app automatically (26 on iOS 26+, 10 on
  /// earlier releases); set a value to override.
  final double? cornerRadius;

  final CupertinoNativeListTileCallback? onRowTap;
  final CupertinoNativeListToggleCallback? onToggle;

  const CupertinoNativeList({
    super.key,
    required this.sections,
    this.style = CupertinoNativeListStyle.insetGrouped,
    this.height,
    this.scrollable = false,
    this.activeColor,
    this.cornerRadius,
    this.onRowTap,
    this.onToggle,
  });

  @override
  Widget build(BuildContext context) {
    return NativeCollectionView(
      variant: 'list',
      style: style.name,
      sections: sections,
      height: height,
      scrollable: scrollable,
      activeColor: activeColor,
      cornerRadius: cornerRadius,
      onRowTap: onRowTap,
      onToggle: onToggle,
    );
  }
}
