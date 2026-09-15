## Unreleased

### Breaking: widgets named after Flutter's Cupertino widgets

Every widget now carries the name of its Flutter counterpart behind the
`CupertinoNative` prefix, with the same parameter names for what they share.
No aliases are kept.

| Before | After |
|---|---|
| `CupertinoAppBar` / `CupertinoSliverAppBar` | `CupertinoNativeNavigationBar` / `CupertinoNativeSliverNavigationBar` |
| `CupertinoNativeAppBar` (scaffold config) | `CupertinoNativeScaffoldNavigationBar` |
| `CupertinoNativeScaffold` (`appBar`) | `CupertinoNativePageScaffold` (`navigationBar`) |
| `CupertinoNativeSegmentedControl` | `CupertinoNativeSlidingSegmentedControl<T>` — `children: Map<T, Text>`, `onValueChanged`, `thumbColor` |
| `CupertinoNativeProgressIndicator` | `CupertinoNativeActivityIndicator` (`color`, `radius`, `animating`) and `CupertinoNativeLinearActivityIndicator` (`progress`, `height`, `color`) |
| `CupertinoNativeAlert` / `CupertinoNativeAlertAction` | `CupertinoNativeAlertDialog` (`content`) / `CupertinoNativeDialogAction` (`child`, `isDefaultAction`, `isDestructiveAction`) |
| `CupertinoNativeListRow` (`icon`, `value`) / section `rows` | `CupertinoNativeListTile` (`leading`, `additionalInfo`) / section `children` |

* **Button:** the label is `child` — a `Text`, `CupertinoSymbolImage`, `Icon`
  or a `Row` of them — and the style is the constructor: default,
  `.filled`, `.tinted`, `.glass`, `.glassProminent`. `activeColor` → `color`,
  `controlSize` → `sizeStyle`; `title`, `icon`, `systemImage`, `labelStyle`
  and `textStyle` are gone. `onPressed` is required, as in Flutter.
* **Switch:** `activeColor` → `activeTrackColor`.
* **Date picker:** `value` → `initialDateTime`, `onChanged` →
  `onDateTimeChanged`, `mode` takes Flutter's `CupertinoDatePickerMode`.
* **Tab bar:** `tabs` → `items`, `value` (tab id) → `currentIndex`,
  `onChanged` → `onTap` (index).
* **Text field:** `prefixIcon` / `suffixIcon` → `prefix` / `suffix`.
* **Context menu:** `items` → `actions`.
* The deprecated aliases in `legacy_names.dart` are removed.

### The scroll edge effect is native

`CupertinoScrollEdgeEffect` — and with it `CupertinoAppBar`,
`CupertinoSliverAppBar` and the tab bar's effect — is now a native view on iOS,
rebuilt from the layers of the system's own `ScrollEdgeEffectView` as read off a
device:

* **Blur:** Core Animation's `variableBlur` at the system's radius (1pt), on a
  smootherstep curve.
* **Adaptive wash:** the render server measures the luminance under the bar
  (`_UILumaTrackingBackdropView`, sampling the 44pt bar below the status bar)
  and the wash settles on three levels — white 85%, black 27%, black 47% — on
  the system's 0.5s critically damped spring. It starts from the app theme.
* **Native controls blur live.** The effect is composited above the page, so it
  samples native views as well as Flutter content.
* New `onBrightnessChanged`: the app bars turn their title white over dark
  content, like the system's bar items.
* Visible through route transitions; route-transition photos of native
  controls are off by default.
* The `haze` dependency is gone; off iOS `soft` draws nothing.

**Action required:** add `<key>FLTDisablePartialRepaint</key><true/>` to the
app's `Info.plist`. With partial repaint, Flutter leaves the pixels under its
own overlays uncleared and a stale copy of the bar title glows inside the blur.
Debug builds warn when the key is missing.

### Removed

The bitmap-and-cut path that stood in for a blur Flutter could not apply to
native views: `BarSnapshotSurface`, the published edge regions
(`CupertinoEdgeEffectCoverage`, `CupertinoEdgeEffectExempt`), the native cut and
its KVO geometry hook, and the `setEdgeEffectRegion`, `setEdgeEffectExempt` and
`setEdgeCut` channel methods. None were public. The route-transition bitmap of
native views is off by default (`hidesDuringRouteTransition`).

## 0.1.0 (unreleased)

Naming pass for Flutter familiarity. Every removed name still resolves through
a deprecated alias in `lib/src/legacy_names.dart`, so existing code keeps
compiling with warnings. The aliases are removed in 0.3.0.

**No native changes** — the method-channel names and argument keys are
byte-identical, so nothing on the Swift side is affected.

### Enums replaced by Flutter's own

| Removed | Use instead |
| --- | --- |
| `CupertinoNativeClearButtonMode` | `OverlayVisibilityMode` (`package:flutter/cupertino.dart`) |
| `CupertinoNativeTextVerticalAlignment` | `TextAlignVertical` (`package:flutter/widgets.dart`) |

These are the exact types `CupertinoTextField.clearButtonMode` and
`TextField.textAlignVertical` take.

`TextAlignVertical` is a drop-in — `top`, `center` and `bottom` all exist on
it. It is continuous rather than a three-value enum, so any
`TextAlignVertical.y` is snapped to the nearest of UIKit's three
`contentVerticalAlignment` positions.

`OverlayVisibilityMode` spells two of its values differently, and the alias
cannot bridge those:

* `whileEditing` → `OverlayVisibilityMode.editing`
* `unlessEditing` → `OverlayVisibilityMode.notEditing`

