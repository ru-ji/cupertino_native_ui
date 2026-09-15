import Flutter
import ObjectiveC
import UIKit

/// A progressive blur drawn by Core Animation (`variableBlur` on a
/// `CABackdropLayer`), with the system's adaptive wash on top. It samples
/// everything composited beneath it, native views included.
@available(iOS 15.0, *)
class NativeEdgeBlurFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return NativeEdgeBlurPlatformView(viewId: viewId, arguments: args, messenger: messenger)
    }

    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

@available(iOS 15.0, *)
final class NativeEdgeBlurPlatformView: NSObject, FlutterPlatformView {
    private let edgeView = EdgeBlurView()
    private let channel: FlutterMethodChannel

    init(viewId: Int64, arguments args: Any?, messenger: FlutterBinaryMessenger) {
        #if DEBUG
            // Partial repaint is on by default on iOS (Impeller). It leaves the
            // Flutter surface under an overlay uncleared, and this blur samples
            // that surface: a stale copy of any Flutter chrome drawn over it (a
            // bar title) comes back blurred inside the effect.
            if Bundle.main.object(forInfoDictionaryKey: "FLTDisablePartialRepaint") as? Bool != true {
                print(
                    "[EdgeBlur] WARNING: partial repaint is enabled. Flutter content drawn over this blur will ghost inside it. Add <key>FLTDisablePartialRepaint</key><true/> to the app's Info.plist."
                )
            }
        #endif
        channel = FlutterMethodChannel(
            name: "cupertino_widgets/edge_blur_\(viewId)", binaryMessenger: messenger)
        super.init()
        edgeView.onLightChange = { [weak self] light in
            self?.channel.invokeMethod("lumaChanged", arguments: ["light": light])
        }
        edgeView.apply(EdgeBlurConfig(args))
        channel.setMethodCallHandler { [weak self] call, result in
            guard call.method == "update" else {
                result(FlutterMethodNotImplemented)
                return
            }
            self?.edgeView.apply(EdgeBlurConfig(call.arguments))
            result(nil)
        }
    }

    func view() -> UIView { edgeView }
}

struct EdgeBlurConfig {
    /// Peak radius at the edge, points.
    var sigma: CGFloat
    var bottom: Bool
    /// ARGB32; its alpha is the peak opacity at the edge. Nil for none.
    /// Ignored when `adaptive`.
    var tint: Int?
    /// The system's luma-tracked light/dark wash.
    var adaptive: Bool
    /// Calibration factor on `inputRadius`.
    var radiusScale: CGFloat
    /// The app theme: what the wash shows before the first luma measurement.
    var isDark: Bool
    /// 0…1: scales the blur radius and the washes together.
    var intensity: CGFloat
    var debugPaintRect: Bool

    init(_ arguments: Any?) {
        let map = arguments as? [String: Any] ?? [:]
        sigma = CGFloat(map["sigma"] as? Double ?? 0)
        bottom = (map["edge"] as? String) == "bottom"
        tint = map["tint"] as? Int
        adaptive = map["adaptive"] as? Bool ?? false
        radiusScale = CGFloat(map["radiusScale"] as? Double ?? 1)
        isDark = map["isDark"] as? Bool ?? false
        intensity = CGFloat(min(max(map["intensity"] as? Double ?? 1, 0), 1))
        debugPaintRect = map["debug"] as? Bool ?? false
    }
}

/// The blur and wash curves.
enum EdgeBlurProfile {
    static let blurHold = 0.41
    static let tintHold = 0.35

    /// Peak of the white wash over near-white content.
    static let lightPeak = 0.85
    /// The dark wash's two levels, for mid and for dark content.
    // ponytail: deepDark derived from one measurement; tune by eye.
    static let midDark = 0.27
    static let deepDark = 0.47

    /// Near-white content or not (the white wash's decision).
    static let brightLow = 0.75
    static let brightHigh = 0.85
    /// Among the rest: mid content like the warm gradient, or dark content —
    /// grey, the busy band, vivid, black.
    // ponytail: guessed from the bands' luma (warm ~0.65, grey 0.5); tune.
    static let deepLow = 0.55
    static let deepHigh = 0.62

