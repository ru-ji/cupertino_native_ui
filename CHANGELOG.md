## Unreleased

### Breaking

* `CupertinoNativeGlassGroupItem.slotId` is removed: a glass is
  identified by its `actionId` alone. To swap one glass for another, give
  it a new `actionId`.
* `CupertinoNativeBody.textField(keyboardToolbar:)` takes
  `List<CupertinoNativeBody>` instead of encoded maps.

### Added

* The Flutter navigation bars group their `trailing` buttons (glass or the
  default style) into one capsule, as SwiftUI groups toolbar items. A
  `Spacer()` ends a capsule; a `glassProminent` button stands alone. Three
  trailing items or more move the inline title to the leading side. What
  does not fit goes into a ••• menu, ordered by the new
  `CupertinoNativeButton.visibilityPriority` (navigation bars only).
* `CupertinoNativeGlassGroup.alignment`.
* A text field in a `nativeBody` (page scaffold or sheet) shows its
  keyboard bar. Its items report through `onBodyEvent` as
  `<fieldId>.toolbar.<itemId>`.

### Fixed

* A picker whose items are renamed in place (same count) shows the new
  names.
* A slider, and a control in a native body (page scaffold or sheet), no
  longer sends its value back to the native side when the page hands back
  the value it just reported: a drag used to send the whole configuration,
  or the whole body, on every frame. A sheet's `updateNativeBody` sends
  nothing when the tree has not changed.
* The Flutter navigation bars' inline title follows a theme change instead
  of staying white after a switch from dark to light.
* Menus, toolbar items and swipe actions are listed by position, not by
  `actionId`.
* A list no longer rebuilds when a toggle nested in an expandable row flips.
* The inline photos picker no longer reloads, losing its scroll position,
  when a sheet or route opens over it.
* An inline calendar in a list fits its month from the start instead of
  shrinking at the first tap.
* Controls in a list row's `trailing` take the values Dart pushes (a date,
  a switch, a field's config) instead of keeping their first ones.
* In a `nativeBody`, a switch, checkbox and segmented control show the value
  Dart pushes, so a change the app refuses is put back. A date picker takes
  a new date, range, mode and tint, and keeps the day the user picked when
  Dart did not change it.
* The prefix controls of a text editor take the values Dart pushes.
* The keyboard bar of a field in a list row follows changes to its items and
  the app's light or dark mode.
* A segmented control with no `groupValue` shows no segment selected inside
  a list row or keyboard bar.
* A stepper, color picker, gauge, multi-date picker or text editor no longer
  drops a change made while its native view was being created.
* A photos picker in a `nativeBody` takes a changed configuration.

## 0.1.0

* Initial release.
* Native iOS views as Flutter widgets: Liquid Glass on iOS 26, the earlier
  styles on iOS 15–18, with the names and parameters of Flutter's Cupertino
  widgets.
* Controls: button, switch, checkbox, slider, stepper, segmented control,
  picker, date and multi-date pickers, color picker, gauge, activity
  indicator, text field, text editor, menu, context menu, photos picker and
  SF Symbols.
* Alert dialog, with text fields, and action sheet.
* Lists and forms, with badges, swipe actions, selection and reordering.
* Navigation bars, tab bar, a native scaffold, sheets and popovers.
* Liquid Glass containers and groups.
* The iOS 26 scroll edge effect, adapting to the content under the bars.
* Custom icons from icon fonts and image assets.
