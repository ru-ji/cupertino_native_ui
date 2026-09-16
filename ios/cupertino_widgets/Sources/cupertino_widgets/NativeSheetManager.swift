import Flutter
import SwiftUI
import UIKit

/// Presents a Flutter-rendered page as a native iOS sheet
/// (`UISheetPresentationController`) — the standard page-sheet modal that
/// pushes the presenting screen back as it rises, with system detents, the
/// grabber, and the swipe-to-dismiss gesture.
@available(iOS 26.0, *)
final class NativeSheetManager: NSObject, UIAdaptivePresentationControllerDelegate,
    UIPopoverPresentationControllerDelegate
{
    static let shared = NativeSheetManager()

    /// Main-app messenger, seeded at plugin registration; carries sheet
    /// events (bar actions, segment changes, search) back to Dart.
    var mainMessenger: FlutterBinaryMessenger?
    private var eventsChannel: FlutterMethodChannel?

    private var engine: FlutterEngine?
    private var controller: UIViewController?
    /// Completes the Dart `show()` future when the sheet is fully dismissed.
    private var showResult: FlutterResult?

    func show(args: [String: Any], result: @escaping FlutterResult) {
        guard controller == nil else {
            result(
                FlutterError(
                    code: "SHEET_ALREADY_PRESENTED",
                    message: "A CupertinoNativeSheet is already presented",
                    details: nil))
            return
        }
        guard let route = args["route"] as? String, !route.isEmpty else {
            result(
                FlutterError(
                    code: "INVALID_ARGS", message: "Missing 'route'", details: nil))
            return
        }
        guard let presenter = Self.topViewController() else {
            result(
                FlutterError(
                    code: "NO_PRESENTER",
                    message: "No view controller available to present from",
                    details: nil))
            return
        }
        if eventsChannel == nil, let messenger = mainMessenger {
            eventsChannel = FlutterMethodChannel(
                name: "cupertino_widgets/sheet_events", binaryMessenger: messenger)
        }

        let isDark = args["isDark"] as? Bool ?? false
        let engine: FlutterEngine
        if let pooled = NativeScaffoldView.takePooledEngine(route: route) {
            // Route was prewarmed: attach the already-booted engine.
            engine = pooled
        } else {
            engine = NativeScaffoldView.sharedEngineGroup.makeEngine(
                withEntrypoint: nil, libraryURI: nil,
                initialRoute: "cn-scaffold://\(route)?dark=\(isDark ? 1 : 0)")
            if !engine.hasPlugin("FlutterCupertinoPlugin"),
                let registrar = engine.registrar(forPlugin: "FlutterCupertinoPlugin")
            {
                FlutterCupertinoPlugin.register(with: registrar)
            }
        }
        // Same well-known channel as scaffold bodies, so
        // `CupertinoNativeSheet.pop()` works from inside the sheet.
        let bodyChannel = FlutterMethodChannel(
            name: "cupertino_widgets/scaffold_body", binaryMessenger: engine.binaryMessenger)
        bodyChannel.setMethodCallHandler { [weak self] call, res in
            switch call.method {
            case "pop":
                self?.dismiss(result: nil)
                res(nil)
            case "getBrightness":
                res(isDark)
            default:
                res(FlutterMethodNotImplemented)
            }
        }
        // A pooled engine booted, and pulled its brightness, long before this
        // sheet: push the app's current one so the body matches the sheet.
        bodyChannel.invokeMethod("setBrightness", arguments: ["isDark": isDark])

        let appBar = (args["appBar"] as? [String: Any]).flatMap {
            decodeConfig(AppBarConfig.self, from: $0)
        }
        let segments = args["bottomSegments"] as? [String]
        let initialSegment = args["bottomSelectedIndex"] as? Int ?? 0
        let scrollEdgeEffect = args["scrollEdgeEffect"] as? String
        let showLoadingIndicator = args["showLoadingIndicator"] as? Bool ?? false
        let backgroundArgb = args["backgroundColor"] as? Int

        let presented: UIViewController
        if appBar != nil || segments != nil {
            // Native chrome: pinned nav bar + native ScrollView over Flutter.
            let root = SheetRootView(
                engine: engine,
                appBar: appBar,
                segments: segments,
                initialSegment: initialSegment,
                scrollEdgeEffect: scrollEdgeEffect,
                showLoadingIndicator: showLoadingIndicator,
                backgroundColor: backgroundArgb,
                onBarAction: { [weak self] id in
                    self?.eventsChannel?.invokeMethod("barAction", arguments: id)
                },
                onSegment: { [weak self] index in
                    self?.eventsChannel?.invokeMethod("segmentChanged", arguments: index)
                },
                onSearchChanged: { [weak self] query in
                    self?.eventsChannel?.invokeMethod("searchChanged", arguments: query)
                },
                onSearchSubmitted: { [weak self] query in
                    self?.eventsChannel?.invokeMethod("searchSubmitted", arguments: query)
                }
            )
            presented = UIHostingController(rootView: root)
        } else {
            // Bare sheet: no chrome, but the body still rides a native
            // ScrollView — self-sized Columns scroll instead of
            // overflowing, and pull-down-at-top drags the sheet.
            presented = UIHostingController(
                rootView: PageScrollBody(
                    engine: engine,
                    scrollEdgeEffect: scrollEdgeEffect,
                    showLoadingIndicator: showLoadingIndicator))
        }

        presented.overrideUserInterfaceStyle = isDark ? .dark : .light
        // Unify the chrome background with the Flutter body's — otherwise the
        // hosting controller's default systemBackground shows as a distinct
        // band in the bar / safe-area regions the body doesn't paint.
        if let bg = args["backgroundColor"] as? Int {
            presented.view.backgroundColor = UIColor(argb: bg)
        }
        // A popover is the same engine and the same chrome, presented
        // pointing at a control instead of rising from the bottom. On iPhone
        // UIKit adapts it back to a sheet unless told not to.
        if let anchor = args["sourceRect"] as? [String: Any],
            let x = anchor["x"] as? Double, let y = anchor["y"] as? Double,
            let w = anchor["width"] as? Double, let h = anchor["height"] as? Double
        {
            presented.modalPresentationStyle = .popover
            if let size = args["preferredSize"] as? [String: Any],
                let pw = size["width"] as? Double, let ph = size["height"] as? Double
            {
                presented.preferredContentSize = CGSize(width: pw, height: ph)
            }
            if let popover = presented.popoverPresentationController {
                popover.sourceView = presenter.view
                popover.sourceRect = CGRect(x: x, y: y, width: w, height: h)
                popover.delegate = self
            }
            presented.presentationController?.delegate = self
            self.engine = engine
            self.controller = presented
            self.showResult = result
            presenter.present(presented, animated: true)
            return
        }

        presented.modalPresentationStyle = .pageSheet
        if let sheet = presented.sheetPresentationController {
            var detents: [UISheetPresentationController.Detent] = []
            for name in (args["detents"] as? [String]) ?? [] {
                switch name {
                case "medium": detents.append(.medium())
                default: detents.append(.large())
                }
            }
            sheet.detents = detents.isEmpty ? [.large()] : detents
            sheet.prefersGrabberVisible = args["showGrabber"] as? Bool ?? false
            if let radius = args["cornerRadius"] as? Double {
                sheet.preferredCornerRadius = CGFloat(radius)
            }
            // Let the sheet's inner ScrollView drive detent expansion the
            // system way (scroll up expands medium → large).
            sheet.prefersScrollingExpandsWhenScrolledToEdge = true
        }
        presented.presentationController?.delegate = self

        self.engine = engine
        self.controller = presented
        self.showResult = result
        presenter.present(presented, animated: true)
    }

    /// Programmatic dismissal (Dart `dismiss()` / body `pop()`).
    func dismiss(result: FlutterResult?) {
        guard let controller else {
            result?(nil)
            return
        }
        controller.dismiss(animated: true) { [weak self] in
            self?.finish()
            result?(nil)
        }
    }

    /// Swipe-to-dismiss.
    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        finish()
    }

    /// Keep a popover a popover on iPhone. Without this UIKit adapts it to a
    /// full-screen sheet in a compact size class, which is the thing the
    /// caller asked not to have.
    func adaptivePresentationStyle(
        for controller: UIPresentationController, traitCollection: UITraitCollection
    ) -> UIModalPresentationStyle {
        return .none
    }

    private func finish() {
        showResult?(nil)
        showResult = nil
        controller = nil
        // Releasing the engine shuts down the sheet's isolate.
        engine = nil
    }

    /// The controller currently on top of the key window's presented chain.
    static func topViewController() -> UIViewController? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController
        var top = root
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top
    }
}

