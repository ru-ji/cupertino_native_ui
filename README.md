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
- iOS 26+ at runtime. The package is built on Liquid Glass; there are no
  fallbacks for earlier versions. It still **compiles and links** into an app
  with a lower deployment target — below iOS 26 the plugin registers nothing
  and the widgets render their non-iOS fallbacks — so adopting it does not
  force your whole app to iOS 26.
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

### Action Sheet

The system sheet of choices that rises from the bottom —
`UIAlertController(preferredStyle: .actionSheet)`, what SwiftUI's
`.confirmationDialog` presents. Shares its action type with the dialog.

```dart
CupertinoNativeActionSheet.show(
  context: context,
  title: 'Move to…',
  actions: [
    CupertinoNativeDialogAction(onPressed: _delete, isDestructiveAction: true, child: const Text('Delete')),
    CupertinoNativeDialogAction(isDefaultAction: true, child: const Text('Cancel')),
  ],
)
```

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `title` / `message` | `String?` | — | |
| `actions` | `List<CupertinoNativeDialogAction>` | required | |
| `anchor` | `Rect?` | — | iPad/Mac only, where UIKit makes it a popover. `CupertinoNativeActionSheet.anchorOf(context)` gives the rect of the control that opened it. |

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
| `keyboardToolbar` | `CupertinoNativeBody?` | — | The bar above the keyboard. |
| `onKeyboardAction` | `void Function(String id, Object? value)?` | — | A `keyboardToolbar` control changed. |
| `onChanged` / `onSubmitted` / `onEditingComplete` / `onTap` / `onTapOutside` | | — | |
| `width` / `height` | `double?` | — | |

#### Keyboard toolbar

The bar above the keyboard — the focused field's `inputAccessoryView`, in a
`UIInputView` styled like the keyboard. Write the package's own controls, and
a `Spacer` where the bar should break:

```dart
CupertinoNativeTextField(
  keyboardToolbar: [
    CupertinoNativeButton(onPressed: _prev, child: CupertinoSymbolImage('chevron.up')),
    CupertinoNativeButton(onPressed: _next, child: CupertinoSymbolImage('chevron.down')),
    const Spacer(),
    CupertinoNativeButton(onPressed: _done, child: const Text('Done')),
  ],
)
```

Each item keeps its own `onPressed` / `onChanged`, so there is no id to invent
and no separate callback.

**The widgets are read, not mounted.** The bar lives in the keyboard's own
`UIWindow`, where Flutter cannot draw, so its contents are built natively: the
package walks what you wrote, copies what each native control needs, and keeps
its callback.

