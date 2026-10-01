# cupertino_widgets

Native iOS widgets for Flutter — the real UIKit and SwiftUI controls, iOS 26
**Liquid Glass** included — with the names and parameters of Flutter's own
Cupertino widgets.

Every control is a real platform view, so it renders however the installed
OS renders it: the same widget is Liquid Glass on iOS 26, a plain SwiftUI
control on 17–18, UIKit-shaped on 15–16 — no version check in your app code,
and no rewrite needed when a future iOS changes how a control looks again.

Options tied to a newer iOS (marked *iOS 26+* or *iOS 27+* below) are simply
ignored on older releases. The iOS 27 ones also need the app built with
Xcode 27; an older Xcode compiles them out.

## Installation

```bash
flutter pub add cupertino_widgets
```

```dart
import 'package:cupertino_widgets/cupertino_widgets.dart';
```

- Flutter 3.41+, Dart 3.10+
- **iOS 15+ at runtime.** Liquid Glass (the material, the scroll edge effect,
  `GlassEffectContainer`) is iOS 26+ only and falls back to plain content or
  a bordered style below it; a handful of other APIs gate the same way at
  their own version (`NavigationStack` at 16, `symbolEffect`/`sensoryFeedback`
  at 17, `Tab` at 18) — everything else works the same from 15 up. Below 16
  there is no path-driven navigation stack, so a pushed page shows only the
  root.
- Other platforms, and iOS below 15, get simple Flutter fallbacks, so shared
  code still builds.

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
| `onChangeStart` / `onChangeEnd` | `ValueChanged<double>?` | — | Drag begins / ends. |
| `minimumIcon` / `maximumIcon` | `CupertinoNativeIcon?` | — | Icons at the track's ends, e.g. `speaker.fill` / `speaker.wave.3.fill`. |
| `showTicks` | `bool` | `false` | A tick at every division. *iOS 26+* |
| `neutralValue` | `double?` | — | Where the filled track starts, e.g. `0` in `-1...1`. *iOS 26+* |

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

### Checkbox

iOS has no system checkbox, so this one is the selection symbol Reminders and
Mail use: `circle` off, `checkmark.circle.fill` on. For picking rows of a
list, prefer the list's own [edit mode](#list--form).

```dart
CupertinoNativeCheckbox(
  value: _done,
  label: 'Done',
  onChanged: (v) => setState(() => _done = v),
)
```

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `value` | `bool` | required | |
| `onChanged` | `ValueChanged<bool>?` | — | Null disables it. |
| `label` | `String?` | — | Label beside the box. |
| `activeColor` | `Color?` | — | Checked colour. |
| `textStyle` | `TextStyle?` | — | |
| `width` / `height` | `double?` | — | |

### Stepper, Color Picker, Gauge

```dart
CupertinoNativeStepper(
  label: 'Guests: $_guests',
  value: _guests.toDouble(),
  min: 1,
  max: 10,
  onChanged: (v) => setState(() => _guests = v.round()),
)

CupertinoNativeColorPicker(
  label: 'Accent',
  color: _color,
  onChanged: (c) => setState(() => _color = c),
)

CupertinoNativeGauge(
  value: 0.7,
  currentValueLabel: '70%',
  style: CupertinoNativeGaugeStyle.circularCapacity,
)
```

* **`CupertinoNativeStepper`** — `value`, `onChanged` (null disables), `min`
  / `max` (`0` / `100`), `step` (`1`), `label`, `activeColor`. Without a
  label it sizes to its buttons; with one it fills the row.
* **`CupertinoNativeColorPicker`** — `color`, `onChanged`, `label`,
  `supportsOpacity` (`true`).
* **`CupertinoNativeGauge`** *iOS 16+ (a progress bar on 15)* — `value`,
  `min` / `max` (`0` / `1`), `label`, `currentValueLabel`,
  `minimumValueLabel` / `maximumValueLabel`, `style` (`automatic`,
  `linearCapacity`, `circular`, `circularCapacity`), `color`.

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

