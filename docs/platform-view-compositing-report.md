# Native views in Flutter on iOS: why effects don't reach them, and what can

Engine read: `~/Documents/flutter/engine/src/flutter` (engine `a804b26`, Aug 2026).
Files: `flow/embedded_views.h`, `flow/layers/backdrop_filter_layer.cc`,
`shell/platform/darwin/ios/framework/Source/FlutterPlatformViewsController.mm`,
`FlutterPlatformViews.mm`, `FlutterPlatformViews_Internal.h`, `overlay_layer_pool.mm`.

---

## 1. How a frame with a platform view is actually built

There are **two rasterisers** and **one compositor**:

| Who | Produces | Where |
|---|---|---|
| Flutter (Impeller) | Pixels in `CAMetalLayer` drawables | raster thread |
| UIKit / SwiftUI | Layer trees (Liquid Glass, `UIVisualEffectView` materials) | render server (backboardd) |
| **Core Animation** | The final on-screen image | render server |

Frame pipeline, per `FlutterPlatformViewsController.mm`:

1. **Preroll.** Each `PlatformViewLayer` calls `prerollCompositeEmbeddedView`. The mutators
   above it (transform, clip, opacity, backdrop filter) are recorded as a `MutatorsStack`
   (`embedded_views.h`, `enum MutatorType`).
2. **Slicing.** Everything painted before the first platform view goes to the root
   `FlutterView` surface. What is painted after platform view *N* is recorded into slice *N*.
   `SliceViews()` intersects each slice with the platform views' rects. Each non-empty region
   is rendered into a `FlutterOverlayView`, a separate `CAMetalLayer` taken from
   `overlay_layer_pool`.
3. **Submit** (`performSubmit`, a single `CATransaction` on the main thread):
   - `compositeView:withParams:` → `applyMutators:` turns the mutator stack into UIKit:
     - transform becomes `layer.transform`
     - clips become a `FlutterClippingMaskView` on the `ChildClippingView`
     - opacity becomes `alpha`
   - `bringLayersIntoView:` orders subviews as
     `[root FlutterView] [PV1 clip view] [overlay 1] [PV2 clip view] [overlay 2] …`.

The consequence: **a platform view is never pixels to Flutter.** It is a sibling `UIView`
that Core Animation composites between two Flutter `CAMetalLayer`s. Flutter content above it
does draw over it, because overlays are z-ordered correctly. But any Flutter operation that
has to *read* pixels only sees its own render target:

- `BackdropFilter` with `ImageFilter.shader`
- `ShaderMask`
- `saveLayer` blend modes

The native pixels are not in that target.

This isn't really "native drawing over Flutter". It's "native pixels existing only after
Flutter is done". Neither side can sample the other's output. Only Core Animation holds both.

## 2. The finding the codebase has missed: the engine already forwards blur

`backdrop_filter_layer.cc` → `Preroll`:

```cpp
if (filter_ && context->view_embedder != nullptr) {
  context->view_embedder->PushFilterToVisitedPlatformViews(
      filter_, context->state_stack.device_cull_rect());
}
```

Every platform view **already visited** (painted earlier, so below the filter) receives a
`kBackdropFilter` mutator. On iOS, `applyMutators` handles it:

```objc
case flutter::MutatorType::kBackdropFilter: {
  // Only support DlBlurImageFilter for BackdropFilter.
  if (!self.canApplyBlurBackdrop || !(*iter)->GetFilterMutation().GetFilter().asBlur()) break;
  ... PlatformViewFilter initWithFrame:frameInClipView blurRadius:sigma_x ...
}
[clipView applyBlurBackdropFilters:blurFilters];
```

`PlatformViewFilter` (`FlutterPlatformViews.mm`) takes a `UIVisualEffectView` apart:

- it copies Apple's private `gaussianBlur` `CAFilter` onto the `_UIVisualEffectBackdropView`
  with `inputRadius = sigma`
- it clears the tint subview, so there's no saturation or wash
- it clips to the filter rect, with rounded or superellipse corners taken from
  `ClipRRect`/`ClipRSuperellipse`

