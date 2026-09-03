import Flutter
import SwiftUI
import UIKit

/// Base class for platform views that host a SwiftUI view via `UIHostingController`.
/// Owns the hosting-controller lifecycle, Auto Layout pinning, and intrinsic-size
/// calculation shared by every `Native*View` bridge class. Subclasses own their own
/// `FlutterMethodChannel`, method-call routing, and config decoding.
@available(iOS 15.0, *)
class NativeHostingView: NSObject, FlutterPlatformView {
    let _view = HostingContainerView()
    private(set) var hostingController: UIHostingController<AnyView>?

    /// Where measured sizes are pushed. Subclasses assign their own channel
    /// right after creating it; leaving it nil keeps the view pull-only.
    ///
    /// Pushing is the point: Dart used to *poll* for the size — a dozen
    /// method calls per view, spread over more than a second, because there
    /// was no way to know when SwiftUI had settled. The view knows exactly
    /// when: its container just laid out. One message, at the right moment,
    /// instead of twelve guesses.
    var sizeChannel: FlutterMethodChannel?

    /// Last size handed to Dart, so an unchanged layout pass sends nothing.
    private var publishedSize: CGSize?
    /// One pending measurement at a time; a layout pass can fire many times.
    private var measurementScheduled = false

    /// Whether this view's content has a size worth reporting.
    ///
    /// False for a view attached to FILL the box Flutter built. Measuring one
    /// of those is meaningless — it answers an unbounded proposal with the
    /// proposal, so `intrinsicSize()` falls back to re-measuring against the
    /// current bounds and returns a number about the box, not the content.
    /// Harmless while Dart only ever pulled (it pulled just for the widgets
    /// that wanted an answer); actively wrong now that the view pushes on its
    /// own, because it pushes to widgets that never asked.
    var measuresIntrinsicSize = true

    func view() -> UIView {
        return _view
    }

    /// Creates (or replaces) the hosting controller with `content`, laid out by `configureConstraints`
    /// (defaults to pinning all 4 edges to `_view`, which is what most widgets want).
    ///
    /// `keyboardAvoidance` is off by default: SwiftUI's automatic keyboard
    /// avoidance would shift each control up inside its own (Flutter-sized)
    /// container when the keyboard appears, making embedded controls visibly
    /// slide over neighboring Flutter content. The scaffold opts back in,
    /// since it owns a full-screen hierarchy where avoidance is correct.
    func attach(
        _ content: AnyView,
        keyboardAvoidance: Bool = false,
        configureConstraints: (UIView, UIView) -> Void = { host, container in
            NSLayoutConstraint.activate([
                host.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                host.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                host.topAnchor.constraint(equalTo: container.topAnchor),
                host.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
        }
    ) {
        if let old = hostingController {
            old.willMove(toParent: nil)
            old.view.removeFromSuperview()
            old.removeFromParent()
        }

        let host = UIHostingController(rootView: content)
        if !keyboardAvoidance {
            if #available(iOS 16.4, *) {
                // Embedded controls are sized and positioned entirely by
                // Flutter, so no safe-area region may influence their layout:
                // .keyboard would shift content up inside the box when the
                // keyboard opens, and .container insets content away from the
                // screen edge when the box scrolls near it (content visibly
                // overflowing onto neighboring Flutter widgets).
                host.safeAreaRegions = []
            }
        }
        if #available(iOS 16.0, *) {
            // Keep `host.view.intrinsicContentSize` in step with the SwiftUI
            // content. Without it a hosting controller's view does not
            // republish its size as the content settles, and the content
            // hugging / compression resistance that the hug-and-center
            // widgets (button, switch) size themselves with has nothing to
            // read — the host resolves to an ambiguous size while the SwiftUI
            // control, which is `fixedSize`, keeps drawing at its own. That is
            // how a switch ends up painting past its box and off the screen
            // edge. Harmless where the host's edges are pinned: a required
            // pin outranks an intrinsic size every time.
            host.sizingOptions = .intrinsicContentSize
        }
        host.view.backgroundColor = .clear
        // A UIView is `isOpaque = true` by DEFAULT, which is a promise to the
        // render server that every pixel of its bounds is filled. A hosted
        // control keeps that promise nowhere: a switch is a capsule in a
        // rectangle, a glass circle is a circle. The compositor is entitled to
        // skip blending and show the box — which is what surfaces as a faint
        // rectangle around an embedded control, most visibly where two of
        // their boxes overlap or a snapshot is taken (the context menu lift).
        // Clearing the background is not the same statement and does not
        // retract it.
        host.view.isOpaque = false
        host.view.translatesAutoresizingMaskIntoConstraints = false
        _view.addSubview(host.view)
        configureConstraints(host.view, _view)
        hostingController = host
        // Keep the controller parented into the view-controller hierarchy for
        // as long as our container is in a window (see HostingContainerView).
        _view.hostedController = host
        _view.updateHostParenting()
        // A re-attach can change the content's size; let the next layout pass
        // say so rather than assuming it did not.
        publishedSize = nil
        _view.onLayoutMeasure = { [weak self] in self?.scheduleMeasurement() }
    }