> SwiftUI's
> [`ToolbarItemGroup(placement: .keyboard)`](https://developer.apple.com/documentation/swiftui/toolbaritemplacement/keyboard)
> is the documented way to do this, and it is what this was first built on.
> It resolves to nothing when the SwiftUI tree is a child
> `UIHostingController` embedded in a Flutter platform view — which is how
> every widget here is hosted. `inputAccessoryView` is the UIKit mechanism
> underneath it and does not care where the hosting controller sits. That is also why only these are accepted —
`CupertinoNativeButton`, `CupertinoNativeSwitch`, `CupertinoNativePicker`,
`CupertinoNativeSymbol`, `Text`, `Spacer`, `SizedBox` (a fixed gap), and
`CupertinoNativeFlutterView`. Anything else asserts with that explanation.

`CupertinoNativeFlutterView('route')` puts your own Flutter in the bar, hosted
in its own engine — the route is registered in `maybeRun` like a scaffold
body. It is the expensive item: one view is one isolate. A row of buttons
costs nothing.

It belongs to *this* field's responder: it shows when this field is focused,
and not for a Flutter `TextField` elsewhere on the page.

**On iOS 26 the bar is already Liquid Glass**, so a `.glass` button inside it
is glass on glass — the same double capsule the navigation bar's
`sharedBackgroundVisibility` warns about. The system's own bars use plain
buttons on the shared material.

A field the package does not own gets no bar: the toolbar is *this* field's
`inputAccessoryView`. Drawing one in Flutter instead is possible but not
advisable — it would be positioned by us rather than moved by UIKit, so it
lags the keyboard on open and on close.

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

### Picker

A native SwiftUI `Picker`. The style is the control: `.palette` is the Liquid
Glass row of icons with the selection travelling between them, `.wheel` the
spinning drum, `.menu` a button that opens the options as a native menu.

```dart
CupertinoNativePicker.palette(
  items: const [
    CupertinoNativePickerItem(icon: CupertinoNativeIcon.named('list.bullet')),
    CupertinoNativePickerItem(icon: CupertinoNativeIcon.named('square.grid.2x2')),
  ],
  selectedIndex: _layout,
  onChanged: (i) => setState(() => _layout = i),
)
```

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `items` | `List<CupertinoNativePickerItem>` | required | `title`, `icon`, or both. |
| `selectedIndex` | `int` | required | Clamped to the list. |
| `onChanged` | `ValueChanged<int>?` | — | |
| `style` | `CupertinoNativePickerStyle` | `.automatic` | `wheel`, `menu`, `segmented`, `palette`, `inline`, `navigationLink`. |
| `label` / `showLabel` | `String?` / `bool` | — / `false` | |
| `activeColor` | `Color?` | theme primary | |
| `sizeStyle` | `CupertinoNativeControlSize?` | — | |
| `height` | `double?` | — | Required-ish for `.wheel`, which has no height of its own (the `.wheel` constructor defaults it to 216). |

`navigationLink` only works inside a native `NavigationStack`, i.e. a
`CupertinoNativePageScaffold` body. For a plain segmented strip prefer
`CupertinoNativeSlidingSegmentedControl`; its `.menu` constructor is the
generic-keyed version of the menu style.

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
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  child: Row(mainAxisSize: MainAxisSize.min, children: [...]),
)
```

Content goes on the glass three ways, in increasing cost:

* **`child`** — an ordinary Flutter widget, drawn by the engine you are
  already in, over the glass and sizing it. No route, no registration, no
  second isolate. This is the one you want.
* **`icon`** — a native SF Symbol drawn by SwiftUI inside the material.
* **`route`** — Flutter content hosted *inside* the glass in its own engine.
  Only when the material has to treat the content as part of its own shape.

`child` sits *over* the material rather than inside it, which is invisible for
anything that isn't refracted by its own container — that is, almost
everything.

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `shape` | `CupertinoGlassShape` | `.roundedRect` | `capsule`, `circle`, `roundedRect`. |
| `cornerRadius` | `double` | `26` | |
| `variant` | `CupertinoGlassVariant` | `.regular` | `regular`, `clear`. |
| `tint` | `Color?` | — | |
| `interactive` | `bool` | `false` | |
| `onPressed` | `VoidCallback?` | — | |
| `child` | `Widget?` | — | Flutter drawn over the glass, sizing it. No engine. |
| `icon` | `CupertinoNativeIcon?` | — | |
| `route` | `String?` | — | Flutter content *inside* the glass, in its own engine, registered like a scaffold body. Prefer `child`. |
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
Flutter widgets only — unless you give the scaffold a `nativeBody`, which
renders as SwiftUI directly (see below).

Declare a body once with `CupertinoNativeBodyRoute` to keep its name in a
single place:

```dart
final homeBody = CupertinoNativeBodyRoute('home', () => const HomeBody());

void main() {
  if (CupertinoNativePageScaffold.maybeRunRoutes([homeBody])) return;
  runApp(const MyApp());
  CupertinoNativePageScaffold.prewarmRoutes([homeBody]);
}

CupertinoNativePageScaffold(body: homeBody.name)
```

**There is no `child:` here, and there cannot be.** The body engine boots by
running your `main()` again with the body's name as its initial route, so
`maybeRun` executes *in the body isolate* and can only reach builders that are
statically part of the program. A widget written inline in the host's `build()`
is an object in the host's heap; the body isolate has no way to reach it.
Generating the name automatically would not change that — the name is not the
obstacle, the builder is.

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
| `resizeToAvoidBottomInset` | `bool` | `true` | |
| `interactiveKeyboardDismiss` | `bool` | `false` | Drag down over the keyboard to dismiss it, following the finger. |
| `nativeBody` | `CupertinoNativeBody?` | — | A body rendered as SwiftUI directly. Replaces `body` / the tabs' routes. |
| `onBodyEvent` | `void Function(String id, Object? value)?` | — | A `nativeBody` control changed. |

#### Talking to a body — the isolate boundary

Each body runs in its own FlutterEngine, so in its own **isolate**. Isolates
share no memory: a Riverpod `ProviderContainer`, a BLoC, a `ValueNotifier`, a
`BuildContext` — none of it reaches across. Objects cannot be passed, only
data.

So you mirror rather than share. `CupertinoNativeBodyBridge` is that mirror:

```dart
// Host: publish a snapshot of whatever your state manager already holds.
ref.listen(cartProvider, (_, cart) {
  CupertinoNativeBodyBridge.publish({'count': cart.count, 'total': cart.total});
});
CupertinoNativeBodyBridge.onAction = (action, payload) {
  if (action == 'addItem') ref.read(cartProvider.notifier).add(payload! as String);
};

