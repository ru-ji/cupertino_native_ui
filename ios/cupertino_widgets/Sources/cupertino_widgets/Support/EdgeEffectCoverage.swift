import UIKit

/// Where the Flutter scroll edge effects currently are on screen, so the
/// native views passing under them can melt away the way Flutter content does.
///
/// **Why this exists.** `Haze` is a `BackdropFilter`, and a backdrop filter
/// only ever filters its own render target. Painted over a platform view it
/// lands in an overlay surface the embedder clears to transparent each frame,
/// so it filters nothing: every SwiftUI control keeps drawing crisp through
/// the bar while the Flutter content around it blurs away. Flutter cannot
/// sample a `UIView` — the pixels never exist inside its render targets.
///
/// So the control does its own half. Dart publishes the effect's rectangle and
/// strength; each hosted view masks itself with the SAME falloff over the part
/// of it that is covered. Not a blur — no public API hands a view a blurred
/// copy of its own content — but the composite reads right: what the eye reads
/// under a scroll edge effect is content dissolving into the tint, and a
/// control that is nearly gone where the tint is densest cannot look crisp.
///
/// Same trick, one layer over, as `CupertinoSearchRowVisibility`: Flutter's
/// `Opacity` cannot fade a platform view either, so the native field fades
/// itself.
///
/// ponytail: mask, not blur. A real blur means a `UIVisualEffectView` per
/// control (the only view UIKit hands the backdrop to) — worth it only if the
/// dissolve reads wrong against the system's.
@available(iOS 15.0, *)
final class EdgeEffectCoverage {
    static let shared = EdgeEffectCoverage()

    /// One published effect. Coordinates are Flutter logical points from the
    /// top-left of the Flutter view, which is UIKit points in the window.
    struct Region {
        let rect: CGRect
        /// Whether the dense end is the top edge of `rect` or the bottom.
        let atTop: Bool
        /// 0 (nothing) to 1 (full), animated as the bar takes content under it.
        let intensity: CGFloat
        /// Fraction of the span held at full strength before the fade starts.
        let plateau: CGFloat

        init?(_ args: [String: Any]) {
            guard let width = args["width"] as? Double, let height = args["height"] as? Double,
                width > 0, height > 0
            else { return nil }
            rect = CGRect(
                x: args["left"] as? Double ?? 0, y: args["top"] as? Double ?? 0,
                width: width, height: height)
            atTop = args["atTop"] as? Bool ?? true
            intensity = CGFloat(args["intensity"] as? Double ?? 1)
            plateau = CGFloat(args["plateau"] as? Double ?? 0.3)
        }
    }

    private var regions: [Int: Region] = [:]
    /// Views that sit ABOVE an effect instead of passing under it — a bar's
    /// leading and trailing buttons. They are inside the effect's rectangle by
    /// design, at the same coordinates as the content melting away beneath
    /// them, so geometry cannot separate them: Dart names them.
    private var exempt: Set<Int64> = []
    private var views = NSHashTable<UIView>.weakObjects()
    /// Driven per frame, because the views MOVE under a stationary effect: a
    /// scroll changes a platform view's frame without laying its own container
    /// out, so there is no callback to hang this on.
    private var displayLink: CADisplayLink?

    /// Dart publishes one of these per live `CupertinoScrollEdgeEffect`,
    /// keyed by widget, and clears it on dispose.
    func setRegion(id: Int, args: [String: Any]?) {
        if let args, let region = Region(args), region.intensity > 0 {
            regions[id] = region
        } else {
            regions.removeValue(forKey: id)
        }
        sync()
    }

    func setExempt(viewId: Int64, _ isExempt: Bool) {
        if isExempt {
            exempt.insert(viewId)
        } else {
            exempt.remove(viewId)
        }
        tick()
    }

    func register(_ view: UIView) {
        views.add(view)
        sync()
    }

    func unregister(_ view: UIView) {
        views.remove(view)
        view.layer.mask = nil
        sync()
    }

    /// Runs the display link only while there is both an effect and something
    /// that could pass under it.
    private func sync() {
        let wanted = !regions.isEmpty && views.count > 0
        if wanted, displayLink == nil {
            let link = CADisplayLink(target: self, selector: #selector(tick))
            link.add(to: .main, forMode: .common)
            displayLink = link
        } else if !wanted, let link = displayLink {
            link.invalidate()
            displayLink = nil
            for view in views.allObjects { view.layer.mask = nil }
        }
        tick()
    }

    @objc private func tick() {
        for view in views.allObjects {
            apply(to: view)
        }
    }

    private func apply(to view: UIView) {
        guard view.window != nil, view.bounds.height > 0,
            !exempt.contains((view as? HostingContainerView)?.viewId ?? -1),
            let region = covering(view)
        else {
            if view.layer.mask != nil { view.layer.mask = nil }
            return
        }
        // The effect's rectangle in the view's own coordinates. Flutter's
        // logical origin is the FlutterView's, which is the window's on every
        // arrangement this package supports (a full-screen FlutterViewController).
        let effect = view.convert(region.rect, from: nil)

        let mask = view.layer.mask as? CAGradientLayer ?? CAGradientLayer()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        mask.frame = view.bounds
        mask.startPoint = CGPoint(x: 0.5, y: 0)
        mask.endPoint = CGPoint(x: 0.5, y: 1)
        var colors: [CGColor] = []
        var locations: [NSNumber] = []
        // Sampled across the view, not across the effect: a mask layer is
        // transparent outside its own frame, so it has to span the whole view
        // and carry the ramp inside it. Sixteen steps is past the point where
        // more of them changes anything on screen.
        let steps = 16
        for i in 0...steps {
            let u = CGFloat(i) / CGFloat(steps)
            let y = view.bounds.minY + u * view.bounds.height
            colors.append(UIColor(white: 1, alpha: alpha(atY: y, in: effect, region: region)).cgColor)
            locations.append(NSNumber(value: Double(u)))
        }
        mask.colors = colors
        mask.locations = locations
        view.layer.mask = mask
        CATransaction.commit()
    }

    /// How much of the view survives at `y` (view coordinates).
    ///
    /// The same smootherstep the Dart side ramps the tint with, so the control
    /// thins out exactly where the wash thickens. Outside the effect the view
    /// is untouched; past its dense edge it stays at the peak rather than
    /// coming back — a row scrolled fully behind the bar must not reappear.
    private func alpha(atY y: CGFloat, in effect: CGRect, region: Region) -> CGFloat {
        guard effect.height > 0 else { return 1 }
        let fromDenseEdge = region.atTop ? (y - effect.minY) : (effect.maxY - y)
        let u = min(max(fromDenseEdge / effect.height, 0), 1)
        let t = region.plateau >= 1 ? 0 : max(0, (u - region.plateau) / (1 - region.plateau))
        let s = t * t * t * (t * (t * 6 - 15) + 10)
        return 1 - region.intensity * (1 - s)
    }

    /// The strongest region this view actually intersects, if any. Overlap is
    /// tested in window space so a view can be checked without laying it out.
    private func covering(_ view: UIView) -> Region? {
        let frame = view.convert(view.bounds, to: nil)
        return regions.values
            .filter { $0.rect.intersects(frame) }
            .max { $0.intensity < $1.intensity }
    }
}
