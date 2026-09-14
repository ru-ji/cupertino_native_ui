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

    /// Which appearance the hosted SwiftUI content must use. `nil` = follow
    /// the system. Set by subclasses from their config's `isDark` — the app's
    /// own brightness, not the device's: a light app on a dark-mode phone
    /// must still host light controls, or the page and the control disagree.
    ///
    /// Applied to the hosting controller rather than as a SwiftUI
    /// `.environment(\.colorScheme)`: the controller-level override also
    /// reaches what a plain environment does not — `UISwitch`-style UIKit
    /// internals, popovers a control presents, its text-field cursor.
    var isDark: Bool? {
        didSet {
            guard isDark != oldValue else { return }
            applyInterfaceStyle()
        }
    }

    private func applyInterfaceStyle() {
        let style: UIUserInterfaceStyle
        switch isDark {
        case true: style = .dark
        case false: style = .light
        default: style = .unspecified
        }
        hostingController?.overrideUserInterfaceStyle = style
    }

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

        let host = ClearHostingController(rootView: content)
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
        host.view.backgroundColor = nil
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
        // Into the content view, not the container itself: the edge cut is a
        // clip view between the two.
        _view.contentView.addSubview(host.view)
        configureConstraints(host.view, _view.contentView)
        hostingController = host
        // Subclasses set `isDark` BEFORE calling attach, while the controller
        // is still the old one (or nil), and `didSet` skips unchanged values —
        // so without this the new controller follows the phone's theme.
        applyInterfaceStyle()
        // Pin the appearance before the host is parented, so the first frame
        // already draws in the theme Dart asked for.
        applyInterfaceStyle()
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

/// A `UIHostingController` whose view is transparent and stays that way.
///
/// Setting `view.backgroundColor = .clear` once is not enough: the class
/// re-asserts an opaque background of its own on several occasions — being
/// added to a parent, a trait change, an appearance transition — and every one
/// of those puts a rectangle of `systemBackground` behind a control that is
/// supposed to be a capsule on nothing. It is invisible against a page of the
/// same colour, which is why it only ever showed up in the wrong theme, or in
/// the bar where the page behind it is not that colour any more.
///
/// Re-asserting it on every layout pass is the cheap durable answer: layout is
/// the one thing that certainly runs after each of those moments.
@available(iOS 15.0, *)
final class ClearHostingController<Content: View>: UIHostingController<Content> {
    /// Off for the one host that legitimately owns a background: the scaffold
    /// paints the page, so its opaque colour is the point rather than a
    /// leftover.
    var forcesClearBackground = true

    override func viewDidLoad() {
        super.viewDidLoad()
        clearBackground()
    }

    override func viewWillLayoutSubviews() {
        super.viewWillLayoutSubviews()
        clearBackground()
    }

    override func didMove(toParent parent: UIViewController?) {
        super.didMove(toParent: parent)
        clearBackground()
    }

    private func clearBackground() {
        guard forcesClearBackground else { return }
        if view.backgroundColor != nil { view.backgroundColor = nil }
        // A UIView promises to fill its bounds unless told otherwise, and the
        // compositor is entitled to take that promise literally.
        if view.isOpaque { view.isOpaque = false }
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

    /// Where the hosted view lives. Always the container's size, so moving
    /// the cut never lays the control out again — only its origin changes.
    let contentView = UIView()

    /// Sits between the container and [contentView] and does the edge cut by
    /// clipping. Unclipped (and outset) while no effect covers the view.
    private let clipView = UIView()

    override init(frame: CGRect) {
        super.init(frame: frame)
        for view in [clipView, contentView] {
            view.backgroundColor = nil
            view.isOpaque = false
        }
        clipView.addSubview(contentView)
        addSubview(clipView)
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    /// Never opaque: see the note on the hosted view in `attach`. This box is
    /// mostly empty by design — a control is centred in it, and since the
    /// paint-room change the box is deliberately larger than the control.
    override var isOpaque: Bool {
        get { false }
        set {}
    }

    /// Nothing gets to paint a box behind the control, whoever asks. The
    /// hosted controller is not the only thing that has tried.
    override var backgroundColor: UIColor? {
        get { nil }
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

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateHostParenting()
    }

    /// The rectangle the view is treated as drawing in, in its own coordinates.
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

    /// Frames the clip container on the outset box and shifts the content back
    /// so the control does not move. Unclipped: the outset is room for what a
    /// control paints past its bounds — a switch's rim, a glass shadow.
    private func layoutClip() {
        let rect = edgeMaskRect
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        clipView.clipsToBounds = false
        clipView.frame = rect
        contentView.frame = CGRect(
            x: bounds.minX - rect.minX, y: bounds.minY - rect.minY,
            width: bounds.width, height: bounds.height)
        CATransaction.commit()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        layoutClip()
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
