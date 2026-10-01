## Unreleased

* **iOS 27** (needs Xcode 27 to take effect; ignored on older SDKs/releases):
  `CupertinoNativeTabRole.prominent`; bar entries get `visibilityPriority`
  and `pinned` (`.topBarPinnedTrailing`); `CupertinoNativeScaffoldNavigationBar`
  gets `overflow` (`.toolbarOverflowMenu`) and `minimizeBehavior`
  (`.toolbarMinimizationBehavior`).
* `CupertinoNativeList`: edit-mode multi-selection (`editing`, `selection`,
  `onSelectionChanged`) with the system selection circles.
* `CupertinoNativeList`: row `badge`, `swipeActions` (+ `onSwipeAction`),
  drag-to-reorder in edit mode (`onReorder`).
* `CupertinoNativeSlider`: `divisions` now snap (were ignored), `onChangeStart`
  / `onChangeEnd`, `minimumIcon` / `maximumIcon`; iOS 26 `showTicks` and
  `neutralValue`.
* `CupertinoNativeTab.badge` (tab bar and scaffold).
* `CupertinoNativeSymbol`: `variableValue`, `paletteColors`; iOS 26 `gradient`.
* `CupertinoNativeSheet.show`: `detentHeights`, `undimmedUpTo`, `dismissible`.
* `CupertinoNativeMenu`: `onPressed` (tap = action, long press = menu),
  `fixedOrder`.
* `CupertinoNativeButton.role` (destructive / cancel).
* New controls, all SwiftUI: `CupertinoNativeStepper`,
  `CupertinoNativeColorPicker`, `CupertinoNativeGauge` (iOS 16+),
  `CupertinoNativeMultiDatePicker` (iOS 16+), `CupertinoNativeTextEditor`.
* `CupertinoNativeMenuControlGroup`: a row of compact icon buttons in a menu
  or context menu (`ControlGroup`).
* `CupertinoNativeDatePicker.style`: `compact`, `graphical`, `wheel`.
* `CupertinoNativeListTile.children`: an expandable row (the `DisclosureGroup` look, children as real rows).
* `CupertinoNativePhotosPicker` (iOS 17+): the system photo picker embedded
  in the page, no permission needed; fast file-based loading with a per-run
  cache and `clearCache()`. `showsAlbums` keeps the Photos / Albums switch;
  `CupertinoNativeBody.photosPicker` puts it in a native body (a native
  sheet with no engine).
* `CupertinoNativeSheet.show(nativeBody:, onBodyEvent:)` and
  `CupertinoNativeSheet.updateNativeBody`: a sheet of pure SwiftUI content,
  no FlutterEngine. `route` is now optional.
* Lowering (list rows, keyboard toolbar, native body) covers the new
  controls (`CupertinoNativeBody.control`), the slider's new options and
  `onChangeStart` / `onChangeEnd`, and the date picker's `style` — they were
  silently dropped before.
* Checkbox drawn with SF Symbols (`circle` / `checkmark.circle.fill`).
* Toolbar entries renamed after SwiftUI: `CupertinoNativeToolbarItem`,
  `CupertinoNativeToolbarItemGroup`, `CupertinoNativeToolbarSpacer`,
  `CupertinoNativeToolbarContent`, and `onBarAction` → `onToolbarAction`
  (`CupertinoNativeToolbarActionCallback`). The sheet and popover take
  `navigationBar` like the scaffold, instead of `appBar`. Every old name still
  works, deprecated.
* Less boilerplate: `CupertinoNativeButton.icon(symbol)` is the round glass
  icon button;
  toolbar items take `systemImage:` or `symbol:` directly.
* **Breaking:** `CupertinoNativeRadio` and `CupertinoNativeBody.radio` removed.

## 0.1.0

First release. Nothing to migrate from.

Native iOS widgets for Flutter — real UIKit and SwiftUI views hosted as
platform views, built on iOS 26's Liquid Glass.

* **Controls:** button, switch, slider, sliding segmented control, text field,
  date picker, activity indicators, menu, context menu, alert dialog.
* **Views:** list and form, glass container, glass group, sheet.
* **Chrome:** navigation bar (inline and sliver, with a built-in search
  variant), tab bar (split, minimize-on-scroll, search role, bottom
  accessory), and `CupertinoNativePageScaffold` — a native `NavigationStack`
  per tab with Flutter bodies in their own engines, so large titles collapse,
  the tab bar minimizes and pushes animate with the system transition.
* **Effects:** `CupertinoScrollEdgeEffect`, rebuilt from the layers of the
  system's own `ScrollEdgeEffectView` — Core Animation `variableBlur` plus the
  render server's luminance-tracked wash.
* **Routing:** `CupertinoNativeRouteSync` mirrors go_router, auto_route, Beamer
  or a plain `Navigator` onto the native stack.

Requires iOS 26+. Other platforms get simple Flutter fallbacks so shared code
still builds.

Add `<key>FLTDisablePartialRepaint</key><true/>` to the app's `Info.plist`, or
the navigation bar title glows inside the scroll edge effect. Debug builds warn
when the key is missing.
