import Flutter
import SwiftUI
import UIKit

/// Embeds an auto-resizable FlutterEngine view controller inside SwiftUI.
///
/// The Dart side drives the size: the host must not constrain the view, it
/// only mirrors its intrinsic size into SwiftUI.
@available(iOS 15.0, *)
struct FlutterContentView: View {
    let engine: FlutterEngine
    /// Show a native spinner until the engine's first layout reports in.
    /// Off by default (matches CupertinoNativeSettings on the Dart side).
    var showLoadingIndicator = false
    /// Height reserved until Flutter's first layout reports in. Nil: the
    /// screen height, for page bodies.
    var placeholderHeight: CGFloat? = nil

    @State private var contentSize: CGSize?
    /// Engine-reported "first frame is on screen". Size observation can lag
    /// (or fail entirely) behind actual rendering; either signal must be able
    /// to dismiss the spinner so it never sits on top of live content.
    @State private var firstFrameRendered = false

    private var isLoading: Bool { contentSize == nil && !firstFrameRendered }

    var body: some View {
        _FlutterContentRepresentable(
            engine: engine,
            onSizeChange: { size in
                // Reported from UIKit layout passes; hop out before mutating state.
                DispatchQueue.main.async {
                    if contentSize != size {
                        contentSize = size
                    }
                }
            },
            onFirstFrame: {
                DispatchQueue.main.async { firstFrameRendered = true }
            }
        )
        // Placeholder height until Flutter's first layout reports in.
        .frame(height: contentSize?.height ?? placeholderHeight ?? UIScreen.main.bounds.height)
        // Native spinner while the body engine renders its first frame, so
        // the page never reads as empty (opt out via showLoadingIndicator).
        .overlay(alignment: .top) {
            if showLoadingIndicator && isLoading {
                ProgressView()
                    .padding(.top, 80)
                    .transition(.opacity)
            }
        }
        .animation(.easeOut(duration: 0.15), value: isLoading)
    }
}

@available(iOS 15.0, *)
private struct _FlutterContentRepresentable: UIViewControllerRepresentable {
    let engine: FlutterEngine
    let onSizeChange: (CGSize) -> Void
    let onFirstFrame: () -> Void

    func makeUIViewController(context: Context) -> FlutterHostViewController {
        let controller = FlutterHostViewController(engine: engine)
        controller.onSizeChange = onSizeChange
        controller.onFirstFrame = onFirstFrame
        return controller
    }

    func updateUIViewController(_ uiViewController: FlutterHostViewController, context: Context) {
        uiViewController.onSizeChange = onSizeChange
        uiViewController.onFirstFrame = onFirstFrame
    }
}

/// Hosts the FlutterViewController pinned top/leading/trailing to this view,
/// its width is the host's, and leaves the height to the auto-resizable
/// FlutterView, which installs its own (FlutterAutoResizeLayoutConstraint) and
/// publishes the Dart-chosen size through intrinsicContentSize/bounds.
@available(iOS 15.0, *)
final class FlutterHostViewController: UIViewController {
    private let flutterController: FlutterViewController
    private var lastReportedSize: CGSize = .zero
    private var boundsObservation: NSKeyValueObservation?
    private var displayObservation: NSKeyValueObservation?

    var onSizeChange: ((CGSize) -> Void)?
    var onFirstFrame: (() -> Void)?

    /// Dart's own measure of its root's height. Once a frame carries platform
    /// views the engine never resizes the auto-resizable view again
    /// (`FlutterPlatformViewsController.submitFrame` only calls `performResize`
    /// when there are none), so a body whose lists measure themselves after
    /// the first frame would stay at its first height. Dart tells us instead.
    private var heightChannel: FlutterMethodChannel?

    init(engine: FlutterEngine) {
        flutterController = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
        flutterController.isViewOpaque = false
        flutterController.isAutoResizable = true
        super.init(nibName: nil, bundle: nil)
        let channel = FlutterMethodChannel(
            name: "cupertino_native_ui/body_height", binaryMessenger: engine.binaryMessenger)
        channel.setMethodCallHandler { [weak self] call, result in
            if call.method == "height", let height = (call.arguments as? NSNumber)?.doubleValue {
                self?.adoptDartHeight(CGFloat(height))
            }
            result(nil)
        }
        heightChannel = channel
    }

    /// The last height Dart reported, kept so it can be applied again if the view
    /// was not laid out yet, or the engine dropped its constraints.
    private var dartHeight: CGFloat?

