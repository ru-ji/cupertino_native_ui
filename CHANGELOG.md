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
