# cupertino_widgets

A handful of iOS controls Flutter can only approximate — buttons, toggles,
sliders, menus, tab bars, a SwiftUI navigation scaffold and the iOS 26
**Liquid Glass** material — brought over as-is, with Flutter-style APIs.

> [!WARNING]
> **Experimental.** This package embeds real UIKit and SwiftUI views inside a
> Flutter app. That crosses a boundary Flutter's engine only partly supports,
> and some of the rough edges are not mine to fix — see
> [Limitations](#limitations) for the ones with open Flutter issues behind
> them. Treat it as a research project, not something to put in front of
> paying users. The API is pre-1.0 and will break.

## Why

Flutter's Cupertino widgets are *drawings* of iOS controls, and the gap shows
in the details: gesture feel, haptics, Dynamic Type, accessibility, and
anything Apple ships next year. Embedding the system control closes that gap
for the few places it matters. Everything else stays ordinary Flutter — this
is not a native-UI framework, just better fidelity where iOS users notice.
State lives in Dart with the usual `value` / `onChanged` API.

## Install

```yaml
dependencies:
  cupertino_widgets: ^0.1.0
```

```dart
import 'package:cupertino_widgets/cupertino_widgets.dart';
```

Flutter 3.41+, Dart 3.10+, iOS 15+. Integrates via Swift Package Manager.

iOS 26 is not required. On iOS 15–18 every component renders its classic
pre-26 system style — material blur instead of Liquid Glass, Flutter's
`CupertinoSliverNavigationBar` behind `CupertinoSliverAppBar` — and iOS 26-only
properties (glass styles, corner concentricity, scroll edge effect tuning) are
ignored rather than throwing. The native scaffold needs iOS 16+. On platforms
other than iOS the widgets render simple Flutter fallbacks, so shared code
still builds.

## Contents

- [Native controls](#native-controls) — Slider, Switch, Segmented Control,
  Button, Popup Menu, Context Menu, Alert, Progress, Text Field, Date Picker,
  Liquid Glass, Tab Bar, List &amp; Form, Sheet, Native Scaffold
- [Flutter-drawn companions](#flutter-drawn-companions) — App Bar, Scroll Edge
  Effect, Symbol Image
- [Shared models](#shared-models) — icons, menu items, list rows, bar items
- [Limitations](#limitations) — what does not work, and why
- [Routing](#routing--go_router--friends) · [Performance](#performance)

---

# Native controls

## Slider

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_widgets/main/doc/images/slider.jpg" width="320" alt="Native slider" />

```dart
CupertinoNativeSlider(
  value: _volume,
  onChanged: (v) => setState(() => _volume = v),
)
```

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `value` | `double` | required | Current position. |
| `onChanged` | `ValueChanged<double>?` | — | Fires continuously while dragging. Null disables the control. |
| `min` | `double` | `0.0` | Lower bound. |
| `max` | `double` | `1.0` | Upper bound. |
| `divisions` | `int?` | — | Snap to N discrete steps. Null is continuous. |
| `activeColor` | `Color?` | — | Tint of the filled track. |
| `thumbColor` | `Color?` | — | Tint of the knob. |

## Switch

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_widgets/main/doc/images/toggle.jpg" width="320" alt="Native switch" />

```dart
CupertinoNativeSwitch(
  value: _wifi,
  onChanged: (v) => setState(() => _wifi = v),
)
```

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `value` | `bool` | required | On/off state. |
| `onChanged` | `ValueChanged<bool>?` | — | Null disables the control. |
| `label` | `String?` | — | Native label drawn beside the switch. |
| `activeColor` | `Color?` | — | Tint when on. |
| `textStyle` | `TextStyle?` | — | Style for `label`; `fontSize`, `fontWeight` and `color` are forwarded. |
| `width` / `height` | `double?` | — | Explicit size; intrinsic when null. |

## Segmented Control

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_widgets/main/doc/images/segmented.jpg" width="320" alt="Native segmented control" />

```dart
CupertinoNativeSegmentedControl(
  children: ['Day', 'Week', 'Month'],
  groupValue: _range,
  onChanged: (v) => setState(() => _range = v),
)
```

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `children` | `List<String>` | required | Segment titles. |
| `groupValue` | `int` | required | Index of the selected segment. |
| `onChanged` | `ValueChanged<int>?` | — | Fires with the new index. |
| `activeColor` | `Color?` | — | Tint of the sliding selection. |
| `width` / `height` | `double?` | — | Explicit size; intrinsic when null. |

## Button

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_widgets/main/doc/images/buttons.jpg" width="320" alt="Native buttons" />

```dart
CupertinoNativeButton(
  title: 'Call',
  icon: CupertinoNativeIcon.symbol(CupertinoSymbols.phoneFill),
  style: CupertinoNativeButtonStyle.glassProminent, // Liquid Glass on iOS 26
  borderShape: CupertinoNativeButtonBorderShape.capsule,
  onPressed: () {},
)
```

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `title` | `String` | `''` | Button label. |
| `icon` | `CupertinoNativeIcon?` | — | SF Symbol or Flutter glyph. Takes precedence over `systemImage`. |
| `systemImage` | `String?` | — | **Deprecated** — raw SF Symbol name. Use `icon`. |
| `style` | `CupertinoNativeButtonStyle` | `.automatic` | `automatic`, `filled`, `tinted`, `plain`, `glass`, `glassProminent`. |
| `controlSize` | `CupertinoNativeControlSize` | `.regular` | SwiftUI metrics — height, padding, font — not an explicit size. `mini` for tight spaces, `small` for secondary toolbar options, `regular` for everyday controls, `large` for call-to-action, `extraLarge` for full-width or prominent ones (falls back to `large` below iOS 17). |
| `borderShape` | `CupertinoNativeButtonBorderShape` | `.automatic` | `automatic`, `capsule`, `circle`, `roundedRectangle`. |
| `labelStyle` | `CupertinoNativeButtonLabelStyle` | `.titleAndIcon` | `titleAndIcon`, `titleOnly`, `iconOnly`. |
| `expand` | `bool` | `false` | Stretch to the available width. |
| `onPressed` | `VoidCallback?` | — | Null disables the button. |
| `activeColor` | `Color?` | — | Tint. |
| `textStyle` | `TextStyle?` | — | `fontSize`, `fontWeight`, `color` forwarded natively. |
| `width` / `height` | `double?` | — | Explicit size; intrinsic when null. |

## Popup Menu

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_widgets/main/doc/images/menu.jpg" width="320" alt="Native popup menu" />

```dart
CupertinoNativeMenu(
  title: 'Actions',
  items: [
    CupertinoNativeMenuAction(
        title: 'Rename', systemImage: 'pencil', actionId: 'rename'),
    CupertinoNativeMenuAction(
        title: 'Delete', systemImage: 'trash',
        isDestructive: true, actionId: 'delete'),
  ],
  onAction: (id, _) => handle(id),
)
```

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `items` | `List<CupertinoNativeMenuItem>` | required | Actions, sections, submenus, toggles — see [Menu items](#menu-items). |
| `onAction` | `CupertinoNativeMenuActionCallback?` | — | `(actionId, value)`; `value` is the new state for toggles. |
| `title` | `String` | `'Options'` | Label of the button that opens the menu. |
| `systemImage` | `String?` | — | SF Symbol on that button. |
| `style` | `CupertinoNativeButtonStyle` | `.automatic` | Style of the anchor button. |
| `borderShape` | `CupertinoNativeButtonBorderShape` | `.automatic` | Outline of the anchor. A `circle` needs `labelStyle: .iconOnly` — an anchor still carrying its title is laid out as a capsule whatever shape is asked for. |
| `labelStyle` | `CupertinoNativeButtonLabelStyle` | `.titleAndIcon` | Which halves of the anchor show. |
| `controlSize` | `CupertinoNativeControlSize` | `.regular` | The anchor's metrics. |
| `activeColor` | `Color?` | — | Tint. |
| `textStyle` | `TextStyle?` | — | Style of the anchor label. |
| `width` / `height` | `double?` | — | Explicit size; intrinsic when null. |

## Context Menu

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_widgets/main/doc/images/contextmenu.jpg" width="320" alt="Native context menu" />

```dart
CupertinoNativeContextMenu(
  items: [/* same CupertinoNativeMenuItem model as the popup menu */],
  onAction: (id, _) => handle(id),
  blurBackground: true, // native blur over the whole app while open
  child: PhotoCard(),
)
```

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `child` | `Widget` | required | Flutter content the menu wraps. |
| `items` | `List<CupertinoNativeMenuItem>` | required | Menu entries. |
| `onAction` | `CupertinoNativeMenuActionCallback?` | — | Tapped item's `actionId`. |
| `preview` | `Widget?` | — | Replaces the lifted preview. Defaults to a snapshot of `child`. |
| `onOpenChanged` | `ValueChanged<bool>?` | — | Fires `false` when dismissal *starts*, not when it ends. |
| `blurBackground` | `bool` | `false` | Blurs the whole app behind the menu, natively (`UIVisualEffectView` over the window) — a Flutter blur cannot sample the native menu above it. |
| `childInteractive` | `bool` | `false` | Let `child` receive touches. Keep false so the long-press reaches the native interaction. |

## Alert

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_widgets/main/doc/images/alert.jpg" width="320" alt="Native alert" />

```dart
CupertinoNativeAlert.show(
  context: context,
  title: 'Erase All Content and Settings?',
  message: 'This cannot be undone.',
  actions: [
    CupertinoNativeAlertAction(title: 'Cancel', isCancel: true, onPressed: () {}),
    CupertinoNativeAlertAction(
        title: 'Erase', isDestructive: true, onPressed: () {}),
  ],
)
```

`CupertinoNativeAlert.show({context, title, message, actions})` — a static
call, not a widget. Each `CupertinoNativeAlertAction` takes:

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `title` | `String` | required | Button label. |
| `isDestructive` | `bool` | `false` | Red destructive styling. |
| `isCancel` | `bool` | `false` | Bold cancel role, pinned to the bottom. |
| `onPressed` | `VoidCallback?` | — | Fired after the alert dismisses. |

## Progress

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_widgets/main/doc/images/progress.jpg" width="320" alt="Native progress indicators" />

```dart
CupertinoNativeProgressIndicator(
  value: downloaded, total: totalBytes,          // linear, determinate
  style: CupertinoNativeProgressStyle.linear,
)
CupertinoNativeProgressIndicator(                // circular, indeterminate
  style: CupertinoNativeProgressStyle.circular,
)
```

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `value` | `double?` | — | Progress. **Null loops indefinitely** (indeterminate). |
| `total` | `double` | `1.0` | Value corresponding to 100 %. |
| `label` | `String?` | — | Optional label drawn with the indicator. |
| `style` | `CupertinoNativeProgressStyle` | `.automatic` | `automatic`, `linear`, `circular`. |
| `activeColor` | `Color?` | — | Tint. |

## Text Field

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_widgets/main/doc/images/textfield.jpg" width="320" alt="Native text field" />

```dart
CupertinoNativeTextField(
  placeholder: 'Search or enter text…',
  glass: CupertinoGlass(cornerRadius: 22),  // Liquid Glass capsule (iOS 26)
  prefixIcon: CupertinoNativeIcon.symbol(CupertinoSymbols.magnifyingglass),
  clearButtonMode: OverlayVisibilityMode.editing,
  onChanged: (v) => setState(() => _query = v),
)
```

A real `UITextField`: iOS autofill, QuickType, the system caret and selection
handles. Single-line only — multi-line would need `UITextView`.

**Content and state**

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `controller` | `TextEditingController?` | — | Standard Flutter controller. |
| `focusNode` | `FocusNode?` | — | Bridged to the native first-responder state, both directions. |
| `placeholder` | `String?` | — | Hint text. |
| `enabled` | `bool` | `true` | |
| `readOnly` | `bool` | `false` | |
| `autofocus` | `bool` | `false` | |
| `maxLength` | `int?` | — | |

**Keyboard and input**

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `keyboardType` | `TextInputType` | `.text` | |
| `textInputAction` | `TextInputAction?` | — | Return-key role. |
| `obscureText` | `bool` | `false` | |
| `autocorrect` | `bool` | `true` | |
| `enableSuggestions` | `bool` | `true` | |
| `textCapitalization` | `TextCapitalization` | `.none` | |
| `textContentType` | `String?` | — | iOS autofill hint: `'password'`, `'username'`, `'emailAddress'`, `'oneTimeCode'`, … |

**Appearance**

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `style` | `TextStyle?` | — | `fontSize`, `fontWeight`, `color` forwarded natively. |
| `textAlign` | `TextAlign` | `.start` | |
| `verticalAlignment` | `TextAlignVertical` | `.center` | Where the line sits in an explicit `height`. |
| `cursorColor` | `Color?` | — | |
| `clearButtonMode` | `OverlayVisibilityMode` | `.never` | Same type `CupertinoTextField` takes. |
| `backgroundColor` | `Color?` | — | Defaults to transparent. |
| `cornerRadius` | `double?` | — | Native radius on that background; also gives the text a 16 pt inset. Ignored when `glass` is set. |
| `glass` | `CupertinoGlass?` | — | Renders the field on Liquid Glass (iOS 26). |
| `prefixIcon` / `suffixIcon` | `CupertinoNativeIcon?` | — | Native `leftView` / `rightView`. SF Symbols only. |
| `width` / `height` | `double?` | — | Fills the available width when null. |
| `fillHeight` | `bool` | `false` | Adopt the parent's height, so the native view resizes with its host. |

**Callbacks** — `onChanged`, `onSubmitted`, `onEditingComplete`, `onTap`
(fires on focus), `onTapOutside` (`(_) => FocusScope.of(context).unfocus()`
dismisses the keyboard).

## Date Picker

```dart
CupertinoNativeDatePicker(
  value: _starts,
  mode: CupertinoNativeDatePickerMode.dateAndTime,
  onChanged: (d) => setState(() => _starts = d),
)
```

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `value` | `DateTime` | required | Selected date/time. |
| `onChanged` | `ValueChanged<DateTime>?` | — | |
| `mode` | `CupertinoNativeDatePickerMode` | `.date` | `date`, `time`, `dateAndTime`. |
| `minimumDate` / `maximumDate` | `DateTime?` | — | Selectable range. |
| `activeColor` | `Color?` | — | Accent of the popped-open calendar. |
| `width` / `height` | `double?` | — | Defaults to the compact pill (148 × 36). |

## Liquid Glass (iOS 26)

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_widgets/main/doc/images/glass.jpg" width="320" alt="Liquid Glass container" />

```dart
CupertinoNativeGlassContainer(
  shape: CupertinoGlassShape.capsule,
  variant: CupertinoGlassVariant.clear,  // .regular (default) or .clear
  interactive: true,                     // system touch shimmer
  onPressed: () {},                      // makes it a glass button
  route: 'now_playing',                  // Flutter content INSIDE the glass
)
```

Check `CupertinoNativeGlassContainer.isSupported` to branch below iOS 26.

**Content goes inside the glass.** `route` hosts a Flutter engine as a SwiftUI
view and applies `glassEffect` to it — the arrangement Apple documents
(`content.glassEffect(...)`), so the content is drawn above the material rather
than refracted through it. It is live Flutter: `setState`, Riverpod,
animations, gestures, all of it runs in there as it does anywhere else.

```dart
CupertinoNativeGlassContainer(shape: CupertinoGlassShape.capsule, route: 'now_playing')
```

```dart
void main() {
  if (CupertinoNativeScaffold.maybeRun({
    'now_playing': () => const NowPlayingLabel(),
  })) return;
  runApp(const MyApp());
}
```

The route runs in its own isolate, like every scaffold body: it cannot read the
surrounding widget tree, so pass it what it needs over a channel. Its engine is
parked in the shared pool when the container goes away, so a container that
scrolls out of view and back re-attaches instead of re-booting.

With no `route` and no `icon`, the container is glass and nothing else — size
it and stack whatever you like over it in Flutter. That is compositing: the
material treats the widget as backdrop and refracts it at the edges, plainly
visible with the clear variant.

**Animating.** Two paths, and each is the cheap one for what it animates.

`animateChanges` covers everything the native side owns — tint, variant, shape,
corner radius. Dart sends the target once and CoreAnimation interpolates, so
the transition costs a single message instead of one per frame and stays smooth
while the Dart thread is busy.

Size is the other path. Drive `width`/`height` from Flutter — a
`TweenAnimationBuilder`, an `AnimatedBuilder`, anything — and the glass follows
frame for frame at no cost: the platform view's frame *is* the box Flutter
built, so the material fills it with nothing sent natively. The container
compares what it last sent before touching the channel, so those rebuilds stop
in Dart. Leave `animateChanges` off for that: the box is already animating.

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `route` | `String?` | — | Live Flutter content inside the glass, hosted as an engine. Registered like a scaffold body. |
| `shape` | `CupertinoGlassShape` | `.roundedRect` | `capsule`, `circle`, `roundedRect`. |
| `cornerRadius` | `double` | `26` | For `roundedRect`; continuous corners. |
| `variant` | `CupertinoGlassVariant` | `.regular` | `regular` or the more transparent `clear`. |
| `tint` | `Color?` | — | Tint mixed into the material. |
| `interactive` | `bool` | `false` | System touch shimmer. |
| `animateChanges` | `bool` | `false` | Interpolate tint/variant/shape changes on the SwiftUI side. |
| `onPressed` | `VoidCallback?` | — | Makes the container a glass button. |
| `icon` | `CupertinoNativeIcon?` | — | Symbol rendered natively, centered in the glass. |
| `padding` | `EdgeInsetsGeometry` | `.zero` | Inset between glass bounds and its content. |
| `width` / `height` | `double?` | — | Explicit size, animatable from Dart. Left null a native `icon` or a `route` body is measured by SwiftUI; with neither the glass fills the space offered. |

`CupertinoGlass` — the settings object taken by `CupertinoNativeTextField.glass`:
`cornerRadius` (`16`), `variant` (`.regular`), `interactive` (`true`), `tint`.

## Tab Bar

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_widgets/main/doc/images/tabbar.jpg" width="320" alt="Native tab bar" />

```dart
CupertinoNativeTabBar(
  value: _tab,
  split: true, rightCount: 1,            // iOS 26 split search tab
  tabs: [
    CupertinoNativeTab(
        title: 'Home',
        icon: CupertinoNativeIcon.symbol(CupertinoSymbols.houseFill),
        id: 'home'),
    CupertinoNativeTab(
        title: '',
        icon: CupertinoNativeIcon.symbol(CupertinoSymbols.magnifyingglass),
        id: 'search',
        role: CupertinoNativeTabRole.search),
  ],
  onChanged: (id) => setState(() => _tab = id),
)
```

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `tabs` | `List<CupertinoNativeTab>` | required | See [Tabs](#tabs). |
| `value` | `String` | required | Id of the selected tab. |
| `onChanged` | `ValueChanged<String>?` | — | Fires with the new tab id. |
| `split` | `bool` | `false` | Detach the trailing `rightCount` tabs into their own bar (iOS 26). |
| `rightCount` | `int` | `1` | How many tabs go in the detached bar. |
| `splitSpacing` | `double` | `8.0` | Gap between the two bars. |
| `shrinkCentered` | `bool` | `true` | When not split, hug the content width (floating pill). |
| `minimizeBehavior` | `CupertinoNativeTabBarMinimizeBehavior` | `.automatic` | `automatic`, `onScrollDown`, `onScrollUp`, `never`. Only inside `CupertinoNativeScaffold`. |
| `scrollEdgeEffect` | `CupertinoScrollEdgeEffectStyle` | `.automatic` | `soft`/`automatic` translucent, `hard` opaque. iOS 26 only. |
| `accessory` | `CupertinoNativeTabBarAccessory?` | — | iOS 26 bottom accessory above the bar. Only inside `CupertinoNativeScaffold`. |
| `activeColor` / `backgroundColor` | `Color?` | — | |
| `height` | `double?` | — | Intrinsic when null. |

`CupertinoNativeTabBarAccessory` — `title`, `subtitle`, `icon`,
`actionId` (default `'accessory'`).

Best used as a `Stack` overlay (`Align(alignment: Alignment.bottomCenter)`)
rather than in `Scaffold.bottomNavigationBar`, so it can hug its intrinsic
width and float like the iOS 26 pill.

## List & Form

Real SwiftUI inset-grouped sections — 26 pt concentric corners on iOS 26,
10 pt before — with row taps and toggles reported back to Dart.

```dart
CupertinoNativeList(
  style: CupertinoNativeListStyle.insetGrouped,
  onRowTap: (id) => open(id),
  onToggle: (id, on) => setState(() => _flags[id] = on),
  sections: [
    CupertinoNativeListSection(
      header: 'Connectivity',
      footer: 'Turning this off disables all wireless radios.',
      rows: [
        CupertinoNativeListRow(
          id: 'wifi',
          title: 'Wi-Fi',
          value: 'Home',
          icon: CupertinoNativeIcon.symbol(CupertinoSymbols.wifi),
          showChevron: true,
        ),
        CupertinoNativeListRow(
          id: 'airplane',
          title: 'Airplane Mode',
          type: CupertinoNativeListRowType.toggle,
          toggleValue: false,
        ),
      ],
    ),
  ],
)
```

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `sections` | `List<CupertinoNativeListSection>` | required | |
| `style` | `CupertinoNativeListStyle` | `.insetGrouped` | `automatic`, `plain`, `grouped`, `insetGrouped`, `sidebar`. |
| `scrollable` | `bool` | `false` | Let the native list own its scrolling. Keep false inside a Flutter scroll view. |
| `height` | `double?` | — | Intrinsic when null. |
| `cornerRadius` | `double?` | — | Null matches the running iOS version's Settings app. |
| `activeColor` | `Color?` | — | Tint for toggles and buttons. |
| `onRowTap` | `CupertinoNativeListRowCallback?` | — | Row `id`. |
| `onToggle` | `CupertinoNativeListToggleCallback?` | — | `(id, value)`. |

`CupertinoNativeForm` takes the same parameters minus `style` — it is the
`Form`-styled variant.

## Sheet

A native page sheet: detents, grabber, a pinned native app bar, and your
Flutter content scrolling beneath it. The body runs in its own engine, resolved
from the same route table as the scaffold.

```dart
await CupertinoNativeSheet.show(
  route: 'newEvent',
  appBar: CupertinoNativeAppBar(title: 'New Event'),
  detents: [CupertinoNativeSheetDetent.medium, CupertinoNativeSheetDetent.large],
  showDragHandle: true,
  onBarAction: (id) { if (id == 'close') CupertinoNativeSheet.dismiss(); },
);
```

`CupertinoNativeSheet.show({...})` — static, returns when the sheet dismisses.

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `route` | `String` | required | Body route, resolved by `maybeRun`. |
| `appBar` | `CupertinoNativeAppBar?` | — | Pinned navigation bar. |
| `bottom` | `CupertinoNativeSheetSegmentedControl?` | — | Native segmented control pinned under the bar (`segments`, `selectedIndex`). |
| `detents` | `List<CupertinoNativeSheetDetent>` | `[large]` | `medium`, `large`. |
| `showDragHandle` | `bool` | `false` | The grabber. |
| `cornerRadius` | `double?` | — | |
| `scrollEdgeEffect` | `CupertinoScrollEdgeEffectStyle` | `.soft` | |
| `backgroundColor` | `Color?` | — | Match your body's background so chrome bands don't show. |
| `showLoadingIndicator` | `bool?` | — | Falls back to `CupertinoWidgetsSettings.showLoadingIndicator`. |
| `isDark` | `bool?` | — | Forces the body's brightness. |
| `onBarAction` | `void Function(String)?` | — | Bar item `actionId`. |
| `onBottomChanged` | `ValueChanged<int>?` | — | Segmented control index. |
| `onSearchChanged` / `onSearchSubmitted` | `ValueChanged<String>?` | — | When the bar declares a search field. |

Dismiss programmatically with `CupertinoNativeSheet.dismiss()`.

## Native Scaffold

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_widgets/main/doc/images/scaffold.jpg" width="320" alt="Native scaffold with bottom accessory" />

Your Flutter pages, rendered inside a SwiftUI `NavigationStack`: system
push/pop transitions and back-swipe, large titles collapsing on scroll. The
one thing here with real architectural weight — read [Routing](#routing--go_router--friends)
and [Performance](#performance) before reaching for it.

```dart
// main.dart — bodies run in their own engines, resolved from a route table:
void main() {
  if (CupertinoNativeScaffold.maybeRun(scaffoldRoutes())) return;
  runApp(const MyApp());
  CupertinoNativeScaffold.prewarm(); // optional: pay engine cold-start now
}

CupertinoNativeScaffold(
  appBar: CupertinoNativeAppBar(title: 'Library'),
  tabBar: CupertinoNativeTabBar(
    accessory: CupertinoNativeTabBarAccessory(
        title: 'Now Playing', icon: CupertinoNativeIcon.named('music.note')),
    tabs: [/* ... */],
  ),
)
```

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `body` | `String?` | — | Root body route when there is no `tabBar`. With one, each tab `id` doubles as its route. |
| `appBar` | `CupertinoNativeAppBar?` | — | Root bar config, applied to each tab's root page. |
| `tabBar` | `CupertinoNativeTabBar?` | — | Enables tabbed mode. |
| `controller` | `CupertinoNativeScaffoldController?` | — | Imperative `pushNamed` / `pop`. |
| `onBarAction` | `CupertinoNativeBarActionCallback?` | — | Bar item `actionId`. |
| `onTabChanged` | `ValueChanged<String>?` | — | |
| `onRouteChanged` | `CupertinoNativeRouteChangedCallback?` | — | The tab's native stack after any push/pop, including back-swipe. |
| `onSearchChanged` / `onSearchSubmitted` | `CupertinoNativeSearchCallback?` | — | Per-page search field. |
| `onSearchActiveChanged` | `CupertinoNativeSearchActiveCallback?` | — | SwiftUI `isSearching`. |
| `scrollEdgeEffect` | `CupertinoScrollEdgeEffectStyle` | `.automatic` | |
| `backgroundColor` | `Color?` | — | Defaults to `Theme.of(context).scaffoldBackgroundColor`. |
| `activeColor` | `Color?` | — | Defaults to `Theme.of(context).colorScheme.primary`. |
| `showLoadingIndicator` | `bool?` | — | Spinner while a body engine boots. Defaults to the global setting. |

**Writing a body.** A body runs in its own engine, so it must use drawn
Flutter widgets — no platform views inside it — and must self-size
(`Column(mainAxisSize: MainAxisSize.min)`). The same holds for sheet bodies.

Push and pop with `CupertinoNativeScaffold.push(CupertinoNativeScaffoldPage(route:, appBar:))`,
`.pushNamed(route)`, `.pop()`. Inside a body, read the live native search state
from `CupertinoNativeScaffold.searchState` — a
`ValueNotifier<CupertinoNativeSearchState>` carrying `query`, `isActive`,
`isSubmitted`.

### Native app bar

`CupertinoNativeAppBar` configures the SwiftUI navigation bar of a scaffold or
sheet page.

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `title` | `String` | required | |
| `subtitle` | `String?` | — | `.navigationSubtitle`, iOS 26+. |
| `titleDisplayMode` | `CupertinoNativeToolbarTitleDisplayMode` | `.automatic` | `automatic`, `inline`, `inlineLarge`, `large`. |
| `leading` / `trailing` | `List<CupertinoNativeBarEntry>` | `[]` | See [Bar items](#bar-items). |
| `search` | `CupertinoNativeSearchField?` | — | Makes the page `.searchable`. |

`CupertinoNativeSearchField` — `placeholder`, and `placement`
(`CupertinoNativeSearchPlacement`: `automatic`, `toolbar`,
`navigationBarDrawer`, `navigationBarDrawerAlways`).

---

# Flutter-drawn companions

These are drawn in Flutter, not hosted natively — so they compose normally,
transform correctly, and are not subject to the platform-view
[limitations](#limitations) below.

## App Bar

`CupertinoSliverAppBar` recreates the iOS 26 navigation bar: no solid
background or hairline, a blur-morph large-title collapse, Liquid Glass bar
buttons, and a `.search` variant whose field morphs to the top when tapped.
Below iOS 26 it falls back to Flutter's `CupertinoSliverNavigationBar`.

```dart
CustomScrollView(
  slivers: [
    CupertinoSliverAppBar.search(
      largeTitle: 'Library',
      subtitle: '128 albums',
      leading: CupertinoNativeButton(
        icon: CupertinoNativeIcon.symbol(CupertinoSymbols.chevronBackward),
        style: CupertinoNativeButtonStyle.glass,
        borderShape: CupertinoNativeButtonBorderShape.circle,
        labelStyle: CupertinoNativeButtonLabelStyle.iconOnly,
        onPressed: () => Navigator.pop(context),
      ),
      trailing: [
        CupertinoNativeButton(
          icon: CupertinoNativeIcon.symbol(CupertinoSymbols.arrowUpArrowDown),
          style: CupertinoNativeButtonStyle.glass,
          borderShape: CupertinoNativeButtonBorderShape.circle,
          labelStyle: CupertinoNativeButtonLabelStyle.iconOnly,
          onPressed: () {},
        ),
        CupertinoNativeButton(
          title: 'Edit',
          style: CupertinoNativeButtonStyle.glass,
          borderShape: CupertinoNativeButtonBorderShape.capsule,
          onPressed: () {},
        ),
      ],
      searchPlaceholder: 'Artists, Songs, Albums',
      bottomMode: NavigationBarBottomMode.always,
      onSearchChanged: (q) => setState(() => _query = q),
      onSearchActiveChanged: (active) => setState(() => _searching = active),
    ),
    // ... your slivers
  ],
)
```

**Title and layout**

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `largeTitle` | `String` | required | The title text. |
| `subtitle` | `String?` | — | Second line, under the large and the inline title. |
| `centerTitle` | `bool` | `true` | Inline title centered, or right after `leading`. |
| `expandedTitle` | `bool` | `true` | False makes the bar inline-only — nothing collapses. |
| `collapseTitle` | `bool` | `true` | False keeps the title large for good; the edge effect still comes up at the collapse point. iOS 26+. |

**Actions**

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `leading` | `Widget?` | — | Anything. |
| `trailing` | `List<Widget>` | `[]` | Anything, laid out in a row with 10pt between entries. |

There is no action type: the bar positions whatever you give it and stays out
of its way. The iOS 26 bar button is a `CupertinoNativeButton` in the system's
`.glass` style with the `circle` border shape and the `iconOnly` label style —
44×44 by default, `controlSize` to shift the metrics, `width`/`height` or an
enclosing `SizedBox` to override them outright. A glass capsule with text in it
is a `.glass` `CupertinoNativeButton` with the `capsule` border shape.

**Bottom slot** — default constructor

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `bottom` | `Widget?` | — | Widget under the large title. Always visible: the title collapses, this stays pinned. |
| `bottomHeight` | `double` | `44` | Height of that slot. |

**Bottom slot** — `.search` constructor

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `searchPlaceholder` | `String?` | — | Hint text. |
| `searchStyle` | `TextStyle?` | — | `fontSize`, `fontWeight`, `color` forwarded natively. |
| `searchPrefixIcon` / `searchSuffixIcon` | `CupertinoNativeIcon?` | — | Defaults to the system magnifying glass. |
| `searchGlass` | `bool` | `false` | Rest the field on Liquid Glass instead of the filled capsule. |
| `searchFieldHeight` | `double` | `44` | |
| `bottomMode` | `NavigationBarBottomMode` | `.automatic` | `automatic` collapses the row with the scroll; `always` keeps it visible. |
| `scrollToTopOnSearch` | `bool` | `true` | Set false when the search filters content in place rather than replacing it. |
| `onSearchChanged` | `ValueChanged<String>?` | — | Every keystroke. |
| `onSearchActiveChanged` | `ValueChanged<bool>?` | — | Swap the page content for a search view. |

**Edge effect**

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `scrollEdgeEffect` | `CupertinoScrollEdgeEffectStyle` | `.soft` | |
| `tintColor` | `Color?` | — | Tint of the edge effect. Pass your page background when it is not `systemBackground`. |

`CupertinoAppBar` is the non-sliver version, for pages that do not scroll:
`title`, `subtitle`, `centerTitle`, `leading`, `trailing`, `scrollEdgeEffect`,
`tintColor`.

## Scroll Edge Effect

The iOS 26 progressive blur plus gradient scrim where content meets a screen
edge, with the system's parameters filled in. Place it in a `Stack` behind a
bar, sized to the region that should melt into the edge.

```dart
Stack(children: [
  Positioned(top: 0, left: 0, right: 0, height: 120,
    child: CupertinoScrollEdgeEffect(edge: CupertinoScrollEdgeEffectEdge.top)),
  // ... bar content
])
```

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `edge` | `CupertinoScrollEdgeEffectEdge` | `.top` | `top` or `bottom`. |
| `style` | `CupertinoScrollEdgeEffectStyle` | `.soft` | `soft` is the progressive blur plus scrim. `hard` is the system's cut-off: an opaque background ending with the bar, no blur and no fade — the way Flutter's own `AppBar` sits on a `Scaffold`. `automatic` is treated as `soft`. |
| `color` | `Color?` | — | Tint. Defaults to the resolved system background — pass your page background when it differs. |
| `intensity` | `double` | `1` | Scales blur and scrim together, 0 to 1. |
| `native` | `bool` | `false` | Render as a native view instead of the shader. Set it only when the effect has to cover a native control — see below. Ignored off iOS. |

Built on [haze](https://pub.dev/packages/haze): two backdrop layers running a
separable fragment shader (`ui.ImageFilter.shader`), not a plain Gaussian blur,
with sampling bounded to the widget's own rectangle so nothing outside it
smears in.

**Over a native control, set `native: true`.** A backdrop filter only ever
filters its own render target. Painted over a platform view, the shader lands in
an overlay layer that the iOS embedder clears to transparent before rendering
into it — so it filters nothing, and the control keeps drawing crisply through
the effect. `native: true` swaps the shader for a `UIVisualEffectView`, which is
composited after the control's own view and samples the whole UIKit hierarchy
below it: Flutter surface and native controls alike.

It is a trade, not an upgrade. `UIVisualEffectView` is the only view UIKit hands
the backdrop to, and its blur radius is the material's rather than ours, so
`intensity` scales how much of the effect shows through the falloff instead of
how wide the kernel is — the ramp reads flatter than the shader's. Nothing an
app can write sees past its own content: not Metal in a `CAMetalLayer`, not
SwiftUI's `.layerEffect`, not Flutter's `ImageFilter`. Flutter's own engine hit
this wall and answered it by reaching into `UIVisualEffectView`'s private view
tree for its `gaussianBlur` CAFilter, with a runtime bail-out for the day Apple
renames something. Leave `native` false on pages with no native view under the
effect.

**Not the system effect.** `UIScrollEdgeEffect` is a property of a scroll view
and blurs *that scroll view's own content*. A Flutter page has no `UIScrollView`
in it, so a native effect hosted over one finds nothing to blur and draws
nothing at all — measured, not assumed. (`glassEffect` is the exception that
makes this worth checking: it samples its backdrop, which is why the glass
container refracts Flutter content behind it.) The system's adaptive tint —
which thins over bright, busy content — is therefore out of reach here, and
available only inside `CupertinoNativeScaffold`, where a real SwiftUI
`ScrollView` owns the content.

## Symbol Image

An SF Symbol rasterized natively and handed back as an image, so it draws in
Flutter's own layer tree instead of a platform view. Use it for SF Symbols in
Flutter-drawn UI, where a hosted icon would hit the limitations below.

```dart
CupertinoSymbolImage('gear', size: 17, color: CupertinoColors.systemBlue)
CupertinoSymbolImage.symbol(CupertinoSymbols.listBullet, size: 20)
```

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `name` | `String` | required | Raw SF Symbol name, e.g. `slider.horizontal.3`. |
| `size` | `double` | `17` | Point size for `UIImage.SymbolConfiguration`. The rendered image is larger — a symbol's box includes the font ascent — so the widget sizes itself to the image. |
| `color` | `Color?` | — | Tint. |
| `weight` | `FontWeight` | `.normal` | Mapped to the five `UIImage.SymbolWeight` values. |

Results are cached process-wide by name/size/color/weight, and the futures are
shared, so repeats in a list cost one platform call. Renders nothing until the
first frame after that call returns, and nothing at all off iOS or for an
unknown symbol name.

---

# Shared models

## Icons

`CupertinoNativeIcon` is what every native control takes for an icon.

```dart
CupertinoNativeIcon.symbol(CupertinoSymbols.starFill, size: 20, color: gold)
CupertinoNativeIcon.named('rectangle.topthird.inset.filled')  // any raw name
CupertinoNativeIcon.flutter(Icons.rocket_launch)              // Flutter glyph
```

| Constructor | |
| --- | --- |
| `.symbol(CupertinoSymbols, {size, color, renderingMode})` | Typo-safe, from the enum. |
| `.named(String, {size, color, renderingMode})` | Any raw SF Symbol name. |
| `.flutter(IconData, {size, color})` | Any Flutter icon font — the font is loaded from the app bundle and drawn natively. |

`renderingMode` is `CupertinoSymbolRenderingMode`: `monochrome`,
`hierarchical`, `palette`, `multicolor`. `CupertinoSymbols` covers 176 common
symbols; use `.named` for anything else.

## Menu items

Shared by `CupertinoNativeMenu` and `CupertinoNativeContextMenu`.

| Type | Fields |
| --- | --- |
| `CupertinoNativeMenuAction` | `title`, `actionId`, `subtitle`, `systemImage`, `isDestructive` (`false`), `isDisabled` (`false`) |
| `CupertinoNativeMenuToggle` | `title`, `actionId`, `value`, `systemImage` |
| `CupertinoNativeSubmenu` | `title`, `items`, `systemImage` |
| `CupertinoNativeMenuSection` | `title`, `items` — a titled group with separators |

## List rows

| Type | Fields |
| --- | --- |
| `CupertinoNativeListSection` | `rows`, `header`, `footer` |
| `CupertinoNativeListRow` | `id`, `title`, `subtitle`, `icon`, `value` (trailing detail text), `showChevron` (`false`), `type` (`.label`), `toggleValue` (`false`), `enabled` (`true`) |

`CupertinoNativeListRowType`: `label` (taps → `onRowTap`), `toggle` (flips →
`onToggle`), `button` (tinted title, taps → `onRowTap`).

## Bar items

For `CupertinoNativeAppBar.leading` / `.trailing`.

| Type | Fields |
| --- | --- |
| `CupertinoNativeBarItem` | `actionId`, `title`, `icon`, `sharedBackgroundVisibility` (`false`), `glass` (`true`) |
| `CupertinoNativeBarItemGroup` | `items`, `sharedBackgroundVisibility` (`false`) — several buttons in one toolbar item |

`CupertinoNativeAppBarAction` is an alias of `CupertinoNativeBarItem`.

`sharedBackgroundVisibility: true` maps to SwiftUI's
`.sharedBackgroundVisibility(.hidden)` on the entry's `ToolbarItem` (iOS 26+):
the entry leaves the capsule the system draws behind the whole toolbar and
carries its own background. `.buttonStyle(.glass)` comes with it — alone
outside the shared capsule a bare button reads as plain text — so set
`glass: false` when that plain look is what you want. Left `false`, the entry
stays in the shared background, unstyled, and both flags are ignored (as they
are below iOS 26).

## Tabs

`CupertinoNativeTab` — `id`, `title`, `icon`, `role`
(`CupertinoNativeTabRole.search` makes iOS present the tab as a search field),
`search` (a `CupertinoNativeSearchField` for that tab, inside a scaffold).

## Global settings

`CupertinoWidgetsSettings.showLoadingIndicator` (default `false`) — whether a
native spinner shows while a scaffold or sheet body engine boots. Individual
`showLoadingIndicator` parameters override it.

---

# Limitations

These are properties of how Flutter embeds native views on iOS, not bugs in
this package.

**How a native view is composited.** When a frame contains a platform view,
the iOS embedder stops rendering into a single surface. Per the
[embedder documentation](https://api.flutter.dev/ios-embedder/interface_flutter_overlay_view.html):

> instead of rendering into a single render target, Flutter renders into
> multiple render targets […] the `FlutterView` contains the backing store for
> the root render target, the `FlutterOverlay` view contains the backing
> stores for the rest

Everything painted **before** the first platform view lands in the root
surface; everything painted **after** it lands in one or more
`FlutterOverlayView` layers, separate UIViews positioned on the platform
thread. That split is not a defect — it is how the embedder interleaves UIKit
and Flutter content at all — but it is what the limitations below follow from,
and it explains their signature: a page looks correct down to its first native
control and wrong from there on.

## Native views desync during route transitions

During a Flutter page transition the root surface slides, but platform views
and their overlay layers are repositioned out of step. Native controls hang at
the wrong offset for the length of the animation, and a control from the
outgoing page can end up sitting over the incoming one.

Left as is: the transition stays the system's own. Dropping the native views
for the length of the animation would hide the artifact, but it trades a
misplaced control for no control at all, and a page that fills in only once it
has finished arriving.

Related: [flutter#163498](https://github.com/flutter/flutter/issues/163498)
(open) — animations cause Flutter UI to flicker and platform views to be
visible.

## Glass under `Transform` and `Opacity`

Flutter's effect widgets do reach a native view: `Transform` translate,
clipping, `Offstage` and `Visibility` all apply through platform-view
mutators, and `Opacity` fades the view. Glass is the exception, twice over.

Liquid Glass and material backgrounds (`UIVisualEffectView`) keep rendering at
full intensity under an inherited alpha — `Opacity` fades a glass button's
label before its glass — so use `Visibility`/`Offstage` to hide a glass surface
outright. And they do not survive live rotation or scaling, so swap to a
non-glass style while transformed.

The example's *Widget Effects* page exercises all of these.

---

# Routing — go_router & friends

The scaffold is **router-agnostic**. Its bodies run in separate engines that
short-circuit at the very top of `main()` — before `runApp`, before any
router is even created — so your main app can use go_router, auto_route,
plain `Navigator`, anything:

```dart
void main() {
  // Body isolates take this branch and never reach the router below.
  if (CupertinoNativeScaffold.maybeRun(scaffoldRoutes())) return;
  runApp(MaterialApp.router(routerConfig: goRouter)); // your router, untouched
}
```

A page *containing* a `CupertinoNativeScaffold` is a regular Flutter page:
route to it with `context.go(...)` or anything else, as usual.

## The one real constraint

Each scaffold body is its **own FlutterEngine** — a separate isolate with
separate memory. A `GoRouter` (or any `Navigator`) built in your app does not
exist inside a body: there is no object to share and no `BuildContext`
spanning the two. So don't call `context.go(...)` inside a body; there is no
router there.

Navigation between scaffold pages happens on the **native**
`NavigationStack` instead. What you *can* do is keep that native stack and
your router mirrored, so your router stays the single source of truth.

## Mirroring your router onto the native stack

`CupertinoNativeRouteSync` drives the mirroring in both directions. It speaks
plain route-id stacks (`['library', 'album']`), not URLs, so it never has to
agree with your router about path syntax.

```dart
final controller = CupertinoNativeScaffoldController();

late final sync = CupertinoNativeRouteSync(
  controller: controller,
  // Native back button or back-swipe fired — bring the router along.
  onNativeStackChanged: (routes) => context.go(locationFromRoutes(routes)),
  // Optional: give pushed pages their own navigation bars.
  pageBuilder: (route) => CupertinoNativeScaffoldPage(
    route: route,
    appBar: CupertinoNativeAppBar(title: titles[route] ?? route),
  ),
);

CupertinoNativeScaffold(
  controller: controller,
  body: 'library',
  onRouteChanged: sync.reportNativeStack,   // native -> Dart
  // ...
)
```

Then push the router's location at it whenever that location changes —
from a `build`, a `GoRouter` listener, wherever:

```dart
sync.syncTo(routesFromLocation(GoRouterState.of(context).uri.path));
```

`syncTo` diffs against the live native stack and emits the minimum
push/pop sequence, keeping the shared prefix so a push still animates as a
push. It is a no-op when the stack already matches, so calling it on every
build is fine. While it applies its ops, the resulting stack reports are
recognised as echoes and are *not* forwarded to `onNativeStackChanged`, so
the two directions cannot loop.

The ops it emits are `CupertinoNativeStackOp`s — `CupertinoNativePushOp(route)`
and `CupertinoNativePopOp()` — exposed so you can inspect or log a diff before
it is applied.

`routesFromLocation` / `locationFromRoutes` are just the default `/a/b/c`
convention. If your locations don't nest that way, map them yourself — the
sync only ever sees the resulting list.

## Plain imperative Navigator

If you aren't using a URL router at all, skip the sync and push by name:

```dart
controller.pushNamed('details');   // from the app
controller.pop();
```

and from inside a body, where there is no `BuildContext` to hand to a
`Navigator`:

```dart
CupertinoNativeScaffold.pushNamed('details');
CupertinoNativeScaffold.pop();
```

Tab switches remain the scaffold's own business either way: swapping the
root route is a tab change, not a stack operation, so `syncTo` never pops
the root out from under you.

---

# Performance

## How scaffold bodies live

Every `CupertinoNativeScaffold` (and native sheet) body is a Flutter page
running in its own lightweight engine, spawned from one shared
`FlutterEngineGroup` — engines share the GPU context and Dart snapshot, so
each one costs a few MB, not a whole app. Their lifecycle:

1. **Lazy** — a body boots the first time its page or tab is shown, never
   before.
2. **Kept across visits** — when you leave a scaffold, its root bodies are
   *parked*: detached from the screen, still running, rendering nothing.
   Re-opening the same route re-attaches the parked body instantly — no
   reload, no spinner, scroll position and state intact.
3. Pushed detail pages are per-instance and are discarded when popped.

## `prewarm()`

The one boot users can still feel is the **very first engine after app
launch**: the engine group pays its one-time cost (loading the Dart snapshot,
creating the isolate group) right when the user opens the first native screen.
`prewarm()` moves that cost to app startup instead, where nobody notices it:

```dart
void main() {
  if (CupertinoNativeScaffold.maybeRun(routes)) return;
  runApp(const MyApp());
  CupertinoNativeScaffold.prewarm(); // after runApp — non-blocking
}
```

That plain call is all most apps need. Pass `routes:` only when a specific
page must show its Flutter content with **zero** delay on its very first
open — typically a scaffold visible immediately at launch:

```dart
CupertinoNativeScaffold.prewarm(routes: ['home']);
```

This fully boots and parks that body at startup. It's a trade-off: **each
listed route boots on the main thread in the first seconds of the app and
holds memory from then on**, so listing many routes slows startup — prewarm
only what the user sees first, and let everything else load lazily. (Debug
builds JIT-compile Dart on top of all this; judge real latency in
`--release`.)

---

# Example app

The [example](example/) is a full iOS-styled catalog — every widget in a
realistic Settings-style screen. Run it on an iOS 26 device to see the Liquid
Glass features.

# Contributing

I build this on my own, mostly to find out how far Flutter and UIKit can be
made to meet. If that sounds interesting, come along — issues, pull requests,
a reproduction of something that broke on your device, or just telling me a
limitation above is wrong. All of it helps.

The interesting problem right now is in [Limitations](#limitations): keeping
native views visible through a route transition instead of dropping them for
its duration. Snapshotting each view and sliding the bitmap would do it — if
you have solved this somewhere else, or know a better trick, I would like to
hear it.

Repository: <https://github.com/ru-ji/cupertino_widgets>

# License

BSD 3-Clause. Copyright 2026 THON Hermès. See [LICENSE](LICENSE).