/// The sheet's native chrome: NavigationStack with the scaffold's app-bar
/// toolbar, optional searchable field, optional segmented control pinned
/// under the bar, and the Flutter body in a native ScrollView.
@available(iOS 26.0, *)
struct SheetRootView: View {
    let engine: FlutterEngine
    let appBar: AppBarConfig?
    let segments: [String]?
    let initialSegment: Int
    let scrollEdgeEffect: String?
    let showLoadingIndicator: Bool
    /// Sheet background (ARGB), re-applied inside the NavigationStack, which
    /// draws its own opaque background.
    let backgroundColor: Int?
    let onBarAction: (String) -> Void
    let onSegment: (Int) -> Void
    let onSearchChanged: (String) -> Void
    let onSearchSubmitted: (String) -> Void

    @State private var searchText = ""
    @State private var segment: Int

    init(
        engine: FlutterEngine,
        appBar: AppBarConfig?,
        segments: [String]?,
        initialSegment: Int,
        scrollEdgeEffect: String?,
        showLoadingIndicator: Bool,
        backgroundColor: Int?,
        onBarAction: @escaping (String) -> Void,
        onSegment: @escaping (Int) -> Void,
        onSearchChanged: @escaping (String) -> Void,
        onSearchSubmitted: @escaping (String) -> Void
    ) {
        self.engine = engine
        self.appBar = appBar
        self.segments = segments
        self.initialSegment = initialSegment
        self.scrollEdgeEffect = scrollEdgeEffect
        self.showLoadingIndicator = showLoadingIndicator
        self.backgroundColor = backgroundColor
        self.onBarAction = onBarAction
        self.onSegment = onSegment
        self.onSearchChanged = onSearchChanged
        self.onSearchSubmitted = onSearchSubmitted
        _segment = State(initialValue: initialSegment)
    }