// Round icon button (glass circle) — the bar button of iOS 26
CupertinoNativeButton.icon(CupertinoSymbols.heartFill, onPressed: () {})
```

Constructors: `CupertinoNativeButton` (plain), `.filled`, `.tinted`, `.glass`,
`.glassProminent`, and `.icon(symbol)` — an SF Symbol in a circle, glass by
default (`style:` to change it).

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `child` | `Widget` | required | A `Text`, `CupertinoSymbolImage`, `Icon`, or a `Row` of an icon and a `Text`. |
| `onPressed` | `VoidCallback?` | required | |
| `color` | `Color?` | — | Tint. |
| `sizeStyle` | `CupertinoNativeControlSize` | `.regular` | `mini`, `small`, `regular`, `large`, `extraLarge`. |
| `borderShape` | `CupertinoNativeButtonBorderShape` | `.automatic` | `automatic`, `capsule`, `circle`, `roundedRectangle`. |
| `expand` | `bool` | `false` | Fill the available width. |
| `role` | `CupertinoNativeButtonRole?` | — | `destructive` (drawn red), `cancel`. |
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
| `onPressed` | `VoidCallback?` | — | Split button: a tap calls this, a long press opens the menu. |
| `fixedOrder` | `bool` | `false` | Keep `items` in the given order even when the menu opens upward. *iOS 16+* |

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
| `iconSpacing` | `double` | `8` | |
| `cursorColor` / `backgroundColor` | `Color?` | — | |
| `cornerRadius` | `double?` | — | |
| `glass` | `CupertinoNativeGlass?` | — | |
| `glassTint` | `Color?` | — | |
| `textContentType` | `String?` | — | Autofill hint, e.g. `'password'`. |
| `toolbarActions` | `List<Widget>` | `[]` | The bar above the keyboard — see below. |
| `onChanged` / `onSubmitted` / `onEditingComplete` / `onTap` / `onTapOutside` | | — | |
| `width` / `height` | `double?` | — | |

#### Keyboard toolbar

`toolbarActions` fills the bar above the keyboard while this field is focused —
the row of actions Notes and Numbers put there.

```dart
CupertinoNativeTextField(
  toolbarActions: [
    CupertinoNativeButton(onPressed: _prev, child: CupertinoSymbolImage('chevron.up')),
    CupertinoNativeButton(onPressed: _next, child: CupertinoSymbolImage('chevron.down')),
    const Spacer(),
    CupertinoNativeButton(onPressed: _done, child: const Text('Done')),
  ],
)
```

The bar takes the height of what you give it: wrap the items in a `Padding`
for room around them.

**The bar paints nothing, so what you see through it is whatever your page puts
behind the keyboard** — and UIKit counts the bar as part of the keyboard's frame,
so `viewInsets.bottom` covers the strip as well. A scaffold that resizes for the
keyboard therefore ends the page exactly at the top of the bar and leaves nothing
behind it but its own background colour: a flat, opaque band with the bar's
content sitting on it. `resizeToAvoidBottomInset: false` and padding the scroll
content with `MediaQuery.viewInsetsOf(context).bottom` is the fix, and it is the
same flag on all three scaffolds — `Scaffold`, `CupertinoPageScaffold` and
`CupertinoNativePageScaffold` — all of which default it to `true`.

A page with no scaffold needs neither: nothing shrinks for the keyboard unless a
scaffold shrinks it, so the content runs under the bar and the bar shows it.

**Keeping the field itself visible is a separate question**, and the answer is not
the same one. SwiftUI moves a `TextField` up on its own, but a Flutter app is not
SwiftUI: its root is a `FlutterViewController`/`FlutterView` — UIKit views, and
UIKit does no keyboard avoidance at all. The engine only *reports* the inset as
`MediaQuery.viewInsets`; nothing acts on it. So in Flutter exactly two things lift
a field clear of the keyboard: a box that shrank (a scaffold resizing, or your own
padding driven by `viewInsets`), or a scrollable ancestor. A focused field scrolls
itself into view through `showOnScreen` on every rising metrics tick, and
`showOnScreen` walks up to a viewport; with no scrollable above it the call
reaches the root and does nothing. A field pinned to the bottom of a plain
`Container`, with no scaffold and no scrollable, therefore stays under the
keyboard no matter what — `scrollPadding` included, since there is nothing to
scroll. Put it in a `ListView`/`CustomScrollView`, or move its container yourself
with `Padding(padding: EdgeInsets.only(bottom:
MediaQuery.viewInsetsOf(context).bottom))` — plain `Padding`, not
`AnimatedPadding`: the engine already delivers the inset frame by frame along the
keyboard's own curve, and animating it again only adds lag.

That SwiftUI behaviour is the same mechanism as the scaffold's — the keyboard is
contributed to the *safe area*, so the layout region gets shorter and the content
is laid out in a smaller box. It is why this package turns it **off** for the
controls it hosts: `NativeHostingView.attach` sets `safeAreaRegions = []` by
default, because avoidance inside a Flutter-sized platform view slides a control's
content up over its Flutter neighbours. `CupertinoNativePageScaffold` opts back in
— `keyboardAvoidance: true`, then `.all` or `.container` depending on
`resizeToAvoidBottomInset`.

A glass capsule can hold its own row:

```dart
CupertinoNativeTextField(
  toolbarActions: [
    Padding(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
      child: CupertinoNativeGlassContainer(
        shape: CupertinoGlassShape.capsule,
        interactive: true,
        height: 40,
        padding: const EdgeInsets.symmetric(horizontal: 12),
        child: Row(
          children: [
            CupertinoNativeButton(onPressed: _bold, child: const Text('B')),
            const Spacer(),
            CupertinoNativeButton(onPressed: _done, child: const Text('Done')),
          ],
        ),
      ),
    ),
  ],
)
```

`onPressed: null` greys a button out, so the chevrons can disable themselves at
the first and last field. Pass resolved colors —
`CupertinoColors.label.resolveFrom(context)`, not the dynamic color.

Accepted here: `CupertinoNativeButton`, `CupertinoNativeSwitch`,
`CupertinoNativePicker`, `CupertinoNativeSymbol`,
`CupertinoNativeGlassContainer`, `Text`, `Spacer`, `SizedBox`, `Padding`,
`Row`, `Column`, and `CupertinoNativeFlutterView` for your own Flutter (see
[Embedding Flutter in SwiftUI](#embedding-flutter-in-swiftui)). Anything else
asserts.

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
| `style` | `CupertinoNativeDatePickerStyle` | `.compact` | `compact` (a field that pops a calendar), `graphical` (the calendar inline), `wheel`. |
| `minimumDate` / `maximumDate` | `DateTime?` | — | |
| `activeColor` | `Color?` | — | |
| `width` / `height` | `double?` | — | |

### Multi-Date Picker — *iOS 16+*

A calendar where several days can be picked. Controlled: echo `onChanged`
back into `dates`.

```dart
CupertinoNativeMultiDatePicker(
  dates: _days,
  minimumDate: DateTime.now(),
  onChanged: (days) => setState(() => _days = days),
)
```

`dates`, `onChanged`, `minimumDate` / `maximumDate` (both included),
`activeColor`.

### Text Editor

SwiftUI's multi-line `TextEditor`, scrolling inside a fixed `height`.

```dart
CupertinoNativeTextEditor(
  text: _notes,
  placeholder: 'Notes',
  onChanged: (t) => setState(() => _notes = t),
)
```

`text`, `onChanged` (null makes it read-only), `placeholder`, `fontSize`,
`height` (`120`), `style`, `cursorColor`, `backgroundColor`, `cornerRadius`,
`keyboardType`, `textCapitalization`, `textContentType`, `textAlign`,
`autocorrect`, `maxLength`, `readOnly`, `glass`, `glassTint`, `padding`,
`prefix`, `placeholderPadding`.

### Photos Picker — *iOS 17+*

The system photo picker **embedded in your page** (SwiftUI `PhotosPicker`,
inline or compact style) instead of presented full screen — put it in your own
sheet for a WhatsApp-style attachment panel. No photo-library permission: the
picker runs out of process and hands over only what the user ticks.

```dart
if (CupertinoNativePhotosPicker.isSupported)
  SizedBox(
    height: 420, // it fills its box (420 / 96 for compact if unbounded)
    child: CupertinoNativePhotosPicker(
      maxSelection: 10,
      onChanged: (media) => setState(() => _media = media),
    ),
  )
