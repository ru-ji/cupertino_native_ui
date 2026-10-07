# cupertino_native_ui

Native iOS views in Flutter, Liquid Glass included, that adapt to the iOS
version they run on. They look and feel exactly like iOS, and fit into your
Flutter code like any other widget.

Options tied to a newer iOS (marked _iOS 26+_ or _iOS 27+_ below) are simply
ignored on older releases. The iOS 27 ones also need the app built with
Xcode 27; an older Xcode compiles them out.

## Contents

- [Motivation](#motivation)
- [Installation](#installation)
- [What's in the package](#whats-in-the-package)
- [Controls](#controls)
  - [Button](#button)
  - [Switch](#switch)
  - [Checkbox](#checkbox)
  - [Slider](#slider)
  - [Stepper, Color Picker, Gauge](#stepper-color-picker-gauge)
  - [Segmented Control](#segmented-control)
  - [Picker](#picker)
  - [Date Picker](#date-picker)
  - [Multi-Date Picker iOS 16+](#multi-date-picker-ios-16)
  - [Text Field](#text-field)
  - [Text Editor](#text-editor)
  - [Activity Indicator](#activity-indicator)
  - [Symbol Image](#symbol-image)
  - [Animated Symbol](#animated-symbol)
  - [Popup Menu](#popup-menu)
  - [Context Menu](#context-menu)
  - [List](#list)
- [Scaffold and navigation](#scaffold-and-navigation)
  - [Page Scaffold](#page-scaffold)
    - [State management: talking to a body](#state-management-talking-to-a-body)
    - [Native body: SwiftUI without the nesting](#native-body-swiftui-without-the-nesting)
  - [Navigation Bar](#navigation-bar)
  - [Tab Bar](#tab-bar)
  - [Router Integration](#router-integration)
- [Presentations](#presentations)
  - [Alert Dialog](#alert-dialog)
  - [Action Sheet](#action-sheet)
  - [Sheet](#sheet)
  - [Popover](#popover)
- [Special](#special)
  - [Liquid Glass](#liquid-glass)
  - [Photos Picker iOS 17+](#photos-picker-ios-17)
  - [Embedding Flutter in SwiftUI](#embedding-flutter-in-swiftui)
- [Icons](#icons)
- [Example app](#example-app)

## Motivation

Flutter draws every pixel itself, and its Cupertino widgets are careful
copies of iOS. So when iOS 26 brought Liquid Glass, they stayed on the old
design.

Other packages bring Liquid Glass to Flutter, and some are great. But they
often expose only a few options, so you can't quite match a native app. And
some only handle iOS 26, so you end up writing your screens twice.

`cupertino_native_ui` uses the real iOS controls instead, so iOS itself draws
them: Liquid Glass on iOS 26, the earlier style on older versions, from the
same code. They follow the names and parameters of Flutter's Cupertino
widgets, so they feel familiar.

## Installation

```bash
flutter pub add cupertino_native_ui
```

```dart
import 'package:cupertino_native_ui/cupertino_native_ui.dart';
```

The package adapts to the iOS version it runs on: each widget uses the
newest native API available and its closest equivalent below. Other
platforms get simple Flutter fallbacks, so shared code still builds.

## What's in the package

Every widget is `CupertinoNative` + the name of its Flutter counterpart.

## Controls

### Button

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_native_ui/main/doc/images/buttons.jpg" width="320" alt="Buttons" />

```dart
CupertinoNativeButton.filled(
  onPressed: () {},
  child: const Text('Press me'),
)

// Round icon button (glass circle): the bar button of iOS 26
CupertinoNativeButton.icon(CupertinoSymbols.heartFill, onPressed: () {})

// Your own icons: any icon font, or an image asset
CupertinoNativeButton.glass(onPressed: () {}, child: const Icon(CupertinoIcons.heart))
CupertinoNativeButton.glass(onPressed: () {}, child: const ImageIcon(AssetImage('assets/logo.png')))
```

Constructors: `CupertinoNativeButton` (plain), `.filled`, `.tinted`, `.glass`,
`.glassProminent`, and `.icon(symbol)` for an SF Symbol in a circle, glass by
default (`style:` to change it).

| Parameter          | Type                               | Description                                                                                                       |
| ------------------ | ---------------------------------- | ----------------------------------------------------------------------------------------------------------------- |
| `child`            | `Widget`                           | The label: a `Text`, `CupertinoSymbolImage`, `Icon`, `ImageIcon` of an asset, or a `Row` of an icon and a `Text`. |
| `onPressed`        | `VoidCallback?`                    | Called on tap. Null disables the button.                                                                          |
| `color`            | `Color?`                           | Tint colour of the button.                                                                                        |
| `sizeStyle`        | `CupertinoNativeControlSize`       | `mini`, `small`, `regular`, `large`, `extraLarge`. Default `regular`.                                             |
| `borderShape`      | `CupertinoNativeButtonBorderShape` | `automatic`, `capsule`, `circle`, `roundedRectangle`. Default `automatic`.                                        |
| `expand`           | `bool`                             | Fill the available width. Default `false`.                                                                        |
| `role`             | `CupertinoNativeButtonRole?`       | `destructive` (drawn red), `cancel`.                                                                              |
| `width` / `height` | `double?`                          | Fixed size. Null hugs the label.                                                                                  |
| `visibilityPriority` | `CupertinoNativeToolbarVisibilityPriority` | Only in a navigation bar's `trailing`: which buttons stay in the bar when they do not all fit (`low`, `automatic`, `high`); the others go into its ••• menu. Ignored elsewhere. Default `automatic`. |

### Switch

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_native_ui/main/doc/images/toggle.jpg" width="320" alt="Switch" />

```dart
bool _on = true;

CupertinoNativeSwitch(
  value: _on,
  onChanged: (v) => setState(() => _on = v),
)
```

| Parameter          | Type                  | Description                                                                    |
| ------------------ | --------------------- | ------------------------------------------------------------------------------ |
| `value`            | `bool`                | Whether the switch is on.                                                      |
| `onChanged`        | `ValueChanged<bool>?` | Called with the new state when the switch is tapped or slid. Null disables it. |
| `activeTrackColor` | `Color?`              | Track colour when on.                                                          |
| `label`            | `String?`             | Text beside the switch.                                                        |
| `width` / `height` | `double?`             | Fixed size of the box. Null uses the switch's own.                             |

### Checkbox

iOS has no system checkbox, so this one is the selection symbol Reminders and
Mail use: `circle` off, `checkmark.circle.fill` on. For picking rows of a
list, prefer the list's own [edit mode](#list).

```dart
CupertinoNativeCheckbox(
  value: _done,
  label: 'Done',
  onChanged: (v) => setState(() => _done = v),
)
```

| Parameter          | Type                  | Description                                              |
| ------------------ | --------------------- | -------------------------------------------------------- |
| `value`            | `bool`                | Whether it is checked.                                   |
| `onChanged`        | `ValueChanged<bool>?` | Called with the new state when tapped. Null disables it. |
| `label`            | `String?`             | Text beside the symbol.                                  |
| `activeColor`      | `Color?`              | Colour of the checked symbol.                            |
| `textStyle`        | `TextStyle?`          | Style of the label.                                      |
| `width` / `height` | `double?`             | Fixed size of the box. Null hugs the content.            |

### Slider

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_native_ui/main/doc/images/slider.jpg" width="320" alt="Slider" />

```dart
double _value = 50;

CupertinoNativeSlider(
  value: _value,
  max: 100,
  onChanged: (v) => setState(() => _value = v),
)
```

| Parameter                       | Type                    | Description                                                                |
| ------------------------------- | ----------------------- | -------------------------------------------------------------------------- |
| `value`                         | `double`                | The thumb's position, between `min` and `max`.                             |
| `onChanged`                     | `ValueChanged<double>?` | Called with the new value while the thumb moves. Null disables the slider. |
| `min` / `max`                   | `double`                | The range. Default `0.0` / `1.0`.                                          |
| `divisions`                     | `int?`                  | Number of steps the thumb snaps to. Null slides continuously.              |
| `activeColor`                   | `Color?`                | Colour of the filled part of the track.                                    |
| `thumbColor`                    | `Color?`                | Colour of the knob.                                                        |
| `onChangeStart` / `onChangeEnd` | `ValueChanged<double>?` | Called with the value when a drag begins / ends.                           |
| `minimumIcon` / `maximumIcon`   | `CupertinoNativeIcon?`  | Icons at the track's ends, e.g. `speaker.fill` / `speaker.wave.3.fill`.    |
| `showTicks`                     | `bool`                  | A tick at every division. Default `false`. _iOS 26+_                       |
| `neutralValue`                  | `double?`               | Where the filled track starts, e.g. `0` in `-1...1`. _iOS 26+_             |

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

- **`CupertinoNativeStepper`**: `value`, `onChanged` (null disables), `min`
  / `max` (`0` / `100`), `step` (`1`), `label`, `activeColor`. Without a
  label it sizes to its buttons; with one it fills the row.
- **`CupertinoNativeColorPicker`**: `color`, `onChanged`, `label`,
  `supportsOpacity` (`true`).
- **`CupertinoNativeGauge`** _iOS 16+ (a progress bar on 15)_: `value`,
  `min` / `max` (`0` / `1`), `label`, `currentValueLabel`,
  `minimumValueLabel` / `maximumValueLabel`, `style` (`automatic`,
  `linearCapacity`, `circular`, `circularCapacity`), `color`.

### Segmented Control

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_native_ui/main/doc/images/segmented.jpg" width="320" alt="Segmented control" />

```dart
int _index = 0;

CupertinoNativeSlidingSegmentedControl<int>(
  children: const {0: Text('One'), 1: Text('Two'), 2: Text('Three')},
  groupValue: _index,
  onValueChanged: (v) => setState(() => _index = v!),
)
```

| Parameter          | Type               | Description                                                                               |
| ------------------ | ------------------ | ----------------------------------------------------------------------------------------- |
| `children`         | `Map<T, Widget>`   | One segment per entry: the key is the value the segment stands for, the `Text` its label. |
| `onValueChanged`   | `ValueChanged<T?>` | Called with the key of the tapped segment.                                                |
| `groupValue`       | `T?`               | Key of the selected segment. Null selects none.                                           |
| `thumbColor`       | `Color?`           | Colour of the selected segment.                                                           |
| `width` / `height` | `double?`          | Fixed size. Null fills the width at the control's own height.                             |

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

| Parameter             | Type                              | Description                                                                                        |
| --------------------- | --------------------------------- | -------------------------------------------------------------------------------------------------- |
| `items`               | `List<CupertinoNativePickerItem>` | The options: each a `title`, an `icon`, or both.                                                   |
| `selectedIndex`       | `int`                             | Index of the selected option, clamped to the list.                                                 |
| `onChanged`           | `ValueChanged<int>?`              | Called with the index of the picked option. Null disables the picker.                              |
| `style`               | `CupertinoNativePickerStyle`      | `wheel`, `menu`, `segmented`, `palette`, `inline`, `navigationLink`. Default `automatic`.          |
| `label` / `showLabel` | `String?` / `bool`                | Text naming the picker, shown only with `showLabel` (default `false`).                             |
| `activeColor`         | `Color?`                          | Tint of the selection. Default the theme's primary colour.                                         |
| `sizeStyle`           | `CupertinoNativeControlSize?`     | Size of the control.                                                                               |
| `height`              | `double?`                         | Needed for `.wheel`, which has no height of its own (the `.wheel` constructor defaults it to 216). |

`navigationLink` only works inside a native `NavigationStack`, i.e. a
`CupertinoNativePageScaffold` body. For a plain segmented strip prefer
`CupertinoNativeSlidingSegmentedControl`; its `.menu` constructor is the
generic-keyed version of the menu style.

### Date Picker

```dart
DateTime _date = DateTime.now();

CupertinoNativeDatePicker(
  initialDateTime: _date,
  mode: CupertinoDatePickerMode.date,
  onDateTimeChanged: (d) => setState(() => _date = d),
)
```

| Parameter                     | Type                             | Description                                                                                              |
| ----------------------------- | -------------------------------- | -------------------------------------------------------------------------------------------------------- |
| `onDateTimeChanged`           | `ValueChanged<DateTime>`         | Called with the picked date and time.                                                                    |
| `initialDateTime`             | `DateTime?`                      | Date shown first. Default now.                                                                           |
| `mode`                        | `CupertinoDatePickerMode`        | What is picked: `date`, `time` or `dateAndTime`. Default `dateAndTime`.                                  |
| `style`                       | `CupertinoNativeDatePickerStyle` | `compact` (a field that pops a calendar), `graphical` (the calendar inline), `wheel`. Default `compact`. |
| `minimumDate` / `maximumDate` | `DateTime?`                      | Earliest / latest date that can be picked.                                                               |
| `activeColor`                 | `Color?`                         | Tint of the selection.                                                                                   |
| `width` / `height`            | `double?`                        | Fixed size. Null uses the picker's own.                                                                  |

### Multi-Date Picker _iOS 16+_

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

### Text Field

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_native_ui/main/doc/images/textfield.jpg" width="320" alt="Text field" />

```dart
CupertinoNativeTextField(
  placeholder: 'Search',
  prefix: CupertinoNativeIcon.symbol(CupertinoSymbols.magnifyingglass),
  clearButtonMode: OverlayVisibilityMode.editing,
  onChanged: (v) {},
)
```

| Parameter                                           | Type                    | Description                                                                                                                                                  |
| --------------------------------------------------- | ----------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `controller` / `focusNode`                          |                         | Standard Flutter controller and focus node.                                                                                                                  |
| `placeholder`                                       | `String?`               | Grey hint shown while the field is empty.                                                                                                                    |
| `style`                                             | `TextStyle?`            | Font size, weight and colour of the text.                                                                                                                    |
| `keyboardType`                                      | `TextInputType`         | Which keyboard opens: text, number, email, URL, phone… Default `text`.                                                                                       |
| `textInputAction`                                   | `TextInputAction?`      | Label of the keyboard's return key: `done`, `next`, `search`, `go`, `send`… It only changes the label; handle the tap in `onSubmitted`.                      |
| `obscureText` / `autocorrect` / `enableSuggestions` | `bool`                  | Hide the text (passwords) / correct spelling / show QuickType suggestions. Default `false` / `true` / `true`.                                                |
| `textCapitalization`                                | `TextCapitalization`    | Automatic capitals: `none`, `words`, `sentences`, `characters`. Default `none`.                                                                              |
| `textAlign`                                         | `TextAlign`             | Alignment of the text. Default `start`.                                                                                                                      |
| `maxLength`                                         | `int?`                  | Longer input is cut.                                                                                                                                         |
| `enabled` / `readOnly` / `autofocus`                | `bool`                  | Disabled greys the field out; read-only can still be selected and copied; autofocus opens the keyboard on first display. Default `true` / `false` / `false`. |
| `clearButtonMode`                                   | `OverlayVisibilityMode` | When the native ✕ that clears the field shows. Default `never`.                                                                                              |
| `prefix` / `suffix`                                 | `CupertinoNativeIcon?`  | Icons drawn inside the field, before / after the text.                                                                                                       |
| `iconSpacing`                                       | `double`                | Gap between `prefix` / `suffix` and the text. Default `8`.                                                                                                   |
| `cursorColor` / `backgroundColor`                   | `Color?`                | Colour of the caret and selection / fill behind the field (transparent when null).                                                                           |
| `cornerRadius`                                      | `double?`               | Rounds the background and the glass. The glass defaults to `16`.                                                                                             |
| `glass`                                             | `CupertinoNativeGlass?` | Draws the field on Liquid Glass: `regular`, `clear` or `identity`, always interactive. Null: no glass. _iOS 26+_                                             |
| `glassTint`                                         | `Color?`                | Colour mixed into the glass.                                                                                                                                 |
| `textContentType`                                   | `String?`               | Autofill hint, e.g. `'password'`.                                                                                                                            |
| `toolbarActions`                                    | `List<Widget>`          | The bar above the keyboard, see below.                                                                                                                       |
| `onChanged` / `onSubmitted` / `onEditingComplete`   |                         | Each edit, with the text / the return key, with the text / the return key.                                                                                   |
| `onTap` / `onTapOutside`                            |                         | The field takes focus / a tap lands elsewhere (unfocuses by default).                                                                                        |
| `width` / `height`                                  | `double?`               | Fixed size of the field.                                                                                                                                     |

#### Keyboard toolbar

`toolbarActions` fills the bar above the keyboard while this field is focused:
the row of actions Notes and Numbers put there.

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_native_ui/main/doc/images/keyboard_toolbar.jpg" width="320" alt="Keyboard toolbar" />

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
for room around them. It paints nothing, so your page shows through it: use
`resizeToAvoidBottomInset: false` on the scaffold and pad your scroll content
with `MediaQuery.viewInsetsOf(context).bottom`, or the scaffold's background
fills the strip behind it.

`onPressed: null` greys a button out, so the chevrons can disable themselves at
the first and last field. A dynamic color resolves for the app's light or dark
mode.

The bar works the same on a field in a list row's `trailing`, and on a
`CupertinoNativeBody.textField` in a `nativeBody`, whose `keyboardToolbar`
takes the items as `CupertinoNativeBody` nodes; they report through
`onBodyEvent` as `<fieldId>.toolbar.<itemId>`.

Accepted here: `CupertinoNativeButton`, `CupertinoNativeSwitch`,
`CupertinoNativePicker`, `CupertinoNativeSymbol`,
`CupertinoNativeGlassContainer`, `Text`, `Spacer`, `SizedBox`, `Padding`,
`Row`, `Column`, and `CupertinoNativeFlutterView` for your own Flutter (see
[Embedding Flutter in SwiftUI](#embedding-flutter-in-swiftui)). Anything else
asserts.

### Text Editor

SwiftUI's multi-line `TextEditor`, scrolling inside a fixed `height`.

```dart
CupertinoNativeTextEditor(
  text: _notes,
  placeholder: 'Notes',
  onChanged: (t) => setState(() => _notes = t),
)
```

| Parameter                                                                                                    | Type                     | Description                                                                                                                                     |
| ------------------------------------------------------------------------------------------------------------ | ------------------------ | ----------------------------------------------------------------------------------------------------------------------------------------------- |
| `text`                                                                                                       | `String`                 | The text shown. Echo `onChanged` back into it.                                                                                                  |
| `onChanged`                                                                                                  | `ValueChanged<String>?`  | Called on each edit. Null makes the editor read-only.                                                                                           |
| `placeholder`                                                                                                | `String?`                | Grey hint while the editor is empty.                                                                                                            |
| `height`                                                                                                     | `double`                 | The editor scrolls inside this height. Default `120`.                                                                                           |
| `style` / `fontSize`                                                                                         | `TextStyle?` / `double?` | Font size, weight and colour of the text; `fontSize` is a shorthand.                                                                            |
| `padding`                                                                                                    | `EdgeInsets?`            | Room between the text and the background or glass edge.                                                                                         |
| `prefix`                                                                                                     | `Widget?`                | Drawn before the text, on its first line: any widget the package transcribes natively (an icon, a button, a `Row` of them), callbacks included. |
| `placeholderPadding`                                                                                         | `EdgeInsets?`            | Moves the placeholder (top / left) when it does not line up with typed text.                                                                    |
| `cursorColor`, `backgroundColor`, `cornerRadius`, `glass`, `glassTint`                                       |                          | As on the text field.                                                                                                                           |
| `keyboardType`, `textCapitalization`, `textContentType`, `textAlign`, `autocorrect`, `maxLength`, `readOnly` |                          | As on the text field; the keyboard defaults to `multiline`, capitals to `sentences`.                                                            |

### Activity Indicator

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_native_ui/main/doc/images/progress.jpg" width="320" alt="Activity indicators" />

```dart
const CupertinoNativeActivityIndicator()

CupertinoNativeLinearActivityIndicator(progress: 0.4)
```

| `CupertinoNativeActivityIndicator` | Type     | Description                        |
| ---------------------------------- | -------- | ---------------------------------- |
| `color`                            | `Color?` | Colour of the spinner.             |
| `radius`                           | `double` | Size of the spinner. Default `10`. |
| `animating`                        | `bool`   | False hides it. Default `true`.    |

| `CupertinoNativeLinearActivityIndicator` | Type     | Description                          |
| ---------------------------------------- | -------- | ------------------------------------ |
| `progress`                               | `double` | How much is done, from 0 to 1.       |
| `height`                                 | `double` | Thickness of the bar. Default `4.5`. |
| `color`                                  | `Color?` | Colour of the filled part.           |

### Symbol Image

An SF Symbol as a regular Flutter image.

```dart
CupertinoSymbolImage.symbol(CupertinoSymbols.star, size: 20, color: CupertinoColors.systemYellow)
```

| Parameter | Type         | Description                                       |
| --------- | ------------ | ------------------------------------------------- |
| `name`    | `String`     | SF Symbol name, or `.symbol(CupertinoSymbols)`.   |
| `size`    | `double`     | Point size. Default `17`.                         |
| `color`   | `Color?`     | Colour of the symbol. The label colour when null. |
| `weight`  | `FontWeight` | Stroke weight. Default `normal`.                  |

### Animated Symbol

The same symbol as a live SwiftUI `Image`, so `.symbolEffect` has a view to
animate. Use `CupertinoSymbolImage` for a still icon: it composites in
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

| Parameter                   | Type                                  | Description                                                                                 |
| --------------------------- | ------------------------------------- | ------------------------------------------------------------------------------------------- |
| `name`                      | `String`                              | SF Symbol name, or `.symbol(CupertinoSymbols)`.                                             |
| `size` / `color` / `weight` |                                       | As on `CupertinoSymbolImage`. Default `17` / label colour / `normal`.                       |
| `renderingMode`             | `CupertinoNativeSymbolRenderingMode?` | `monochrome`, `hierarchical`, `palette`, `multicolor`.                                      |
| `effect`                    | `CupertinoNativeSymbolEffect?`        | `bounce`, `pulse`, `variableColor`, `wiggle`, `rotate`, `breathe`.                          |
| `trigger`                   | `int`                                 | Change it to fire a discrete effect once. Default `0`.                                      |
| `repeating`                 | `bool`                                | Run the effect continuously. `bounce` is discrete only. Default `false`.                    |
| `replaceOnChange`           | `bool`                                | Morph between symbols when `name` changes, instead of cutting. Default `false`.             |
| `variableValue`             | `double?`                             | `0...1`: how many layers of a variable symbol (`wifi`, `speaker.wave.3`) are lit. _iOS 16+_ |
| `paletteColors`             | `List<Color>`                         | 2–3 layer colours for the `palette` rendering mode.                                         |
| `gradient`                  | `bool`                                | Gradient fill of the symbol's colour. Default `false`. _iOS 26+_                            |

### Popup Menu

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_native_ui/main/doc/images/menu.jpg" width="320" alt="Popup menu" />

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

| Parameter     | Type                                 | Description                                                                                                                           |
| ------------- | ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| `items`       | `List<CupertinoNativeMenuItem>`      | The entries of the menu. See [Menu items](#menu-items).                                                                               |
| `onAction`    | `CupertinoNativeMenuActionCallback?` | Called when an entry is picked, with its `actionId` and a value: the new state for a `CupertinoNativeMenuToggle`, null for an action. |
| `title`       | `String`                             | Label of the button. Default `'Options'`.                                                                                             |
| `systemImage` | `String?`                            | SF Symbol of the button.                                                                                                              |
| `style`       | `CupertinoNativeButtonStyle`         | Look of the button: `automatic`, `filled`, `tinted`, `plain`, `glass`, `glassProminent`.                                              |
| `borderShape` | `CupertinoNativeButtonBorderShape`   | Shape of the button.                                                                                                                  |
| `labelStyle`  | `CupertinoNativeButtonLabelStyle`    | `titleAndIcon`, `titleOnly`, `iconOnly`. Default `titleAndIcon`.                                                                      |
| `controlSize` | `CupertinoNativeControlSize`         | Size of the button. Default `regular`.                                                                                                |
| `activeColor` | `Color?`                             | Tint of the button.                                                                                                                   |
| `onPressed`   | `VoidCallback?`                      | Split button: a tap calls this, a long press opens the menu.                                                                          |
| `fixedOrder`  | `bool`                               | Keep `items` in the given order even when the menu opens upward. _iOS 16+_                                                            |

#### Menu items

| Type                              | Description                                                                                                                                                            |
| --------------------------------- | ---------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `CupertinoNativeMenuAction`       | A tappable entry. `actionId` is what `onAction` reports. `title`, `subtitle`, `systemImage` (SF Symbol name); `isDestructive` draws it red, `isDisabled` greys it out. |
| `CupertinoNativeMenuToggle`       | An entry with a checkmark: `value` is its current state, and a tap reports its `actionId` with the new state.                                                          |
| `CupertinoNativeSubmenu`          | Opens a nested menu of `items`, under its `title` and `systemImage`.                                                                                                   |
| `CupertinoNativeMenuSection`      | Groups `items` between separators, under an optional `title`.                                                                                                          |
| `CupertinoNativeMenuControlGroup` | A row of up to 3 compact icon buttons (`ControlGroup`), e.g. Copy / Paste / Share at the top of the menu.                                                              |

### Context Menu

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_native_ui/main/doc/images/contextmenu.jpg" width="320" alt="Context menu" />

```dart
CupertinoNativeContextMenu(
  actions: [
    CupertinoNativeMenuAction(title: 'Share', systemImage: 'square.and.arrow.up', actionId: 'share'),
  ],
  onAction: (id, _) {},
  child: const PhotoCard(),
)
```

| Parameter             | Type                                 | Description                                                                                                                           |
| --------------------- | ------------------------------------ | ------------------------------------------------------------------------------------------------------------------------------------- |
| `child`               | `Widget`                             | The widget that lifts and shows the menu on long press.                                                                               |
| `actions`             | `List<CupertinoNativeMenuItem>`      | The entries of the menu. See [Menu items](#menu-items).                                                                               |
| `onAction`            | `CupertinoNativeMenuActionCallback?` | Called when an entry is picked, with its `actionId` and a value: the new state for a `CupertinoNativeMenuToggle`, null for an action. |
| `preview`             | `Widget?`                            | Shown lifted instead of `child`.                                                                                                      |
| `onOpenChanged`       | `ValueChanged<bool>?`                | Called with `true` when the menu opens, `false` when it closes.                                                                       |
| `childInteractive`    | `bool`                               | Let `child` receive taps; the menu then opens on long press only. Default `false`.                                                    |
| `previewCornerRadius` | `double`                             | Corner radius of the lifted `child`. Default `0`.                                                                                     |

### List

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

**Selecting and reordering.** Two separate states, set one or both.
`editing: true` slides the system selection circles in at each row's leading
edge; selection is controlled, so echo `onSelectionChanged` back into
`selection`. `reorderable: true` shows the drag handles at the trailing edge;
a row moves within its own section, and `onReorder` reports where it landed.

```dart
CupertinoNativeList(
  editing: _editing, // toggled by your own Edit / Done button
  selection: _picked,
  onSelectionChanged: (ids) => setState(() => _picked = ids),
  reorderable: _editing, // both at once here; either alone works too
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

| Parameter                          | Type                                         | Description                                                                                                                                                    |
| ---------------------------------- | -------------------------------------------- | -------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `sections`                         | `List<CupertinoNativeListSection>`           | The cards of the list, each with its rows. See [List tiles](#list-tiles).                                                                                      |
| `style`                            | `CupertinoNativeListStyle`                   | `insetGrouped` (Settings cards), `grouped`, `plain`, `sidebar`, `automatic`. Default `insetGrouped`; `CupertinoNativeForm` has none.                           |
| `onRowTap`                         | `CupertinoNativeListTileCallback?`           | Called with the `id` of the tapped row. Without it, plain rows are not tappable (no pressed highlight).                                                        |
| `onToggle`                         | `CupertinoNativeListToggleCallback?`         | Called with the `id` and the new state of a toggle row.                                                                                                        |
| `scrollable`                       | `bool`                                       | Scroll inside the list's own height instead of sizing to its rows. Default `false`.                                                                            |
| `height` / `cornerRadius`          | `double?`                                    | Fixed height / corner radius of the cards (the system's when null).                                                                                            |
| `activeColor`                      | `Color?`                                     | Tint of the rows' controls and checkmarks.                                                                                                                     |
| `editing`                          | `bool`                                       | Selection circles at each row's leading edge. Independent of `reorderable`. Default `false`.                                                                   |
| `selection` / `onSelectionChanged` | `Set<String>` / `ValueChanged<Set<String>>?` | Ids of the rows checked in edit mode, and the call reporting them. Echo it back.                                                                               |
| `onSwipeAction`                    | `CupertinoNativeListSwipeCallback?`          | Called with the row's `id` and the `actionId` of the swipe button tapped.                                                                                      |
| `reorderable`                      | `bool`                                       | Drag handles at each row's trailing edge; rows move within their section. Independent of `editing`. Default `false`.                                           |
| `onReorder`                        | `CupertinoNativeListReorderCallback?`        | Called when a row is dropped, with the section and the old and new index, the new one as `List.insert` takes it after the removal. `CupertinoNativeList` only. |

#### List tiles

`CupertinoNativeListSection` is one card: `header` and `footer` text above and
below it, and its rows as `children`.

| `CupertinoNativeListTile` | Description                                                                                                               |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------- |
| `id`                      | Names the row in every callback: `onRowTap`, `onToggle`, `onSwipeAction`, `selection`. Unique in the list.                |
| `title` / `subtitle`      | The row's text, on one or two lines.                                                                                      |
| `leading`                 | Icon before the title.                                                                                                    |
| `additionalInfo`          | Grey text at the trailing edge, like the network name beside Wi-Fi.                                                       |
| `showChevron`             | The trailing › that says the row opens another page. Visual only: the tap still arrives in `onRowTap`.                    |
| `type`                    | `label` (default), `toggle` (a switch, reported by `onToggle`), `button` (a tinted title, an action).                     |
| `toggleValue`             | State of a `toggle` row.                                                                                                  |
| `enabled`                 | False greys the row out and ignores taps.                                                                                 |
| `selected`                | Shows a checkmark, as in a selection list. You keep which rows are selected.                                              |
| `trailing`                | A control at the trailing edge (switch, slider, text field, stepper…) transcribed into the native row with its callbacks. |
| `badge`                   | A count or short text in a capsule at the trailing edge.                                                                  |
| `swipeActions`            | Buttons revealed by swiping the row left, reported by `onSwipeAction`.                                                    |
| `children`                | Rows revealed under this one when it is tapped: an expandable row.                                                        |

## Scaffold and navigation

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
Flutter widgets only, unless you give the scaffold a `nativeBody`, which
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
`maybeRun` executes _in the body isolate_ and can only reach builders that are
statically part of the program. A widget written inline in the host's `build()`
is an object in the host's heap; the body isolate has no way to reach it.
Generating the name automatically would not change that: the name is not the
obstacle, the builder is.

| Parameter                               | Type                                       | Description                                                                                         |
| --------------------------------------- | ------------------------------------------ | --------------------------------------------------------------------------------------------------- |
| `body`                                  | `String?`                                  | Route of the root page when there is no `tabBar`.                                                   |
| `navigationBar`                         | `CupertinoNativeScaffoldNavigationBar?`    | Title, toolbar items and search of the root page.                                                   |
| `tabBar`                                | `CupertinoNativeTabBar?`                   | Tabs; each tab `id` is its route.                                                                   |
| `controller`                            | `CupertinoNativePageScaffoldController?`   | Push and pop from code.                                                                             |
| `onToolbarAction`                       | `CupertinoNativeToolbarActionCallback?`    | Called with the route and the `actionId` of a tapped toolbar item.                                  |
| `onTabChanged`                          | `ValueChanged<String>?`                    | Called with the `id` of the selected tab.                                                           |
| `onRouteChanged`                        | `CupertinoNativeRouteChangedCallback?`     | Called with the native stack, root first, after each push or pop.                                   |
| `onSearchChanged` / `onSearchSubmitted` | `CupertinoNativeSearchCallback?`           | Called with the route and the query as it is typed / when the search key is pressed.                |
| `onSearchActiveChanged`                 | `CupertinoNativeSearchActiveCallback?`     | Called when the search field gains or loses focus.                                                  |
| `scrollEdgeEffect`                      | `CupertinoScrollEdgeEffectStyle`           | Blur where content scrolls under the bars. Default `automatic`.                                     |
| `backgroundColor` / `activeColor`       | `Color?`                                   | Page background / tint of the bars and controls.                                                    |
| `showLoadingIndicator`                  | `bool?`                                    | Spinner while a body boots. Falls back to `CupertinoNativeSettings.showLoadingIndicator` (`false`). |
| `resizeToAvoidBottomInset`              | `bool`                                     | Shrink the body for the keyboard. Default `true`.                                                   |
| `nativeBody`                            | `CupertinoNativeBody?`                     | A body rendered as SwiftUI directly, no engine. Replaces `body` / the tabs' routes.                 |
| `onBodyEvent`                           | `void Function(String id, Object? value)?` | Called when a `nativeBody` control changes, with its node `id` and the new value.                   |

#### State management: talking to a body

Each body runs in its own FlutterEngine, so in its own **isolate**. Isolates
share no memory: a Riverpod `ProviderContainer`, a BLoC, a `ValueNotifier`, a
`BuildContext`. None of it reaches across. Objects cannot be passed, only
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

|                           |                                                                                                                                                                          |
| ------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `publish(Map)`            | Host → every body. Replaces the snapshot.                                                                                                                                |
| `state`                   | `ValueListenable<Map>`: read it in a body.                                                                                                                               |
| `send(action, [payload])` | Body → host.                                                                                                                                                             |
| `onAction`                | Called in the host when a body sends one.                                                                                                                                |
| `requestState()`          | Body → host: "send the snapshot again". A body that boots mid-session has missed everything before it; call this once on start and answer it by calling `publish` again. |

Everything crossing must survive `StandardMessageCodec`: null, bool, num,
String, `Uint8List`, and `List`/`Map` of those.

**Often the better answer is not to cross at all.** A page made of system
controls can be a `nativeBody` instead: no engine, so it lives in the host
isolate and your existing state management works untouched.

#### Native body: SwiftUI without the nesting

An ordinary body is a route in its own FlutterEngine. A native control placed
there is a platform view inside a hierarchy that was already native:
**Flutter → SwiftUI → FlutterView → SwiftUI**.

`nativeBody` removes the middle. Dart sends a description, SwiftUI renders it,
and the controls are real SwiftUI views in the scaffold's own tree: the
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
`CupertinoNativeBody` can express: you cannot have both a body written in
arbitrary Flutter and controls that render as SwiftUI directly. Keep the route
body when the page is mostly your own Flutter UI; use `nativeBody` when the
page is mostly system controls.

| Node                           | Parameters                                                                                                             |
| ------------------------------ | ---------------------------------------------------------------------------------------------------------------------- |
| `.column` / `.row` / `.scroll` | `children`, `spacing`, `alignment`, `padding`, `expand`                                                                |
| `.spacer`                      | `extent`: flexible when null                                                                                           |
| `.divider`                     |                                                                                                                        |
| `.text`                        | `value`, `style`, `fontSize`, `fontWeight`, `color`, `align`                                                           |
| `.button`                      | `id`, `title`, `icon`, `style`, `sizeStyle`, `borderShape`, `color`, `expand`                                          |
| `.textField`                   | `id`, `value`, `placeholder`, `obscureText`, `enabled`, `glass`, `cornerRadius`, `prefix`, `suffix`, `keyboardToolbar` |
| `.toggle`                      | `id`, `value`, `label`, `color`                                                                                        |
| `.slider`                      | `id`, `value`, `min`, `max`, `step`, `color`, `enabled`                                                                |
| `.picker`                      | `id`, `items`, `selectedIndex`, `style`, `label`, `showLabel`, `color`                                                 |
| `.list`                        | `id`, `sections`                                                                                                       |
| `.symbol`                      | `name`, `size`, `color`, `effect`, `trigger`, `repeating`                                                              |

Push a new tree to change a value: a toggle, checkbox or segmented control
shows the value Dart sends, so one the app refuses goes back. A date picker's
`value` is its starting date, and only moves it when Dart changes it.

Interactive nodes need an `id`. `onBodyEvent` reports `(id, value)`: null for
a button, the text for a field, a bool for a toggle, a double for a slider, an
int index for a picker. A field also reports `('<id>.focused', bool)` and
`('<id>.submitted', String)`.

Navigate with `CupertinoNativePageScaffold.push(...)`, `.pushNamed(route)` and
`.pop()`.

`CupertinoNativeScaffoldNavigationBar`:

| Parameter              | Type                                     | Description                                                                |
| ---------------------- | ---------------------------------------- | -------------------------------------------------------------------------- |
| `title`                | `String`                                 | Page title.                                                                |
| `subtitle`             | `String?`                                | A second line under the title.                                             |
| `titleDisplayMode`     | `CupertinoNativeToolbarTitleDisplayMode` | `automatic`, `inline`, `inlineLarge`, `large`. Default `automatic`.        |
| `leading` / `trailing` | `List<CupertinoNativeToolbarContent>`    | Toolbar items at each end of the bar. See [Toolbar items](#toolbar-items). |
| `bottom`               | `List<CupertinoNativeToolbarContent>`    | The bottom toolbar, up to 5 entries.                                       |
| `search`               | `CupertinoNativeSearchField?`            | Makes the page `.searchable` with this field.                              |

#### Bottom toolbar

SwiftUI's `.bottomBar` placement: the glass bar above the home indicator in
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

#### When the bar runs out of room _iOS 27+_

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

- `visibilityPriority` (`automatic`, `low`, `high`) decides which entries stay
  when space runs short; `pinned` keeps a trailing entry on screen always
  (`.topBarPinnedTrailing`).
- `overflow` items always live in the bar's "…" menu (`.toolbarOverflowMenu`).
- `minimizeBehavior` collapses the navigation bar on scroll
  (`.toolbarMinimizationBehavior`).

#### Search

`CupertinoNativeSearchField` is the page's `.searchable` field.

| Parameter         | Type                                   | Description                                                                                           |
| ----------------- | -------------------------------------- | ----------------------------------------------------------------------------------------------------- |
| `placeholder`     | `String?`                              | Grey hint in the empty field.                                                                         |
| `placement`       | `CupertinoNativeSearchPlacement`       | `automatic`, `toolbar`, `navigationBarDrawer`, `navigationBarDrawerAlways`. Default `automatic`.      |
| `toolbarBehavior` | `CupertinoNativeSearchToolbarBehavior` | `minimize` collapses the field to a magnifying-glass button as the page scrolls. Default `automatic`. |

`placement: .toolbar` is the iOS 26 bottom-docked search: on iPhone the field
sits at the **bottom** of the screen in its own glass capsule rather than in a
drawer under the large title. It is a different thing from
`CupertinoNativeTabRole.search`, which makes a whole _tab_ the search tab:
the two are often used together (Music, Photos) but either works alone.

Both are properties of the native `NavigationStack`, so they exist only inside
a `CupertinoNativePageScaffold`. There is no way to bring `.searchable` to an
ordinary Flutter page: it is a modifier on a SwiftUI navigation container, and
hosting one standalone is the same problem that keeps `navigationTitle` out of
`CupertinoNativeSliverNavigationBar`.

#### Toolbar items

| Type                              | Description                                                                                                                                                                                                                                                                                                                                               |
| --------------------------------- | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `CupertinoNativeToolbarItem`      | A bar button. `actionId` is what `onToolbarAction` reports. Its content is a `title`, or an SF Symbol as `systemImage` (name), `symbol` (`CupertinoSymbols`) or `icon`. `sharedBackgroundVisibility` gives it its own glass instead of the capsule shared with its neighbours, and `glass` styles it there. `visibilityPriority` and `pinned`: see above. |
| `CupertinoNativeToolbarItemGroup` | Several `items` in one capsule, with the same `sharedBackgroundVisibility`, `visibilityPriority` and `pinned`.                                                                                                                                                                                                                                            |
| `CupertinoNativeToolbarSpacer`    | A `ToolbarSpacer`: breaks the shared capsule in two. `flexible` pushes what follows to the far edge.                                                                                                                                                                                                                                                      |

### Navigation Bar

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_native_ui/main/doc/images/scaffold.jpg" width="320" alt="Navigation bar" />

The iOS 26 bar, with a large title that collapses on scroll, glass buttons and
an optional search field. Its edge effect and buttons adapt to the content
under the bar (see [Scroll Edge Effect](#scroll-edge-effect)).

As the page scrolls, the inline title and subtitle rise into the bar while
they fade in and unblur, the subtitle arriving after its title and leaving
before it.

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

| Parameter                   | Type                             | Description                                                                                                                    |
| --------------------------- | -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------ |
| `largeTitle`                | `String`                         | Shown large, then inline once the page scrolls.                                                                                |
| `subtitle`                  | `String?`                        | A second line under the title.                                                                                                 |
| `leading`                   | `Widget?`                        | At the leading edge. Left null on a page that can pop, the bar adds the back button.                                           |
| `automaticallyImplyLeading` | `bool`                           | Whether that back button is added: a glass chevron on iOS 26, the chevron and the previous page's title below. Default `true`. |
| `trailing`                  | `List<Widget>`                   | Buttons at the trailing edge, grouped as SwiftUI groups toolbar items (see below). In the bar a button takes the system's bar weights: medium title and symbol on iOS 26. |
| `centerTitle`               | `bool`                           | Centre the inline title. With three `trailing` items or more it moves to the leading side, as SwiftUI's does. Default `true`. |
| `expandedTitle`             | `bool`                           | Whether the large title row exists; false makes the bar inline only. Default `true`.                                           |
| `collapseTitle`             | `bool`                           | Whether the large title collapses into the bar on scroll; false keeps it large. Default `true`. _iOS 26+_                      |
| `bottom` / `bottomHeight`   | `Widget?` / `double`             | A widget under the large title, and its height. Default height `44`.                                                           |
| `scrollEdgeEffect`          | `CupertinoScrollEdgeEffectStyle` | Blur where content scrolls under the bar. Default `soft`.                                                                      |

`.search` adds `searchPlaceholder`, `searchStyle`, `searchPrefixIcon`,
`searchSuffixIcon`, `searchGlass`, `searchFieldHeight`, `bottomMode`,
`scrollToTopOnSearch`, `onSearchChanged` and `onSearchActiveChanged`.

**Trailing items share one glass capsule**, as the system's toolbar items do:
buttons side by side, glass or in the default style, are drawn in one capsule. A `Spacer()` between two
ends the capsule, and a `CupertinoNativeButton.glassProminent` (or any other
widget) always stands alone. What does not fit goes into a ••• menu at the
end, buttons with a `low` `visibilityPriority` first and `high` last, from the
end. A button labelled with an icon and a `Text` shows its icon in the bar and
its title in that menu:

```dart
trailing: [
  CupertinoNativeButton.icon(CupertinoSymbols.squareAndArrowUp, onPressed: share),
  CupertinoNativeButton.icon(CupertinoSymbols.heart, onPressed: like),
  CupertinoNativeButton.glassProminent(
    borderShape: CupertinoNativeButtonBorderShape.circle,
    onPressed: add,
    child: CupertinoSymbolImage.symbol(CupertinoSymbols.plus),
  ),
],
```

`CupertinoNativeNavigationBar` is the version for pages that do not scroll:
`title`, `subtitle`, `centerTitle`, `leading`, `trailing`, `scrollEdgeEffect`.

Add this to `ios/Runner/Info.plist`, or the title shows a faint glow over the
scroll edge effect:

```xml
<key>FLTDisablePartialRepaint</key>
<true/>
```

#### Scroll Edge Effect

The iOS 26 blur and tint where content meets a screen edge, fitted to the
system's. The navigation bars and the tab bar already include it.

It has no colour of its own: it takes the background of the page under it.
On `CupertinoColors.systemBackground` or `systemGroupedBackground` the `soft`
wash follows the content; on any other colour it is fixed in that colour, as
SwiftUI's is once a page has a `.background`.

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_native_ui/main/doc/images/scroll_edge_effect.gif" width="320" alt="Scroll edge effect on a coloured page" />

The `soft` wash adapts to what scrolls under it: lighter over bright content,
darker over dark content, as the system's does. The glass buttons of the
navigation bar and the tab bar follow it, turning light or dark with the
content under the bar.

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_native_ui/main/doc/images/adaptive_scroll_edge_effect.gif" width="320" alt="Scroll edge effect adapting to the content" />

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

| Parameter             | Type                             | Description                                                                                                                                                                                 |
| --------------------- | -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `edge`                | `CupertinoScrollEdgeEffectEdge`  | Which edge: `top` or `bottom`. Default `top`.                                                                                                                                               |
| `style`               | `CupertinoScrollEdgeEffectStyle` | `soft`: a wash that follows the content, with a light progressive blur at the top. `hard`: the page colour over an even blur, ending in a hard line. `automatic` is `soft`. Default `soft`. |
| `onBrightnessChanged` | `ValueChanged<Brightness>?`      | Brightness of the content behind the effect, to adapt text over it.                                                                                                                         |

### Tab Bar

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_native_ui/main/doc/images/tabbar.jpg" width="320" alt="Tab bar" />

The iOS 26 tab bar. Its edge effect and glass adapt to the content under it
(see [Scroll Edge Effect](#scroll-edge-effect)).

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

| Parameter                               | Type                                    | Description                                                                                                                                 |
| --------------------------------------- | --------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `items`                                 | `List<CupertinoNativeTab>`              | The tabs, in order. See [Tabs](#tabs).                                                                                                      |
| `currentIndex`                          | `int`                                   | Index of the selected tab. Default `0`.                                                                                                     |
| `onTap`                                 | `ValueChanged<int>?`                    | Called with the index of the tapped tab.                                                                                                    |
| `activeColor` / `backgroundColor`       | `Color?`                                | Colour of the selected tab / fill behind the bar.                                                                                           |
| `height`                                | `double?`                               | Fixed height. Null uses the system's.                                                                                                       |
| `split` / `rightCount` / `splitSpacing` | `bool` / `int` / `double`               | Detach the last `rightCount` tabs into their own bar, `splitSpacing` apart: the search tab in Music. Default `false` / `1` / `8`. _iOS 26+_ |
| `shrinkCentered`                        | `bool`                                  | When not split, size the bar to its tabs, centred, instead of the full width. Default `true`.                                               |
| `scrollEdgeEffect`                      | `CupertinoScrollEdgeEffectStyle`        | Blur where content scrolls under the bar. Default `automatic`.                                                                              |
| `minimizeBehavior`                      | `CupertinoNativeTabBarMinimizeBehavior` | How the bar shrinks on scroll. Inside `CupertinoNativePageScaffold` only.                                                                   |
| `accessory`                             | `CupertinoNativeTabBarAccessory?`       | A persistent bar above the tabs, like Now Playing. Inside `CupertinoNativePageScaffold` only.                                               |

#### Tabs

| Type                             | Description                                                                                                                                                                                                                                                   |
| -------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `CupertinoNativeTab`             | `id` names the tab (what `onTabChanged` reports, and the body route in a scaffold); `title` and `icon`; `badge`, text in a red capsule. `role: .search` sets the tab apart and turns it into a search field (`search` is that field); `.prominent` _iOS 27+_. |
| `CupertinoNativeSearchField`     | See [Search](#search).                                                                                                                                                                                                                                        |
| `CupertinoNativeTabBarAccessory` | The bar above the tabs, like Now Playing: `title`, `subtitle`, `icon`, and the `actionId` a tap reports.                                                                                                                                                      |

### Router Integration

`CupertinoNativePageScaffold`'s pages live on a native `UINavigationController`,
which your app's router (GoRouter, auto_route, Beamer, or a plain imperative
`Navigator`) cannot drive directly: bodies run in their own engines, out of
the router's reach. `CupertinoNativeRouteSync` mirrors the router's stack onto
the native one in both directions: it turns a router's target stack into the
push/pop calls that get there, and reports native back navigation (the system
back button, the edge-swipe) so the router can catch up.

```dart
final controller = CupertinoNativePageScaffoldController();
late final sync = CupertinoNativeRouteSync(
  controller: controller,
  // Native back button / back-swipe happened: tell the router.
  onNativeStackChanged: (routes) => context.go(locationFromRoutes(routes)),
);

CupertinoNativePageScaffold(
  controller: controller,
  body: 'library',
  onRouteChanged: sync.reportNativeStack,   // native -> Dart
)

// Router moved: push/pop natively to match.
sync.syncTo(routesFromLocation(GoRouterState.of(context).uri.path));
```

The two directions cannot fight: while `syncTo` is applying its ops, the stack
reports it produces are recognised as echoes and not forwarded to
`onNativeStackChanged`.

| Function                            |                                |                                                                                                                                                                                                     |
| ----------------------------------- | ------------------------------ | --------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `routesFromLocation(location)`      | `List<String>`                 | `/library/album/track` → `['library', 'album', 'track']`: the default convention; map your own if locations don't nest that way.                                                                    |
| `locationFromRoutes(routes)`        | `String`                       | The inverse.                                                                                                                                                                                        |
| `diffNativeStack(current, desired)` | `List<CupertinoNativeStackOp>` | What `CupertinoNativeRouteSync` runs internally: the push/pop ops that turn one stack into the other, keeping the shared prefix (and always the root) untouched so a push still animates as a push. |

## Presentations

### Alert Dialog

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_native_ui/main/doc/images/alert.jpg" width="320" alt="Alert dialog" />

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

`textFields` puts UIKit's own fields in the alert, one or several (a name, or
a username and a password). Pass `CupertinoNativeTextField`s: they are read,
not mounted. The `controller` gives the starting text and holds what was typed
by the time an action's `onPressed` runs; `placeholder`, `obscureText`,
`keyboardType`, `textCapitalization`, `autocorrect` and `textContentType` are
used too. The alert draws its fields in its own style, so styling is ignored.

```dart
final user = TextEditingController();
final password = TextEditingController();
CupertinoNativeAlertDialog.show(
  context: context,
  title: 'Sign In',
  textFields: [
    CupertinoNativeTextField(controller: user, placeholder: 'Username', textContentType: 'username'),
    CupertinoNativeTextField(controller: password, placeholder: 'Password', obscureText: true),
  ],
  actions: [
    const CupertinoNativeDialogAction(child: Text('Cancel')),
    CupertinoNativeDialogAction(onPressed: () => signIn(user.text, password.text), child: const Text('Sign In')),
  ],
)
```

| `CupertinoNativeDialogAction` | Type            | Description                                  |
| ----------------------------- | --------------- | -------------------------------------------- |
| `child`                       | `Text`          | The button's label.                          |
| `onPressed`                   | `VoidCallback?` | Called on tap; the dialog closes itself.     |
| `isDefaultAction`             | `bool`          | Bold, with the cancel role. Default `false`. |
| `isDestructiveAction`         | `bool`          | Drawn red. Default `false`.                  |

### Action Sheet

The system sheet of choices that rises from the bottom:
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

| Parameter           | Type                                | Description                                                                                                                                 |
| ------------------- | ----------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------- |
| `title` / `message` | `String?`                           | Text above the choices.                                                                                                                     |
| `actions`           | `List<CupertinoNativeDialogAction>` | The choices, top to bottom. The `isDefaultAction` one is the cancel button, set apart at the bottom.                                        |
| `anchor`            | `Rect?`                             | iPad/Mac only, where UIKit makes it a popover. `CupertinoNativeActionSheet.anchorOf(context)` gives the rect of the control that opened it. |

### Sheet

```dart
await CupertinoNativeSheet.show(
  route: 'newEvent',
  navigationBar: CupertinoNativeScaffoldNavigationBar(title: 'New Event'),
  detents: [CupertinoNativeSheetDetent.medium, CupertinoNativeSheetDetent.large],
  showDragHandle: true,
);
```

| Parameter                               | Type                                                       | Description                                                                    |
| --------------------------------------- | ---------------------------------------------------------- | ------------------------------------------------------------------------------ |
| `route`                                 | `String?`                                                  | Body route registered in `maybeRun`. Give this or `nativeBody`.                |
| `nativeBody` / `onBodyEvent`            | `CupertinoNativeBody?` / `void Function(String, Object?)?` | SwiftUI content with no engine, and the call reporting its changes; see below. |
| `navigationBar`                         | `CupertinoNativeScaffoldNavigationBar?`                    | Title and buttons pinned at the top of the sheet.                              |
| `bottom`                                | `CupertinoNativeSheetSegmentedControl?`                    | A segmented control pinned under the bar.                                      |
| `detents`                               | `List<CupertinoNativeSheetDetent>`                         | Heights the sheet rests at: `medium` (half), `large`. Default `[large]`.       |
| `showDragHandle`                        | `bool`                                                     | Show the grabber. Default `false`.                                             |
| `detentHeights`                         | `List<double>`                                             | Extra stops at fixed heights, in points. _iOS 16+_                             |
| `undimmedUpTo`                          | `CupertinoNativeSheetDetent?`                              | Content behind stays undimmed and usable up to this detent (the Maps sheet).   |
| `dismissible`                           | `bool`                                                     | `false` blocks swipe-to-dismiss. Default `true`.                               |
| `cornerRadius`                          | `double?`                                                  | Corner radius of the sheet. The system's when null.                            |
| `scrollEdgeEffect`                      | `CupertinoScrollEdgeEffectStyle`                           | Blur where content scrolls under the bar. Default `soft`.                      |
| `backgroundColor`                       | `Color?`                                                   | Background of the sheet.                                                       |
| `onToolbarAction`                       | `void Function(String)?`                                   | Called with the `actionId` of a tapped bar button.                             |
| `onBottomChanged`                       | `ValueChanged<int>?`                                       | Called with the index of the selected segment.                                 |
| `onSearchChanged` / `onSearchSubmitted` | `ValueChanged<String>?`                                    | Called with the query as it is typed / when the search key is pressed.         |

Close it with `CupertinoNativeSheet.dismiss()`.

**Native body.** Pass `nativeBody` instead of `route` and the sheet's content
is pure SwiftUI, the same `CupertinoNativeBody` tree as the scaffold's, with
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

| Parameter       | Type                                    | Description                                                                                          |
| --------------- | --------------------------------------- | ---------------------------------------------------------------------------------------------------- |
| `route`         | `String`                                | Body route registered in `maybeRun`.                                                                 |
| `anchor`        | `Rect`                                  | Global rect of the control it points at, see `anchorOf`.                                             |
| `preferredSize` | `Size?`                                 | Size of the card. Without one UIKit sizes it to the content, which for a Flutter body is the screen. |
| `navigationBar` | `CupertinoNativeScaffoldNavigationBar?` | Title and buttons pinned at the top.                                                                 |

Dismiss it with `CupertinoNativeSheet.dismiss()`: same presentation
underneath.

## Special

### Liquid Glass

<img src="https://raw.githubusercontent.com/ru-ji/cupertino_native_ui/main/doc/images/glass.jpg" width="320" alt="Liquid Glass" />

```dart
CupertinoNativeGlassContainer(
  shape: CupertinoGlassShape.capsule,
  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
  child: Row(mainAxisSize: MainAxisSize.min, children: [...]),
)
```

Content goes on the glass two ways:

- **`child`**: an ordinary Flutter widget, laid out by the engine you are
  already in and sizing the glass. Its plain `Text`s and still SF Symbols
  (`CupertinoSymbolImage`, `CupertinoNativeSymbol` without an effect) are
  drawn by SwiftUI _inside_ the material, in the frames Flutter laid them out
  in, so they adapt to what is behind the glass as native labels do: through
  `Row`, `Column`, `Wrap`, `Padding`, `Align`, `Center`, `SizedBox`,
  `Expanded` and `Flexible`. Anything else stays Flutter, over the glass.
- **`icon`**: a native SF Symbol drawn by SwiftUI inside the material.

| Parameter          | Type                    | Description                                                                         |
| ------------------ | ----------------------- | ----------------------------------------------------------------------------------- |
| `shape`            | `CupertinoGlassShape`   | `capsule`, `circle`, `roundedRect`. Default `roundedRect`.                          |
| `cornerRadius`     | `double`                | Corner radius of `roundedRect`. Default `26`.                                       |
| `variant`          | `CupertinoGlassVariant` | `regular`, or the more transparent `clear`. Default `regular`.                      |
| `tint`             | `Color?`                | Colour mixed into the glass.                                                        |
| `interactive`      | `bool`                  | Shimmer and stretch under the finger. Default `false`.                              |
| `onPressed`        | `VoidCallback?`         | Makes the glass a button.                                                           |
| `child`            | `Widget?`               | Flutter content sizing the glass; its texts and symbols drawn by SwiftUI inside it. |
| `icon`             | `CupertinoNativeIcon?`  | An icon drawn by SwiftUI inside the material.                                       |
| `padding`          | `EdgeInsetsGeometry`    | Room between the glass edge and `child`. Default none.                              |
| `animateChanges`   | `bool`                  | Let SwiftUI animate tint and variant changes. Default `false`.                      |
| `width` / `height` | `double?`               | Fixed size. Null hugs `child`.                                                      |

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

| Parameter                        | Type                                  | Description                                                                                                                                                                                                                                      |
| -------------------------------- | ------------------------------------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `items`                          | `List<CupertinoNativeGlassGroupItem>` | The glasses, in order. Each has an `actionId` (what a tap reports, and its identity), an `icon` and / or `title`, a `shape` and size, `enabled`, `glassVisible`, `unionId`, `transition` and `menuItems`. |
| `onAction`                       | `ValueChanged<String>?`               | Called with the `actionId` of the tapped glass or menu entry.                                                                                                                                                                                    |
| `spacing`                        | `double`                              | Gap between the glasses, and the distance at which they merge. Default `8`.                                                                                                                                                                      |
| `vertical`                       | `bool`                                | Stack the glasses vertically. Default `false`.                                                                                                                                                                                                   |
| `tint` / `clear` / `interactive` |                                       | As on the glass container, for every glass of the group.                                                                                                                                                                                         |
| `cornerRadius`                   | `double`                              | Corner radius of `roundedRect` glasses. Default `16`.                                                                                                                                                                                            |
| `transition`                     | `CupertinoGlassTransition`            | How a glass arrives and leaves. Default `matchedGeometry`.                                                                                                                                                                                       |
| `alignment`                      | `Alignment`                           | Where the glasses sit in the group's box, and so which way they grow when a change resizes it. Read at creation. Default `center`.                                                                                                               |

#### Transitions

A transition runs when a glass is **inserted or removed**, and at no other
moment. That one sentence decides every question below, because it means a
change only animates if it changes _which glasses exist_. Which glasses
exist is decided by each item's `actionId`, which is also its `glassEffectID`:
a new `actionId` is a new glass, the same `actionId` is the same glass wherever
it sits in `items`.

| Change       | How you cause it                               | Transition         |
| ------------ | ---------------------------------------------- | ------------------ |
| 0 → 1, 1 → 0 | flip `glassVisible`                            | `.materialize`     |
| 1 → 1        | give the item a **new `actionId`**             | `.matchedGeometry` |
| 1 → 2, 2 → 1 | replace the items with differently shaped ones | `.matchedGeometry` |

<p>
<img src="https://raw.githubusercontent.com/ru-ji/cupertino_native_ui/main/doc/images/arrive.gif" width="260" alt="0 to 1: a glass materializes" />
<img src="https://raw.githubusercontent.com/ru-ji/cupertino_native_ui/main/doc/images/swap.gif" width="260" alt="1 to 1: a new actionId morphs the glass" />
<img src="https://raw.githubusercontent.com/ru-ji/cupertino_native_ui/main/doc/images/reshape.gif" width="260" alt="1 to 2: two glasses split from one" />
</p>

`.matchedGeometry` gives the departing glass and the arriving one a single
shape that travels between them: it is what makes a merge a merge, and what
lets a "Select" capsule become an X circle in one piece. `.materialize` matches
no geometry at all: the material scales in or out while the content fades,
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
  actionId: _isBack ? 'leading.back' : 'leading.more',
  icon: CupertinoNativeIcon.named(_isBack ? 'chevron.backward' : 'ellipsis'),
)
```

A glass replaced under the finger lights up a second time as the new one
arrives: SwiftUI does the same with an interactive glass. Pass
`interactive: false` to a group whose glass is swapped on tap.

**One glass becoming two is the same trick on a list.** Replace the items with
differently sized ones under new `actionId`s and let matched geometry
morph each old shape into its new one; the gap does the rest, blending the two
as they pass:

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
**infers** it. SwiftUI merges effects nearer to each other than the container's
spacing, whatever their ids say. `spacing` sets the gap, `mergeDistance` the
radius on its own:

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
the whole group's bounding box, and the glass fills it, so a union of two
44pt items is one 96pt capsule, not a circle stranded in the middle.

##### When the default is not what the system does

Two of these are exact and one is not. Held against a 60fps capture of the
system's own bar button, a swap on `.matchedGeometry` is _too still_: the
material is matched so perfectly that nothing announces the change. What the
system plays there is neither a fade nor a scale: the circle **squares up**,
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
content blurs in. `CupertinoGlassTransition.intensity` is that, and because
nothing is inserted or removed, it is not a transition at all, so a glass on
`intensity` does not merge or match geometry with its neighbours.

The example app's **Liquid Glass** page plays all three, and each glass is
tappable there: the change is driven by the glass as much as by the button
under it.

A glass can also be a **menu anchor** rather than a button. Give the item
`menuItems` and the glass becomes the menu's own label, so the system has the
capsule as its anchor and grows the menu out of it: the whole shape
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

> A navigation bar's buttons are **not** glasses in a container: they are
> toolbar items, animated by the bar itself, and there is no modifier to copy.
> If your buttons live in a bar, use `CupertinoNativeToolbarItem` in a
> [Page Scaffold](#page-scaffold) and the system plays its own transition, this
> release and the next. The group is for glass that floats over content, where
> there is no bar to do it for you.

### Photos Picker _iOS 17+_

The system photo picker **embedded in your page** (SwiftUI `PhotosPicker`,
inline or compact style) instead of presented full screen: put it in your own
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
ready, so show placeholders straight away.

Loading is built for speed: no system transcoding, the file is moved (never
read into memory), images are decoded straight at `maxDimension` with ImageIO,
items load in parallel and report one by one, and a per-run cache makes
re-picking a photo free. Files live in the app's temporary directory: copy or
upload what you keep, then call `CupertinoNativePhotosPicker.clearCache()`.

| Parameter      | Type                                             | Description                                                                                                                                                                                                          |
| -------------- | ------------------------------------------------ | -------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------- |
| `onChanged`    | `ValueChanged<List<CupertinoNativePickedMedia>>` | Called with the whole selection, in pick order, each time it changes. Each item has `id`, `path` (null while loading), `isVideo`, `thumbnailPath` (a video's first frame), `width`, `height`, `failed`, `isLoading`. |
| `style`        | `CupertinoNativePhotosPickerStyle`               | `inline` (the grid), `compact` (one scrolling row). Default `inline`.                                                                                                                                                |
| `filter`       | `CupertinoNativePhotosPickerFilter`              | What can be picked: `all`, `images`, `videos`. Default `all`.                                                                                                                                                        |
| `maxSelection` | `int?`                                           | How many items can be ticked. No limit when null.                                                                                                                                                                    |
| `maxDimension` | `double?`                                        | Longest side of a delivered JPEG. Null keeps the original file (fastest; HEIC stays HEIC). Default `2048`.                                                                                                           |
| `jpegQuality`  | `double`                                         | Compression of delivered JPEGs, from 0 to 1. Default `0.8`.                                                                                                                                                          |
| `showsAlbums`  | `bool`                                           | Keep the picker's top bar with its Photos / Albums switch. Off: the grid alone. Default `false`.                                                                                                                     |

Below iOS 17 `isSupported` is false and the widget draws nothing: fall back to
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

### Embedding Flutter in SwiftUI

Native surfaces (a scaffold body, a keyboard toolbar) host Flutter in a
**separate engine**, and an engine is an isolate:
a widget built in the host's heap is unreachable from it. That is why there is
no `child:` there, only _names_ cross. The pattern is **declare once, use
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
```

Three ways to put content in a native view, in increasing cost:

|                            | Engine                    | State management        | Router                 |
| -------------------------- | ------------------------- | ----------------------- | ---------------------- |
| `nativeBody`               | none: SwiftUI directly    | yours, untouched        | native NavigationStack |
| glass `child:`             | the one you're already in | yours, untouched        | yours                  |
| `CupertinoNativeBodyRoute` | one per route             | mirrored via the bridge | any, per island        |

**State across the boundary is mirrored, not shared.** The host keeps owning
the state and publishes a serializable snapshot; bodies read it and send
actions back. Nothing about how your views manage their own state changes:
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

A body that boots mid-session has missed earlier publishes: call
`CupertinoNativeBodyBridge.requestState()` when it starts.

**A complete example**: a cart owned by the host, mirrored into a keyboard
toolbar island. The host's state manager is whatever you already use; only
the bridge lines are added, nothing about the views changes:

```dart
// ---- Shared: what crosses the bridge is DATA --------------------------------

/// The snapshot every island mirrors. Plain data: it must survive
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

/// The manager you already use: here a plain `ChangeNotifier`. Riverpod,
/// BLoC, Provider all work: the bridge only needs a listener.
final cart = ValueNotifier(const CartSnapshot(count: 0, total: 0));

final cartBar = CupertinoNativeBodyRoute('cartBar', () => const CartBar());

void main() {
  // The island's engine runs this same main() again, in ANOTHER isolate:
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

// The island lives where Flutter is hosted inside SwiftUI: the keyboard bar
// here. The host owns `cart`; the island never touches it directly.
CupertinoNativeTextField(toolbarActions: [cartBar.island]);
```

The flow is always the same: the host **owns** the state and publishes a
snapshot; each island **mirrors** it through
`CupertinoNativeBodyBridge.state` and sends **intents** (`send`) that the host
applies with its own manager, so the state managers never need to know about
each other, or about the bridge.

**Routers:** inside an island any router works (it is a full Flutter app), but
it is confined to that island. One router across host and islands is
impossible: two isolates share no objects. Coordinate through the bridge
(publish the active route), or use `nativeBody` + the native NavigationStack
for whole-app navigation and keep routers only where you truly need arbitrary
Flutter.

Anything crossing the bridge must survive `StandardMessageCodec`: null, bool,
num, String, Uint8List, List and Map of those.

## Icons

`CupertinoNativeIcon` is the icon every native control takes: an SF Symbol, or one of your own. To show a symbol in the Flutter tree, use `CupertinoSymbolImage`.

| Constructor                                                       |                                                                                      |
| ----------------------------------------------------------------- | ------------------------------------------------------------------------------------ |
| `.symbol(CupertinoSymbols, {size, weight, color, renderingMode})` | SF Symbol from the enum.                                                             |
| `.named(String, {size, weight, color, renderingMode})`            | Any SF Symbol name.                                                                  |
| `.iconData(IconData, {size, color})`                              | A glyph of an icon font: `CupertinoIcons`, `Icons`, or your own.                     |
| `.asset(String, {package, size, color})`                          | A transparent PNG asset from your `pubspec.yaml`, with its `2.0x` / `3.0x` variants. |

Your own icons are drawn as templates, in the control's tint or in `color`, like a symbol. They are read from the app's bundle on the native side, so nothing is sent but their names.

`renderingMode`: `monochrome`, `hierarchical`, `palette`, `multicolor`.

## Example app

The [example](example/) shows every widget and its variants. Run it on an
iOS 26 device.

Contributions are welcome, see [CONTRIBUTING.md](CONTRIBUTING.md) for setup,
how to run the example, and what CI checks before a PR merges.
