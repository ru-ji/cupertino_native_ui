import Combine
import Flutter
import SwiftUI
import UIKit

@available(iOS 26.0, *)
class NativeScaffoldFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return NativeScaffoldView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            messenger: messenger
        )
    }

    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

/// One entry in a scaffold NavigationStack path. `id` is unique per push so
/// the same route can be pushed twice and each instance keeps its own engine.
@available(iOS 26.0, *)
struct PushedRoute: Hashable {
    let id: UUID
    let route: String
    let appBar: AppBarConfig?
}

/// Observable state shared between the platform view (which mutates it from
/// method-channel calls) and the SwiftUI ScaffoldView (which binds to it).
@available(iOS 26.0, *)
class ScaffoldModel: ObservableObject {
    @Published var config: ScaffoldConfig
    @Published var selection: String {
        didSet {
            if oldValue != selection { onSelectionChanged?(selection) }
        }
    }
    @Published var paths: [String: [PushedRoute]] = [:] {
        didSet { onPathsChanged?(oldValue, paths) }
    }
    /// Live text of each searchable page's `.searchable` field, keyed by root route.
    @Published var searchTexts: [String: String] = [:]

    // Engine storage lives here so SwiftUI can look bodies up during builds.
    // @Published so bodies re-render when an engine is spawned after the
    // first frame (engine creation is deferred off the init path).
    @Published var rootEngines: [String: FlutterEngine] = [:]
    @Published var pushedEngines: [UUID: FlutterEngine] = [:]

    /// The SwiftUI-rendered body's live state, when `config.nativeBody` is
    /// set. Held here so the tree survives config pushes.
    let bodyModel = NativeBodyModel()

    /// (nodeId, value) from a native body's controls.
    var onBodyEvent: ((String, Any?) -> Void)?

    var onSelectionChanged: ((String) -> Void)?
    var onPathsChanged: (([String: [PushedRoute]], [String: [PushedRoute]]) -> Void)?
    var onSearchChanged: ((String, String) -> Void)?
    var onSearchActiveChanged: ((String, Bool) -> Void)?
    var onSearchSubmitted: ((String, String) -> Void)?

    /// Publishes a searchable field's new text (only on real edits) and
    /// reports the keystroke via `onSearchChanged`.
    func setSearchText(_ text: String, for key: String) {
        if searchTexts[key] != text {
            searchTexts[key] = text
            onSearchChanged?(key, text)
        }
    }

    init(config: ScaffoldConfig) {
        self.config = config
        bodyModel.root = config.nativeBody
        bodyModel.seed(config.nativeBody)
        self.selection = config.tabBar?.selection ?? config.tabBar?.tabs.first?.id ?? ""
        // Seed every stack key up front so NavigationStack's initial binding
        // sync doesn't structurally change the dictionary (which would
        // publish a change on every view update).
        if let tabBar = config.tabBar {
            for tab in tabBar.tabs { paths[tab.id] = [] }
        } else if let body = config.body {
            paths[body] = []
        }
    }
}

@available(iOS 26.0, *)
class NativeScaffoldView: NativeHostingView {
    /// One engine group shared by every scaffold instance. Engines spawned
    /// from the same group share the GPU context, font caches and isolate
    /// snapshot, so every spawn after the first is drastically cheaper —
    /// per-instance groups would pay the full cold start on each scaffold.
    static let sharedEngineGroup = FlutterEngineGroup(
        name: "cupertino_widgets_scaffold", project: nil)

    /// Hidden idle engine that keeps `sharedEngineGroup` warm.
    private static var warmupEngine: FlutterEngine?

    /// Engines fully booted ahead of time for specific routes — main() has
    /// run, the route's Dart libraries are loaded, runApp has been called.
    /// A scaffold/sheet that needs one of these routes attaches instantly
    /// instead of spawning.
    private static var pooledEngines: [String: FlutterEngine] = [:]

    /// Pays engine start-up costs ahead of time
    /// (Dart: `CupertinoNativePageScaffold.prewarm(routes:)`). With routes, one
    /// engine per route is fully booted and parked.
    static func prewarm(routes: [String] = [], isDark: Bool = false) {
        if routes.isEmpty {
            guard warmupEngine == nil else { return }
            warmupEngine = sharedEngineGroup.makeEngine(
                withEntrypoint: nil, libraryURI: nil,
                initialRoute: "cn-scaffold://_warmup")
            return
        }
        for route in routes where pooledEngines[route] == nil {
            let engine = sharedEngineGroup.makeEngine(
                withEntrypoint: nil, libraryURI: nil,
                initialRoute: "cn-scaffold://\(route)?dark=\(isDark ? 1 : 0)")
            if !engine.hasPlugin("FlutterCupertinoPlugin"),
                let registrar = engine.registrar(forPlugin: "FlutterCupertinoPlugin")
            {
                FlutterCupertinoPlugin.register(with: registrar)
            }
            pooledEngines[route] = engine
        }
    }

