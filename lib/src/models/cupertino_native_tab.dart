import '../cupertino_native_scaffold_navigation_bar.dart';
import 'cupertino_native_icon.dart';

enum CupertinoNativeTabRole {
  search,

  /// `TabRole.prominent` (iOS 27+): stronger emphasis in the tab bar. A
  /// plain tab on earlier releases.
  prominent,
}

class CupertinoNativeTab {
  final String title;

  /// The tab's icon: an SF Symbol, [CupertinoNativeIcon.symbol] or
  /// [CupertinoNativeIcon.named].
  final CupertinoNativeIcon? icon;

  final String id;
  final CupertinoNativeTabRole? role;

  /// Optional native `.searchable` field for this tab (inside
  /// [CupertinoNativePageScaffold]). Most useful on a [CupertinoNativeTabRole.search]
  /// tab, where iOS presents the tab itself as a search field. Your tab body
  /// renders the results via [CupertinoNativePageScaffold.searchState].
  final CupertinoNativeSearchField? search;

  /// Red badge on the tab icon: a count like `'3'`, or any short text.
  /// SwiftUI `.badge` / `UITabBarItem.badgeValue`.
  final String? badge;

  const CupertinoNativeTab({
    required this.title,
    required this.id,
    this.icon,
    this.role,
    this.search,
    this.badge,
  });

  /// The SF Symbol name of [icon].
  String? get resolvedSymbolName => icon?.sfSymbol;

  Map<String, dynamic> toMap({bool isDark = false}) {
    return {
      'title': title,
      'icon': icon?.toMap(isDark: isDark),
      'id': id,
      'role': role?.name,
      'search': search?.toMap(),
      'badge': badge,
    };
  }

  @override
  bool operator ==(Object other) {
    if (identical(this, other)) return true;
    return other is CupertinoNativeTab &&
        other.title == title &&
        other.icon == icon &&
        other.id == id &&
        other.role == role &&
        other.badge == badge;
  }

  @override
  int get hashCode => Object.hash(title, icon, id, role, badge);
}