```

Ticks report live, in selection order. Each `CupertinoNativePickedMedia`
arrives at once without a `path` (`isLoading`), then again once its file is
ready — so show placeholders straight away.

Loading is built for speed: no system transcoding, the file is moved (never
read into memory), images are decoded straight at `maxDimension` with ImageIO,
items load in parallel and report one by one, and a per-run cache makes
re-picking a photo free. Files live in the app's temporary directory: copy or
upload what you keep, then call `CupertinoNativePhotosPicker.clearCache()`.

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `onChanged` | `ValueChanged<List<CupertinoNativePickedMedia>>` | required | `id`, `path`, `isVideo`, `width`, `height`, `failed`, `isLoading`. |
| `style` | `CupertinoNativePhotosPickerStyle` | `.inline` | `inline` (the grid), `compact` (one scrolling row). |
| `filter` | `CupertinoNativePhotosPickerFilter` | `.all` | `all`, `images`, `videos`. |
| `maxSelection` | `int?` | — | No limit when null. |
| `maxDimension` | `double?` | `2048` | Longest side of a delivered JPEG. Null keeps the original file (fastest; HEIC stays HEIC). |
| `jpegQuality` | `double` | `0.8` | |
| `showsAlbums` | `bool` | `false` | Keep the picker's top bar with its Photos / Albums switch. Off: the grid alone. |

Below iOS 17 `isSupported` is false and the widget draws nothing — fall back to
a full-screen picker such as `image_picker`.

**In a sheet**, use a native sheet with the picker as its native body rather
than a Flutter modal: the system then dims the whole screen (native views
included) and gives the sheet its own background, and no Flutter engine runs
behind it.

```dart
await CupertinoNativeSheet.show(
  nativeBody: CupertinoNativeBody.photosPicker(
    id: 'photos',
    picker: CupertinoNativePhotosPicker(showsAlbums: true, onChanged: (_) {}),
  ),
  detents: [CupertinoNativeSheetDetent.medium, CupertinoNativeSheetDetent.large],
  showDragHandle: true,
  onBodyEvent: (id, value) =>
      setState(() => _media = CupertinoNativePickedMedia.listFrom(value)),
);
```

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

**Edit mode.** `editing: true` slides the system selection circles in at each
row's leading edge. Selection is controlled: echo `onSelectionChanged` back into
`selection`. With `onReorder` set, rows also get the drag handles.

```dart
CupertinoNativeList(
  editing: _editing, // toggled by your own Edit / Done button
  selection: _picked,
  onSelectionChanged: (ids) => setState(() => _picked = ids),
  onReorder: (section, from, to) => setState(() {
    _rows.insert(to, _rows.removeAt(from));
  }),
  sections: [/* ... */],
)
```

**Swipe actions.** A tile's `swipeActions` are revealed by swiping it left;
the first one also fires on a full swipe.

```dart
CupertinoNativeListTile(
  id: 'mail1',
  title: 'Invoice',
  badge: '2',
  swipeActions: [
    CupertinoNativeMenuAction(title: 'Delete', systemImage: 'trash', isDestructive: true, actionId: 'delete'),
  ],
)
// on the list:
onSwipeAction: (rowId, actionId) {},
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
| `editing` | `bool` | `false` | Edit mode: selection circles (and drag handles with `onReorder`). |
| `selection` / `onSelectionChanged` | `Set<String>` / `ValueChanged<Set<String>>?` | `{}` / — | Ids of the checked rows. |
| `onSwipeAction` | `CupertinoNativeListSwipeCallback?` | — | `(rowId, actionId)`. |
| `onReorder` | `CupertinoNativeListReorderCallback?` | — | `(section, oldIndex, newIndex)`, `newIndex` as `List.insert` takes it after the removal. `CupertinoNativeList` only. |

