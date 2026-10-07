import 'package:flutter/widgets.dart';

import '../cupertino_native_button.dart';
import '../cupertino_native_glass_group.dart';
import '../cupertino_native_menu.dart';
import '../cupertino_symbol_image.dart';
import '../models/cupertino_native_button_extra_options.dart';
import '../models/cupertino_native_icon.dart';
import '../models/cupertino_native_button_style.dart';
import '../models/cupertino_native_menu_item.dart';
import '../models/cupertino_native_toolbar_item.dart';
import 'bar_holes.dart';

/// Whether the inline title is centred: as asked, until three trailing items
/// leave it no room, where SwiftUI moves it to the leading side.
bool titleCentered(bool centerTitle, List<Widget> trailing) =>
    centerTitle && trailing.where((item) => item is! Spacer).length < 3;

/// [trailing] as SwiftUI lays toolbar items out: bar buttons (glass or the
/// default style) side by side share one capsule, which a [Spacer] ends;
/// anything else, a prominent button included, stands alone. Each entry is
/// cut out of the edge effect's wash ([BarHole]).
///
/// What does not fit in [width] goes into a ••• menu at the end, as the
/// system's overflow does: the buttons of the lowest
/// [CupertinoNativeButton.visibilityPriority] first, from the end. Only
/// buttons that join a capsule can go: anything else has no menu row.
///
/// In the bar a button whose label has an icon shows the icon alone, its
/// title kept for the menu, as SwiftUI's `Button("Add", systemImage:)` does.
List<Widget> toolbarGroups(
  List<Widget> trailing, {
  double width = double.infinity,
}) {
  final visible = [...trailing];
  final hidden = <CupertinoNativeButton>[];
  List<Widget> laidOut() => hidden.isEmpty
      ? visible
      : [
          ...visible,
          BarOverflowMenu([
            for (final item in trailing)
              if (hidden.contains(item)) item as CupertinoNativeButton,
          ]),
        ];

  final candidates =
      [
        for (final (i, item) in trailing.indexed)
          if (item is CupertinoNativeButton && _joins(item)) (i, item),
      ]..sort((a, b) {
        final byPriority = _rank(a.$2).compareTo(_rank(b.$2));
        return byPriority != 0 ? byPriority : b.$1.compareTo(a.$1);
      });
  for (final (_, button) in candidates) {
    if (_width(_runs(laidOut())) <= width) break;
    visible.remove(button);
    hidden.add(button);
  }

  return [
    for (final run in _runs(laidOut()))
      BarHole(
        child: run.length == 1 ? _alone(run.single) : SharedGlassCapsule(run),
      ),
  ];
}

/// The order buttons leave the bar in: low, then automatic, then high.
int _rank(CupertinoNativeButton b) => switch (b.visibilityPriority) {
  CupertinoNativeToolbarVisibilityPriority.low => 0,
  CupertinoNativeToolbarVisibilityPriority.automatic => 1,
  CupertinoNativeToolbarVisibilityPriority.high => 2,
};

/// Bar buttons sharing one capsule, as ONE native view: a glass group
/// whose glasses are united, the way SwiftUI draws a `ToolbarItemGroup`.
/// Each button becomes a glass of the group (its icon, or its title when it
/// has no icon) and the ••• menu one more, so a capsule of N buttons costs
/// one platform view instead of a glass plus N buttons.
class SharedGlassCapsule extends StatelessWidget {
  const SharedGlassCapsule(this.items, {super.key});

  /// Bar buttons, and the ••• menu when the bar overflows.
  final List<Widget> items;