It is inserted **inside the platform view's `ChildClippingView`, above the native view and
below the next overlay**. Core Animation evaluates it live, so it blurs real Liquid Glass with
live refraction, not a frozen bitmap. `_canApplyBlurBackdrop = YES` is the default (line
329). It only switches off if Apple changes `UIVisualEffectView`'s internals.

So the statement repeated in `bar_snapshots.dart`, `edge_effect_coverage.dart`,
`native_platform_view_mixin.dart`, `cupertino_native_context_menu.dart` and the README is
incomplete. The accurate version:

> A `BackdropFilter` reaches a platform view **only if its filter is `ImageFilter.blur`**
> (uniform Gaussian, no tile mode, no compose, no matrix/color filter, no shader), the platform
> view is painted before it, and the filter rect intersects the view.

A shader backdrop filter (`ImageFilter.shader`) fails the `asBlur()` test, is dropped silently,
and the native control comes through crisp. **That one check is the whole limitation.**

## 3. The root constraint, stated once

An effect reaches a native view **only if Core Animation performs it**. Flutter can:

- (a) ask CA to do it, via a mutator (what the engine does for blur), or
- (b) turn the native view into Flutter pixels, via a snapshot or texture.

(b) is what the plugin does today. For Liquid Glass it has a hard ceiling. Glass and materials
are rendered in the render server from what is behind them:

- `layer.render(in:)` skips them.
- `drawHierarchy` is slow, only correct on screen, and frozen once captured.
- There is no offscreen or `CVPixelBuffer` path that gives a live, refracting glass image to
  `FlutterTexture` (`ios_external_texture_metal.mm`).

Memory confirms this: baking the backdrop in froze the refraction.

(a) is the only route that keeps glass **live**. Its limit is expressiveness: CA runs a fixed
set of private `CAFilter`s, not Flutter shaders.

## 4. Options, ranked

### Option 1 — Progressive blur built from stacked `ImageFilter.blur` bands (no native code) ★

The system scroll edge effect is essentially a blur whose radius falls off with distance from
the edge, plus a wash. Build it from the path the engine already supports:

```dart
// ponytail: N discrete sigmas approximate a continuous ramp; raise N if steps show.
Column(children: [
  for (var i = 0; i < bands; i++)
    Expanded(child: ClipRect(child: BackdropFilter(
      filter: ui.ImageFilter.blur(sigmaX: sigmaAt(i), sigmaY: sigmaAt(i)),
      child: const SizedBox.expand(),
    ))),
])
// then the tint gradient as a plain DecoratedBox on top (Flutter pixels, overlay layer)
```

**Why it could work**

- Each band is a real `DlBlurImageFilter`, so the engine adds one live `gaussianBlur` view
  per band inside every intersecting platform view.
- Flutter content in the same band gets the same sigma through Impeller, so Flutter and
  native blur match by construction.
- Glass stays live, since nothing is snapshotted.
- The wash is a normal gradient drawn in the overlay above the native view. That needs no
  mutator, because overlays already sit above it.

**This would delete:** the snapshot/cut machinery for the edge effect (`bar_snapshots.dart`,
`EdgeEffectCoverage.swift`, the KVO mask hook, the seam bug class). Route-transition
snapshots are a different problem and stay.

**Risks to verify, in this order**

1. **Band seams.** Each band clips its blur hard at its own edge, on both the CA side and the
   Impeller side. With about 8–12 bands and small sigma steps a seam should be invisible under
   the wash. It may not be. This is *the* experiment.
2. **Cost.** Each band × each intersecting platform view is one `UIVisualEffectView`. That's
   fine for a few controls under a bar and heavy for a dense list. Measure it.
3. **Stale-view mutation.** `applyMutators` rebuilds filter views whenever a view is
   recomposited. `applyBlurBackdropFilters` reuses subviews by index, so scrolling should only
   update frames. Check for flicker.
4. **Private-API fallback.** If the `UIVisualEffectView` layout changes, the engine sets
   `canApplyBlurBackdrop = NO` and quietly stops blurring. Keep that in mind when a new iOS
   beta lands.
5. **Sigma tuning.** The ramp is a stack of Gaussians and needs tuning by
   eye against the native `.scrollEdgeEffectStyle` in `CupertinoNativeScaffold`.