`never` and `always` are unchanged.

### Enums renamed

| Before | After | Why |
| --- | --- | --- |
| `CupertinoNativeScrollEdgeEffect` | `CupertinoScrollEdgeEffectStyle` | It collided with the `CupertinoScrollEdgeEffect` widget — two public names differing only by `Native`. |
| `CupertinoNativeGlassShape` | `CupertinoGlassShape` | Matches `CupertinoGlassVariant` sitting beside it. |

Enums that name a real SwiftUI/UIKit type keep the `CupertinoNative` prefix
(`ButtonStyle`, `ControlSize`, `ListStyle`, `SheetDetent`, `TabRole`,
`ToolbarTitleDisplayMode` and the rest).

### Widget renamed

`CupertinoNativeToggle` → **`CupertinoNativeSwitch`**, matching Flutter's
`CupertinoSwitch` (its `value` / `onChanged` / `activeColor` already did). The
old name resolves through a deprecated alias.

### Parameters

One tint parameter across the package, spelled the way Flutter spells it.
`color`, `tint`, `accentColor` and `primaryColor` all become **`activeColor`**
on `CupertinoNativeButton`, `Menu`, `SegmentedControl`, `ProgressIndicator`,
`DatePicker`, `List`, `Form`, `TabBar` and `Scaffold`.
`CupertinoNativeGlassContainer.tint` keeps its name — that is a material tint,
not an accent.

Flutter's `value` / `onChanged` contract:

| Widget | Before | After |
| --- | --- | --- |
| `CupertinoNativeTabBar` | `selection`, `onSelectionChanged` | `value`, `onChanged` |
| `CupertinoNativeSegmentedControl` | `onValueChanged` | `onChanged` |

Raw `Function(...)` types are replaced by named typedefs, so callback
parameters infer their types at the call site instead of arriving as
`dynamic`: `CupertinoNativeMenuActionCallback`,
`CupertinoNativeListRowCallback`, `CupertinoNativeListToggleCallback`,
`CupertinoNativeBarActionCallback`, `CupertinoNativeRouteChangedCallback`,
`CupertinoNativeSearchCallback`, `CupertinoNativeSearchActiveCallback`.
`CupertinoNativeScaffold.onTabChanged` is now a `ValueChanged<String>`.

`CupertinoNativeTextField`'s five flat glass parameters (`glassEffect`,
`glassCornerRadius`, `glassVariant`, `glassInteractive`, `glassTint`) collapse
into one **`CupertinoGlass? glass`** — null renders the plain field. Its field
names match `CupertinoNativeGlassContainer`'s.

```dart
// before
CupertinoNativeTextField(glassEffect: true, glassCornerRadius: 16)
// after
CupertinoNativeTextField(glass: CupertinoGlass(cornerRadius: 16))
```

`CupertinoNativeSheet.show`'s `showGrabber` → **`showDragHandle`**, matching
Material's `showDragHandle`.

`CupertinoNativeButton.systemImage` is deprecated in favour of `icon`, which
already takes precedence over it — `CupertinoNativeTab.systemImage` was
already deprecated this way.

Parameter renames have no deprecated shims, unlike the type aliases: this
package has no published release, so there is no code to keep compiling.

### Routing — mirror any router onto the native stack

New `CupertinoNativeRouteSync` keeps a `CupertinoNativeScaffold`'s native
`NavigationStack` in step with whatever router the app already uses —
go_router, auto_route, Beamer, or a plain imperative `Navigator`. It speaks
route-id stacks rather than URLs, so it never has to agree with your router
about path syntax.

* `syncTo(routes)` diffs against the live native stack and emits the minimum
  push/pop sequence, keeping the shared prefix so a push still animates as a
  push. It is a no-op when the stack already matches.
* `reportNativeStack` (wired to `onRouteChanged`) forwards native back
  button / back-swipe navigation to `onNativeStackChanged` so the router can
  follow.
* The two directions can't loop: stack reports produced while `syncTo` is
  applying its own ops are recognised as echoes and dropped.
* `diffNativeStack`, `routesFromLocation` and `locationFromRoutes` are
  exported as plain functions for apps that want to drive the mirroring
  themselves.

String-only navigation for the common case: `controller.pushNamed(route)` and
`CupertinoNativeScaffold.pushNamed(route)` (the body-isolate form), avoiding a
`CupertinoNativeScaffoldPage` when the destination needs no bar of its own.

This does **not** make a Flutter `Navigator` work across scaffold bodies, and
nothing can: each body is its own FlutterEngine, so a router built in the host
engine has no object and no `BuildContext` reaching into it. The README's
routing section documents the constraint and the mirroring pattern.

### Other

* `deprecated_member_use_from_same_package` is now enabled, so the package
  reports its own uses of deprecated members.
* New `test/platform_view_wire_test.dart` decodes the real `creationParams`
  handed to `UiKitView` and pins the method-channel keys against the Swift
  `Models/*.swift` configs. The 0.1.0 renames changed Dart parameter names
  while deliberately keeping those keys, and a mistake there would compile,
  analyze and unit-test cleanly while silently breaking the widget on device.
* GitHub Actions CI (`.github/workflows/ci.yml`) runs analyze, the format
  check and the tests — pub.dev scores packages by static analysis only and
  never executes `test/`. A second job runs `pana` so the published score is
  visible before publishing.
* `homepage`, `repository` and `issue_tracker` added to the pubspec (pana
  penalises their absence), and `lib/` + `test/` are now fully formatted.

## 0.0.1

* Initial release.