### Group

Renders its children as **one** native view instead of Flutter's usual stack
of alternating Flutter/platform-view layers — the way a hand-written SwiftUI
form reads.

```dart
CupertinoNativeGroup(
  child: Row(
    children: [
      const Text('Notifications'),
      const Spacer(),
      CupertinoNativeSwitch(value: on, onChanged: (v) => setState(() {})),
    ],
  ),
)
```

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `child` | `Widget` | required | Transcribed, not mounted — see below. |
| `padding` | `EdgeInsets` | `EdgeInsets.zero` | |
| `width` / `height` | `double?` | — | Null hugs the content. |

**The child is read, not mounted.** Only what the transcription accepts can go
in — this package's own controls, `Text`, `Row`, `Column`, `Padding`,
`SizedBox`, `Spacer` — and `CupertinoNativeFlutterView` for anything else,
which costs an engine. An unsupported widget asserts with that list. For a
settings-style form with the grouped card and rows already built, see
[List & Form](#list--form).

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
| `items` | `List<CupertinoNativeGlassGroupItem>` | required | `actionId`, `icon`, `title`, `shape`, `width`, `height`, `enabled`, `glassVisible`, `unionId`, `transition`. |
| `onAction` | `ValueChanged<String>?` | — | |
| `spacing` | `double` | `8` | Gap, and the distance at which glasses merge. |
| `vertical` | `bool` | `false` | |
| `tint` / `clear` / `interactive` | | — | |
| `cornerRadius` | `double` | `16` | |
| `transition` | `CupertinoGlassTransition` | `.matchedGeometry` | How a glass arrives and leaves. |

#### Transitions

A transition runs when a glass is **inserted or removed**, and at no other
moment. That one sentence decides every question below, because it means a
change only animates if it changes *which glasses exist* — and which glasses
exist is decided by `actionId`, which is the `glassEffectID` SwiftUI morphs
along.

| Change | How you cause it | Transition |
| --- | --- | --- |
| 0 → 1, 1 → 0 | flip `glassVisible` | `.materialize` |
| 1 → 1 | give the item a **new `actionId`** | `.matchedGeometry` |
| 1 → 2, 2 → 1 | replace the items with differently shaped ones | `.matchedGeometry` |

`.matchedGeometry` gives the departing glass and the arriving one a single
shape that travels between them: it is what makes a merge a merge, and what
lets a "Select" capsule become an X circle in one piece. `.materialize` matches
no geometry at all — the material scales in or out while the content fades —
which is what a glass wants when it appears where there was nothing.
`.identity` does neither.

**A glass that arrives from nothing keeps its slot.** Leave the item in the
list and flip `glassVisible`; taking it out shrinks the group's box underneath
the transition and the arriving glass has nowhere to land:

```dart
CupertinoNativeGlassGroup(
  transition: CupertinoGlassTransition.materialize,
  items: [
    CupertinoNativeGlassGroupItem(
      actionId: 'play',
      icon: CupertinoNativeIcon.named('play.fill'),
      glassVisible: _playing, // only the material goes
    ),
  ],
)
```

**Swapping one glass for another is a change of `actionId`, not of icon.**
Keep the id and change only the icon and nothing animates: no glass left, none
arrived, so there was no transition to run and the content hard-cuts. Change
the id and SwiftUI sees a different glass in the same place; both are the same
44pt circle, so the matched geometry holds the material perfectly still while
the content turns over:

```dart
CupertinoNativeGlassGroupItem(
  // NOT a constant id with a changing icon.
  actionId: _isBack ? 'leading.back' : 'leading.more',
  icon: CupertinoNativeIcon.named(_isBack ? 'chevron.backward' : 'ellipsis'),
)
```

**One glass becoming two is the same trick on a list.** Replace the items with
differently sized ones and let matched geometry morph each old shape into its
new one; the gap does the rest, blending the two as they pass:

```dart
CupertinoNativeGlassGroup(
  spacing: 6, // under the blend radius, so they run together on the way
  items: _selecting
      ? [
          CupertinoNativeGlassGroupItem(
            actionId: 'menu.wide',
            shape: CupertinoGlassGroupShape.capsule,
            icon: menuIcon,
            title: '•••',
          ),
          CupertinoNativeGlassGroupItem(
            actionId: 'close',
            shape: CupertinoGlassGroupShape.capsule,
            icon: closeIcon,
            width: 44,
          ),
        ]
      : [
          CupertinoNativeGlassGroupItem(
            actionId: 'menu',
            shape: CupertinoGlassGroupShape.capsule,
            icon: menuIcon,
            width: 44,
          ),
          CupertinoNativeGlassGroupItem(
            actionId: 'select',
            shape: CupertinoGlassGroupShape.capsule,
            title: 'Select',
          ),
        ],
)
```

##### Unions

Two glasses are drawn as one shape for either of two reasons, and they are
separate questions: a `unionId` **states** it, and the container's spacing
**infers** it — SwiftUI merges effects nearer to each other than the container's
spacing, whatever their ids say. `spacing` used to answer both; `mergeDistance`
sets the radius on its own:

```dart
CupertinoNativeGlassGroup(
  spacing: 20,        // the glasses sit 20pt apart
  mergeDistance: 0,   // and blend only where a unionId says so
  items: [
    CupertinoNativeGlassGroupItem(
      actionId: 'back', unionId: _united ? 'pair' : null, icon: backIcon),
    CupertinoNativeGlassGroupItem(
      actionId: 'forward', unionId: _united ? 'pair' : null, icon: forwardIcon),
  ],
)
```

`spacing: 0` is the shorthand that puts every item under one id, which is why an
explicit `unionId` is only read when `spacing` is above 0. A union's frame is
the whole group's bounding box, and the glass fills it — so a union of two
44pt items is one 96pt capsule, not a circle stranded in the middle.

##### When the default is not what the system does

Two of these are exact and one is not. Held against a 60fps capture of the
system's own bar button, a swap on `.matchedGeometry` is *too still*: the
material is matched so perfectly that nothing announces the change. What the
system plays there is neither a fade nor a scale — the circle **squares up**,
top and bottom edges flattening first and then the sides, before unwinding. The
glass barely changes size at all.

`morphOnChange` plays that, on the group rather than on one glass (the glass
that starts the change is not the one that finishes it):

```dart
CupertinoNativeGlassGroup(
  morphOnChange: 0.45, // 0 = off, ~0.45 reads like the system's
  items: [...],
)
```

Likewise `.materialize` scales the glass in, and a system button appearing does
not move at all: the material reads as a gauge driven from zero while the
content blurs in. `CupertinoGlassTransition.intensity` is that — and because
nothing is inserted or removed, it is not a transition at all, so a glass on
`intensity` does not merge or match geometry with its neighbours.

The example app's **Glass transitions** page plays all three, and each glass is
tappable there — the change is driven by the glass as much as by the button
under it.

A glass can also be a **menu anchor** rather than a button. Give the item
`menuItems` and the glass becomes the menu's own label, so the system has the
capsule as its anchor and grows the menu out of it — the whole shape
transforms, which is what a toolbar menu does and what presenting a popover
beside the button cannot give:

```dart
CupertinoNativeGlassGroupItem(
  actionId: 'menu',
  shape: CupertinoGlassGroupShape.capsule,
  icon: CupertinoNativeIcon.named('line.3.horizontal'),
  width: 44,
  menuItems: const [
    CupertinoNativeMenuAction(
      title: 'Select', systemImage: 'checkmark.circle', actionId: 'menu.select'),
    CupertinoNativeMenuAction(
      title: 'Delete', systemImage: 'trash', actionId: 'menu.delete',
      isDestructive: true),
  ],
)
```

Entries report through their own `actionId` on the group's `onAction`, not the
item's. Keep `menuItems` on both sides of a change and the morph carries a live
menu across it.

> A navigation bar's buttons are **not** glasses in a container — they are
> toolbar items, animated by the bar itself, and there is no modifier to copy.
> If your buttons live in a bar, use `CupertinoNativeToolbarItem` in a
> [Page Scaffold](#page-scaffold) and the system plays its own transition, this
> release and the next. The group is for glass that floats over content, where
> there is no bar to do it for you.

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
        CupertinoNativeButton.icon(CupertinoSymbols.plus, onPressed: () {}),
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
| `onToolbarAction` | `CupertinoNativeToolbarActionCallback?` | — | |
| `onTabChanged` | `ValueChanged<String>?` | — | |
| `onRouteChanged` | `CupertinoNativeRouteChangedCallback?` | — | |
| `onSearchChanged` / `onSearchSubmitted` | `CupertinoNativeSearchCallback?` | — | |
| `onSearchActiveChanged` | `CupertinoNativeSearchActiveCallback?` | — | |
| `scrollEdgeEffect` | `CupertinoScrollEdgeEffectStyle` | `.automatic` | |
| `backgroundColor` / `activeColor` | `Color?` | — | |
| `showLoadingIndicator` | `bool?` | — | Falls back to `CupertinoWidgetsSettings.showLoadingIndicator` (`false`), a global switch for every engine-booting surface at once. |
| `resizeToAvoidBottomInset` | `bool` | `true` | |
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

The stepper, color picker, gauge, multi-date picker and text editor go in
through `CupertinoNativeBody.control`, which takes the widget itself; its
changes arrive in `onBodyEvent` like the others:

```dart
CupertinoNativeBody.control(
  id: 'guests',
  control: CupertinoNativeStepper(value: _guests, max: 10, onChanged: null),
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
| `leading` / `trailing` | `List<CupertinoNativeToolbarContent>` | `[]` | See [Toolbar items](#toolbar-items). |
| `bottom` | `List<CupertinoNativeToolbarContent>` | `[]` | The bottom toolbar. Up to 5 entries. |
| `search` | `CupertinoNativeSearchField?` | — | |

#### Bottom toolbar

SwiftUI's `.bottomBar` placement — the glass bar above the home indicator in
Mail, Safari and Notes. The system draws one shared capsule behind the
entries; a `CupertinoNativeToolbarSpacer` breaks it, so each side gets its own.

```dart
CupertinoNativeScaffoldNavigationBar(
  title: 'Inbox',
  bottom: [
    CupertinoNativeToolbarItem(systemImage: 'folder', actionId: 'move'),
    CupertinoNativeToolbarItem(systemImage: 'trash', actionId: 'delete'),
    const CupertinoNativeToolbarSpacer(),
    CupertinoNativeToolbarItem(systemImage: 'square.and.pencil', actionId: 'compose'),
  ],
)
```

Taps report through the scaffold's `onToolbarAction`, like the other two sides.

#### When the bar runs out of room — *iOS 27+*

```dart
CupertinoNativeScaffoldNavigationBar(
  title: 'Photo',
  trailing: [
    CupertinoNativeToolbarItem(systemImage: 'square.and.arrow.up', actionId: 'share', pinned: true),
    CupertinoNativeToolbarItem(systemImage: 'heart', actionId: 'like',
        visibilityPriority: CupertinoNativeToolbarVisibilityPriority.high),
  ],
  overflow: [
    CupertinoNativeToolbarItem(title: 'Duplicate', systemImage: 'plus.square.on.square', actionId: 'duplicate'),
  ],
  minimizeBehavior: CupertinoNativeToolbarMinimizeBehavior.onScrollDown,
)
```

* `visibilityPriority` (`automatic`, `low`, `high`) decides which entries stay
  when space runs short; `pinned` keeps a trailing entry on screen always
  (`.topBarPinnedTrailing`).
* `overflow` items always live in the bar's "…" menu (`.toolbarOverflowMenu`).
* `minimizeBehavior` collapses the navigation bar on scroll
  (`.toolbarMinimizationBehavior`).

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

### Router Integration

`CupertinoNativePageScaffold`'s pages live on a native `UINavigationController`,
which your app's router (GoRouter, auto_route, Beamer, or a plain imperative
`Navigator`) cannot drive directly — bodies run in their own engines, out of
the router's reach. `CupertinoNativeRouteSync` mirrors the router's stack onto
the native one in both directions: it turns a router's target stack into the
push/pop calls that get there, and reports native back navigation (the system
back button, the edge-swipe) so the router can catch up.

```dart
final controller = CupertinoNativePageScaffoldController();
late final sync = CupertinoNativeRouteSync(
  controller: controller,
  // Native back button / back-swipe happened — tell the router.
  onNativeStackChanged: (routes) => context.go(locationFromRoutes(routes)),
);

CupertinoNativePageScaffold(
  controller: controller,
  body: 'library',
  onRouteChanged: sync.reportNativeStack,   // native -> Dart
)

// Router moved — push/pop natively to match.
sync.syncTo(routesFromLocation(GoRouterState.of(context).uri.path));
```

The two directions cannot fight: while `syncTo` is applying its ops, the stack
reports it produces are recognised as echoes and not forwarded to
`onNativeStackChanged`.

| Function | | |
| --- | --- | --- |
| `routesFromLocation(location)` | `List<String>` | `/library/album/track` → `['library', 'album', 'track']` — the default convention; map your own if locations don't nest that way. |
| `locationFromRoutes(routes)` | `String` | The inverse. |
| `diffNativeStack(current, desired)` | `List<CupertinoNativeStackOp>` | What `CupertinoNativeRouteSync` runs internally: the push/pop ops that turn one stack into the other, keeping the shared prefix (and always the root) untouched so a push still animates as a push. |

### Embedding Flutter in SwiftUI

Native surfaces (a scaffold body, a keyboard toolbar, a glass container's
`route:`) host Flutter in a **separate engine**, and an engine is an isolate:
a widget built in the host's heap is unreachable from it. That is why there is
no `child:` there — only *names* cross. The pattern is **declare once, use
anywhere**:

```dart
// Declared once, top-level: the body isolate reaches it through main().
final editorBar = CupertinoNativeBodyRoute('editorBar', () => const EditorBar());

void main() {
  if (CupertinoNativePageScaffold.maybeRunRoutes([editorBar])) return;
  runApp(const MyApp());
}

// The same object feeds every surface that hosts Flutter inside SwiftUI.
CupertinoNativePageScaffold(body: editorBar.name);
CupertinoNativeTextField(toolbarActions: [editorBar.island, CupertinoNativeButton(...)]);
CupertinoNativeGlassContainer(route: editorBar.name);
```

Three ways to put content in a native view, in increasing cost:

| | Engine | State management | Router |
| --- | --- | --- | --- |
| `nativeBody` | none — SwiftUI directly | yours, untouched | native NavigationStack |
| glass `child:` | the one you're already in | yours, untouched | yours |
| `CupertinoNativeBodyRoute` | one per route | mirrored via the bridge | any, per island |

**State across the boundary is mirrored, not shared.** The host keeps owning
the state and publishes a serializable snapshot; bodies read it and send
actions back. Nothing about how your views manage their own state changes —
you only add the bridge lines, from whatever manager you already use:

```dart
// Host: mirror what the islands care about.
ref.listen(cartProvider, (_, cart) {
  CupertinoNativeBodyBridge.publish({'count': cart.count});
});
CupertinoNativeBodyBridge.onAction = (action, payload) { ... };

// Island: read the mirror, send intents back.
ValueListenableBuilder(
  valueListenable: CupertinoNativeBodyBridge.state,
  builder: (context, state, _) => Text('${state['count']} items'),
);
CupertinoNativeBodyBridge.send('addItem', 'sku-42');
```

A body that boots mid-session has missed earlier publishes — call
`CupertinoNativeBodyBridge.requestState()` when it starts.

**A complete example** — a cart owned by the host, mirrored into a keyboard
toolbar island. The host's state manager is whatever you already use; only
the bridge lines are added, nothing about the views changes:

```dart
// ---- Shared: what crosses the bridge is DATA --------------------------------

/// The snapshot every island mirrors. Plain data — it must survive
/// `StandardMessageCodec`.
class CartSnapshot {
  const CartSnapshot({required this.count, required this.total});

  final int count;
  final double total;

  Map<String, Object?> toMap() => {'count': count, 'total': total};

  factory CartSnapshot.fromMap(Map<String, Object?> map) => CartSnapshot(
        count: (map['count'] as num?)?.toInt() ?? 0,
        total: (map['total'] as num?)?.toDouble() ?? 0,
      );
}

// ---- Host: own the state, mirror it ------------------------------------------

/// The manager you already use — here a plain `ChangeNotifier`. Riverpod,
/// BLoC, Provider all work: the bridge only needs a listener.
final cart = ValueNotifier(const CartSnapshot(count: 0, total: 0));

final cartBar = CupertinoNativeBodyRoute('cartBar', () => const CartBar());

void main() {
  // The island's engine runs this same main() again, in ANOTHER isolate —
  // which is why the mirror below exists.
  if (CupertinoNativePageScaffold.maybeRunRoutes([cartBar])) return;

  // Mirror: publish on every change of the state you already have.
  cart.addListener(() => CupertinoNativeBodyBridge.publish(cart.value.toMap()));
  // Handle the intents the islands send back.
  CupertinoNativeBodyBridge.onAction = (action, payload) {
    switch (action) {
      case 'add':
        cart.value = CartSnapshot(
          count: cart.value.count + 1,
          total: cart.value.total + ((payload as num?) ?? 0),
        );
      case 'clear':
        cart.value = const CartSnapshot(count: 0, total: 0);
    }
  };

  runApp(const MyApp());
}

// ---- Island: read the mirror, send intents back ------------------------------

class CartBar extends StatefulWidget {
  const CartBar({super.key});

  @override
  State<CartBar> createState() => _CartBarState();
}

class _CartBarState extends State<CartBar> {
  @override
  void initState() {
    super.initState();
    // The island may have booted mid-session: pull the current snapshot.
    CupertinoNativeBodyBridge.requestState();
  }

  @override
  Widget build(BuildContext context) {
    return ValueListenableBuilder<Map<String, Object?>>(
      valueListenable: CupertinoNativeBodyBridge.state,
      builder: (context, state, _) {
        final cart = CartSnapshot.fromMap(state);
        return Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text('${cart.count} items · \$${cart.total.toStringAsFixed(2)}'),
            TextButton(
              onPressed: () => CupertinoNativeBodyBridge.send('add', 9.99),
              child: const Text('Add'),
            ),
          ],
        );
      },
    );
  }
}