    /// Queues a measurement for just after the current layout pass.
    ///
    /// Never during it: `intrinsicSize()` lays the hosted view out to measure
    /// it, and driving layout from inside `layoutSubviews` is how a layout
    /// loop starts. Coalesced, because one pass can call back several times
    /// and the answer cannot change in between.
    private func scheduleMeasurement() {
        guard sizeChannel != nil, measuresIntrinsicSize, !measurementScheduled else { return }
        measurementScheduled = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.measurementScheduled = false
            self.publishIntrinsicSize()
        }
    }

    /// Hands Dart the content's measured size, if it has one and it moved.
    ///
    /// Driven by the container's layout pass, which is the moment SwiftUI has
    /// actually settled — including the late settles (fonts, images, async
    /// builds, a route transition finishing) that the old retry loop existed
    /// to catch and often missed anyway.
    func publishIntrinsicSize() {
        guard let sizeChannel else { return }
        let measured = intrinsicSize()
        guard let width = measured["width"], let height = measured["height"],
            width > 0, height > 0
        else { return }
        let size = CGSize(width: width, height: height)
        guard size != publishedSize else { return }
        publishedSize = size
        #if DEBUG
            // What the view actually reports, rather than what a screenshot
            // suggests. Fires only when the size changes, so it is one line
            // per control per layout that moved.
            print(
                "[cupertino_widgets] \(type(of: self)) measured "
                    + "\(String(format: "%.2f", width)) x \(String(format: "%.2f", height))")
        #endif
        sizeChannel.invokeMethod("intrinsicSize", arguments: measured)
    }

    /// Replaces the currently hosted SwiftUI view's root without re-attaching.
    func update(_ content: AnyView) {
        hostingController?.rootView = content
    }

    /// Measures the hosted SwiftUI content's natural size, for `getIntrinsicSize` handlers.
    ///
    /// Measured against an unbounded proposal, which is the size SwiftUI gives
    /// a view left to itself. A control that does not expand — a button, a
    /// switch — answers with exactly the size UIKit draws it at, so the box
    /// Flutter builds around it matches the pixels and nothing has to be
    /// clipped or padded to fit.
    ///
    /// A view that *fills*, though — a text field, a labeled switch, a button
    /// with `expand` — answers an unbounded proposal with the proposal
    /// itself: `.greatestFiniteMagnitude` in both axes, a number Flutter would
    /// happily build a box out of. Those are re-measured against the width
    /// Flutter has already given this view and a compressed height, which is
    /// the size they will really be laid out at.
    ///
    /// A degenerate answer (either axis at zero, which happens when the view
    /// has not been laid out yet) is reported as zero on both axes: the Dart
    /// side ignores non-positive sizes and keeps its default until a later
    /// measurement lands, rather than sizing the box to a bad number.
    func intrinsicSize() -> [String: Double] {
        guard let host = hostingController else { return ["width": 0.0, "height": 0.0] }
        host.view.setNeedsLayout()
        host.view.layoutIfNeeded()
        var fitting = host.sizeThatFits(
            in: CGSize(
                width: CGFloat.greatestFiniteMagnitude,
                height: CGFloat.greatestFiniteMagnitude))
        if !Self.isUsable(fitting), _view.bounds.width > 0 {
            fitting = host.sizeThatFits(in: CGSize(width: _view.bounds.width, height: 0))
        }
        guard Self.isUsable(fitting) else { return ["width": 0.0, "height": 0.0] }
        return ["width": Double(fitting.width), "height": Double(fitting.height)]
    }

    /// A measurement Flutter can size a box with: laid out (non-zero) and not
    /// the unbounded proposal handed straight back. No control here is
    /// anywhere near this tall or wide, so the bound only ever rejects the
    /// "I fill whatever you give me" answer.
    private static func isUsable(_ size: CGSize) -> Bool {
        let maxSensible: CGFloat = 100_000
        return size.width > 0 && size.height > 0
            && size.width < maxSensible && size.height < maxSensible
    }
}

/// Container view that keeps the hosted `UIHostingController` properly
/// parented as a child view controller of whatever view controller owns the
/// window it currently lives in (the FlutterViewController, in practice).
///
/// Without containment the hosting controller is "unparented": it never
/// receives appearance/containment callbacks, and when Flutter removes and
/// re-adds the platform view around route navigation the controller's layout
/// and safe-area state can come back corrupted (controls remeasure oversized
/// and overlap). Parenting on window attach — and unparenting on detach — is
/// the UIKit-sanctioned lifecycle for embedded hosting controllers.
@available(iOS 15.0, *)
final class HostingContainerView: UIView {
    weak var hostedController: UIHostingController<AnyView>?

