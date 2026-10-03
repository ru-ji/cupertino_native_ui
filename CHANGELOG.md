## Unreleased

* `CupertinoNativeGlassContainer.child`: its `Text`s and still SF Symbols are
  drawn by SwiftUI inside the glass, in the frames Flutter laid them out in —
  through `Row`, `Column`, `Wrap`, `Padding`, `Align`, `SizedBox` and
  `Flexible` — so they adapt to the backdrop like native labels. Other
  widgets stay Flutter, over the glass.
* The scroll edge effect takes the page background, as SwiftUI's does: the
  nearest `CupertinoPageScaffold`'s or `Scaffold`'s colour, else the theme's —
  `.soft`'s bright wash and `.hard` alike. `tintColor` on the navigation bars
  and `color` on `CupertinoScrollEdgeEffect` are deprecated and ignored: the
  effect cannot be tinted on its own. On `CupertinoColors.systemBackground`
  — what a `CupertinoPageScaffold` starts from — the wash follows the
  content; on any other colour, the page's or the theme's, it is fixed in
  it, as SwiftUI's is once a page has a `.background`. It is the page
  showing under the
  effect that counts: a tab bar laid over tabs that each have their own
  scaffold takes the visible tab's, as the system's does. In a dark app the
  wash is black alone, at the system's three strengths — 31% over bright
  content, 60% over mid, 85% over near-black — and the bar's chrome stays
  light: it no longer turned the page's black into an 85% wash over white.
* iOS 15–18: between two pages with `CupertinoNativeSliverNavigationBar`, the
  system's bar transition — the page's title, large or inline, flies into the
  next page's back button, whose label it becomes; bar items fade. Swipe-back
  drives it too.
* `CupertinoNativeContextMenu.blurBackground` is deprecated and ignored: the
  system already blurs the app behind the menu, and this stacked a second,
  stronger blur on top of it.
* Navigation bars add the back button themselves on a page that can pop
  (`automaticallyImplyLeading`, default `true`): a glass chevron on iOS 26,
  as the iOS 15–18 bar already did.
* Bar buttons take the system's weights (medium title and symbol on iOS 26;
  medium symbol, regular title, semibold `glassProminent` below) and its
  edge insets on 414pt-wide phones; 12pt between trailing glass buttons.
* Fixed: `CupertinoDynamicColor`s (`CupertinoColors.label`, the grouped
  backgrounds…) reached the native side as their light variant in dark mode.
* Fixed: a `TextStyle.fontWeight` on a button, switch, checkbox or menu label
  was ignored (sent as 100–900, read as 0–8).
* Fixed: dragging a text field's selection handle up or down scrolled the
  page instead.
* Fixed: a list scrolled off screen could report a wrong height and blank the
  page; a wheel in a list row now spins instead of scrolling the page.
* Fixed: on iOS 26 an action sheet without an anchor floated mid-screen
  without its Cancel button.
* `CupertinoNativeTextEditor.padding` insets the text inside the scroll view;
  the placeholder follows it.
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
* `CupertinoNativeTextEditor`: the text field's options (`style`,
  `cursorColor`, `backgroundColor`, `cornerRadius`, `keyboardType`,
  `textCapitalization`, `textContentType`, `textAlign`, `autocorrect`,
  `maxLength`, `readOnly`), `glass` / `glassTint`, `padding`, a `prefix`
  (any transcribable widget, callbacks kept) and `placeholderPadding`. Its
  background is transparent (iOS 16+), and it now lifts above the keyboard
  like a text field.
* `CupertinoNativeTextField`: `prefix`, `suffix` and the clear button are
  UIKit's own (`leftView`, `rightView`, `clearButtonMode`), drawn inside the
  field; `iconSpacing` (default 8) sets the gap to the text. `style.fontWeight`
  is applied — it was sent in the wrong unit and ignored.
* Keyboard: a field is lifted from the first frame of the keyboard (its focus
  is reported straight from UIKit), and moving focus under a keyboard that is
  already up scrolls smoothly instead of jumping.
* `CupertinoNativeList`: a row nobody listens to (no `onRowTap`) no longer
  flashes the pressed highlight, nor does any row outside edit mode. Opening
  or closing an expandable row grows the box with the rows, and the page
  under it moves with them — it used to jump. A text field's clear button now
  shows inside a list or native body.
* **Breaking:** `CupertinoGlass` removed. `CupertinoNativeTextField.glass` (and
  `CupertinoNativeBody.textField`) take a `CupertinoNativeGlass` —
  `.regular`, `.clear`, `.identity`, SwiftUI's own `Glass` variants, always
  interactive — with `glassTint` beside it; the glass corners follow
  `cornerRadius`.
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