  @override
  Widget build(BuildContext context) {
    final buttons = items.whereType<CupertinoNativeButton>().toList();
    final more = items.whereType<BarOverflowMenu>().firstOrNull;
    return CupertinoNativeGlassGroup(
      // No gap: the glasses are drawn as one capsule.
      spacing: 0,
      alignment: Alignment.centerRight,
      onAction: (id) => switch (id[0]) {
        'b' => buttons[int.parse(id.substring(1))].onPressed?.call(),
        'm' => more?.hidden[int.parse(id.substring(1))].onPressed?.call(),
        _ => null,
      },
      items: [
        for (final (i, b) in buttons.indexed) _glass(b, 'b$i'),
        if (more != null)
          CupertinoNativeGlassGroupItem(
            actionId: 'more',
            icon: _barIcon(const CupertinoNativeIcon.named('ellipsis')),
            menuItems: [
              for (final (i, b) in more.hidden.indexed)
                BarOverflowMenu._menuAction(b, 'm$i'),
            ],
          ),
      ],
    );
  }

  /// [b] as a glass of the capsule: its icon alone when it has one, as in
  /// the bar, else its title.
  static CupertinoNativeGlassGroupItem _glass(
    CupertinoNativeButton b,
    String actionId,
  ) {
    final label = ButtonLabel(b.child);
    final icon = label.icon;
    return CupertinoNativeGlassGroupItem(
      actionId: actionId,
      icon: icon == null ? null : _barIcon(icon),
      title: icon == null ? label.title : null,
      width: b.width,
      enabled: b.onPressed != null,
    );
  }

  /// A bar button's symbol weight: medium, as on [CupertinoNativeButton] in
  /// a bar slot.
  static CupertinoNativeIcon _barIcon(CupertinoNativeIcon icon) =>
      icon.withDefaultWeight(FontWeight.w500);
}

/// The ••• that holds what the bar has no room for.
class BarOverflowMenu extends StatelessWidget {
  const BarOverflowMenu(this.hidden, {super.key});

  final List<CupertinoNativeButton> hidden;

  @override
  Widget build(BuildContext context) => CupertinoNativeMenu(
    title: 'More',
    systemImage: 'ellipsis',
    labelStyle: CupertinoNativeButtonLabelStyle.iconOnly,
    style: CupertinoNativeButtonStyle.glass,
    borderShape: CupertinoNativeButtonBorderShape.circle,
    width: 44,
    height: 44,
    fixedOrder: true,
    items: [for (final (i, b) in hidden.indexed) _menuAction(b, '$i')],
    onAction: (id, _) => hidden[int.parse(id)].onPressed?.call(),
  );

  static CupertinoNativeMenuAction _menuAction(
    CupertinoNativeButton b,
    String id,
  ) {
    final label = ButtonLabel(b.child);
    final symbol = label.icon?.sfSymbol;
    return CupertinoNativeMenuAction(
      title: label.title.isNotEmpty ? label.title : symbol ?? '',
      systemImage: symbol,
      actionId: id,
      isDisabled: b.onPressed == null,
      isDestructive: b.role == CupertinoNativeButtonRole.destructive,
    );
  }
}

/// The styles a toolbar draws in its shared capsule: SwiftUI's own bar
/// buttons, whatever their style, short of a prominent one.
const _joinsCapsule = {
  CupertinoNativeButtonStyle.glass,
  CupertinoNativeButtonStyle.plain,
  CupertinoNativeButtonStyle.automatic,
};

bool _joins(Widget item) =>
    item is BarOverflowMenu ||
    item is CupertinoNativeButton && _joinsCapsule.contains(item.style);

/// [items] cut into what is drawn together: runs of capsule buttons, and
/// everything else on its own.
List<List<Widget>> _runs(List<Widget> items) {
  final runs = <List<Widget>>[];
  var run = <Widget>[];
  void end() {
    if (run.isNotEmpty) runs.add(run);
    run = [];
  }

  for (final item in items) {
    if (item is Spacer) {
      end();
    } else if (_joins(item)) {
      run.add(item);
    } else {
      end();
      runs.add([item]);
    }
  }
  end();
  return runs;
}

/// Between two glass capsules, measured on iOS 26 Notes.
const double _gap = 12;

