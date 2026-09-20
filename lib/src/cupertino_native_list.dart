// The builder's parameters are copied into private fields; an initializing
// formal cannot name a private field from a public constructor.
// ignore_for_file: prefer_initializing_formals

import 'package:flutter/widgets.dart';

import 'callbacks.dart';

import 'internal/native_collection_view.dart';
import 'models/cupertino_native_list_section.dart';
import 'models/cupertino_native_list_tile.dart';

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
/// By default the list self-sizes to its content so it can sit inside
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
  }) : _itemCount = null,
       _itemBuilder = null,
       _header = null,
       _footer = null;

  /// One section, built row by row — `ListView.builder`'s shape.
  ///
  /// ```dart
  /// CupertinoNativeList.builder(
  ///   header: 'Contacts',
  ///   itemCount: people.length,
  ///   itemBuilder: (context, i) => CupertinoNativeListTile(
  ///     id: people[i].id,
  ///     title: people[i].name,
  ///     showChevron: true,
  ///   ),
  /// )
  /// ```
  ///
  /// Unlike `ListView.builder` the rows are **not** built lazily: the list is
  /// one native view, and it is handed the whole section at once. The builder
  /// is for writing convenience, not for a long feed — use
  /// `CupertinoNativeListSection` directly if you already hold the rows.
  const CupertinoNativeList.builder({
    super.key,
    required int itemCount,
    required CupertinoNativeListTile Function(BuildContext context, int index)
    itemBuilder,
    String? header,
    String? footer,
    this.style = CupertinoNativeListStyle.insetGrouped,
    this.height,
    this.scrollable = false,
    this.activeColor,
    this.cornerRadius,
    this.onRowTap,
    this.onToggle,
  }) : sections = const [],
       _itemCount = itemCount,
       _itemBuilder = itemBuilder,
       _header = header,
       _footer = footer;


  /// Set by [CupertinoNativeList.builder]; the rows are built in `build`,
  /// where there is a context to hand them.
  final int? _itemCount;
  final CupertinoNativeListTile Function(BuildContext context, int index)?
  _itemBuilder;
  final String? _header;
  final String? _footer;

  @override
  Widget build(BuildContext context) {
    final builder = _itemBuilder;
    final built = builder == null
        ? sections
        : [
            CupertinoNativeListSection(
              header: _header,
              footer: _footer,
              children: [
                for (var i = 0; i < (_itemCount ?? 0); i++) builder(context, i),
              ],
            ),
          ];
    return NativeCollectionView(
      variant: 'list',
      style: style.name,
      sections: built,
      height: height,
      scrollable: scrollable,
      activeColor: activeColor,
      cornerRadius: cornerRadius,
      onRowTap: onRowTap,
      onToggle: onToggle,
    );
  }
}
