# Glass transitions, measured

What `CupertinoNativeGlassGroup`'s transitions actually do, on a running app,
rather than what the SwiftUI documentation says they should. Written after the
`glassEffectTransition` work on `feat/glass-effect-transitions`.

## Why this exists

The group had no `.glassEffectTransition` at all before that branch, and the
container it built changed identity with the spacing — so the merge was a state
and never a transition. Reading the Swift could not tell us whether fixing that
would produce the effect, only that it might. This is the run that settles it.

## Method

A temporary probe entrypoint (`example/lib/glass_probe_main.dart`, deleted after
use) cycled one group through the changes on a 1.8s timer, with the current step
printed on screen so every recorded frame is self-identifying. It was built with
`flutter build ios --simulator --debug -t lib/glass_probe_main.dart`, launched
with `simctl`, and recorded with `xcrun simctl io <UDID> recordVideo` — 45.0s at
1284×2778 on an **iPhone 12 Pro Max, iOS 26.2**.

Frames were sampled with AVFoundation (there is no `ffmpeg` on this machine) and
tiled into contact sheets, 24 frames across ~2.7s, i.e. one frame every 0.117s.
The same three cases are reachable interactively from the demo page's *Glass
transitions* section.

## What it does

**0 → 1, `materialize`.** The glass arrives **at full size**, edge-less and
translucent, with its glyph still a smudge; one frame later (0.17s) it is a crisp
rim around a sharp glyph. No scale, no travel. This is the same signature that
was measured off the user's reference recording of a third-party app, which is
what makes it worth stating: the package reproduces it.

**1 → 0, `materialize`.** The reverse. The circle softens into an edge-less blur
and is gone by the next frame.

**2 → 1, union.** Two separate circles become one continuous capsule holding both
glyphs, with **concave notches at the left and right edges** where the two
circles' silhouettes cross. That silhouette is the evidence — a cross-fade would
produce a smooth capsule with no notches.

**1 → 2.** The reverse, back to two separate circles.

**`matchedGeometry` and `materialize` are visibly different.** At the first frame
after the change, `matchedGeometry` has already produced the wide united shape;
`materialize` produces a normal-sized single circle that then grows into the
union. Same endpoint, different path — which is the point of exposing the field
rather than picking one.

**The group's box does not move.** Across the whole 45s the glass keeps the same
centre and the same distance below a fixed Flutter-drawn landmark line, through
the empty frames of 0 → 1 and 1 → 0 as well as the populated ones. That is
`glassVisible: false` plus `.hidden()` holding the item's slot doing what it was
added for.

## The risk that did not materialise

Before the run, the main open question was whether `glassEffectID` and
`glassEffectUnion` can be applied to the same view. Apple's examples use one or
the other, never both, and the union documentation only promises that effects
sharing "a similar shape, Liquid Glass effect, and ID" combine.

**On the simulator, they coexist fine.** The union forms, both transitions fire,
and no visual corruption appears in any of the 45s. The fallback — driving the
merge through `glassEffectID` plus container spacing alone — was not needed.

## What this does not prove

- **The simulator is not the device.** Refraction and edge lighting are
  simplified here; what was verified is timing and shape behaviour, not optical
  fidelity. A device still has to confirm the glass *looks* right.
- **The label and the glass are composited separately.** The step label is drawn
  by Flutter, the glass is a native platform view, so in a single frame the label
  can lead or trail the glass by a frame. A blurred frame's label is not
  authoritative for that instant — which is why the step boundaries here were
  read from several consecutive frames, not one.
- **Not exercised:** the `identity` transition, `vertical: true`, `glassVisible`
  on a multi-item group, and animating `spacing` at runtime.
- `interactive: false` throughout, so the touch shimmer is not covered.
