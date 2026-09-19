# Native bridge diagnostics — list padding, glass tint, searchable body, keyboard

This document records how the native surfaces in this package are wired, the
root cause of the reported bugs, and the fixes applied. The native side is
SwiftUI-first; UIKit is only used where SwiftUI has no first-class API.

## 1. How the pieces fit

### 1.1 `CupertinoNativeList`

```
CupertinoNativeList (Dart)
  → NativeCollectionView / NativeCollectionViewState  (lib/src/internal/native_collection_view.dart)
    → UiKitView(viewType: .../cupertino_native_list)
      → NativeListView (SwiftUI host)                  (ios/.../NativeListView.swift)
        → AdaptiveListView (SwiftUI)                   (ios/.../SwiftUI/AdaptiveListView.swift)
```

`AdaptiveListView` deliberately does **not** use SwiftUI `List`/`Form`. Those are
`UICollectionView`-backed greedy containers that do not report a content-based
height, so a platform view embedded in Flutter would clip. Instead it is a
composed `VStack` that mimics the grouped look and self-sizes exactly.

Row `trailing` widgets are not mounted in Flutter. They are **lowered** —
transcribed into `BodyNodeConfig` trees by
`lib/src/internal/widget_lowering.dart` — and rendered by `NativeBodyNode` in
`ios/.../SwiftUI/NativeBodyView.swift`. A lowered control reports through the
list channel as `onTrailingEvent(rowId, nodeId, value)`.

### 1.2 Native scaffold + search

```
CupertinoNativePageScaffold (Dart)
  → UiKitView(viewType: .../cupertino_native_scaffold)
    → NativeScaffoldView                             (ios/.../NativeScaffoldView.swift)
      → ScaffoldView (NavigationStack / TabView)     (ios/.../SwiftUI/ScaffoldView.swift)
        → pageRoot:
            • nativeBody != nil → NativeBodyView (pure SwiftUI)
            • else              → SearchablePageBody → PageScrollBody
                                   → FlutterContentView (a second FlutterEngine)
```

Each body runs in its **own** `FlutterEngine` from a shared `FlutterEngineGroup`.
The engine view is auto-resizable (`FlutterViewController.isAutoResizable = true`)
and is embedded inside a native SwiftUI `ScrollView`; the native scroll view owns
the actual scrolling.

Search state flows:

```
SwiftUI .searchable  →  SearchablePageBody reads @Environment(\.isSearching)
  → ScaffoldModel.onSearchActiveChanged
    → NativeScaffoldView.reportSearch
      → bodyChannels[route].invokeMethod("onScaffoldSearch", …)
        → Dart CupertinoNativePageScaffold._searchState (ValueNotifier)
```

`isSearching` is only delivered to a **descendant** of the view the `.searchable`
modifier is attached to; it is not propagated up the hierarchy (Apple docs,
`EnvironmentValues.isSearching`). That is why `SearchablePageBody` exists as a
dedicated child instead of reading it in `navStack`.

## 2. Bug: manual default padding on `CupertinoNativeList`

**Cause.** A previous change made `AdaptiveListView` hard-write spacing values
it had guessed:

```swift
VStack(spacing: isPlain ? 0 : 22) { … }.padding(.vertical, isPlain ? 0 : 14)
…
.frame(minHeight: 44).padding(.horizontal, 16).padding(.vertical, 6)
…
.padding(.horizontal, cardInset)   // cardInset defaulted to 16
```

Those numbers fight the metrics SwiftUI already applies for the list style, so
rows and sections came out over-spaced.

**Fix.** Keep the knobs (`cardInset`, `rowPadding`, `sectionSpacing`,
`stackPadding`, `minHeight`) so an app *can* tune a section — but stop
hard-writing defaults. Each modifier is applied only when the caller supplied a
value, so with nothing set SwiftUI owns every metric:

```swift
.applyRowPadding(section.rowPadding)             // nil → no padding
.applySectionCardInset(section.cardInset)        // nil → no inset
.applySectionStackPadding(effectiveStackPadding) // nil → no padding
```

`rowPadding` is an `EdgeInsetsDTO` applied as a whole (leading/trailing/top/
bottom) rather than being split into separate hard-coded calls.

## 3. Bug: tint selection in the Liquid Glass demo

**Cause.** The tint control is a `CupertinoNativeSlidingSegmentedControl.menu`
lowered into a list row's `trailing`. In `AdaptiveListView`, the row's whole
`HStack` carried `.contentShape(Rectangle()).onTapGesture { onRowTap }`. A
parent tap gesture and the menu `Picker`'s own tap compete for the same touch.
When the row gesture wins, the menu never opens (or opens and the selection is
swallowed), so `onTrailingEvent` never fires and `_tintIndex` never changes.

**Fix.** Scope the row tap to the label/value/chevron region only. The lowered
`trailing` controls sit outside that hit region, so they always receive their
own taps. This also matches UIKit cell behaviour (tapping a control does not
trigger the row action).

## 4. Bug: searchable body is empty after opening/closing search