    static func smootherstep(_ d: Double) -> Double {
        let x = min(max(d, 0), 1)
        return x * x * x * (x * (x * 6 - 15) + 10)
    }

    /// 1 at the edge down to 0 at the far side; `t` is 0 at the edge.
    static func blur(_ t: Double) -> Double {
        1 - smootherstep((t - blurHold) / (1 - blurHold))
    }

    static func tint(_ t: Double) -> Double {
        1 - smootherstep((t - tintHold) / (1 - tintHold))
    }

    /// Fraction of the peak radius at profile `p`, on a geometric ramp
    /// from 1 physical pixel up to `sigmaPx`: equal steps multiply the radius
    /// by the same factor, so every stretch adds the same perceived blur.
    static func radiusFraction(_ p: Double, sigmaPx: Double) -> Double {
        let r = max(sigmaPx, 1.0001)
        return (pow(r, p) - 1) / (r - 1)
    }

    /// Integer hash in 0…1, for dither.
    static func hash(_ x: Int, _ y: Int) -> Double {
        var h = UInt32(truncatingIfNeeded: x &* 374_761_393 &+ y &* 668_265_263)
        h = (h ^ (h >> 13)) &* 1_274_126_177
        h ^= h >> 16
        return Double(h) / Double(UInt32.max)
    }
}

/// The system's luminance adjustment settles on three levels, not two.
enum WashLevel {
    case light, mid, deep

    var lightOpacity: Float { self == .light ? 1 : 0 }

    var darkOpacity: Float {
        switch self {
        case .light: return 0
        case .mid: return Float(EdgeBlurProfile.midDark)
        case .deep: return Float(EdgeBlurProfile.deepDark)
        }
    }
}

@available(iOS 15.0, *)
final class EdgeBlurView: UIView {
    private let blur = BackdropBlurView()
    /// Holds the washes, so `intensity` fades them as one.
    private let washLayer = CALayer()
    /// Wash layers: images, not gradients, and siblings, never masks.
    private let fixedWash = CALayer()
    private let lightWash = CALayer()
    private let darkWash = CALayer()
    private var config = EdgeBlurConfig(nil)
    private var luma: LumaTracker?
    private var darkLuma: LumaTracker?
    /// Latest decisions from the two trackers; nil until they measure.
    private var bright: Bool?
    private var deep: Bool?
    /// Told when the wash flips, so Flutter chrome over it can flip with it
    /// (dark text on the white wash, white text on the dark one).
    var onLightChange: ((Bool) -> Void)?
    private var level = WashLevel.light
    /// Pixel size and settings the wash images were rendered for.
    private var renderedKey: String?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        backgroundColor = .clear
        addSubview(blur)
        layer.addSublayer(washLayer)
        for wash in [fixedWash, lightWash, darkWash] {
            wash.contentsGravity = .resize
            wash.isHidden = true
            washLayer.addSublayer(wash)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ newConfig: EdgeBlurConfig) {
        config = newConfig
        blur.configure(
            sigma: config.sigma * config.radiusScale * config.intensity, bottom: config.bottom)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        washLayer.opacity = Float(config.intensity)
        CATransaction.commit()
        if config.adaptive {
            if luma == nil {
                luma = LumaTracker(
                    host: self, low: EdgeBlurProfile.brightLow, high: EdgeBlurProfile.brightHigh
                ) { [weak self] bright in
                    self?.bright = bright
                    self?.updateLevel()
                }
            }
            if darkLuma == nil {
                darkLuma = LumaTracker(
                    host: self, low: EdgeBlurProfile.deepLow, high: EdgeBlurProfile.deepHigh
                ) { [weak self] aboveDeep in
                    self?.deep = !aboveDeep
                    self?.updateLevel()
                }
            }
        } else {
            luma?.remove()
            luma = nil
            darkLuma?.remove()
            darkLuma = nil
            bright = nil
            deep = nil
        }
        // Until the first measurement the wash is the app's own: white on a
        // light theme, dark on a dark one — what the system shows on arrival.
        if bright == nil { level = config.isDark ? .deep : .light }
        layer.borderWidth = config.debugPaintRect ? 1 : 0
        layer.borderColor = UIColor.red.cgColor
        renderedKey = nil
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        blur.frame = bounds
        washLayer.frame = bounds
        for wash in [fixedWash, lightWash, darkWash] { wash.frame = washLayer.bounds }
        let insets = window?.safeAreaInsets ?? .zero
        for tracker in [luma, darkLuma] {
            tracker?.layout(
                in: bounds, bottom: config.bottom,
                inset: config.bottom ? insets.bottom : insets.top)
        }
        renderWashes()
        CATransaction.commit()
    }

