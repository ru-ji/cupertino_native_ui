# cupertino_widgets

Native iOS widgets for Flutter — the real UIKit and SwiftUI controls, iOS 26
**Liquid Glass** included — with the names and parameters of Flutter's own
Cupertino widgets.

## Installation

```bash
flutter pub add cupertino_widgets
```

```dart
import 'package:cupertino_widgets/cupertino_widgets.dart';
```

- Flutter 3.41+, Dart 3.10+
- iOS 15+ (the page scaffold needs iOS 16+). Liquid Glass styles need iOS 26;
  earlier versions show the classic system style.
- Other platforms get simple Flutter fallbacks, so shared code still builds.

Add this to `ios/Runner/Info.plist`, or the navigation bar title shows a faint
glow over the scroll edge effect:

```xml
<key>FLTDisablePartialRepaint</key>
<true/>
```

## What's in the package

Every widget is `CupertinoNative` + the name of its Flutter counterpart.

### Slider

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_widgets/main/doc/images/slider.jpg" width="320" alt="Slider" />

```dart
double _value = 50;

CupertinoNativeSlider(
  value: _value,
  max: 100,
  onChanged: (v) => setState(() => _value = v),
)
```

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `value` | `double` | required | Current position. |
| `onChanged` | `ValueChanged<double>?` | required | Null disables the slider. |
| `min` / `max` | `double` | `0.0` / `1.0` | |
| `divisions` | `int?` | — | Snap to N steps. |
| `activeColor` | `Color?` | — | Filled track. |
| `thumbColor` | `Color?` | — | Knob. |

### Switch

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_widgets/main/doc/images/toggle.jpg" width="320" alt="Switch" />

```dart
bool _on = true;

CupertinoNativeSwitch(
  value: _on,
  onChanged: (v) => setState(() => _on = v),
)
```

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `value` | `bool` | required | |
| `onChanged` | `ValueChanged<bool>?` | — | |
| `activeTrackColor` | `Color?` | — | Track when on. |
| `label` | `String?` | — | Label beside the switch. |
| `width` / `height` | `double?` | — | |

### Sliding Segmented Control

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_widgets/main/doc/images/segmented.jpg" width="320" alt="Segmented control" />

```dart
int _index = 0;

CupertinoNativeSlidingSegmentedControl<int>(
  children: const {0: Text('One'), 1: Text('Two'), 2: Text('Three')},
  groupValue: _index,
  onValueChanged: (v) => setState(() => _index = v!),
)
```

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `children` | `Map<T, Widget>` | required | Value → `Text` label. |
| `onValueChanged` | `ValueChanged<T?>` | required | |
| `groupValue` | `T?` | — | Selected value. |
| `thumbColor` | `Color?` | — | Selected segment. |
| `width` / `height` | `double?` | — | |

### Button

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_widgets/main/doc/images/buttons.jpg" width="320" alt="Buttons" />

```dart
CupertinoNativeButton.filled(
  onPressed: () {},
  child: const Text('Press me'),
)

// Icon button
CupertinoNativeButton.glass(
  borderShape: CupertinoNativeButtonBorderShape.circle,
  onPressed: () {},
  child: CupertinoSymbolImage.symbol(CupertinoSymbols.heartFill),
)
```

Constructors: `CupertinoNativeButton` (plain), `.filled`, `.tinted`, `.glass`,
`.glassProminent`.

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `child` | `Widget` | required | A `Text`, `CupertinoSymbolImage`, `Icon`, or a `Row` of an icon and a `Text`. |
| `onPressed` | `VoidCallback?` | required | |
| `color` | `Color?` | — | Tint. |
| `sizeStyle` | `CupertinoNativeControlSize` | `.regular` | `mini`, `small`, `regular`, `large`, `extraLarge`. |
| `borderShape` | `CupertinoNativeButtonBorderShape` | `.automatic` | `automatic`, `capsule`, `circle`, `roundedRectangle`. |
| `expand` | `bool` | `false` | Fill the available width. |
| `width` / `height` | `double?` | — | |