// Body: read the mirror, send intent back.
ValueListenableBuilder(
  valueListenable: CupertinoNativeBodyBridge.state,
  builder: (context, state, _) => Text('${state['count']} items'),
);
CupertinoNativeBodyBridge.send('addItem', 'sku-42');
```

| | |
| --- | --- |
| `publish(Map)` | Host → every body. Replaces the snapshot. |
| `state` | `ValueListenable<Map>` — read it in a body. |
| `send(action, [payload])` | Body → host. |
| `onAction` | Called in the host when a body sends one. |
| `requestState()` | Body → host: "send the snapshot again". A body that boots mid-session has missed everything before it; call this once on start and answer it by calling `publish` again. |

Everything crossing must survive `StandardMessageCodec`: null, bool, num,
String, `Uint8List`, and `List`/`Map` of those.

**Often the better answer is not to cross at all.** A page made of system
controls can be a `nativeBody` instead — no engine, so it lives in the host
isolate and your existing state management works untouched.

#### Native body — SwiftUI without the nesting

An ordinary body is a route in its own FlutterEngine. A native control placed
there is a platform view inside a hierarchy that was already native:
**Flutter → SwiftUI → FlutterView → SwiftUI**.

`nativeBody` removes the middle. Dart sends a description, SwiftUI renders it,
and the controls are real SwiftUI views in the scaffold's own tree — the
hierarchy you would get writing the SwiftUI by hand.

```dart
CupertinoNativePageScaffold(
  navigationBar: const CupertinoNativeScaffoldNavigationBar(title: 'Profile'),
  nativeBody: CupertinoNativeBody.column(
    spacing: 16,
    padding: const EdgeInsets.all(20),
    children: [
      CupertinoNativeBody.text('Account', style: CupertinoNativeTextStyle.headline),
      CupertinoNativeBody.textField(id: 'name', value: _name, placeholder: 'Your name'),
      CupertinoNativeBody.toggle(id: 'notify', label: 'Notifications', value: _notify),
      CupertinoNativeBody.slider(id: 'volume', value: _volume),
      CupertinoNativeBody.button(
        id: 'save',
        title: 'Save',
        style: CupertinoNativeButtonStyle.glassProminent,
        expand: true,
      ),
    ],
  ),
  onBodyEvent: (id, value) => setState(() { /* ... */ }),
)
```

**The trade is real and it has no way around it.** These are descriptions, not
widgets: they are serialized and sent, not built. A native body is only what
`CupertinoNativeBody` can express — you cannot have both a body written in
arbitrary Flutter and controls that render as SwiftUI directly. Keep the route
body when the page is mostly your own Flutter UI; use `nativeBody` when the
page is mostly system controls.

| Node | |
| --- | --- |
| `.column` / `.row` / `.scroll` | `children`, `spacing`, `alignment`, `padding`, `expand` |
| `.spacer` | `extent` — flexible when null |
| `.divider` | |
| `.text` | `value`, `style`, `fontSize`, `fontWeight`, `color`, `align` |
| `.button` | `id`, `title`, `icon`, `style`, `sizeStyle`, `borderShape`, `color`, `expand` |
| `.field` | `id`, `value`, `placeholder`, `obscureText`, `enabled` |
| `.toggle` | `id`, `value`, `label`, `color` |
| `.slider` | `id`, `value`, `min`, `max`, `step`, `color`, `enabled` |
| `.picker` | `id`, `items`, `selectedIndex`, `style`, `label`, `showLabel`, `color` |
| `.list` | `id`, `sections` |
| `.symbol` | `name`, `size`, `color`, `effect`, `trigger`, `repeating` |

Interactive nodes need an `id`. `onBodyEvent` reports `(id, value)`: null for
a button, the text for a field, a bool for a toggle, a double for a slider, an
int index for a picker. A field also reports `('<id>.focused', bool)` and
`('<id>.submitted', String)`.

Navigate with `CupertinoNativePageScaffold.push(...)`, `.pushNamed(route)` and
`.pop()`.

`CupertinoNativeScaffoldNavigationBar`:

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `title` | `String` | required | |
| `subtitle` | `String?` | — | |
| `titleDisplayMode` | `CupertinoNativeToolbarTitleDisplayMode` | `.automatic` | `automatic`, `inline`, `inlineLarge`, `large`. |
| `leading` / `trailing` | `List<CupertinoNativeBarEntry>` | `[]` | See [Bar items](#bar-items). |
| `bottom` | `List<CupertinoNativeBarEntry>` | `[]` | The bottom toolbar. Up to 5 entries. |
| `search` | `CupertinoNativeSearchField?` | — | |

#### Bottom toolbar

SwiftUI's `.bottomBar` placement — the glass bar above the home indicator in
Mail, Safari and Notes. The system draws one shared capsule behind the
entries; a `CupertinoNativeBarSpacer` breaks it, so each side gets its own.

```dart
CupertinoNativeScaffoldNavigationBar(
  title: 'Inbox',
  bottom: [
    CupertinoNativeBarItem(icon: CupertinoNativeIcon.named('folder'), actionId: 'move'),
    CupertinoNativeBarItem(icon: CupertinoNativeIcon.named('trash'), actionId: 'delete'),
    const CupertinoNativeBarSpacer(),
    CupertinoNativeBarItem(icon: CupertinoNativeIcon.named('square.and.pencil'), actionId: 'compose'),
  ],
)
```

Taps report through the scaffold's `onBarAction`, like the other two sides.

#### Search

`CupertinoNativeSearchField` is the page's `.searchable` field.

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `placeholder` | `String?` | — | |
| `placement` | `CupertinoNativeSearchPlacement` | `.automatic` | `automatic`, `toolbar`, `navigationBarDrawer`, `navigationBarDrawerAlways`. |
| `toolbarBehavior` | `CupertinoNativeSearchToolbarBehavior` | `.automatic` | `minimize` collapses the field to a magnifying-glass button as the page scrolls. |

`placement: .toolbar` is the iOS 26 bottom-docked search: on iPhone the field
sits at the **bottom** of the screen in its own glass capsule rather than in a
drawer under the large title. It is a different thing from
`CupertinoNativeTabRole.search`, which makes a whole *tab* the search tab —
the two are often used together (Music, Photos) but either works alone.

Both are properties of the native `NavigationStack`, so they exist only inside
a `CupertinoNativePageScaffold`. There is no way to bring `.searchable` to an
ordinary Flutter page: it is a modifier on a SwiftUI navigation container, and
hosting one standalone is the same problem that keeps `navigationTitle` out of
`CupertinoNativeSliverNavigationBar`.

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

### Popover

The same machinery as the sheet, presented as a floating card pointing at the
control it came from. It stays a popover on iPhone instead of adapting back
into a sheet.

```dart
CupertinoNativePopover.show(
  route: 'filters',
  anchor: CupertinoNativePopover.anchorOf(buttonKey.currentContext!)!,
  preferredSize: const Size(320, 240),
)
```

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `route` | `String` | required | Body route registered in `maybeRun`. |
| `anchor` | `Rect` | required | Global rect of the control — see `anchorOf`. |
| `preferredSize` | `Size?` | — | Without one UIKit sizes the card to the content, which for a Flutter body is the screen. |
| `appBar` | `CupertinoNativeScaffoldNavigationBar?` | — | |

Dismiss it with `CupertinoNativeSheet.dismiss()` — same presentation
underneath.

### Keyboard

Flutter only learns the keyboard's **end** state — `MediaQuery.viewInsets`
jumps to the final height and Flutter then animates over it on a curve of its
own. Anything that moves with the keyboard drifts out of step with it, and a
keyboard dragged down with a finger doesn't move it at all.

`CupertinoNativeKeyboard.metrics` reports the real one, frame by frame: a
`CADisplayLink` reads the presentation layer of a view pinned to the host's
`keyboardLayoutGuide` while UIKit animates it, and KVO catches the steps of an
interactive drag. (The technique is the one
[react-native-keyboard-controller](https://github.com/kirillzyusko/react-native-keyboard-controller)
uses; on iOS 26 it needs no private API.)

**Wrap the app once and you are done.** `CupertinoNativeKeyboardScope`
replaces `MediaQuery.viewInsets.bottom` with the live height, so everything
that already reacts to it — `Scaffold.resizeToAvoidBottomInset`,
`CupertinoPageScaffold`, bottom sheets, scroll-into-view — follows the real
keyboard without knowing this package exists.

```dart
MaterialApp(
  builder: (context, child) => CupertinoNativeKeyboardScope(child: child!),
  home: const HomePage(),
)
```

Bodies of a `CupertinoNativePageScaffold` already have it — the package owns
their root, so there it is automatic.

Read the value directly only when you want something Flutter has no inset for:

```dart
CupertinoKeyboardAvoider(child: composer)