This is different from the rejected "hand-made `UIVisualEffectView` + gradient mask", for two
reasons. There's no plugin-side native view: the engine inserts and positions the blur inside
its own `CATransaction`, which is exactly the sync problem the KVO hook fights. And the same
filter blurs Flutter content, so no second implementation has to be matched to it.

### Option 2 — Upstream: make the mutator understand more than uniform blur

The hook is already there. `kBackdropFilter` carries the full `DlImageFilter`, and iOS
throws everything but `asBlur()` away. Candidate PRs to `flutter/flutter`:

- **Compose / color-matrix filters.** Map to `colorMatrix` / `vibrantColorMatrix` CAFilters
  alongside `gaussianBlur`. That covers blur + saturation, which is what system materials
  really are.
- **Progressive blur.** CA has a private `variableBlur` filter (`inputRadius` +
  `inputMaskImage`), which is what Apple's own edge effect uses. There is no `DlImageFilter`
  that expresses it, so it needs a new Dart API (e.g. `ImageFilter.blur` with a gradient
  mask). Impeller would have to implement it as well. That's a big ask, but it's the "correct"
  fix.
- Related open TODOs right in `applyMutators`: flutter#179126 (corner radius taken from the
  innermost clip only) and flutter#179127 (`kBackdropClipPath` ignored).

Upstream timelines are long, and this doesn't depend on the plugin. Worth an issue linked to
this project as the motivating case.

### Option 3 — Keep native as the top compositor where it matters (already done)

`CupertinoNativeScaffold` puts the real `UIScrollView` under real bars, so the real edge
effect works. It is still the only path to 100% fidelity for chrome. Its cost is that page
content under the bars can't hold Flutter-only effects. No change proposed.

### Option 4 — Current design: snapshot + cut (keep as fallback)

This is correct for a shader blur's exact look, but frozen by nature: no live glass under the bar,
a 10 Hz poll for off-screen views, and seam risk. Keep it only if Option 1's seams prove
visible.

### Not viable (for the record)

- **Native view → `FlutterTexture`.** No live glass offscreen (§3).
- **Plugin-side `CAFilter` on the Flutter overlay layer.** A filter on an overlay's
  `CAMetalLayer` filters the overlay's own contents, not what's behind it. Backdrop sampling
  needs a `CABackdropLayer`, and that is what `UIVisualEffectView` wraps. We'd be rebuilding
  Option 1 by hand, outside the engine's transaction.
- **Custom Metal shader over native pixels.** No public API exposes the backdrop
  (already in memory).
- **Hybrid composition à la Android (`SurfaceView`/`TextureLayer`).** iOS has no equivalent
  mode. The embedder described in §1 is the only one.

## 5. Other limitations, explained by the same model

| Symptom | Engine cause |
|---|---|
| Native view lags the route slide | Mutators are applied in `performSubmit` on the platform thread, while the Flutter surfaces present from the raster thread. When threads aren't merged they can land in different CA commits. |
| Glass ignores `Opacity` | `kOpacity` sets `embeddedView.alpha`. Glass and backdrop layers render at full intensity regardless of inherited alpha, which is UIKit behaviour. |
| Glass breaks under rotate/scale | `kTransform` sets `layer.transform`. Backdrop sampling under non-translation transforms is unsupported by CA. |
| Page correct until the first native control | Slicing: everything after PV1 lives in overlay layers (§1.2). |
| `ShaderMask` / blend modes over a native view do nothing | Same as a shader backdrop: not blur, so there's no mutator. |

## 6. Recommendation

1. **Spike Option 1 in the example app first:** a single `CupertinoScrollEdgeEffect` variant
   built from bands, over a page with a glass button and a switch. Decide on seams by eye.
   Effort is about one widget; it touches no native code.
2. If it holds, route `CupertinoScrollEdgeEffect` over native content through it, and retire
   the bar-snapshot path for the edge effect.
3. Either way, fix the misleading "BackdropFilter cannot reach a platform view" comments and
   the README wording to "only `ImageFilter.blur` does".
4. File the upstream issue for compose and progressive filters in the iOS mutator
   (Option 2).