// The island lives where Flutter is hosted inside SwiftUI — the keyboard bar
// here. The host owns `cart`; the island never touches it directly.
CupertinoNativeTextField(toolbarActions: [cartBar.island]);
```

The flow is always the same: the host **owns** the state and publishes a
snapshot; each island **mirrors** it through
`CupertinoNativeBodyBridge.state` and sends **intents** (`send`) that the host
applies with its own manager — so the state managers never need to know about
each other, or about the bridge.

**Routers:** inside an island any router works (it is a full Flutter app), but
it is confined to that island. One router across host and islands is
impossible — two isolates share no objects. Coordinate through the bridge
(publish the active route), or use `nativeBody` + the native NavigationStack
for whole-app navigation and keep routers only where you truly need arbitrary
Flutter.

Anything crossing the bridge must survive `StandardMessageCodec`: null, bool,
num, String, Uint8List, List and Map of those.

### Sheet

```dart
await CupertinoNativeSheet.show(
  route: 'newEvent',
  navigationBar: CupertinoNativeScaffoldNavigationBar(title: 'New Event'),
  detents: [CupertinoNativeSheetDetent.medium, CupertinoNativeSheetDetent.large],
  showDragHandle: true,
);
```

| Parameter | Type | Default | |
| --- | --- | --- | --- |
| `route` | `String?` | — | Body route registered in `maybeRun`. Give this or `nativeBody`. |
| `nativeBody` / `onBodyEvent` | `CupertinoNativeBody?` / `void Function(String, Object?)?` | — | SwiftUI content with no engine; see below. |
| `navigationBar` | `CupertinoNativeScaffoldNavigationBar?` | — | |
| `bottom` | `CupertinoNativeSheetSegmentedControl?` | — | |
| `detents` | `List<CupertinoNativeSheetDetent>` | `[large]` | `medium`, `large`. |
| `showDragHandle` | `bool` | `false` | |
| `detentHeights` | `List<double>` | `[]` | Extra stops at fixed heights, in points. *iOS 16+* |
| `undimmedUpTo` | `CupertinoNativeSheetDetent?` | — | Content behind stays undimmed and usable up to this detent (the Maps sheet). |
| `dismissible` | `bool` | `true` | `false` blocks swipe-to-dismiss. |
| `cornerRadius` | `double?` | — | |
| `scrollEdgeEffect` | `CupertinoScrollEdgeEffectStyle` | `.soft` | |
| `backgroundColor` | `Color?` | — | |
| `onToolbarAction` | `void Function(String)?` | — | |
| `onBottomChanged` | `ValueChanged<int>?` | — | |
| `onSearchChanged` / `onSearchSubmitted` | `ValueChanged<String>?` | — | |

Close it with `CupertinoNativeSheet.dismiss()`.

**Native body.** Pass `nativeBody` instead of `route` and the sheet's content
is pure SwiftUI — the same `CupertinoNativeBody` tree as the scaffold's — with
no FlutterEngine behind it: it opens faster and costs no isolate. Changes
report through `onBodyEvent`; push a changed tree back with
`CupertinoNativeSheet.updateNativeBody`.

```dart
await CupertinoNativeSheet.show(
  nativeBody: _body(), // a CupertinoNativeBody built from your state
  detents: [CupertinoNativeSheetDetent.medium],
  onBodyEvent: (id, value) {
    _reminder = value as bool;
    CupertinoNativeSheet.updateNativeBody(_body());
  },
);
```

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
| `navigationBar` | `CupertinoNativeScaffoldNavigationBar?` | — | |

Dismiss it with `CupertinoNativeSheet.dismiss()` — same presentation
underneath.

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
| `variableValue` | `double?` | — | `0...1`: how many layers of a variable symbol (`wifi`, `speaker.wave.3`) are lit. *iOS 16+* |
| `paletteColors` | `List<Color>` | `[]` | 2–3 layer colours for the `palette` rendering mode. |
| `gradient` | `bool` | `false` | Gradient fill of the symbol's colour. *iOS 26+* |

## Models

### Icons

`CupertinoNativeIcon` is the SF Symbol every native control takes. To show a symbol in the Flutter tree, use `CupertinoSymbolImage`.

| Constructor | |
| --- | --- |
| `.symbol(CupertinoSymbols, {size, weight, color, renderingMode})` | SF Symbol from the enum. |
| `.named(String, {size, weight, color, renderingMode})` | Any SF Symbol name. |

`renderingMode`: `monochrome`, `hierarchical`, `palette`, `multicolor`.

### Menu items

| Type | Fields |
| --- | --- |
| `CupertinoNativeMenuAction` | `title`, `actionId`, `subtitle`, `systemImage`, `isDestructive`, `isDisabled` |
| `CupertinoNativeMenuToggle` | `title`, `actionId`, `value`, `systemImage` |
| `CupertinoNativeSubmenu` | `title`, `items`, `systemImage` |
| `CupertinoNativeMenuSection` | `title`, `items` |
| `CupertinoNativeMenuControlGroup` | `items` — a row of up to 3 compact icon buttons (`ControlGroup`), e.g. Copy / Paste / Share at the top of the menu |

### List tiles

| Type | Fields |
| --- | --- |
| `CupertinoNativeListSection` | `header`, `footer`, `children` |
| `CupertinoNativeListTile` | `id`, `title`, `subtitle`, `leading`, `additionalInfo`, `showChevron`, `type` (`label`, `toggle`, `button`), `toggleValue`, `enabled`, `selected`, `trailing`, `badge`, `swipeActions`, `children` (nested rows: an expandable row that reveals them underneath) |

### Toolbar items

| Type | Fields |
| --- | --- |
| `CupertinoNativeToolbarItem` | `actionId`, `title`, `systemImage` (SF Symbol name) or `symbol` (`CupertinoSymbols`) or `icon`, `sharedBackgroundVisibility`, `glass`, `visibilityPriority`, `pinned` |
| `CupertinoNativeToolbarItemGroup` | `items`, `sharedBackgroundVisibility`, `visibilityPriority`, `pinned` |
| `CupertinoNativeToolbarSpacer` | `flexible` — a `ToolbarSpacer`: breaks the toolbar's shared glass capsule in two. |

### Tabs

| Type | Fields |
| --- | --- |
| `CupertinoNativeTab` | `id`, `title`, `icon`, `role` (`.search`, `.prominent` *iOS 27+*), `search`, `badge` |
| `CupertinoNativeSearchField` | `placeholder`, `placement`, `toolbarBehavior` |
| `CupertinoNativeTabBarAccessory` | `title`, `subtitle`, `icon`, `actionId` |

## Example app

The [example](example/) shows every widget and its variants. Run it on an
iOS 26 device.

Contributions are welcome — see [CONTRIBUTING.md](CONTRIBUTING.md) for setup,
how to run the example, and what CI checks before a PR merges.