    var body: some View {
        NavigationStack {
            PageScrollBody(
                engine: engine,
                scrollEdgeEffect: scrollEdgeEffect,
                showLoadingIndicator: showLoadingIndicator
            )
            .safeAreaInset(edge: .top, spacing: 0) { segmentedBar }
            .applyAppBar(appBar, onAction: onBarAction)
            // No bar background band: the bar items float on the sheet
            // and the scroll-edge effect keeps them legible on scroll.
            .toolbarBackground(.hidden, for: .navigationBar)
            .applySearchable(appBar?.search, text: $searchText) {
                onSearchSubmitted(searchText)
            }
            .onChange(of: searchText) { onSearchChanged($0) }
            .background(sheetBackground)
        }
    }

    /// The Dart-provided background, under the bar and safe areas too, so
    /// the chrome matches the Flutter body exactly.
    @ViewBuilder
    private var sheetBackground: some View {
        if let backgroundColor = backgroundColor {
            Color(argb: backgroundColor).ignoresSafeArea()
        } else {
            Color.clear
        }
    }

    @ViewBuilder
    private var segmentedBar: some View {
        if let segments, !segments.isEmpty {
            Picker("", selection: $segment) {
                ForEach(Array(segments.enumerated()), id: \.offset) { index, title in
                    Text(title).tag(index)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .onChange(of: segment) { onSegment($0) }
        }
    }
}
