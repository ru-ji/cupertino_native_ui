import 'cupertino_native_list_tile.dart';

/// A `Section` of a [CupertinoNativeList] or [CupertinoNativeForm], with an
/// optional header/footer and its rows — mirroring SwiftUI's
/// `Section(header:footer:) { ... }`.
class CupertinoNativeListSection {
  final String? header;
  final String? footer;
  final List<CupertinoNativeListTile> children;

  const CupertinoNativeListSection({
    this.header,
    this.footer,
    this.children = const [],
  });

  Map<String, dynamic> toMap() {
    return {
      'header': header,
      'footer': footer,
      'rows': children.map((r) => r.toMap()).toList(),
    };
  }
}
