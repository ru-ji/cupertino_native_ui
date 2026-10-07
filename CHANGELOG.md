## Unreleased

### Breaking

* `CupertinoNativeGlassGroupItem.slotId` is removed: a glass is
  identified by its `actionId` alone. To swap one glass for another, give
  it a new `actionId`.
* `CupertinoNativeBody.textField(keyboardToolbar:)` takes
  `List<CupertinoNativeBody>` instead of encoded maps.

### Added

* `CupertinoNativeGlassGroup.alignment`.
* A text field in a `nativeBody` (page scaffold or sheet) shows its
  keyboard bar. Its items report through `onBodyEvent` as
  `<fieldId>.toolbar.<itemId>`.

### Fixed

* A glass keeps one SwiftUI view across changes, so a press carries into
  its transition.
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