    private func renderWashes() {
        let scale = traitCollection.displayScale > 0 ? traitCollection.displayScale : UIScreen.main.scale
        let width = Int((bounds.width * scale).rounded())
        let height = Int((bounds.height * scale).rounded())
        let key = "\(width)x\(height) b\(config.bottom) a\(config.adaptive) t\(config.tint.map(String.init) ?? "-")"
        guard width > 0, height > 0, key != renderedKey else { return }
        renderedKey = key
        for wash in [fixedWash, lightWash, darkWash] {
            wash.contentsScale = scale
            wash.contents = nil
            wash.isHidden = true
        }
        if config.adaptive {
            // The bright wash is white unless a tint is given.
            var red: CGFloat = 1, green: CGFloat = 1, blue: CGFloat = 1, alpha: CGFloat = 1
            if let argb = config.tint {
                UIColor(argb: argb).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            }
            lightWash.contents = Self.washImage(
                red: Double(red), green: Double(green), blue: Double(blue),
                peak: EdgeBlurProfile.lightPeak,
                width: width, height: height, bottom: config.bottom)
            // Full peak: the layer's opacity carries the level (0.27 or 0.47).
            darkWash.contents = Self.washImage(
                red: 0, green: 0, blue: 0, peak: 1,
                width: width, height: height, bottom: config.bottom)
            lightWash.isHidden = false
            darkWash.isHidden = false
            lightWash.opacity = level.lightOpacity
            darkWash.opacity = level.darkOpacity
        } else if let argb = config.tint {
            let color = UIColor(argb: argb)
            var red: CGFloat = 0, green: CGFloat = 0, blue: CGFloat = 0, alpha: CGFloat = 0
            color.getRed(&red, green: &green, blue: &blue, alpha: &alpha)
            fixedWash.contents = Self.washImage(
                red: Double(red), green: Double(green), blue: Double(blue), peak: Double(alpha),
                width: width, height: height, bottom: config.bottom)
            fixedWash.isHidden = false
        }
    }

    private func updateLevel() {
        guard let bright else { return }
        // The deep tracker may not have measured yet: mid until it has.
        let next: WashLevel = bright ? .light : (deep == true ? .deep : .mid)
        guard next != level else { return }
        level = next
        onLightChange?(next == .light)
        Self.spring(lightWash, to: next.lightOpacity)
        Self.spring(darkWash, to: next.darkOpacity)
    }

    /// The system's transition: a critically damped spring, response ≈ 0.5s.
    private static func spring(_ layer: CALayer, to value: Float) {
        let from = layer.presentation()?.opacity ?? layer.opacity
        let animation = CASpringAnimation(keyPath: "opacity")
        animation.mass = 1
        animation.stiffness = 150  // ω²
        animation.damping = 24.5  // 2ω: critical, no overshoot
        animation.fromValue = from
        animation.toValue = value
        animation.duration = animation.settlingDuration
        layer.opacity = value
        layer.add(animation, forKey: "lumaWash")
    }

    /// The wash as premultiplied pixels at the layer's own resolution: alpha
    /// follows the tint curve per row, with ±0.5 code of dither per pixel —
    /// a ramp this slow quantises into visible bands otherwise.
    // ponytail: full-resolution RGBA per wash (~3MB each on a 3x bar); a
    // narrower image would stretch the dither into streaks.
    private static func washImage(
        red: Double, green: Double, blue: Double, peak: Double,
        width: Int, height: Int, bottom: Bool
    ) -> CGImage? {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for row in 0..<height {
            let fromTop = (Double(row) + 0.5) / Double(height)
            let alpha = peak * EdgeBlurProfile.tint(bottom ? 1 - fromTop : fromTop) * 255
            if alpha <= 0 { continue }
            let base = row * width * 4
            for x in 0..<width {
                let a = (min(max(alpha + EdgeBlurProfile.hash(x, row) - 0.5, 0), 255)).rounded()
                let i = base + x * 4
                pixels[i] = UInt8((red * a).rounded())
                pixels[i + 1] = UInt8((green * a).rounded())
                pixels[i + 2] = UInt8((blue * a).rounded())
                pixels[i + 3] = UInt8(a)
            }
        }
        return pixels.withUnsafeMutableBytes { raw -> CGImage? in
            guard let base = raw.baseAddress,
                let context = CGContext(
                    data: base, width: width, height: height, bitsPerComponent: 8,
                    bytesPerRow: width * 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return nil }
            return context.makeImage()
        }
    }
}

