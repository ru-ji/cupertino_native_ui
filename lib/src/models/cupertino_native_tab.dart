// The deprecated [CupertinoNativeTab.systemImage] has to keep working until
// it is removed, so this file necessarily reads it.
// ignore_for_file: deprecated_member_use_from_same_package

import '../cupertino_native_scaffold_navigation_bar.dart';
import 'cupertino_native_icon.dart';

enum CupertinoNativeTabRole { search }

class CupertinoNativeTab {
  final String title;

  /// Optional native icon for this tab. When provided, the icon is rendered
  /// via [CupertinoNativeIcon] (SF Symbol or Flutter glyph). When null,
  /// falls back to [systemImage] for backward compatibility.
  final CupertinoNativeIcon? icon;

  /// Raw SF Symbol name string — kept for backward compatibility. Prefer
  /// using [icon] with [CupertinoNativeIcon.symbol] or [CupertinoNativeIcon.named]
  /// for consistency with bar items.
  @Deprecated(
    'Use icon: CupertinoNativeIcon.symbol(...) or .named(...) instead',
  )
  final String? systemImage;

  final String id;
  final CupertinoNativeTabRole? role;

  /// Optional native `.searchable` field for this tab (inside
  /// [CupertinoNativePageScaffold]). Most useful on a [CupertinoNativeTabRole.search]
  /// tab, where iOS presents the tab itself as a search field. Your tab body
  /// renders the results via [CupertinoNativePageScaffold.searchState].
  final CupertinoNativeSearchField? search;

  const CupertinoNativeTab({
    required this.title,
    required this.id,
    this.icon,
    @Deprecated(
      'Use icon: CupertinoNativeIcon.symbol(...) or .named(...) instead',
    )
    this.systemImage,
    this.role,
    this.search,
  });

  /// Resolved SF Symbol name: from [icon] if it's an SF Symbol,
  /// or from legacy [systemImage].
  String? get resolvedSymbolName {
    if (icon case CupertinoNativeIcon i when i.sfSymbol != null) {
      return i.sfSymbol;
    }
    return systemImage;
  }

  Map<String, dynamic> toMap() {
    return {
      'title': title,
      'icon': icon?.toMap(),
      'systemImage': systemImage,
      'id': id,
      'role': role?.name,
      'search': search?.toMap(),
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CupertinoNativeTab &&
        other.title == title &&
        other.icon == icon &&
        other.systemImage == systemImage &&
        other.id == id &&
        other.role == role;
  }

  @override
  int get hashCode => Object.hash(title, icon, systemImage, id, role);
}