    /// Gives the FlutterView Dart's measured height.
    ///
    /// The engine's own auto-resize constraint is what sizes the view, and it is
    /// only ever created (or updated) on a frame without platform views. When it
    /// exists, its constant is moved to the new height. When it does not, the
    /// first frame already carried a platform view, it is created the way the
    /// engine would have: `-[FlutterView setIntrinsicContentSize:]`, which takes
    /// physical pixels. Creating it (rather than sizing the view some other way)
    /// matters: with an engine constraint in place the engine keeps its limit at
    /// the frame's *first* size (0, i.e. unbounded); without one it re-reads the
    /// current frame as the limit and Dart can never grow past it.
    private func adoptDartHeight(_ height: CGFloat) {
        guard height > 1 else { return }
        dartHeight = height
        let flutterView: UIView = flutterController.view
        let engineHeights = flutterView.constraints.filter {
            $0.firstAttribute == .height
                && String(describing: type(of: $0)).contains("AutoResize")
        }
        if engineHeights.isEmpty {
            let width = flutterView.bounds.width
            let selector = NSSelectorFromString("setIntrinsicContentSize:")
            guard width > 1, flutterView.responds(to: selector) else { return }
            let scale = flutterView.window?.windowScene?.screen.scale ?? UIScreen.main.scale
            typealias SetSize = @convention(c) (AnyObject, Selector, CGSize) -> Void
            let setSize = unsafeBitCast(flutterView.method(for: selector), to: SetSize.self)
            setSize(flutterView, selector, CGSize(width: width * scale, height: height * scale))
            return
        }
        for constraint in engineHeights where abs(constraint.constant - height) > 0.5 {
            constraint.constant = height
            flutterView.setNeedsLayout()
        }
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        // The engine's own first-frame signal, so the spinner never outlives
        // visible content.
        displayObservation = flutterController.observe(
            \.isDisplayingFlutterUI, options: [.initial, .new]
        ) { [weak self] controller, _ in
            if controller.isDisplayingFlutterUI {
                DispatchQueue.main.async { self?.onFirstFrame?() }
            }
        }

        // The engine resizes the FlutterView through its own constraints;
        // host layout passes don't reliably re-run when that happens, so
        // observe the view's bounds directly.
        boundsObservation = flutterController.view.observe(\.bounds, options: [.new]) {
            [weak self] observedView, _ in
            self?.reportIfChanged(observedView.bounds.size)
        }
    }

    /// Whether the FlutterView is in place: see [installFlutterView].
    private var flutterViewInstalled = false

    /// Puts the FlutterView in, pinned top/leading/trailing, on this view's
    /// first layout that has a width.
    ///
    /// Not in `viewDidLoad`: SwiftUI lays a representable out at zero width
    /// before it places it, and an auto-resizable FlutterView keeps the frame
    /// of its first layout as its size limit. Pinned from the start, that
    /// first frame was 0 wide: the engine logged "the host native view's width
    /// is 0" on every layout from then on and treated the width as unbounded.
    /// Pinned once this view has a width, the first frame is the real one,
    /// the way Flutter's own add-to-app sample does it (left unconstrained it
    /// gets an arbitrary width: 360pt on a 414pt Plus iPhone). Width and top
    /// are the host's; the height stays Dart's.
    private func installFlutterView() {
        flutterViewInstalled = true
        addChild(flutterController)
        let flutterView = flutterController.view!
        flutterView.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(flutterView)
        NSLayoutConstraint.activate([
            flutterView.topAnchor.constraint(equalTo: view.topAnchor),
            flutterView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            flutterView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
        ])
        // The engine removes its own width/height constraints when the trait
        // collection changes (`resetIntrinsicContentSize`), and on the next
        // layout takes the view's *current frame* as its size limit
        // (`updateAutoResizeConstraints`). With nothing to say what the height
        // is meanwhile, UIKit keeps the old frame, so the limit becomes that
        // height and the content can never grow again. A weak zero height makes
        // the frame collapse instead, which the engine reads as "unbounded",
        // and loses to the engine's own (required) constraint whenever it exists.
        let weakHeight = flutterView.heightAnchor.constraint(equalToConstant: 0)
        weakHeight.priority = UILayoutPriority(1)
        weakHeight.isActive = true
        flutterController.didMove(toParent: self)
    }

    deinit {
        boundsObservation?.invalidate()
        displayObservation?.invalidate()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
        if !flutterViewInstalled {
            guard view.bounds.width > 0 else { return }
            installFlutterView()
        }
        if let dartHeight { adoptDartHeight(dartHeight) }
        reportIfChanged(flutterController.view.intrinsicContentSize)
        // Dart layout can settle after this pass (fonts, images, async
        // builds); re-check once shortly after.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) { [weak self] in
            guard let self = self else { return }
            self.reportIfChanged(self.flutterController.view.intrinsicContentSize)
        }
    }

    private func reportIfChanged(_ size: CGSize) {
        guard size.width > 1, size.height > 1, size != lastReportedSize else { return }
        lastReportedSize = size
        // Rounded up to a whole point, so a fractional Dart height never leaves the
        // body a sliver short.
        onSizeChange?(CGSize(width: size.width, height: size.height.rounded(.up)))
    }
}