    /// Hands over a prewarmed engine for `route`, if one is parked.
    static func takePooledEngine(route: String) -> FlutterEngine? {
        return pooledEngines.removeValue(forKey: route)
    }

    /// Parks a detached engine back in the pool, so the next view on the same
    /// route re-attaches it instead of paying a fresh Dart boot. Dropped on
    /// the floor if that route is already parked — one parked engine per
    /// route, not one per view that ever existed.
    static func parkEngine(_ engine: FlutterEngine, route: String) {
        engine.viewController = nil
        guard pooledEngines[route] == nil else { return }
        pooledEngines[route] = engine
    }

    deinit {
        // Park root bodies back in the shared pool, so reopening the same route
        // re-attaches the running engine instead of booting a new one.
        for (route, engine) in model.rootEngines {
            engine.viewController = nil
            if Self.pooledEngines[route] == nil {
                Self.pooledEngines[route] = engine
            }
        }
        // Pushed detail pages are per-instance (the same route can be pushed
        // twice with independent state); they die with the scaffold.
        for engine in model.pushedEngines.values {
            engine.viewController = nil
        }
    }

    private let channel: FlutterMethodChannel
    private let model: ScaffoldModel
    private var bodyChannels: [String: FlutterMethodChannel] = [:]
    /// Last known (query, active) per searchable route, so each forwarded
    /// snapshot to the body engine carries the full current state.
    private var searchSnapshots: [String: (query: String, active: Bool)] = [:]
    /// The app's current brightness, seeded into each body engine's route so
    /// its Flutter content matches the app. Updated by `setBrightness`.
    private var currentIsDark: Bool = false
    private var selectionCancellable: AnyCancellable?

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        messenger: FlutterBinaryMessenger
    ) {
        channel = FlutterMethodChannel(
            name: "cupertino_widgets/scaffold_\(viewId)", binaryMessenger: messenger)

        if let argsMap = args as? [String: Any],
            let config = decodeConfig(ScaffoldConfig.self, from: argsMap)
        {
            model = ScaffoldModel(config: config)
        } else {
            model = ScaffoldModel(
                config: ScaffoldConfig(
                    body: nil, nativeBody: nil, appBar: nil, tabBar: nil,
                    scrollEdgeEffect: nil, isDark: nil,
                    backgroundColor: nil, primaryColor: nil,
                    showLoadingIndicator: nil))
        }

        super.init()
        _view.backgroundColor = .clear
        // Before attach: the NavigationStack's large title takes its inset from
        // the parent's system margins, so never let it go unparented while the
        // engine briefly takes the view out of the window.
        _view.keepsParentWhileDetached = true
        // Before the navigation bar ever lays out with zero margins — see
        // pinNavigationMargins. Dart also asks once each route slide settles.
        _view.onLayout = { [weak self] in self?.pinNavigationMargins(layout: false) }
        _view.onParentingChanged = { [weak self] in
            guard let self, self.hostingController?.parent != nil else { return }
            self.watchForNavigationBar()
        }

        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
        model.onSelectionChanged = { [weak self] selection in
            self?.channel.invokeMethod("onTabChanged", arguments: ["selection": selection])
        }
        model.onPathsChanged = { [weak self] old, new in
            self?.pathsDidChange(old: old, new: new)
        }
        model.onSearchChanged = { [weak self] route, query in
            self?.reportSearch(route: route, query: query, active: nil, submitted: false)
        }
        model.onSearchActiveChanged = { [weak self] route, active in
            self?.reportSearch(route: route, query: nil, active: active, submitted: false)
        }
        model.onSearchSubmitted = { [weak self] route, query in
            self?.reportSearch(route: route, query: query, active: nil, submitted: true)
        }
        model.onBodyEvent = { [weak self] id, value in
            self?.channel.invokeMethod(
                "onBodyEvent", arguments: ["id": id, "value": value])
        }

        attachContent()

        // Lazily create engines when the user switches tabs — the new
        // tab's engine is spun up on demand so init only blocks on one.
        selectionCancellable = model.$selection
            .removeDuplicates()
            .sink { [weak self] route in
                self?.ensureEngine(for: route)
            }

        // Apply Flutter's brightness to the hosting controller's view so
        // SwiftUI matches the Flutter theme (not the device's default).
        // MUST happen after attachContent() which creates hostingController.
        if let argsMap = args as? [String: Any],
            let isDark = (argsMap["isDark"] as? NSNumber)?.boolValue
        {
            // Seed brightness BEFORE createRootEngines() so each body engine's
            // route carries it (?dark=) and its content matches the app.
            currentIsDark = isDark
            hostingController?.overrideUserInterfaceStyle = isDark ? .dark : .light
        }
        // Apply Flutter theme colors (background, tint).
        if let argsMap = args as? [String: Any] {
            if let bg = (argsMap["backgroundColor"] as? NSNumber)?.intValue {
                // The scaffold IS the page, so it keeps the background the
                // embedded controls have theirs stripped for.
                (hostingController as? ClearHostingController<AnyView>)?
                    .forcesClearBackground = false
                hostingController?.view.backgroundColor = UIColor(argb: bg)
            }
            if let tint = (argsMap["primaryColor"] as? NSNumber)?.intValue {
                hostingController?.view.tintColor = UIColor(argb: tint)
            }
        }

        // Spawn the first body engine on the next runloop turn: platform-view
        // creation returns immediately so the push transition animates
        // jank-free, and by now `currentIsDark` is seeded so the engine's
        // route carries the right brightness.
        // A native body has no engine to spawn: the body IS the SwiftUI tree.
        if model.config.nativeBody == nil {
            DispatchQueue.main.async { [weak self] in
                self?.createRootEngines()
            }
        }
    }

    /// Pins the native navigation controller's layout margins to the window's.
    /// UIKit grants system minimum margins only to a view exactly at the screen
    /// edge; after a Flutter route slide this one sits at a fractional x or off
    /// screen and would get zero. `layout`: false inside a layout pass.
    @discardableResult
    private func pinNavigationMargins(layout: Bool) -> Bool {
        guard let root = hostingController?.view, let window = _view.window else { return false }
        var found = false
        let windowMin = window.rootViewController?.systemMinimumLayoutMargins
        let side = max(windowMin?.leading ?? 0, windowMin?.trailing ?? 0, 16)
        let margins = NSDirectionalEdgeInsets(top: 0, leading: side, bottom: 0, trailing: side)
        func visit(_ view: UIView, _ depth: Int) {
            guard depth < 40 else { return }
            for subview in view.subviews {
                if let bar = subview as? UINavigationBar,
                    let nav = bar.delegate as? UINavigationController
                {
                    found = true
                    if nav.viewRespectsSystemMinimumLayoutMargins
                        || nav.view.directionalLayoutMargins != margins
                    {
                        nav.viewRespectsSystemMinimumLayoutMargins = false
                        nav.view.directionalLayoutMargins = margins
                        nav.view.setNeedsLayout()
                        bar.setNeedsLayout()
                        if layout {
                            nav.view.layoutIfNeeded()
                            bar.layoutIfNeeded()
                        }
                    }
                } else {
                    visit(subview, depth + 1)
                }
            }
        }
        visit(root, 0)
        return found
    }

    /// Polls for the navigation bar right after parenting. SwiftUI creates it
    /// in a layout pass of its own — while the route still slides in, off
    /// screen — and no layout pass of ours follows, so `onLayout` alone pins it
    /// only after it was seen flush. Stops once pinned, or after 2s.
    private var marginLink: CADisplayLink?
    private var marginLinkStart: CFTimeInterval = 0

    private func watchForNavigationBar() {
        marginLink?.invalidate()
        marginLinkStart = CACurrentMediaTime()
        let link = CADisplayLink(target: self, selector: #selector(marginTick))
        link.add(to: .main, forMode: .common)
        marginLink = link
    }

    @objc private func marginTick() {
        if pinNavigationMargins(layout: true) || CACurrentMediaTime() - marginLinkStart > 2 {
            marginLink?.invalidate()
            marginLink = nil
        }
    }

    // MARK: - Engines

    /// Creates only the engine for the currently active tab (or the single
    /// body route when there's no tab bar). Other engines are created on
    /// demand via `ensureEngine(for:)` when the user switches tabs, which
    /// keeps the init-time main-thread blocking to a single engine.
    private func createRootEngines() {
        let activeRoute: String?
        if let tabBar = model.config.tabBar {
            activeRoute = model.selection
        } else {
            activeRoute = model.config.body
        }
        if let route = activeRoute, !route.isEmpty {
            model.rootEngines[route] = makeEngine(route: route, key: route)
        }
    }

    /// Creates the engine for `route` if it doesn't already exist. Called
    /// when the user switches tabs so inactive tabs don't pay the startup
    /// cost at init.
    private func ensureEngine(for route: String) {
        guard model.rootEngines[route] == nil else { return }
        model.rootEngines[route] = makeEngine(route: route, key: route)
    }

    private func makeEngine(route: String, key: String) -> FlutterEngine {
        let engine: FlutterEngine
        if let pooled = Self.takePooledEngine(route: route) {
            // Prewarmed for this exact route: already booted and registered.
            engine = pooled
        } else {
            // `?dark=` seeds the body's brightness for its very first frame;
            // later changes stream through the scaffold_body channel.
            engine = Self.sharedEngineGroup.makeEngine(
                withEntrypoint: nil, libraryURI: nil,
                initialRoute: "cn-scaffold://\(route)?dark=\(currentIsDark ? 1 : 0)")
            // Register this plugin's platform-view factories on the spawned
            // engine so package widgets (buttons, toggles, ...) work inside
            // scaffold bodies too. Guarded: a pooled engine already carries
            // the plugin, and `registrar(forPlugin:)` asserts on a duplicate
            // key rather than returning nil.
            if !engine.hasPlugin("FlutterCupertinoPlugin"),
                let registrar = engine.registrar(forPlugin: "FlutterCupertinoPlugin")
            {
                FlutterCupertinoPlugin.register(with: registrar)
            }
        }
        // Well-known channel so body isolates can drive navigation
        // (`CupertinoNativePageScaffold.push`/`pop` on the Dart side).
        let bodyChannel = FlutterMethodChannel(
            name: "cupertino_widgets/scaffold_body", binaryMessenger: engine.binaryMessenger)
        bodyChannel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
        bodyChannels[key] = bodyChannel
        return engine
    }

    /// Keyboard avoidance follows `resizeToAvoidBottomInset`; the container
    /// safe area (bars, home indicator) always applies.
    private func applyKeyboardAvoidance() {
        guard let host = hostingController else { return }
        host.safeAreaRegions =
            (model.config.resizeToAvoidBottomInset ?? true) ? .all : .container
    }

    private func attachContent() {
        attach(
            AnyView(
                ScaffoldView(model: model) { [weak self] route, actionId in
                    self?.channel.invokeMethod(
                        "onBarAction", arguments: ["route": route, "id": actionId])
                }),
            keyboardAvoidance: true)
        applyKeyboardAvoidance()
    }

    // MARK: - Navigation

    /// Key into `model.paths` for the stack the user is currently looking at.
    private var currentPathKey: String {
        if model.config.tabBar != nil { return model.selection }
        return model.config.body ?? ""
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "refreshLayoutMargins":
            // Sent by Dart when a route slide settles. A navigation stack laid
            // out mid-slide (off screen) got zero system margins and keeps them
            // until the next scroll: the large title sits flush with the edge.
            pinNavigationMargins(layout: true)
            result(nil)
        case "push":
            guard let args = call.arguments as? [String: Any],
                let route = args["route"] as? String
            else {
                result(
                    FlutterError(
                        code: "INVALID_ARGS", message: "push requires a route", details: nil))
                return
            }
            var appBar: AppBarConfig? = nil
            if let appBarMap = args["appBar"] as? [String: Any] {
                appBar = decodeConfig(AppBarConfig.self, from: appBarMap)
            }
            let pushed = PushedRoute(id: UUID(), route: route, appBar: appBar)
            model.pushedEngines[pushed.id] = makeEngine(
                route: route, key: pushed.id.uuidString)
            model.paths[currentPathKey, default: []].append(pushed)
            result(nil)
        case "pop":
            if !(model.paths[currentPathKey] ?? []).isEmpty {
                model.paths[currentPathKey]?.removeLast()
            }
            result(nil)
        case "setTitle":
            if let args = call.arguments as? [String: Any],
                let title = args["title"] as? String,
                let bar = model.config.appBar
            {
                model.config = ScaffoldConfig(
                    body: model.config.body,
                    nativeBody: model.config.nativeBody,
                    appBar: AppBarConfig(
                        title: title, subtitle: bar.subtitle,
                        displayMode: bar.displayMode,
                        leading: bar.leading, trailing: bar.trailing,
                        bottom: bar.bottom, search: bar.search),
                    tabBar: model.config.tabBar,
                    scrollEdgeEffect: model.config.scrollEdgeEffect,
                    isDark: model.config.isDark,
                    backgroundColor: model.config.backgroundColor,
                    primaryColor: model.config.primaryColor,
                    showLoadingIndicator: model.config.showLoadingIndicator,
                    // Carried through explicitly: it has a default, so a
                    // rebuild that forgets it silently resets the page.
                    resizeToAvoidBottomInset: model.config.resizeToAvoidBottomInset)
            }
            result(nil)
        case "updateScaffold":
            if let argsMap = call.arguments as? [String: Any],
                let config = decodeConfig(ScaffoldConfig.self, from: argsMap)
            {
                // Bars/tabs update in place; engines are kept as-is.
                model.config = config
                // Outside any view update, so pushing field configs here is
                // safe (see NativeBodyModel.applyConfigs).
                model.bodyModel.root = config.nativeBody
                model.bodyModel.seed(config.nativeBody)
                model.bodyModel.applyConfigs(config.nativeBody)
                applyKeyboardAvoidance()
                // Seed stack keys for any newly added tabs.
                if let tabBar = config.tabBar {
                    for tab in tabBar.tabs where model.paths[tab.id] == nil {
                        model.paths[tab.id] = []
                    }
                }
                if let selection = config.tabBar?.selection, selection != model.selection {
                    model.selection = selection
                }
                // Apply updated theme colors.
                if let bg = config.backgroundColor {
                    (hostingController as? ClearHostingController<AnyView>)?
                        .forcesClearBackground = false
                    hostingController?.view.backgroundColor = UIColor(argb: bg)
                }
                if let tint = config.primaryColor {
                    hostingController?.view.tintColor = UIColor(argb: tint)
                }
            }
            result(nil)
        case "publishBodyState":
            // Host → every body isolate. They share no memory, so shared
            // state travels as data or not at all.
            for channel in bodyChannels.values {
                channel.invokeMethod("onHostState", arguments: call.arguments)
            }
            result(nil)
        case "sendBodyAction":
            // Body → host. Arrives on the body's own channel, goes out on the
            // scaffold's.
            channel.invokeMethod("onBodyAction", arguments: call.arguments)
            result(nil)
        case "getBrightness":
            // Bodies pull the app brightness on startup (race-free: this
            // handler is installed when the engine is created).
            result(currentIsDark)
        case "setBrightness":
            if let args = call.arguments as? [String: Any],
                let isDark = (args["isDark"] as? NSNumber)?.boolValue
            {
                currentIsDark = isDark
                hostingController?.overrideUserInterfaceStyle = isDark ? .dark : .light
                // Forward into every body engine so its Flutter content matches
                // the app's brightness (they run without the app's MaterialApp).
                for channel in bodyChannels.values {
                    channel.invokeMethod("setBrightness", arguments: ["isDark": isDark])
                }
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing isDark", details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    private func pathsDidChange(old: [String: [PushedRoute]], new: [String: [PushedRoute]]) {
        let oldIds = Set(old.values.flatMap { $0 }.map { $0.id })
        let newIds = Set(new.values.flatMap { $0 }.map { $0.id })

        for removed in oldIds.subtracting(newIds) {
            bodyChannels.removeValue(forKey: removed.uuidString)
            guard let engine = model.pushedEngines.removeValue(forKey: removed) else { continue }
            // Keep the engine alive until the pop transition finishes so the
            // outgoing page stays rendered mid-animation.
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                engine.destroyContext()
            }
        }

        let key = currentPathKey
        let routes = [key] + (new[key] ?? []).map { $0.route }
        channel.invokeMethod("onRouteChanged", arguments: ["routes": routes])
    }

    // MARK: - Search

    /// Reports a search event to the host isolate (the widget that created the
    /// scaffold) and forwards the full current state into the searchable page's
    /// body engine so it can render suggestions/results/loader.
    private func reportSearch(route: String, query: String?, active: Bool?, submitted: Bool) {
        var snap = searchSnapshots[route] ?? (query: "", active: false)
        if let query = query { snap.query = query }
        if let active = active { snap.active = active }
        searchSnapshots[route] = snap

        if let query = query {
            channel.invokeMethod(
                submitted ? "onSearchSubmitted" : "onSearchChanged",
                arguments: ["route": route, "query": query])
        }
        if let active = active {
            channel.invokeMethod(
                "onSearchActiveChanged", arguments: ["route": route, "active": active])
        }

        bodyChannels[route]?.invokeMethod(
            "onScaffoldSearch",
            arguments: [
                "query": snap.query,
                "isActive": snap.active,
                "isSubmitted": submitted,
            ])
    }
}