// or the raw metrics
ValueListenableBuilder(
  valueListenable: CupertinoNativeKeyboard.metrics,
  builder: (context, kb, child) =>
      Padding(padding: EdgeInsets.only(bottom: kb.height), child: child!),
  child: composer,
)
```

| `CupertinoKeyboardMetrics` | Type | |
| --- | --- | --- |
| `height` | `double` | Visible height this frame, mid-animation and mid-drag. |
| `progress` | `double` | `height / targetHeight`, 0 to 1. |
| `isAnimating` | `bool` | Moving, by animation or by finger. |
| `targetHeight` | `double` | Where the current transition is heading. 0 while hiding. |
| `isVisible` | `bool` | `height > 0`. |
| `isTracking` | `bool` | Whether the native side has reported anything yet — `height` is 0 before that because nothing has been measured, not because the keyboard is down. |

| `CupertinoKeyboardAvoider` | Type | Default | |
| --- | --- | --- | --- |
| `child` | `Widget` | required | |
| `offset` | `double` | `0` | Extra gap above the keyboard. |
| `ignoreBottomSafeArea` | `bool` | `false` | Subtract the bottom inset, for a child already inside a `SafeArea` — the keyboard covers the home indicator, so its height already includes it. |

Observation starts with the first listener and stops with the last, so it
costs nothing when nobody is watching. While the keyboard moves it delivers
one platform message per frame (up to 120/s); it is idle otherwise. Off iOS
the metrics stay at zero and `CupertinoKeyboardAvoider` falls back to
`MediaQuery.viewInsets`.

**Drag to dismiss** is `CupertinoNativePageScaffold.interactiveKeyboardDismiss`,
and it lives there rather than on a widget because it is a property of the
native scroll view the bodies ride in — an ordinary Flutter page has none.

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

### Animated Symbol

The same symbol as a live SwiftUI `Image`, so `.symbolEffect` has a view to
animate. Use `CupertinoSymbolImage` for a still icon — it composites in
Flutter's own layer tree and so survives a `CupertinoScrollEdgeEffect`; use
this one when it has to move.

```dart
// Discrete: fires once each time `trigger` changes.
CupertinoNativeSymbol.symbol(
  CupertinoSymbols.bell,
  effect: CupertinoNativeSymbolEffect.bounce,
  trigger: _unreadCount,
)

