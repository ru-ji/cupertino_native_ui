## 0.1.0

First release.

Native iOS widgets for Flutter — the real UIKit and SwiftUI controls, hosted
as platform views, with the names and parameters of Flutter's own Cupertino
widgets. iOS 15+; Liquid Glass on iOS 26, and the iOS 27 options with
Xcode 27. Other platforms get simple Flutter fallbacks so shared code still
builds.

* **Controls:** button (glass, glass prominent, bordered, plain; round icon
  button; roles), switch, checkbox, slider (snapping divisions, start/end
  callbacks, min/max icons, ticks and neutral value on iOS 26), stepper,
  sliding segmented control, picker, date picker (compact, graphical, wheel),
  multi-date picker, color picker, gauge, activity indicators, text field
  (UIKit prefix, suffix and clear button, keyboard toolbar, glass), text
  editor, menu (with control groups), context menu, photos picker, SF Symbols
  with symbol effects, and `CupertinoSymbolImage` for symbols in Flutter's own
  layer tree.
* **Dialogs:** alert dialog and action sheet.
* **Lists and forms:** `CupertinoNativeList` and `CupertinoNativeForm` —
  inset-grouped cards, rows with badges, toggles, steppers and any
  transcribable trailing control, single and multiple choice, expandable rows,
  swipe actions, edit-mode selection and drag-to-reorder. A list sizes itself
  and drops into a Flutter scroll view.
* **Liquid Glass:** `CupertinoNativeGlassContainer` (its Flutter child's texts
  and still symbols drawn by SwiftUI inside the glass, so they adapt to what is
  behind it) and `CupertinoNativeGlassGroup` (glasses that merge, with
  morphing transitions).
* **Navigation bars:** `CupertinoNativeNavigationBar` and
  `CupertinoNativeSliverNavigationBar` — the iOS 26 bar with a collapsing large
  title, subtitle, search, glass buttons at the system's sizes and weights and
  an automatic back button; the iOS 15–18 bar with UIKit's page transition.
  Their glass buttons turn light or dark with the content under the bar, as
  the system's do.
* **Tab bar:** `CupertinoNativeTabBar` — split bars, badges, a search role,
  adapting to the content under it.
* **Scaffold:** `CupertinoNativePageScaffold` — a native `NavigationStack` (and
  `TabView`) whose pages are Flutter bodies in their own engines or native
  bodies described from Dart, so large titles collapse, the tab bar minimizes,
  pushes use the system transition and back-swipe is native. Toolbar items and
  groups after SwiftUI's, search, a bottom accessory.
* **Sheets and popovers:** `CupertinoNativeSheet` and `CupertinoNativePopover`
  — detents, custom heights, an undimmed range, a native navigation bar, a
  Flutter or native body.
* **Scroll edge effect:** `CupertinoScrollEdgeEffect`, the iOS 26 effect fitted
  to the system's frame by frame — the page's own colour, a wash that follows
  the luminance of the content (fixed on a page of its own colour), a light
  progressive blur at the top, and the `hard` style. Built on
  `CupertinoNativeEdgeBlur`, so it reaches native views under the bars.
* **Scrolling and touches:** native views inside Flutter scroll views behave
  as in a `UIScrollView` — the scroll can take a touch back from them, and a
  swipe back starting on one goes back. Fields lift above the keyboard from
  its first frame.
* **Routing:** `CupertinoNativeRouteSync` mirrors go_router, auto_route, Beamer
  or a plain `Navigator` onto the native stack.
* **Theming:** every widget follows the app's brightness, not the device's,
  and resolves `CupertinoDynamicColor`s for it.

Add `<key>FLTDisablePartialRepaint</key><true/>` to the app's `Info.plist`, or
the navigation bar title glows inside the scroll edge effect. Debug builds warn
when the key is missing.