/// Luminance of what is behind the bar, measured through the same
/// `_UILumaTrackingBackdropView` UIKit's scroll pocket uses.
@available(iOS 15.0, *)
final class LumaTracker: NSObject {
    private let low: Double
    private let high: Double
    private let onChange: (Bool) -> Void
    private var trackingView: UIView?
    private var above: Bool?

    /// Calls `onChange(true)` once the luma behind the bar rises above `high`,
    /// `onChange(false)` once it falls below `low`.
    init?(host: UIView, low: Double, high: Double, onChange: @escaping (Bool) -> Void) {
        self.low = low
        self.high = high
        self.onChange = onChange
        super.init()
        guard let view = Self.makeTrackingView(delegate: self, low: low, high: high) else {
            #if DEBUG
                print("[EdgeBlur] _UILumaTrackingBackdropView unavailable: the wash stays light")
            #endif
            return nil
        }
        view.isUserInteractionEnabled = false
        if view.responds(to: NSSelectorFromString("setPaused:")) {
            view.setValue(false, forKey: "paused")
        }
        // Behind the blur: it measures the content, not our own effect.
        host.insertSubview(view, at: 0)
        trackingView = view
    }

    private static func makeTrackingView(delegate: NSObject, low: Double, high: Double) -> UIView? {
        let allocSelector = NSSelectorFromString("alloc")
        let initSelector = NSSelectorFromString("initWithTransitionBoundaries:delegate:frame:")
        guard let type = NSClassFromString("_UILumaTrackingBackdropView"),
            let meta = object_getClass(type),
            class_respondsToSelector(type, initSelector),
            let allocIMP = class_getMethodImplementation(meta, allocSelector),
            let initIMP = class_getMethodImplementation(type, initSelector)
        else { return nil }
        if let proto = NSProtocolFromString("_UILumaTrackingBackdropViewDelegate") {
            class_addProtocol(LumaTracker.self, proto)
        }
        typealias Alloc = @convention(c) (AnyClass, Selector) -> Unmanaged<AnyObject>
        // `{?=dd}` passed as a CGPoint: the same two doubles, the same ABI.
        typealias Init = @convention(c) (AnyObject, Selector, CGPoint, AnyObject?, CGRect) -> Unmanaged<AnyObject>
        let allocated = unsafeBitCast(allocIMP, to: Alloc.self)(type, allocSelector).takeUnretainedValue()
        let object = unsafeBitCast(initIMP, to: Init.self)(
            allocated, initSelector, CGPoint(x: low, y: high), delegate, .zero
        ).takeRetainedValue()
        return object as? UIView
    }

    /// Samples the 44pt bar past the safe-area inset — the system's own
    /// `lumaSubrect` is the navigation bar, not the status bar above it.
    func layout(in bounds: CGRect, bottom: Bool, inset: CGFloat) {
        let height = min(44, max(bounds.height - inset, 0))
        trackingView?.frame = CGRect(
            x: bounds.minX, y: bottom ? bounds.maxY - inset - height : bounds.minY + inset,
            width: bounds.width, height: height)
    }

    func remove() {
        trackingView?.removeFromSuperview()
        trackingView = nil
    }

    /// The only callback `_UILumaTrackingBackdropView` delivers. Level 1 is
    /// content above the boundaries, 2 below, 0 not measured yet.
    @objc(backgroundLumaView:didTransitionToLevel:)
    func backgroundLumaView(_ source: UIView, didTransitionToLevel level: UInt) {
        let next: Bool
        switch level {
        case 1: next = true
        case 2: next = false
        default: return
        }
        guard next != above else { return }
        above = next
        onChange(next)
    }
}