**Cause.** The scaffold body is itself a platform view (an auto-resizable
`FlutterView` inside SwiftUI). The search demo bodies
(`example/lib/pages/search_body.dart`, `search_tab_page.dart`) render their lists
with `CupertinoNativeList`, i.e. a **platform view nested inside a platform
view**. `ScaffoldHomeBody` documents this exact limitation:

> use plain Flutter widgets in scaffold bodies. Platform-view widgets cannot
> render here because the body engine itself already lives inside a native
> platform view.

When search opens the body swaps to the suggestions list, and on cancel back to
the full list — each swap destroys and recreates the nested platform view, which
renders blank. Hence "go and come back → empty body".

**Fix.** Render the search bodies with plain Flutter widgets (drawn rows), the
same rule the other scaffold bodies follow. No native code change is needed: the
native search pipeline is correct.

## 5. Bug: keyboard dismisses on scroll

**Cause.** Not the scroll view. Measured with a probe that scrolled a focused
field by known steps and read `viewInsets.bottom` at each one:

```
inset-before=0.0
inset-focused=1179.0
inset-scroll-20=1179.0
inset-scroll-200=1179.0
inset-scroll-600=0.0    flutter-hasFocus=false
inset-scrolled-back=1179.0   flutter-hasFocus=true
```

The keyboard survives every scroll that leaves the field on screen and dies the
moment the field leaves the viewport. Native logs give the mechanism:

```
textfield window → nil   focused=true   superview=set
field focus → false      window=nil   superview=set   hostWindow=nil
```

The iOS engine removes a platform view from the `FlutterView` on any frame it is
not composited (`FlutterPlatformViewsController.removeUnusedLayers`) and re-adds
it later (`bringLayersIntoView`). Scrolling the field past the viewport is enough
to stop it being composited. **A view outside a window cannot be first
responder**, so UIKit resigns the field and the keyboard closes.

`keepsParentWhileDetached` — which keeps the hosted *controller* parented — was
already set, and does not help: the view itself is still out of the window.

**Fix.** Nothing public keeps a responder alive outside a window, and the engine
offers no way to decline the removal, so the plugin puts the field back the
moment the view returns. `HostingContainerView` gained an `onWindowChanged` hook;
the text field reads its focus on the way *out* — by the time the engine re-adds
the view, SwiftUI has already reset `focused` — and re-drives it on the way back:

```swift
if window == nil {
    self.wantsFocusWhenVisible = self.isFocused
} else if self.wantsFocusWhenVisible {
    self.wantsFocusWhenVisible = false
    self.setFocus(true)
}
```

Focus is re-driven through `TextFieldModel.focusCommand`, never by calling
`becomeFirstResponder()` on the backing field: SwiftUI owns `@FocusState`, and a
responder taken behind its back leaves SwiftUI believing the field is unfocused.

Verified end to end: `inset-scrolled-back=1179.0 flutter-hasFocus=true` —
scrolling back restores focus and the keyboard with no fresh tap.

Separately, SwiftUI's own scroll views dismiss the keyboard on a scroll unless
`.scrollDismissesKeyboard(.never)` is passed (Apple docs,
`scrollDismissesKeyboard(_:)`), so every scroll view that can host a field still
carries it.

## 6. Bug: keyboard toolbar — opaque, one point wide, never placed

**Cause.** The toolbar was declared the SwiftUI way — `ToolbarItemGroup(placement:
.keyboard)` — but every widget here is hosted as a child `UIHostingController`
inside a Flutter platform view. In that shape the `.keyboard` placement resolves
to nothing or crashes on the first focus, and there is no public SwiftUI way to
control the bar's material either (the `.keyboard` chrome belongs to the system).
The bar also rendered as an opaque block instead of the keyboard's material.

**Fix.** The UIKit route SwiftUI has no API for: the field's real input
accessory, `UITextField.inputAccessoryView`, with a transparent accessory view
that pins a strongly-retained `UIHostingController` rendering the same lowered
`BodyNodeConfig` tree as a native body. The bar is retained by the platform view
for its whole lifetime, so the hosting view is never left pointing at a dead
host.

Getting there took three corrections, each visible in the log long before it was
visible on screen:

1. **The bar was one point wide.** `KeyboardInputView` was built with a frame
   width of `UIView.noIntrinsicMetric` and answered `intrinsicContentSize` with
   the same value; `UIPeripheralHost` took that literally and installed the
   accessory at `frame = (-1 0; 1 48)` — an invisible sliver. Both carry real
   numbers now, and `autoresizingMask = [.flexibleWidth]` lets the keyboard
   stretch the bar to its own width.
2. **The accessory was never placed without a reload.** Assigning
   `inputAccessoryView` on a field that is already the responder registers the
   view — it comes back from the property, and UIKit lists it in the input view
   set — but does not add it to the hierarchy: measured, the bar stayed a root
   view with `superview == nil`, `window == nil`, the SwiftUI content never laid
   out, and nothing on screen. `reloadInputViews()` is what makes UIKit rebuild
   the input views around it. (`UIInputView` with the `.keyboard` style makes no
   difference either way — it is not placed with the style, without it, or as a
   plain `UIView`, so a plain view is what this uses.)