### Popup Menu

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_widgets/main/doc/images/menu.jpg" width="320" alt="Popup menu" />

```dart
CupertinoNativeMenu(
  title: 'Actions',
  items: [
    CupertinoNativeMenuAction(title: 'Rename', systemImage: 'pencil', actionId: 'rename'),
    CupertinoNativeMenuAction(title: 'Delete', systemImage: 'trash', isDestructive: true, actionId: 'delete'),
  ],
  onAction: (id, _) {},
)
```

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `items` | `List<CupertinoNativeMenuItem>` | required | See [Menu items](#menu-items). |
| `onAction` | `CupertinoNativeMenuActionCallback?` | — | `(actionId, value)`. |
| `title` | `String` | `'Options'` | Label of the button. |
| `systemImage` | `String?` | — | SF Symbol of the button. |
| `style` | `CupertinoNativeButtonStyle` | `.automatic` | |
| `borderShape` | `CupertinoNativeButtonBorderShape` | `.automatic` | |
| `labelStyle` | `CupertinoNativeButtonLabelStyle` | `.titleAndIcon` | `titleAndIcon`, `titleOnly`, `iconOnly`. |
| `controlSize` | `CupertinoNativeControlSize` | `.regular` | |
| `activeColor` | `Color?` | — | |

### Context Menu

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_widgets/main/doc/images/contextmenu.jpg" width="320" alt="Context menu" />

```dart
CupertinoNativeContextMenu(
  actions: [
    CupertinoNativeMenuAction(title: 'Share', systemImage: 'square.and.arrow.up', actionId: 'share'),
  ],
  onAction: (id, _) {},
  child: const PhotoCard(),
)
```

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `child` | `Widget` | required | |
| `actions` | `List<CupertinoNativeMenuItem>` | required | |
| `onAction` | `CupertinoNativeMenuActionCallback?` | — | |
| `preview` | `Widget?` | — | Replaces the lifted preview. |
| `onOpenChanged` | `ValueChanged<bool>?` | — | |
| `blurBackground` | `bool` | `false` | Blur the app behind the menu. |
| `childInteractive` | `bool` | `false` | Let `child` receive touches. |
| `previewCornerRadius` | `double` | `0` | Corner radius of `child`. |

### Alert Dialog

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_widgets/main/doc/images/alert.jpg" width="320" alt="Alert dialog" />

```dart
CupertinoNativeAlertDialog.show(
  context: context,
  title: 'Delete Photo?',
  content: 'This photo will be deleted from all your devices.',
  actions: [
    CupertinoNativeDialogAction(isDefaultAction: true, onPressed: () {}, child: const Text('Cancel')),
    CupertinoNativeDialogAction(isDestructiveAction: true, onPressed: () {}, child: const Text('Delete')),
  ],
)
```

| `CupertinoNativeDialogAction` | Type | Default | |
| --- | --- | --- | --- |
| `child` | `Text` | required | |
| `onPressed` | `VoidCallback?` | — | |
| `isDefaultAction` | `bool` | `false` | Bold, cancel role. |
| `isDestructiveAction` | `bool` | `false` | Red. |

### Activity Indicator

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_widgets/main/doc/images/progress.jpg" width="320" alt="Activity indicators" />

```dart
const CupertinoNativeActivityIndicator()

CupertinoNativeLinearActivityIndicator(progress: 0.4)
```

| `CupertinoNativeActivityIndicator` | Type | Default | |
| --- | --- | --- | --- |
| `color` | `Color?` | — | |
| `radius` | `double` | `10` | |
| `animating` | `bool` | `true` | False hides it. |

| `CupertinoNativeLinearActivityIndicator` | Type | Default | |
| --- | --- | --- | --- |
| `progress` | `double` | required | 0 to 1. |
| `height` | `double` | `4.5` | |
| `color` | `Color?` | — | |

### Text Field

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_widgets/main/doc/images/textfield.jpg" width="320" alt="Text field" />

```dart
CupertinoNativeTextField(
  placeholder: 'Search',
  prefix: CupertinoNativeIcon.symbol(CupertinoSymbols.magnifyingglass),
  clearButtonMode: OverlayVisibilityMode.editing,
  onChanged: (v) {},
)
```

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `controller` / `focusNode` | | — | Standard Flutter controller and focus node. |
| `placeholder` | `String?` | — | |
| `style` | `TextStyle?` | — | |
| `keyboardType` | `TextInputType` | `.text` | |
| `textInputAction` | `TextInputAction?` | — | |
| `obscureText` / `autocorrect` / `enableSuggestions` | `bool` | `false` / `true` / `true` | |
| `textCapitalization` | `TextCapitalization` | `.none` | |
| `textAlign` | `TextAlign` | `.start` | |
| `maxLength` | `int?` | — | |
| `enabled` / `readOnly` / `autofocus` | `bool` | `true` / `false` / `false` | |
| `clearButtonMode` | `OverlayVisibilityMode` | `.never` | |
| `prefix` / `suffix` | `CupertinoNativeIcon?` | — | |
| `cursorColor` / `backgroundColor` | `Color?` | — | |
| `cornerRadius` | `double?` | — | |
| `glass` | `CupertinoGlass?` | — | Liquid Glass background. |
| `textContentType` | `String?` | — | Autofill hint, e.g. `'password'`. |
| `onChanged` / `onSubmitted` / `onEditingComplete` / `onTap` / `onTapOutside` | | — | |
| `width` / `height` | `double?` | — | |

### Date Picker

```dart
DateTime _date = DateTime.now();

CupertinoNativeDatePicker(
  initialDateTime: _date,
  mode: CupertinoDatePickerMode.date,
  onDateTimeChanged: (d) => setState(() => _date = d),
)
```

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `onDateTimeChanged` | `ValueChanged<DateTime>` | required | |
| `initialDateTime` | `DateTime?` | now | |
| `mode` | `CupertinoDatePickerMode` | `.dateAndTime` | |
| `minimumDate` / `maximumDate` | `DateTime?` | — | |
| `activeColor` | `Color?` | — | |
| `width` / `height` | `double?` | — | |

### Tab Bar

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_widgets/main/doc/images/tabbar.jpg" width="320" alt="Tab bar" />

```dart
int _tab = 0;

// Overlay this at the bottom of your page
CupertinoNativeTabBar(
  items: [
    CupertinoNativeTab(id: 'home', title: 'Home', icon: CupertinoNativeIcon.symbol(CupertinoSymbols.houseFill)),
    CupertinoNativeTab(id: 'profile', title: 'Profile', icon: CupertinoNativeIcon.symbol(CupertinoSymbols.personFill)),
  ],
  currentIndex: _tab,
  onTap: (i) => setState(() => _tab = i),
)
```

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `items` | `List<CupertinoNativeTab>` | required | See [Tabs](#tabs). |
| `currentIndex` | `int` | `0` | |
| `onTap` | `ValueChanged<int>?` | — | |
| `activeColor` / `backgroundColor` | `Color?` | — | |
| `height` | `double?` | — | |
| `split` / `rightCount` / `splitSpacing` | `bool` / `int` / `double` | `false` / `1` / `8` | Detach the last tabs into their own bar (iOS 26). |
| `shrinkCentered` | `bool` | `true` | |
| `scrollEdgeEffect` | `CupertinoScrollEdgeEffectStyle` | `.automatic` | |
| `minimizeBehavior` | `CupertinoNativeTabBarMinimizeBehavior` | `.automatic` | Inside `CupertinoNativePageScaffold`. |
| `accessory` | `CupertinoNativeTabBarAccessory?` | — | Inside `CupertinoNativePageScaffold`. |

### List & Form

```dart
CupertinoNativeList(
  sections: [
    CupertinoNativeListSection(
      header: 'Connectivity',
      children: [
        CupertinoNativeListTile(id: 'wifi', title: 'Wi-Fi', additionalInfo: 'Home', showChevron: true),
        CupertinoNativeListTile(id: 'airplane', title: 'Airplane Mode', type: CupertinoNativeListTileType.toggle),
      ],
    ),
  ],
  onRowTap: (id) {},
  onToggle: (id, on) {},
)
```

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `sections` | `List<CupertinoNativeListSection>` | required | See [List tiles](#list-tiles). |
| `style` | `CupertinoNativeListStyle` | `.insetGrouped` | `CupertinoNativeForm` has no `style`. |
| `onRowTap` | `CupertinoNativeListTileCallback?` | — | |
| `onToggle` | `CupertinoNativeListToggleCallback?` | — | |
| `scrollable` | `bool` | `false` | |
| `height` / `cornerRadius` | `double?` | — | |
| `activeColor` | `Color?` | — | |

### Liquid Glass

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_widgets/main/doc/images/glass.jpg" width="320" alt="Liquid Glass" />

```dart
CupertinoNativeGlassContainer(
  shape: CupertinoGlassShape.capsule,
  interactive: true,
  icon: CupertinoNativeIcon.symbol(CupertinoSymbols.playFill),
  onPressed: () {},
)
```

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `shape` | `CupertinoGlassShape` | `.roundedRect` | `capsule`, `circle`, `roundedRect`. |
| `cornerRadius` | `double` | `26` | |
| `variant` | `CupertinoGlassVariant` | `.regular` | `regular`, `clear`. |
| `tint` | `Color?` | — | |
| `interactive` | `bool` | `false` | |
| `onPressed` | `VoidCallback?` | — | |
| `icon` | `CupertinoNativeIcon?` | — | |
| `route` | `String?` | — | Flutter content inside the glass, registered like a scaffold body. |
| `padding` | `EdgeInsetsGeometry` | `.zero` | |
| `animateChanges` | `bool` | `false` | |
| `width` / `height` | `double?` | — | |

Glasses that should merge into one piece go in a `CupertinoNativeGlassGroup`:

```dart
CupertinoNativeGlassGroup(
  spacing: 4,
  items: [
    CupertinoNativeGlassGroupItem(actionId: 'back', icon: CupertinoNativeIcon.symbol(CupertinoSymbols.chevronBackward)),
    CupertinoNativeGlassGroupItem(actionId: 'edit', title: 'Edit', shape: CupertinoGlassGroupShape.capsule),
  ],
  onAction: (id) {},
)
```

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `items` | `List<CupertinoNativeGlassGroupItem>` | required | `actionId`, `icon`, `title`, `shape`, `width`, `height`, `enabled`. |
| `onAction` | `ValueChanged<String>?` | — | |
| `spacing` | `double` | `8` | Gap, and the distance at which glasses merge. |
| `vertical` | `bool` | `false` | |
| `tint` / `clear` / `interactive` | | — | |
| `cornerRadius` | `double` | `16` | |

### Navigation Bar

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_widgets/main/doc/images/scaffold.jpg" width="320" alt="Navigation bar" />

The iOS 26 bar, with a large title that collapses on scroll, glass buttons and
an optional search field.

```dart
CustomScrollView(
  slivers: [
    CupertinoNativeSliverNavigationBar.search(
      largeTitle: 'Library',
      trailing: [
        CupertinoNativeButton.glass(
          borderShape: CupertinoNativeButtonBorderShape.circle,
          onPressed: () {},
          child: CupertinoSymbolImage.symbol(CupertinoSymbols.plus),
        ),
      ],
      searchPlaceholder: 'Search',
      onSearchChanged: (q) {},
    ),
    // your slivers
  ],
)
```

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `largeTitle` | `String` | required | |
| `subtitle` | `String?` | — | |
| `leading` | `Widget?` | — | |
| `trailing` | `List<Widget>` | `[]` | |
| `centerTitle` | `bool` | `true` | |
| `expandedTitle` / `collapseTitle` | `bool` | `true` | |
| `bottom` / `bottomHeight` | `Widget?` / `double` | — / `44` | Widget under the large title. |
| `scrollEdgeEffect` | `CupertinoScrollEdgeEffectStyle` | `.soft` | |
| `tintColor` | `Color?` | — | |

`.search` adds `searchPlaceholder`, `searchStyle`, `searchPrefixIcon`,
`searchSuffixIcon`, `searchGlass`, `searchFieldHeight`, `bottomMode`,
`scrollToTopOnSearch`, `onSearchChanged` and `onSearchActiveChanged`.

`CupertinoNativeNavigationBar` is the version for pages that do not scroll:
`title`, `subtitle`, `centerTitle`, `leading`, `trailing`, `scrollEdgeEffect`,
`tintColor`.

### Page Scaffold

A full native page: navigation stack, large title, tab bar, search.

```dart
void main() {
  if (CupertinoNativePageScaffold.maybeRun({
    'home': () => const HomeBody(),
    'profile': () => const ProfileBody(),
  })) return;
  runApp(const MyApp());
}

CupertinoNativePageScaffold(
  navigationBar: CupertinoNativeScaffoldNavigationBar(title: 'Library'),
  tabBar: CupertinoNativeTabBar(
    items: [
      CupertinoNativeTab(id: 'home', title: 'Home', icon: CupertinoNativeIcon.symbol(CupertinoSymbols.houseFill)),
      CupertinoNativeTab(id: 'profile', title: 'Profile', icon: CupertinoNativeIcon.symbol(CupertinoSymbols.personFill)),
    ],
  ),
)
```

Each page body is a route registered in `maybeRun`, and bodies use regular
Flutter widgets only.

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `body` | `String?` | — | Root route when there is no `tabBar`. |
| `navigationBar` | `CupertinoNativeScaffoldNavigationBar?` | — | |
| `tabBar` | `CupertinoNativeTabBar?` | — | Each tab `id` is its route. |
| `controller` | `CupertinoNativePageScaffoldController?` | — | |
| `onBarAction` | `CupertinoNativeBarActionCallback?` | — | |
| `onTabChanged` | `ValueChanged<String>?` | — | |
| `onRouteChanged` | `CupertinoNativeRouteChangedCallback?` | — | |
| `onSearchChanged` / `onSearchSubmitted` | `CupertinoNativeSearchCallback?` | — | |
| `onSearchActiveChanged` | `CupertinoNativeSearchActiveCallback?` | — | |
| `scrollEdgeEffect` | `CupertinoScrollEdgeEffectStyle` | `.automatic` | |
| `backgroundColor` / `activeColor` | `Color?` | — | |
| `showLoadingIndicator` | `bool?` | — | |

Navigate with `CupertinoNativePageScaffold.push(...)`, `.pushNamed(route)` and
`.pop()`.

`CupertinoNativeScaffoldNavigationBar`:

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `title` | `String` | required | |
| `subtitle` | `String?` | — | |
| `titleDisplayMode` | `CupertinoNativeToolbarTitleDisplayMode` | `.automatic` | `automatic`, `inline`, `inlineLarge`, `large`. |
| `leading` / `trailing` | `List<CupertinoNativeBarEntry>` | `[]` | See [Bar items](#bar-items). |
| `search` | `CupertinoNativeSearchField?` | — | |

### Sheet

```dart
await CupertinoNativeSheet.show(
  route: 'newEvent',
  appBar: CupertinoNativeScaffoldNavigationBar(title: 'New Event'),
  detents: [CupertinoNativeSheetDetent.medium, CupertinoNativeSheetDetent.large],
  showDragHandle: true,
);
```

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `route` | `String` | required | Body route registered in `maybeRun`. |
| `appBar` | `CupertinoNativeScaffoldNavigationBar?` | — | |
| `bottom` | `CupertinoNativeSheetSegmentedControl?` | — | |
| `detents` | `List<CupertinoNativeSheetDetent>` | `[large]` | `medium`, `large`. |
| `showDragHandle` | `bool` | `false` | |
| `cornerRadius` | `double?` | — | |
| `scrollEdgeEffect` | `CupertinoScrollEdgeEffectStyle` | `.soft` | |
| `backgroundColor` | `Color?` | — | |
| `onBarAction` | `void Function(String)?` | — | |
| `onBottomChanged` | `ValueChanged<int>?` | — | |
| `onSearchChanged` / `onSearchSubmitted` | `ValueChanged<String>?` | — | |

Close it with `CupertinoNativeSheet.dismiss()`.

### Scroll Edge Effect

The iOS 26 blur and tint where content meets a screen edge. The navigation bars
and the tab bar already include it.

```dart
Stack(
  children: [
    // your scrolling content
    Positioned(
      top: 0, left: 0, right: 0, height: 120,
      child: CupertinoScrollEdgeEffect(edge: CupertinoScrollEdgeEffectEdge.top),
    ),
  ],
)
```

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `edge` | `CupertinoScrollEdgeEffectEdge` | `.top` | `top`, `bottom`. |
| `style` | `CupertinoScrollEdgeEffectStyle` | `.soft` | `soft`, `hard`, `automatic`. |
| `color` | `Color?` | — | Background of the `hard` style. |
| `onBrightnessChanged` | `ValueChanged<Brightness>?` | — | Brightness of the content behind the effect, to adapt text over it. |

### Symbol Image

An SF Symbol as a regular Flutter image.

```dart
CupertinoSymbolImage.symbol(CupertinoSymbols.star, size: 20, color: CupertinoColors.systemYellow)
```

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `name` | `String` | required | SF Symbol name (or `.symbol(CupertinoSymbols)`). |
| `size` | `double` | `17` | |
| `color` | `Color?` | — | |
| `weight` | `FontWeight` | `.normal` | |

## Models

### Icons

`CupertinoNativeIcon` is the icon every native control takes.

| Constructor | |
| --- | --- |
| `.symbol(CupertinoSymbols, {size, color, renderingMode})` | SF Symbol from the enum. |
| `.named(String, {size, color, renderingMode})` | Any SF Symbol name. |
| `.flutter(IconData, {size, color})` | A Flutter icon. |

`renderingMode`: `monochrome`, `hierarchical`, `palette`, `multicolor`.

### Menu items

| Type | Fields |
| --- | --- |
| `CupertinoNativeMenuAction` | `title`, `actionId`, `subtitle`, `systemImage`, `isDestructive`, `isDisabled` |
| `CupertinoNativeMenuToggle` | `title`, `actionId`, `value`, `systemImage` |
| `CupertinoNativeSubmenu` | `title`, `items`, `systemImage` |
| `CupertinoNativeMenuSection` | `title`, `items` |

### List tiles

| Type | Fields |
| --- | --- |
| `CupertinoNativeListSection` | `header`, `footer`, `children` |
| `CupertinoNativeListTile` | `id`, `title`, `subtitle`, `leading`, `additionalInfo`, `showChevron`, `type` (`label`, `toggle`, `button`), `toggleValue`, `enabled` |

### Bar items

| Type | Fields |
| --- | --- |
| `CupertinoNativeBarItem` | `actionId`, `title`, `icon`, `sharedBackgroundVisibility`, `glass` |
| `CupertinoNativeBarItemGroup` | `items`, `sharedBackgroundVisibility` |

### Tabs

| Type | Fields |
| --- | --- |
| `CupertinoNativeTab` | `id`, `title`, `icon`, `role` (`.search`), `search` |
| `CupertinoNativeTabBarAccessory` | `title`, `subtitle`, `icon`, `actionId` |

## Example app

The [example](example/) shows every widget and its variants. Run it on an
iOS 26 device to see Liquid Glass.

## What's next

- Widget titles (`largeTitle`, `middle`) on the navigation bars, like Flutter's.
- `onChangeStart` / `onChangeEnd` on the slider.
- More native components.

Contributions are welcome: <https://github.com/ru-ji/cupertino_widgets>

## License

BSD 3-Clause. Copyright 2026 THON Hermès. See [LICENSE](LICENSE).
