import Flutter
import SwiftUI
import UIKit

@available(iOS 15.0, *)
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

/// Platform view exposing the iOS 26 Liquid Glass material as a backdrop that
/// Flutter content is composited on top of. On iOS 15–25 it renders an
/// `ultraThinMaterial` approximation so layouts don't break, but the real
/// refractive effect is 26-only (see `isLiquidGlassSupported` on the plugin
/// channel for feature-gating from Dart).
@available(iOS 15.0, *)
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
        // So Dart can exempt this view from an edge effect's mask (bar chrome
        // is painted over the effect, not under it).
        _view.viewId = viewId

        channel = FlutterMethodChannel(
            name: "cupertino_widgets/liquid_glass_\(viewId)", binaryMessenger: messenger)
        // Push measurements instead of waiting to be polled.
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

    /// Attaches the glass the way `NativeButtonView` attaches the button, and
    /// on the same flag.
    ///
    /// `expand` is what Dart sends when a Flutter child or an explicit size —
    /// not a native icon — is what gives this container its size. The button
    /// hugs its content because SwiftUI can see that content and measure it; a
    /// glass container's content is the Flutter child composited on top, which
    /// the native side never sees.
    private func setupSwiftUI(with config: GlassConfig) {
        lastConfig = config
        let expanded = config.expand == true
        // Filling the box: nothing here has a size of its own to report, and
        // measuring anyway produced the 10x10 that a glass circle was briefly
        // sized to.
        measuresIntrinsicSize = !expanded
        let engine = engine(for: config)

        // The SwiftUI view is built ONCE and fed by an observable model from
        // then on. Rebuilding the root view — never mind re-attaching, which
        // tears down the UIHostingController — throws away the view identity
        // SwiftUI needs to diff and to animate: a tint change would snap, and
        // a hosted engine's view would be pulled out of the hierarchy and put
        // back. Publishing the config instead lets SwiftUI redraw only what
        // moved, and `withAnimation` gives CoreAnimation the transition for
        // free.
        if let model, attachedExpanded == expanded {
            model.update(config, engine: engine, animated: config.animated == true)
            return
        }

        let model = GlassViewModel(config: config, engine: engine)
        self.model = model
        attachedExpanded = expanded
        let content = AnyView(
            AdaptiveLiquidGlassView(model: model) { [weak self] in
                self?.channel?.invokeMethod("pressed", arguments: nil)
            })

        // `expand` is what Dart sends when an explicit size — not a native
        // icon — gives this container its size: fill the box Flutter built.
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


/// What the hosted SwiftUI view observes.
///
/// Config arrives from Dart as a value; publishing it — rather than rebuilding
/// the view around a new one — is what keeps SwiftUI's view identity stable,
/// which is the precondition for both minimal redraws and animated
/// transitions.
@available(iOS 15.0, *)
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

@available(iOS 15.0, *)
struct AdaptiveLiquidGlassView: View {
    @ObservedObject var model: GlassViewModel
    let onPressed: () -> Void

    private var config: GlassConfig { model.config }
    private var expand: Bool { config.expand ?? false }
    private var tint: Color? { config.tint.map { Color(argb: $0) } }

    /// A container that fills the box Flutter built is drawn only once that
    /// box is real. A platform view exists before Flutter has committed its
    /// layout, and a first pass at a degenerate size paints a shape of that
    /// size — a flash of wrong geometry on presentation and page transitions.
    /// An empty frame for one pass is not noticeable; a mis-shaped one is.
    ///
    /// Only in that mode: a container that hugs its own content must be free
    /// to state its size, and `GeometryReader` answers with the space offered
    /// instead, which would collapse the measurement.
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
        if #available(iOS 26.0, *) {
            // The shape Apple's "Applying Liquid Glass to custom views" asks
            // for, in its order: content, then the padding, then the frame,
            // then `glassEffect` last — it captures what it wraps and hands
            // that to the container to render, so nothing that affects
            // appearance may come after it.
            //
            //     Color.white.opacity(0.001)
            //         .frame(width: 80, height: 80)
            //         .glassEffect(.regular.interactive(), in: Circle())
            //
            GlassEffectContainer {
                glassSurface
                    .simultaneousGesture(
                        TapGesture().onEnded { if config.pressable == true { onPressed() } })
            }
        } else {
            // Pre-26 approximation: a system material with an optional tint
            // wash. No refraction — Liquid Glass itself is iOS 26+.
            fallbackClipped
                .overlay(iconView)
                .applyGlassExpand(expand)
                .simultaneousGesture(
                    TapGesture().onEnded { if config.pressable == true { onPressed() } })
        }
    }

    /// The material, and what sits on it.
    ///
    /// A native icon is `glassEffect` CONTENT — the arrangement Apple
    /// documents, and the one the icon-only container already renders
    /// correctly. A hosted engine cannot be. `glassEffect` captures what it
    /// wraps and hands that to the container to render, and a `FlutterView` is
    /// a live Metal layer the capture has nothing to sample: the material and
    /// the body both come out blank. That is the whole difference between the
    /// glass circle with an `icon`, which draws, and every container with a
    /// `route`, which drew nothing.
    ///
    /// So a hosted body gets the glass BEHIND it instead — the same
    /// placeholder Apple uses, carrying the effect, as a `background` so it
    /// takes the body's size in either layout mode. The body is drawn on the
    /// material rather than captured into it, which costs the refraction of
    /// the content itself; it keeps its own crisp pixels, and the container
    /// finally renders.
    @available(iOS 26.0, *)
    @ViewBuilder
    private var glassSurface: some View {
        if let engine = model.engine, #available(iOS 16.0, *) {
            FlutterContentView(engine: engine)
                .padding(insets)
                .applyGlassExpand(expand)
                .background {
                    Color.white.opacity(0.001).glassEffect(glass, in: glassShape)
                }
                // The hosted view states its own height and overshoots the box
                // until Dart's layout reports back; the shape is also the clip.
                .clipShape(glassShape)
        } else {
            content.glassEffect(glass, in: glassShape)
        }
    }

    /// What the glass is painted around when it is `glassEffect` content: a
    /// native icon when there is one, and otherwise Apple's own placeholder —
    /// invisible to the eye, solid to touches. It has to be *something*:
    /// `EmptyView` is erased from the hierarchy (frame and all, so the glass
    /// gets a 0×0 shape and paints nothing) and `Color.clear` has no substance
    /// for `.interactive()` to track, which is a container that renders but
    /// never responds.
    @ViewBuilder
    private var base: some View {
        if let icon = config.icon {
            IconView(icon: icon)
        } else {
            // No content of its own: Apple's placeholder, invisible to the eye
            // but solid to touches, so `.interactive()` has something to
            // track. `EmptyView` is erased from the hierarchy (the glass gets
            // a 0x0 shape and paints nothing) and `Color.clear` has no
            // substance for the interaction to hold on to.
            Color.white.opacity(0.001)
        }
    }

    /// Inset, sized, ready for the material: the glass either fills the box
    /// Flutter built (`expand` — which is where an explicit width/height from
    /// the caller lands, since that box *is* that size) or hugs its content so
    /// `getIntrinsicSize` can measure it.
    @ViewBuilder
    private var content: some View {
        // Padding before the frame, not after: an inset applied last would
        // push the material *outward* past a size Flutter already reserved,
        // and on an expanding container it would shrink the glass away from
        // the box it is meant to fill. Inside, it does what it is for —
        // spacing a native icon off the glass edge, so the container measures
        // like a control instead of like a glyph.
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

    /// The icon alone, for the pre-26 overlay.
    @ViewBuilder
    private var iconView: some View {
        if let icon = config.icon { IconView(icon: icon).padding(insets) }
    }

    @ViewBuilder
    private var fallbackClipped: some View {
        switch config.shape {
        case "capsule": fallbackMaterial.clipShape(Capsule())
        case "circle": fallbackMaterial.clipShape(Circle())
        default:
            fallbackMaterial.clipShape(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }

    private var fallbackMaterial: some View {
        Rectangle()
            .fill(.ultraThinMaterial)
            .overlay((tint ?? Color.clear).opacity(0.18))
    }

    private var cornerRadius: CGFloat { CGFloat(config.cornerRadius ?? 26) }

    @available(iOS 26.0, *)
    private var glass: Glass {
        var glass: Glass = config.variant == "clear" ? .clear : .regular
        if let tint { glass = glass.tint(tint) }
        if config.interactive == true { glass = glass.interactive() }
        return glass
    }

    @available(iOS 16.0, *)
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

@available(iOS 15.0, *)
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
