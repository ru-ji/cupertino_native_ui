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
/// So the pixels are moved to where the blur can reach them. When a control
/// enters an effect's rectangle this tells Dart; Dart takes a bitmap of the
/// control (`PlatformViewSnapshot`), draws the covered band of it inside the
/// bar — ordinary Flutter pixels, under the shader — and only then asks for
/// the cut, at which point this hides exactly that band of the live view.
///
/// What the eye is given is one control: live below the line, a picture of
/// itself above it, blurring away with everything else. Nothing fades, nothing
/// is approximated. Same illusion as SwiftUI's tab-bar indicator, which does
/// not move the icons it passes over — it repaints the part it covers.
///
/// The cut is deliberately NOT applied on this side's own initiative: Dart
/// asks for it once it holds the bitmap, so there is never a frame where the
/// band is hidden and nothing has replaced it.
@available(iOS 15.0, *)
final class EdgeEffectCoverage {
    static let shared = EdgeEffectCoverage()

    /// One published effect. Coordinates are Flutter logical points from the
    /// top-left of the Flutter view, which is UIKit points in the window.
    struct Region {
        let rect: CGRect
        /// Whether the dense end is the top edge of `rect` or the bottom.
        let atTop: Bool

        init?(_ args: [String: Any]) {
            guard let width = args["width"] as? Double, let height = args["height"] as? Double,
                width > 0, height > 0
            else { return nil }
            rect = CGRect(
                x: args["left"] as? Double ?? 0, y: args["top"] as? Double ?? 0,
                width: width, height: height)
            atTop = args["atTop"] as? Bool ?? true
        }
    }

    private var regions: [Int: Region] = [:]
    /// Views that sit ABOVE an effect instead of passing under it — a bar's
    /// leading and trailing buttons. They are inside the effect's rectangle by
    /// design, at the same coordinates as the content melting away beneath
    /// them, so geometry cannot separate them: Dart names them.
    private var exempt: Set<Int64> = []
    /// Views whose covered band Dart has replaced with a bitmap, and which may
    /// therefore be cut. Empty until Dart says so, view by view.
    private var cut: Set<Int64> = []
    private var views = NSHashTable<HostingContainerView>.weakObjects()
    /// Driven per frame, because the views MOVE under a stationary effect: a
    /// scroll changes a platform view's frame without laying its own container
    /// out, so there is no callback to hang this on.
    ///
    /// A run-loop observer rather than a `CADisplayLink`: the embedder moves
    /// the platform views from a task on this thread, part-way through the
    /// frame, and a display link fires at the START of one — so it reads where
    /// the view was a frame ago and masks it there while the view is
    /// composited where it is now. `beforeWaiting` runs after the embedder's
    /// task and just ahead of CoreAnimation's commit.
    private var observer: CFRunLoopObserver?

    /// Dart publishes one of these per live `CupertinoScrollEdgeEffect`,
    /// keyed by widget, and clears it on dispose.
    func setRegion(id: Int, args: [String: Any]?) {
        if let args, let region = Region(args) {
            regions[id] = region
        } else {
            regions.removeValue(forKey: id)
        }
        #if DEBUG
            // Three things produce "the control is not fading" and look
            // identical on screen: the rectangle never arrives, it arrives at
            // zero strength, or it arrives and no view ever intersects it.
            // This line and the one in `apply` say which.
            print(
                "[cupertino_widgets] edge region \(id) "
                    + (regions[id].map {
                        "\(Int($0.rect.width))x\(Int($0.rect.height))"
                            + "@\(Int($0.rect.minY))"
                    } ?? "cleared")
                    + " views=\(views.count)")
        #endif
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

    /// Dart holds the bitmap for this view (or has released it).
    func setCut(viewId: Int64, _ isCut: Bool) {
        if isCut {
            cut.insert(viewId)
        } else {
            cut.remove(viewId)
        }
        tick()
    }

    func register(_ view: HostingContainerView) {
        views.add(view)
        sync()
    }

    func unregister(_ view: HostingContainerView) {
        views.remove(view)
        view.clearEdgeEffect()
        sync()
    }

    /// Runs the display link only while there is both an effect and something
    /// that could pass under it.
    private func sync() {
        let wanted = !regions.isEmpty && views.count > 0
        if wanted, observer == nil {
            // Ahead of CoreAnimation's own commit observer (order 2000000), so
            // the mask lands in the same commit as everything else this frame.
            observer = CFRunLoopObserverCreateWithHandler(
                kCFAllocatorDefault, CFRunLoopActivity.beforeWaiting.rawValue, true, 1_999_000
            ) { [weak self] _, _ in self?.tick() }
            CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes)
        } else if !wanted, let observer {
            CFRunLoopObserverInvalidate(observer)
            self.observer = nil
            for view in views.allObjects { view.clearEdgeEffect() }
        }
        tick()
    }

    private func tick() {
        for view in views.allObjects {
            apply(to: view)
        }
    }

    /// One view, the instant the embedder moved it. See
    /// `HostingContainerView.updateGeometryObservers`.
    func refresh(_ view: HostingContainerView) {
        guard !regions.isEmpty else { return }
        apply(to: view)
    }

    private func apply(to view: HostingContainerView) {
        guard view.window != nil, view.bounds.height > 0, !exempt.contains(view.viewId),
            cut.contains(view.viewId), let region = covering(view)
        else {
            view.clearEdgeEffect()
            return
        }
        // The line the control is cut on, in its own coordinates: the far edge
        // of the bar's own rectangle. Above it Dart draws the bitmap, below it
        // the live view continues — and both come from the same published
        // rectangle, so there is no seam to align by hand.
        let effect = view.convert(region.rect, from: nil)
        view.applyEdgeCut(
            visibleFrom: region.atTop ? effect.maxY : effect.minY, atTop: region.atTop)
    }

    /// The strongest region this view actually intersects, if any. Overlap is
    /// tested in window space so a view can be checked without laying it out.
    private func covering(_ view: UIView) -> Region? {
        let frame = view.convert(view.bounds, to: nil)
        // The tallest of the rectangles this view is inside. Two bars can
        // publish at once (a top one and a tab bar); a control can only be in
        // one of them, and where they somehow overlap the larger cut is the
        // safe one.
        return regions.values
            .filter { $0.rect.intersects(frame) }
            .max { $0.rect.height < $1.rect.height }
    }
}
