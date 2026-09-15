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

    /// Where measured sizes are pushed. Subclasses assign their channel right
    /// after creating it; nil keeps the view pull-only.
    var sizeChannel: FlutterMethodChannel?

    /// Last size handed to Dart, so an unchanged layout pass sends nothing.
    private var publishedSize: CGSize?
    /// One pending measurement at a time; a layout pass can fire many times.
    private var measurementScheduled = false

    /// Whether this view's content has a size worth reporting. False for a view
    /// that fills the box Flutter built.
    var measuresIntrinsicSize = true

    /// Appearance of the hosted content — the app's brightness, not the device's.
    /// `nil` follows the system. Set on the hosting controller, so UIKit internals
    /// and presented popovers follow it too.
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
        if let isDark { Self.syncWindowStyle(isDark: isDark) }
    }

    /// System popovers (compact date picker calendar, UIMenu chrome) are
    /// presented from the window, not from our controller, so they read the
    /// window's style. Pin it only while the app's theme differs from the
    /// device's: a permanent override would freeze Flutter's
    /// `platformBrightness`, and a `ThemeMode.system` app could never follow
    /// the device again.
    static func syncWindowStyle(isDark: Bool) {
        let device = UIScreen.main.traitCollection.userInterfaceStyle
        let wanted: UIUserInterfaceStyle = isDark ? .dark : .light
        let style: UIUserInterfaceStyle = wanted == device ? .unspecified : wanted
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows where window.overrideUserInterfaceStyle != style {
                window.overrideUserInterfaceStyle = style
            }
        }
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
            // Keep `host.view.intrinsicContentSize` in step with the SwiftUI content,
            // so hug-and-center controls (button, switch) size to it.
            host.sizingOptions = .intrinsicContentSize
        }
        host.view.backgroundColor = nil
        // Not opaque: the control does not fill its box, and an opaque view shows a
        // faint rectangle around it.
        host.view.isOpaque = false
        host.view.translatesAutoresizingMaskIntoConstraints = false
        // Into the content view, not the container itself.
        _view.contentView.addSubview(host.view)
        configureConstraints(host.view, _view.contentView)
        hostingController = host
        // Subclasses set `isDark` BEFORE calling attach, while the controller
        // is still the old one (or nil), and `didSet` skips unchanged values —
        // so without this the new controller follows the phone's theme.
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
    func publishIntrinsicSize() {
        guard let sizeChannel else { return }
        let measured = intrinsicSize()
        guard let width = measured["width"], let height = measured["height"],
            width > 0, height > 0
        else { return }
        let size = CGSize(width: width, height: height)
        guard size != publishedSize else { return }
        publishedSize = size
        sizeChannel.invokeMethod("intrinsicSize", arguments: measured)
    }

    /// Replaces the currently hosted SwiftUI view's root without re-attaching.
    func update(_ content: AnyView) {
        hostingController?.rootView = content
    }

    /// Measures the hosted SwiftUI content's natural size, for `getIntrinsicSize` handlers.
    /// A view that fills its box is re-measured against the current width.
    /// Zero on both axes until it has been laid out.
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
/// UIKit re-asserts an opaque background on several occasions (parenting,
/// trait changes, appearance transitions), so it is cleared on every layout.
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
/// Keeps appearance callbacks, layout and safe-area state correct when
/// Flutter removes and re-adds the platform view.
@available(iOS 15.0, *)
final class HostingContainerView: UIView {
    weak var hostedController: UIHostingController<AnyView>?

    /// Where the hosted view lives; always the container's size.
    let contentView = UIView()

    /// Unclipped, outset container, so controls can paint past their bounds.
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

    /// Never opaque: the box is mostly empty around the control.
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

    /// The Flutter platform view id.
    var viewId: Int64 = -1

    /// Called after every (re)parenting pass. Containment changes make UIKit
    /// re-derive the hosted controller's layout margins, so subclass owners
    /// that force custom margins (the scaffold) re-assert them here.
    var onParentingChanged: (() -> Void)?

    /// Called on every layout pass of the container. UIKit recomputes the
    /// hosted hierarchy's margins during layout, so margin-forcing owners
    /// re-assert here too (must not trigger another layout).
    var onLayout: (() -> Void)?

    /// Also called on every layout pass, for `NativeHostingView` itself;
    /// [onLayout] belongs to the subclass.
    var onLayoutMeasure: (() -> Void)?

    override func didMoveToWindow() {
        super.didMoveToWindow()
        updateHostParenting()
    }

    /// The rectangle the view draws in: its bounds plus [edgeMaskOutset], for
    /// what controls paint past them (a switch's rim, a glass shadow).
    var edgeMaskRect: CGRect { bounds.insetBy(dx: -edgeMaskOutset, dy: -edgeMaskOutset) }

    /// How far past its own box this view draws.
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

    /// Keep the controller parented while the view is only temporarily out of
    /// the window. The iOS engine `removeFromSuperview`s a platform view on any
    /// frame it is not composited (a route covering it), and re-adds it later.
    /// Unparented in between, a NavigationStack laid out meanwhile caches zero
    /// system margins and its large title comes back flush with the screen
    /// edge. Released in `deinit` instead.
    var keepsParentWhileDetached = false

    func updateHostParenting() {
        guard let host = hostedController else { return }
        if window != nil {
            if host.parent == nil, let owner = owningViewController() {
                owner.addChild(host)
                host.didMove(toParent: owner)
            }
        } else if host.parent != nil, !keepsParentWhileDetached {
            host.willMove(toParent: nil)
            host.removeFromParent()
        }
        onParentingChanged?()
    }

    deinit {
        guard let host = hostedController, host.parent != nil else { return }
        host.willMove(toParent: nil)
        host.removeFromParent()
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