3. **The bar was rebuilt on every config push.** The "did the toolbar change?"
   test compared a `JSONEncoder` re-encoding of the decoded config, and that is
   not a stable identity: two encodes of one unchanged three-node toolbar came
   back with the keys in different orders (`{"type","id","isDark"}` against
   `{"type","isDark","id"}`). Every push therefore looked like a change, so the
   bar was rebuilt and `reloadInputViews()` ran *under a keyboard that was
   already up* — three rebuilds in a twenty-second run that typed nothing. The
   identity is now the payload Dart sent, compared with `isEqual:` the way the
   rest of the file compares configs.

**What is left.** The bar is attached on focus, and attaching then means a
reload, so the keyboard presents first and the bar lands a frame or two later.
Measured by sampling the inset every frame across the transition:

```
635, 865, 987, 1017, 1027, 1034, 1179, 1179, …
```

— the keyboard ramps to its own height (1035) and *then* grows by the bar's 48pt.
Attaching the bar earlier, while the field is still unfocused, does not avoid
this: SwiftUI's `TextField` keeps its own `inputAccessoryView` (a
`SwiftUI.InputAccessoryGenerator`) on its backing `UITextField` and re-asserts it
as the field takes focus, discarding ours. Measured on device, an accessory
attached before focus read `SwiftUI.InputAccessoryGenerator…` again by the time
the field was first responder. That route was implemented, measured, and removed
rather than left in looking useful.

**Appearance.** The bar paints nothing, which is what "truly transparent" means
here. What shows through is the app, not the keyboard's material: on a red page
the strip behind the bar came back red while the keyboard's own suggestion row
stayed grey. So a light keyboard under a dark page shows a seam at the bar;
painting a `UIVisualEffectView` blur is the fix for that and is a deliberate
non-goal for now.

Key files:
- `ios/.../SwiftUI/KeyboardAccessoryBar.swift` — the bar (accessory view + host).
- `ios/.../NativeTextFieldView.swift` — focus → install / detach wiring.
- `ios/.../Support/NativeHostingView.swift` — `onWindowChanged` hook (bug 5).

**Debugging.** Native logs are tagged `[cupertino_widgets]` via `NativeLog`
(Support/NativeLog.swift). A focus/toolbar cycle logs the focus flip with its
window state, bar creation, the install (with the class of whatever accessory it
replaced, and whether the field was live), the placement of the bar in the view
hierarchy, detach, and brightness changes — `grep cupertino_widgets` in
`flutter run` output. The placement line is the one that cannot be inferred from
Dart, and both of the first two faults above were only visible there.

**Testing.** `example/integration_test/keyboard_toolbar_test.dart` drives focus
through a `FocusNode` and asserts the keyboard inset actually rose. The obvious
version of that test does not work: `tester.tap` never reaches a platform view,
so a tap-based test leaves the field unfocused, the keyboard down and the bar
never built — and passes anyway, having proved nothing. It did exactly that
until the inset assertion was added, which is what makes the failure loud.

Two further traps in the same test:
- the field needs a **tight** width. The platform view has no intrinsic width, so
  a loose-width parent (a `Center`) lays it out 0 wide, the native container
  comes back `frame = (0 0; 0 0)`, and there is no backing text input for focus
  to land on;
- `node.hasFocus` is not evidence that the native field heard anything. Flutter
  focus succeeds even when the `focus` command was dropped because the platform
  view's channel did not exist yet, so the test retries until the inset moves.

## 7. Files touched

| File | Change |
| --- | --- |
| `ios/.../SwiftUI/AdaptiveListView.swift` | padding/inset only when caller-supplied; scope row tap to the label region |
| `ios/.../SwiftUI/SearchableModifier.swift` | `.scrollDismissesKeyboard(.never)` |
| `ios/.../SwiftUI/ScaffoldView.swift` | `.scrollDismissesKeyboard(.never)` on native-body scroll |
| `ios/.../SwiftUI/NativeBodyView.swift` | `.scrollDismissesKeyboard(.never)` on `scroll` nodes |
| `ios/.../Support/NativeHostingView.swift` | `keepsParentWhileDetached` + `onWindowChanged` hook (bug 5) |
| `ios/.../NativeTextFieldView.swift` | window-change → remember focus / restore it (bug 5); `syncAccessory` on config, attach on focus, theme sync, logging (bug 6) |
| `example/lib/pages/search_body.dart` | drawn Flutter rows instead of nested `CupertinoNativeList` |
| `example/lib/pages/search_tab_page.dart` | same |
| `ios/.../SwiftUI/KeyboardAccessoryBar.swift` | UIKit `inputAccessoryView`: transparent accessory view + retained hosting controller; payload-compared rebuild identity |
| `ios/.../Support/NativeLog.swift` | tagged `[cupertino_widgets]` logging helper |
| `example/lib/pages/text_field_demo_page.dart` | `toolbar-field` test key on the toolbar demo field |
| `example/integration_test/keyboard_toolbar_test.dart` | focus-the-field crash regression test; drives focus with a `FocusNode` and fails if the keyboard never appears |