/// A view whose own layer is Core Animation's `CABackdropLayer`, carrying a
/// single `variableBlur`.
///
/// Not a `UIVisualEffectView`: a plain backdrop layer stays out of UIKit's
/// capture groups, and UIKit never reinstalls its filters over ours.
@available(iOS 15.0, *)
final class BackdropBlurView: UIView {
    override class var layerClass: AnyClass {
        NSClassFromString("CABackdropLayer") ?? CALayer.self
    }

    private let filter: NSObject? = BackdropBlurView.makeFilter()
    /// Kept so the mask can be rebuilt once the real screen scale is known.
    private var sigma: CGFloat = 0
    private var bottom = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        #if DEBUG
            if filter == nil { print("[EdgeBlur] CAFilter variableBlur is unavailable") }
            if NSClassFromString("CABackdropLayer") == nil { print("[EdgeBlur] CABackdropLayer is unavailable") }
        #endif
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    /// Looked up at runtime: the class and the filter type are private.
    private static func makeFilter() -> NSObject? {
        guard let type = NSClassFromString("CAFilter") as? NSObject.Type else { return nil }
        let factory = NSSelectorFromString("filterWithType:")
        guard type.responds(to: factory) else { return nil }
        return type.perform(factory, with: "variableBlur")?.takeUnretainedValue() as? NSObject
    }

    func configure(sigma: CGFloat, bottom: Bool) {
        self.sigma = sigma
        self.bottom = bottom
        guard let filter else { return }
        let scale = window?.screen.scale
            ?? (traitCollection.displayScale > 0 ? traitCollection.displayScale : UIScreen.main.scale)
        filter.setValue(max(sigma, 0), forKey: "inputRadius")
        filter.setValue(
            Self.maskImage(sigmaPx: Double(sigma * scale), bottom: bottom),
            forKey: "inputMaskImage")
        // Renormalizes the kernel at the layer's bounds instead of averaging
        // in transparent black — no dark rim at the hugged edge.
        filter.setValue(true, forKey: "inputNormalizeEdges")
        // Breaks up the steps between the filter's own blur levels.
        filter.setValue(true, forKey: "inputDither")

        CATransaction.begin()
        CATransaction.setDisableActions(true)
        layer.filters = [filter]
        // Left at its default the backdrop samples at a reduced scale and the
        // unblurred edge pixelates.
        if layer.responds(to: NSSelectorFromString("setScale:")) {
            layer.setValue(scale, forKey: "scale")
        }
        // A capture group of its own.
        if layer.responds(to: NSSelectorFromString("setGroupName:")) {
            layer.setValue(
                "cupertino_widgets.edgeBlur.\(UInt(bitPattern: ObjectIdentifier(self).hashValue))",
                forKey: "groupName")
        }
        CATransaction.commit()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // The mask's ramp depends on the pixel scale; rebuild it with the real one.
        configure(sigma: sigma, bottom: bottom)
    }

    /// 1 × 1024, alpha = fraction of `inputRadius` at that row, on the
    /// blur curve and geometric ramp. Row 0 is the top of the layer.
    private static func maskImage(sigmaPx: Double, bottom: Bool) -> CGImage? {
        let height = 1024
        var pixels = [UInt8](repeating: 0, count: height * 4)
        for row in 0..<height {
            let fromTop = (Double(row) + 0.5) / Double(height)
            let t = bottom ? 1 - fromTop : fromTop
            let fraction = EdgeBlurProfile.radiusFraction(EdgeBlurProfile.blur(t), sigmaPx: sigmaPx)
            let value = UInt8((min(max(fraction, 0), 1) * 255).rounded())
            // Premultiplied white: alpha and colour carry the same value.
            for channel in 0..<4 { pixels[row * 4 + channel] = value }
        }
        return pixels.withUnsafeMutableBytes { raw -> CGImage? in
            guard let base = raw.baseAddress,
                let context = CGContext(
                    data: base, width: 1, height: height, bitsPerComponent: 8,
                    bytesPerRow: 4, space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
            else { return nil }
            return context.makeImage()
        }
    }
}
