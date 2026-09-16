import Flutter
import SwiftUI

/// Engines for `CupertinoNativeBody.flutter` nodes, one per route.
///
/// A node that hosts Flutter needs a `FlutterViewController`, which needs an
/// engine — the same machinery a scaffold body or a glass container's `route:`
/// uses. It is kept per route rather than per node so the same island shown in
/// two places (a keyboard toolbar that comes and goes, say) does not boot a
/// second isolate each time.
///
/// Engines are retained for the process's lifetime once created. A Flutter
/// island is a real isolate; treat it as you would a scaffold body, not as
/// something to sprinkle.
@available(iOS 26.0, *)
enum BodyEngineRegistry {
    private static var engines: [String: FlutterEngine] = [:]

    private static var controllers: [String: FlutterViewController] = [:]

    /// The island's controller, created once per route and re-parented from
    /// then on.
    static func controller(for route: String, isDark: Bool) -> FlutterViewController {
        if let existing = controllers[route] { return existing }
        let controller = FlutterViewController(
            engine: engine(for: route, isDark: isDark), nibName: nil, bundle: nil)
        controller.isViewOpaque = false
        controller.isAutoResizable = true
        controller.view.backgroundColor = .clear
        controllers[route] = controller
        return controller
    }

    static func engine(for route: String, isDark: Bool) -> FlutterEngine {
        if let existing = engines[route] { return existing }
        let engine: FlutterEngine
        if let pooled = NativeScaffoldView.takePooledEngine(route: route) {
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
        engines[route] = engine
        return engine
    }
}

/// A Flutter island inside a native tree. Sizes itself to the Dart content,
/// with no placeholder height — an island must not claim the screen's height
/// before Dart has reported its own.
///
/// It re-parents ONE controller per route rather than building a new
/// `FlutterViewController` each time SwiftUI rebuilds: an engine can only be
/// attached to one controller at a time, and a second one logs "already used
/// with FlutterViewController" and renders nothing.
@available(iOS 26.0, *)
struct BodyFlutterView: UIViewControllerRepresentable {
    let route: String
    let isDark: Bool

    func makeUIViewController(context: Context) -> UIViewController {
        return BodyEngineRegistry.controller(for: route, isDark: isDark)
    }

    func updateUIViewController(_ controller: UIViewController, context: Context) {}
}