    /// Never opaque: see the note on the hosted view in `attach`. This box is
    /// mostly empty by design — a control is centred in it, and since the
    /// paint-room change the box is deliberately larger than the control.
    override var isOpaque: Bool {
        get { false }
        set {}
    }

    /// The Flutter platform view id, so Dart can name this exact view when it
    /// exempts it from a scroll edge effect's mask. Set by the owning
    /// `Native*View` right after `super.init()`.
    var viewId: Int64 = -1

    /// Called after every (re)parenting pass. Containment changes make UIKit
    /// re-derive the hosted controller's layout margins, so subclass owners
    /// that force custom margins (the scaffold) re-assert them here.
    var onParentingChanged: (() -> Void)?

    /// Called on every layout pass of the container. UIKit recomputes the
    /// hosted hierarchy's margins during layout, so margin-forcing owners
    /// re-assert here too (must not trigger another layout).
    var onLayout: (() -> Void)?

    /// Also called on every layout pass, and kept separate from [onLayout] on
    /// purpose: that one belongs to whoever owns this view (the scaffold sets
    /// it), while this one belongs to `NativeHostingView` itself. One hook for
    /// two owners would have them overwrite each other.
    var onLayoutMeasure: (() -> Void)?

    /// Whether this view dissolves under a Flutter scroll edge effect it
    /// passes beneath. True for the embedded controls, which scroll under
    /// bars; false for a full-screen host (the scaffold), which IS the page
    /// the bar sits on rather than something moving under it.
    var masksUnderEdgeEffect = true {
        didSet { updateEdgeEffectRegistration() }
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateHostParenting()
        updateEdgeEffectRegistration()
    }

    private var edgeMask: CALayer?

    /// The rectangle the cut is measured against, in this view's coordinates.
    ///
    /// Outset, and that is the whole point: a mask layer is TRANSPARENT
    /// outside its own frame, so a mask sized to the view is a clip. UIKit
    /// controls paint past their bounds — the switch's rim, a glass shadow —
    /// and a mask laid on exactly those bounds shaved the excess the moment
    /// the control came near a bar. It looked like the bar was cutting the
    /// switch, because it was.
    var edgeMaskRect: CGRect { bounds.insetBy(dx: -edgeMaskOutset, dy: -edgeMaskOutset) }

    /// How far past its own box this view is treated as drawing — used both by
    /// the cut and by the bitmap that replaces the cut part, so the two cover
    /// the same pixels.
    let edgeMaskOutset: CGFloat = 24

    /// Hides everything past `visibleFrom` — the band Dart is drawing a bitmap
    /// of inside the bar.
    ///
    /// A mask layer is transparent outside its own frame, which is exactly the
    /// tool here: the mask IS the part that stays. Solid, no gradient — the
    /// point is that nothing of the live control shows where its picture is,
    /// and nothing of the picture is missing where the control shows.
    func applyEdgeCut(visibleFrom: CGFloat, atTop: Bool) {
        let full = edgeMaskRect
        let visible =
            atTop
            ? CGRect(
                x: full.minX, y: visibleFrom, width: full.width,
                height: max(0, full.maxY - visibleFrom))
            : CGRect(
                x: full.minX, y: full.minY, width: full.width,
                height: max(0, visibleFrom - full.minY))
        let mask = edgeMask ?? CALayer()
        edgeMask = mask
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        mask.backgroundColor = UIColor.white.cgColor
        // The seam is a hard line on a whole device pixel — Dart snapped the
        // rectangle before publishing it. Antialiasing the mask's edge would
        // put a half-covered row back, which is the hairline all over again.
        mask.edgeAntialiasingMask = []
        mask.frame = visible
        layer.mask = mask
        CATransaction.commit()
    }

    /// Drops the cut, for a view no effect covers any more.
    func clearEdgeEffect() {
        guard edgeMask != nil else { return }
        layer.mask = nil
        edgeMask = nil
    }

    private func updateEdgeEffectRegistration() {
        if window != nil, masksUnderEdgeEffect {
            EdgeEffectCoverage.shared.register(self)
        } else {
            EdgeEffectCoverage.shared.unregister(self)
        }
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
        onLayoutMeasure?()
    }

    func updateHostParenting() {
        guard let host = hostedController else { return }
        if window != nil {
            if host.parent == nil, let owner = owningViewController() {
                owner.addChild(host)
                host.didMove(toParent: owner)
            }
        } else if host.parent != nil {
            host.willMove(toParent: nil)
            host.removeFromParent()
        }
        onParentingChanged?()
    }

    /// Nearest view controller up the responder chain.
    private func owningViewController() -> UIViewController? {
        var responder: UIResponder? = next
        while let current = responder {
            if let vc = current as? UIViewController { return vc }
            responder = current.next
        }
        return nil
    }
}
