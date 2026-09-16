import Flutter
import SwiftUI
import UIKit

@available(iOS 26.0, *)
class NativeLiquidGlassFactory: NSObject, FlutterPlatformViewFactory {
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
        return NativeLiquidGlassView(
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

/// Platform view exposing the iOS 26 Liquid Glass material. Below iOS 26 it
/// renders an `ultraThinMaterial` approximation.
@available(iOS 26.0, *)
class NativeLiquidGlassView: NativeHostingView {
    private var channel: FlutterMethodChannel?
    /// Engine hosting the `route` body, when the container has one. Spawned
    /// from the scaffold's shared group so it costs a warm spawn, not a cold
    /// boot, and parked (not destroyed) if the same route comes back.
    private var bodyEngine: FlutterEngine?
    private var bodyRoute: String?
    private var lastConfig: GlassConfig?
    /// What the SwiftUI view observes. Owned here because the engine it
    /// carries is this view's to spawn and to park.
    private var model: GlassViewModel?
    /// Layout mode the hosting controller was attached with. A config change
    /// that does not cross this line only needs a new root view.
    private var attachedExpanded: Bool?

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        messenger: FlutterBinaryMessenger
    ) {
        super.init()
        _view.viewId = viewId

        channel = FlutterMethodChannel(
            name: "cupertino_widgets/liquid_glass_\(viewId)", binaryMessenger: messenger)
        sizeChannel = channel
        channel?.setMethodCallHandler({
            [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            self?.handle(call, result: result)
        })

        if let argsMap = args as? [String: Any],
            let config = decodeConfig(GlassConfig.self, from: argsMap)
        {
            setupSwiftUI(with: config)
        }
    }

    /// Attaches the glass. `expand` means the Flutter box, not a native icon,
    /// sizes the container.
    private func setupSwiftUI(with config: GlassConfig) {
        lastConfig = config
        // Appearance is owned by the hosting controller: the model-update path
        // below returns early, so the pin must happen before the branch.
        isDark = config.isDark
        let expanded = config.expand == true
        // Filling the box: nothing to measure.
        measuresIntrinsicSize = !expanded
        // The first engine boot is deferred to the next runloop turn, so the
        // page transition is not blocked by it.
        let engine = model == nil ? nil : engine(for: config)

        // Built once, then fed through an observable model: SwiftUI keeps the view
        // identity, so changes redraw minimally and can animate.
        if let model, attachedExpanded == expanded {
            model.update(config, engine: engine, animated: config.animated == true)
            return
        }

        let model = GlassViewModel(config: config, engine: engine)
        self.model = model
        if config.route != nil {
            DispatchQueue.main.async { [weak self] in
                guard let self, let model = self.model, let config = self.lastConfig else { return }
                model.update(config, engine: self.engine(for: config), animated: false)
            }
        }
        attachedExpanded = expanded
        let content = AnyView(
            AdaptiveLiquidGlassView(model: model) { [weak self] in
                self?.channel?.invokeMethod("pressed", arguments: nil)
            })

        guard !expanded else {
            attach(content)
            return
        }
        // No explicit size: the glass is measured like a button, hugging its
        // content, and `getIntrinsicSize` hands that back so Flutter can build
        // the box.
        attach(content) { host, container in
            host.setContentHuggingPriority(.required, for: .horizontal)
            host.setContentHuggingPriority(.required, for: .vertical)
            NSLayoutConstraint.activate([
                host.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                host.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                host.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor),
                host.heightAnchor.constraint(lessThanOrEqualTo: container.heightAnchor),
            ])
        }
    }

    /// The engine for `config.route`, spawned on first use and reused across
    /// updates. Registering this plugin on it is what lets the hosted body use
    /// package widgets of its own.
    private func engine(for config: GlassConfig) -> FlutterEngine? {
        guard let route = config.route else { return nil }
        if let bodyEngine, bodyRoute == route { return bodyEngine }
        if let bodyEngine, let bodyRoute {
            NativeScaffoldView.parkEngine(bodyEngine, route: bodyRoute)
        }
        let engine: FlutterEngine
        if let pooled = NativeScaffoldView.takePooledEngine(route: route) {
            // Already booted AND already registered — asking for a registrar a
            // second time is itself the failure ("Duplicate plugin key"), so
            // registration belongs only on the freshly spawned branch.
            engine = pooled
        } else {
            engine = NativeScaffoldView.sharedEngineGroup.makeEngine(
                withEntrypoint: nil, libraryURI: nil,
                initialRoute: "cn-scaffold://\(route)")
            // Register this plugin's platform-view factories on the spawned
            // engine so the hosted body can use package widgets of its own.
            // Asked only once per engine: `registrar(forPlugin:)` asserts on a
            // key it has already handed out, so the check is the guard, not
            // the result.
            if !engine.hasPlugin("FlutterCupertinoPlugin"),
                let registrar = engine.registrar(forPlugin: "FlutterCupertinoPlugin")
            {
                FlutterCupertinoPlugin.register(with: registrar)
            }
        }
        bodyEngine = engine
        bodyRoute = route
        return engine
    }

    deinit {
        // Park rather than drop: a glass container that scrolls out of a list
        // and back, or lives on a page that is pushed and popped, would
        // otherwise pay a full engine boot on every remount.
        if let bodyEngine, let bodyRoute {
            NativeScaffoldView.parkEngine(bodyEngine, route: bodyRoute)
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // A bitmap of this view, for Flutter to draw in its own layer tree.
        // See PlatformViewSnapshot.
        if call.method == "snapshot" {
            result(PlatformViewSnapshot.capture(view()))
            return
        }
        switch call.method {
        case "getIntrinsicSize":
            result(intrinsicSize())
        case "updateGlass":
            if let argsMap = call.arguments as? [String: Any],
                let config = decodeConfig(GlassConfig.self, from: argsMap)
            {
                setupSwiftUI(with: config)
                result(nil)
            } else {
                result(
                    FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

/// What the hosted SwiftUI view observes. Publishing configs keeps the view
/// identity stable.
@available(iOS 26.0, *)
final class GlassViewModel: ObservableObject {
    @Published private(set) var config: GlassConfig
    /// Engine rendering the `route` body, when there is one.
    @Published private(set) var engine: FlutterEngine?

    init(config: GlassConfig, engine: FlutterEngine?) {
        self.config = config
        self.engine = engine
    }

    /// Applies a new config, optionally as a spring transition. Identical
    /// configs are dropped: `@Published` fires on every set, animated or not.
    func update(_ config: GlassConfig, engine: FlutterEngine?, animated: Bool) {
        guard config != self.config || engine !== self.engine else { return }
        let apply = {
            self.config = config
            self.engine = engine
        }
        if animated {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75), apply)
        } else {
            apply()
        }
    }
}

@available(iOS 26.0, *)
struct AdaptiveLiquidGlassView: View {
    @ObservedObject var model: GlassViewModel
    let onPressed: () -> Void

    private var config: GlassConfig { model.config }
    private var expand: Bool { config.expand ?? false }
    private var tint: Color? { config.tint.map { Color(argb: $0) } }

    /// In filling mode, drawn only once the Flutter box has a real size, to avoid
    /// a flash of wrong geometry.
    var body: some View {
        if expand {
            GeometryReader { geometry in
                if geometry.size.width > 0, geometry.size.height > 0 {
                    glassBody
                }
            }
        } else {
            glassBody
        }
    }

    @ViewBuilder
    private var glassBody: some View {
        // Apple's order: content, padding, frame, then `glassEffect` last.
        GlassEffectContainer {
            glassSurface
                .simultaneousGesture(
                    TapGesture().onEnded { if config.pressable == true { onPressed() } })
        }
    }

    /// The glass and its content: the hosted Flutter view or the native icon,
    /// with `glassEffect` applied to it directly.
    @available(iOS 26.0, *)
    private var glassSurface: some View {
        content.glassEffect(glass, in: glassShape)
    }

    /// What the glass wraps: the hosted Flutter view, the native icon, or Apple's
    /// invisible placeholder so the glass has a shape and `.interactive()`
    /// something to track.
    @ViewBuilder
    private var base: some View {
        if let engine = model.engine {
            // No placeholder height: the glass must not take the screen's
            // height before Dart reports the content's size.
            FlutterContentView(engine: engine, placeholderHeight: 0)
        } else if let icon = config.icon {
            IconView(icon: icon)
        } else {
            Color.white.opacity(0.001)
        }
    }

    /// Inset, sized, ready for the material: the glass either fills the box
    /// Flutter built (`expand` — which is where an explicit width/height from
    /// the caller lands, since that box *is* that size) or hugs its content so
    /// `getIntrinsicSize` can measure it.
    @ViewBuilder
    private var content: some View {
        // Padding before the frame, so it insets the content instead of growing the
        // glass past the Flutter box.
        base
            .padding(insets)
            .applyGlassExpand(expand)
    }

    private var insets: EdgeInsets {
        EdgeInsets(
            top: CGFloat(config.paddingTop ?? 0),
            leading: CGFloat(config.paddingLeft ?? 0),
            bottom: CGFloat(config.paddingBottom ?? 0),
            trailing: CGFloat(config.paddingRight ?? 0))
    }

    private var cornerRadius: CGFloat { CGFloat(config.cornerRadius ?? 26) }

    @available(iOS 26.0, *)
    private var glass: Glass {
        var glass: Glass = config.variant == "clear" ? .clear : .regular
        if let tint { glass = glass.tint(tint) }
        if config.interactive == true { glass = glass.interactive() }
        return glass
    }

    @available(iOS 26.0, *)
    private var glassShape: AnyShape {
        switch config.shape {
        case "capsule":
            return AnyShape(Capsule())
        case "circle":
            return AnyShape(Circle())
        default:
            return AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

@available(iOS 26.0, *)
extension View {
    /// Fills the box Flutter built, in both axes — which is where an explicit
    /// width/height from the caller ends up. Left alone otherwise, so an
    /// icon-only container keeps the size SwiftUI measures it at and reports
    /// that back to Flutter.
    @ViewBuilder
    func applyGlassExpand(_ expand: Bool) -> some View {
        if expand {
            self.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            self
        }
    }
}
