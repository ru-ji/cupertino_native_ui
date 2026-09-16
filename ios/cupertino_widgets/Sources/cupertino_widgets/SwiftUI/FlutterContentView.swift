import Flutter
import SwiftUI
import UIKit

/// Embeds an auto-resizable FlutterEngine view controller inside SwiftUI.
///
/// The Dart side drives the size: the host must not constrain the view, it
/// only mirrors its intrinsic size into SwiftUI.
@available(iOS 26.0, *)
struct FlutterContentView: View {
    let engine: FlutterEngine
    /// Show a native spinner until the engine's first layout reports in.
    /// Off by default (matches CupertinoWidgetsSettings on the Dart side).
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

@available(iOS 26.0, *)
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

/// Hosts the FlutterViewController WITHOUT any external constraints — the
/// auto-resizable FlutterView installs its own (FlutterAutoResizeLayoutConstraint)
/// and publishes the Dart-chosen size through intrinsicContentSize/bounds.
@available(iOS 26.0, *)
final class FlutterHostViewController: UIViewController {
    private let flutterController: FlutterViewController
    private var lastReportedSize: CGSize = .zero
    private var boundsObservation: NSKeyValueObservation?
    private var displayObservation: NSKeyValueObservation?

    var onSizeChange: ((CGSize) -> Void)?
    var onFirstFrame: (() -> Void)?

    init(engine: FlutterEngine) {
        flutterController = FlutterViewController(engine: engine, nibName: nil, bundle: nil)
        flutterController.isViewOpaque = false
        flutterController.isAutoResizable = true
        super.init(nibName: nil, bundle: nil)
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        view.backgroundColor = .clear

        addChild(flutterController)
        view.addSubview(flutterController.view)
        flutterController.didMove(toParent: self)

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

    deinit {
        boundsObservation?.invalidate()
        displayObservation?.invalidate()
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()
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