// Indefinite: runs while `repeating` is true.
CupertinoNativeSymbol('wifi',
    effect: CupertinoNativeSymbolEffect.variableColor, repeating: true)
```

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `name` | `String` | required | Or `.symbol(CupertinoSymbols)`. |
| `size` / `color` / `weight` | | `17` / — / `.normal` | |
| `renderingMode` | `CupertinoNativeSymbolRenderingMode?` | — | `monochrome`, `hierarchical`, `palette`, `multicolor`. |
| `effect` | `CupertinoNativeSymbolEffect?` | — | `bounce`, `pulse`, `variableColor`, `wiggle`, `rotate`, `breathe`. |
| `trigger` | `int` | `0` | Bump to fire a discrete effect. |
| `repeating` | `bool` | `false` | Run the effect continuously. `bounce` is discrete only. |
| `replaceOnChange` | `bool` | `false` | Morph between symbols when `name` changes, instead of cutting. |

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
| `CupertinoNativeBarSpacer` | `flexible` — a `ToolbarSpacer`: breaks the toolbar's shared glass capsule in two. |

### Tabs

| Type | Fields |
| --- | --- |
| `CupertinoNativeTab` | `id`, `title`, `icon`, `role` (`.search`), `search` |
| `CupertinoNativeSearchField` | `placeholder`, `placement`, `toolbarBehavior` |
| `CupertinoNativeTabBarAccessory` | `title`, `subtitle`, `icon`, `actionId` |

## Example app

The [example](example/) shows every widget and its variants. Run it on an
iOS 26 device.

Contributions are welcome: <https://github.com/ru-ji/cupertino_widgets>

