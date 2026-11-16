import Flutter
import UIKit

public class FlutterCupertinoPlugin: NSObject, FlutterPlugin {

    public static func register(with registrar: FlutterPluginRegistrar) {
        // Register the method channel unconditionally so calls on old systems
        // get a descriptive error instead of a MissingPluginException.
        let channel = FlutterMethodChannel(
            name: "com.example.cupertino_native_ui/alert", binaryMessenger: registrar.messenger())
        // One messenger for every factory: a view's channel finds its engine
        // by this object, and Dart finds the same engine by its id.
        let messenger = registrar.messenger()
        NativeEngines.register(messenger, engineId: registrar.engineIdentifier)
        let instance = FlutterCupertinoPlugin()
        registrar.addMethodCallDelegate(instance, channel: channel)

        // Sheet events (bar actions, segment/search changes) flow back to
        // Dart over the main app's messenger. First registration wins: the
        // app engine registers at launch, before any body/sheet engine.
        if NativeSheetManager.shared.mainMessenger == nil {
            NativeSheetManager.shared.mainMessenger = registrar.messenger()
        }

        let menuFactory = NativeMenuFactory(messenger: messenger)
        registrar.register(
            menuFactory, withId: "com.example.cupertino_native_ui/cupertino_native_menu")

        let contextMenuFactory = NativeContextMenuFactory(messenger: messenger)
        registrar.register(
            contextMenuFactory,
            withId: "com.example.cupertino_native_ui/cupertino_native_context_menu")

        let symbolFactory = NativeSymbolFactory(messenger: messenger)
        registrar.register(
            symbolFactory, withId: "com.example.cupertino_native_ui/cupertino_native_symbol")

        let pickerFactory = NativePickerFactory(messenger: messenger)
        registrar.register(
            pickerFactory, withId: "com.example.cupertino_native_ui/cupertino_native_picker")

        let buttonFactory = NativeButtonFactory(messenger: messenger)
        registrar.register(
            buttonFactory, withId: "com.example.cupertino_native_ui/cupertino_native_button")

        let toggleFactory = NativeToggleFactory(messenger: messenger)
        registrar.register(
            toggleFactory, withId: "com.example.cupertino_native_ui/cupertino_native_toggle")

        registrar.register(
            NativePhotosPickerFactory(messenger: messenger),
            withId: "com.example.cupertino_native_ui/cupertino_native_photos_picker")

        registrar.register(
            NativeControlFactory(messenger: messenger),
            withId: "com.example.cupertino_native_ui/cupertino_native_control")

        let checkboxFactory = NativeCheckboxFactory(messenger: messenger)
        registrar.register(
            checkboxFactory, withId: "com.example.cupertino_native_ui/cupertino_native_checkbox")

        let segmentedFactory = NativeSegmentedControlFactory(messenger: messenger)
        registrar.register(
            segmentedFactory, withId: "com.example.cupertino_native_ui/cupertino_native_segmented")

        let sliderFactory = NativeSliderFactory(messenger: messenger)
        registrar.register(
            sliderFactory, withId: "com.example.cupertino_native_ui/cupertino_native_slider")

        let textFieldFactory = NativeTextFieldFactory(messenger: messenger)
        registrar.register(
            textFieldFactory, withId: "com.example.cupertino_native_ui/cupertino_native_text_field")

        let tabBarFactory = NativeTabBarFactory(messenger: messenger)
        registrar.register(
            tabBarFactory, withId: "com.example.cupertino_native_ui/cupertino_native_tabbar")

        let scaffoldFactory = NativeScaffoldFactory(messenger: messenger)
        registrar.register(
            scaffoldFactory, withId: "com.example.cupertino_native_ui/cupertino_native_scaffold")

        let progressFactory = NativeProgressFactory(messenger: messenger)
        registrar.register(
            progressFactory, withId: "com.example.cupertino_native_ui/cupertino_native_progress")

        let listFactory = NativeListFactory(messenger: messenger)
        registrar.register(
            listFactory, withId: "com.example.cupertino_native_ui/cupertino_native_list")

        let glassGroupFactory = NativeGlassGroupFactory(messenger: messenger)
        registrar.register(
            glassGroupFactory,
            withId: "com.example.cupertino_native_ui/cupertino_native_glass_group")

        let liquidGlassFactory = NativeLiquidGlassFactory(messenger: messenger)
        registrar.register(
            liquidGlassFactory,
            withId: "com.example.cupertino_native_ui/cupertino_native_liquid_glass")

        let datePickerFactory = NativeDatePickerFactory(messenger: messenger)
        registrar.register(
            datePickerFactory,
            withId: "com.example.cupertino_native_ui/cupertino_native_date_picker")

        let edgeBlurFactory = NativeEdgeBlurFactory(messenger: messenger)
        registrar.register(
            edgeBlurFactory,
            withId: "com.example.cupertino_native_ui/cupertino_native_edge_blur")

        registrar.register(
            NativeBarMaterialFactory(messenger: messenger),
            withId: "com.example.cupertino_native_ui/cupertino_native_bar_material")
    }

    /// Rasterizes an SF Symbol to PNG bytes so Flutter can draw it as a normal
    /// image instead of hosting a platform view for a 17pt glyph. Platform
    /// views are composited outside Flutter's layer tree, so anything drawn
    /// through one is invisible to a `BackdropFilter`: an icon rendered that
    /// way would punch a hole in the app bar's scroll edge effect.
    @available(iOS 15.0, *)
    static func renderSymbol(
        name: String, size: Double, argb: Int?, weight: String, symbolScale: String,
        scale: Double
    ) -> Data? {
        let size = CGFloat(size)
        let symbolWeight: UIImage.SymbolWeight
        switch weight {
        case "light": symbolWeight = .light
        case "medium": symbolWeight = .medium
        case "semibold": symbolWeight = .semibold
        case "bold": symbolWeight = .bold
        default: symbolWeight = .regular
        }
        let sizeScale: UIImage.SymbolScale
        switch symbolScale {
        case "small": sizeScale = .small
        case "large": sizeScale = .large
        default: sizeScale = .medium
        }
        let config = UIImage.SymbolConfiguration(
            pointSize: size, weight: symbolWeight, scale: sizeScale)
        guard var image = UIImage(systemName: name, withConfiguration: config) else { return nil }
        if let argb {
            image = image.withTintColor(UIColor(argb: argb), renderingMode: .alwaysOriginal)
        }
        // Rasterized at the caller's device pixel ratio: Flutter is handed raw
        // pixels and has no scale factor to read off the PNG.
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = CGFloat(scale)
        format.opaque = false
        // sRGB, not the display's wide gamut: `pngData()` is unreliable for
        // extended-range bitmaps, which is what `.preferred()` yields on every
        // modern device.
        format.preferredRange = .standard
        let rendered = UIGraphicsImageRenderer(size: image.size, format: format).image { _ in
            image.draw(at: .zero)
        }
        return rendered.pngData()
    }

    public func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        if call.method == "showSheet" {
            NativeSheetManager.shared.show(
                args: call.arguments as? [String: Any] ?? [:], result: result)
            return
        }
        if call.method == "updateSheetBody" {
            NativeSheetManager.shared.updateBody(
                args: call.arguments as? [String: Any] ?? [:], result: result)
            return
        }
        if call.method == "dismissSheet" {
            NativeSheetManager.shared.dismiss(result: result)
            return
        }
        result(FlutterMethodNotImplemented)
    }
}
