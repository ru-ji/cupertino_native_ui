# Contributing

Thanks for considering a contribution — issues, PRs and design feedback are
all welcome.

## Setup

```bash
git clone https://github.com/ru-ji/cupertino_widgets.git
cd cupertino_widgets
flutter pub get
cd example && flutter pub get
```

The plugin is Dart + a Swift package
([`ios/cupertino_widgets`](ios/cupertino_widgets)); Xcode is only needed to
build and run the example app. There is no iOS build in CI (GitHub Actions
runs on Linux), so **a Swift change is only verified by building the example
on a Mac** — do that before opening a PR that touches `ios/`.

## Running the example

```bash
cd example
flutter run
```

Most of the package is Liquid Glass, so an **iOS 26 device or simulator** is
what shows it as intended; older versions get the fallbacks described in the
README. The example is also the manual test suite for anything visual — there
is no screenshot testing, so a UI change needs a look on device.

## Before opening a PR

CI ([`.github/workflows/ci.yml`](.github/workflows/ci.yml)) runs these; matching
them locally first saves a round trip:

```bash
flutter analyze
dart format --output=none --set-exit-if-changed lib test
flutter test
```

Or to just apply formatting:

```bash
dart format lib test
```

CI also runs [`pana`](https://pub.dev/packages/pana) — the same score pub.dev
computes on publish — so a warning it raises (missing docs on a public
member, a dependency issue) is worth fixing even if `flutter analyze` is
clean.

## Making a change

- **Dart-only widgets** (anything not backed by a platform view, or a pure
  Dart-side change to one that is) can be developed and tested without Xcode.
- **A new or changed native control** touches three places: the Dart widget
  in `lib/src/`, its Swift counterpart in
  `ios/cupertino_widgets/Sources/cupertino_widgets/`, and a page in
  `example/lib/pages/` that exercises it — add or update the example page in
  the same PR, since it is how a change gets a visual check at all.
- Match the surrounding style: doc comments explain *why*, not just what
  (see any file in `lib/src/` for the tone), and public API stays named after
  its Flutter counterpart (`CupertinoNative` + the widget it mirrors).

## PR checklist

- [ ] `flutter analyze` and `dart format` are clean
- [ ] `flutter test` passes
- [ ] A Swift-touching PR was run on a real iOS 26 device or simulator
- [ ] A new/changed native control has an example page
- [ ] The README is updated if public API changed

## Reporting a bug

Include the iOS version, whether it reproduces on iOS 26+ and/or the
fallback path, and — for anything visual — a screenshot or screen recording.
The [issue tracker](https://github.com/ru-ji/cupertino_widgets/issues) is the
place for these.