/// An icon's place in a shared capsule: three take 156pt in iOS 26 Notes.
const double _capsuleSlot = 52;

/// Either side of a title, in a capsule and on its own glass.
const double _titlePadding = 14;

double _width(List<List<Widget>> runs) {
  var total = _gap * (runs.length - 1);
  for (final run in runs) {
    for (final item in run) {
      total += _itemWidth(item, inCapsule: run.length > 1);
    }
  }
  return total;
}

/// What [item] takes in the bar, padding included. Estimated: the native
/// controls measure themselves only once laid out.
double _itemWidth(Widget item, {required bool inCapsule}) {
  final content = _contentWidth(item);
  if (content == 44) return inCapsule ? _capsuleSlot : 44;
  return content + 2 * _titlePadding;
}

/// [item]'s own width, without the room around it.
double _contentWidth(Widget item) {
  if (item is! CupertinoNativeButton) return 44;
  if (item.width case final width?) return width;
  final label = ButtonLabel(item.child);
  if (label.icon != null || label.title.isEmpty) return 44;
  final painter = TextPainter(
    text: TextSpan(
      text: label.title,
      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w500),
    ),
    textDirection: TextDirection.ltr,
  )..layout();
  final width = painter.width;
  painter.dispose();
  return width;
}

/// A widget standing alone in the bar: a button shows its icon only.
Widget _alone(Widget item) => switch (item) {
  final CupertinoNativeButton b => _barButton(b, b.style),
  _ => item,
};

/// [b] as the bar draws it in [style]: its icon alone when it has one.
CupertinoNativeButton _barButton(
  CupertinoNativeButton b,
  CupertinoNativeButtonStyle style,
) {
  final child = _iconOf(b.child) ?? b.child;
  if (identical(child, b.child) && style == b.style) return b;
  final height = b.height ?? 44;
  return switch (style) {
    CupertinoNativeButtonStyle.glass => CupertinoNativeButton.glass(
      key: b.key,
      onPressed: b.onPressed,
      sizeStyle: b.sizeStyle,
      color: b.color,
      borderShape: b.borderShape,
      role: b.role,
      width: b.width,
      height: height,
      child: child,
    ),
    CupertinoNativeButtonStyle.glassProminent =>
      CupertinoNativeButton.glassProminent(
        key: b.key,
        onPressed: b.onPressed,
        sizeStyle: b.sizeStyle,
        color: b.color,
        borderShape: b.borderShape,
        role: b.role,
        width: b.width,
        height: height,
        child: child,
      ),
    CupertinoNativeButtonStyle.filled => CupertinoNativeButton.filled(
      key: b.key,
      onPressed: b.onPressed,
      sizeStyle: b.sizeStyle,
      color: b.color,
      borderShape: b.borderShape,
      role: b.role,
      width: b.width,
      height: height,
      child: child,
    ),
    CupertinoNativeButtonStyle.tinted => CupertinoNativeButton.tinted(
      key: b.key,
      onPressed: b.onPressed,
      sizeStyle: b.sizeStyle,
      color: b.color,
      borderShape: b.borderShape,
      role: b.role,
      width: b.width,
      height: height,
      child: child,
    ),
    _ => CupertinoNativeButton(
      key: b.key,
      onPressed: b.onPressed,
      sizeStyle: b.sizeStyle,
      color: b.color,
      borderShape: b.borderShape,
      role: b.role,
      width: b.width,
      height: height,
      child: child,
    ),
  };
}

/// The icon of a label holding one beside a title, or null.
Widget? _iconOf(Widget label) => switch (label) {
  Row(:final children) ||
  Wrap(:final children) => children.map(_iconOf).nonNulls.firstOrNull,
  Padding(:final child?) || Center(:final child?) => _iconOf(child),
  CupertinoSymbolImage() || Icon() || ImageIcon() => label,
  _ => null,
};
