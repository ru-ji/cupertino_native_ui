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
                NativeLog.log(
                    "[EdgeBlur] WARNING: partial repaint is enabled. Flutter content drawn over this blur will ghost inside it. Add <key>FLTDisablePartialRepaint</key><true/> to the app's Info.plist."
                )
            }
        #endif
        channel = FlutterMethodChannel(
            name: "cupertino_native_ui/edge_blur_\(viewId)", binaryMessenger: messenger)
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

@available(iOS 15.0, *)
struct EdgeBlurConfig {
    /// Peak radius at the edge, points.
    var sigma: CGFloat
    var bottom: Bool
    /// ARGB32; its alpha is the peak opacity at the edge. Nil for none.
    /// Ignored when `adaptive`.
    var tint: Int?
    /// The system's luma-tracked light/dark wash.
    var adaptive: Bool
    /// Measure the content's luma even under a fixed wash, for the chrome
    /// over the effect: the system's bar items follow the content under its
    /// wash whatever the wash does.
    var tracksLuma: Bool
    /// Calibration factor on `inputRadius`.
    var radiusScale: CGFloat
    /// The app theme: what the wash shows before the first luma measurement.
    var isDark: Bool
    /// 0…1: scales the blur radius and the washes together.
    var intensity: CGFloat
    var debugPaintRect: Bool
    /// The `.hard` style: one even blur over the whole view under a flat
    /// tint, ending in a hard line, no ramp, no adaptation, no holes.
    var hard: Bool
    /// A bar's native items, in this view's points: the wash is cut out under
    /// each as a capsule, so their glass sees the content and not the wash.
    var holes: [CGRect]

    init(_ arguments: Any?) {
        let map = arguments as? [String: Any] ?? [:]
        sigma = CGFloat(map["sigma"] as? Double ?? 0)
        bottom = (map["edge"] as? String) == "bottom"
        tint = map["tint"] as? Int
        adaptive = map["adaptive"] as? Bool ?? false
        tracksLuma = map["tracksLuma"] as? Bool ?? false
        radiusScale = CGFloat(map["radiusScale"] as? Double ?? 1)
        isDark = map["isDark"] as? Bool ?? false
        intensity = CGFloat(min(max(map["intensity"] as? Double ?? 1, 0), 1))
        debugPaintRect = map["debug"] as? Bool ?? false
        hard = map["hard"] as? Bool ?? false
        let runs = (map["holes"] as? [NSNumber])?.map { CGFloat($0.doubleValue) } ?? []
        holes = stride(from: 0, to: runs.count - 3, by: 4).map {
            CGRect(x: runs[$0], y: runs[$0 + 1], width: runs[$0 + 2], height: runs[$0 + 3])
        }
    }
}

/// The blur and wash curves.
@available(iOS 15.0, *)
enum EdgeBlurProfile {
    static let blurHold = 0.41
    static let tintHold = 0.35
    /// The bottom edge's wash barely holds: fitted to the system's tab bar
    /// edge on iOS 26 (hold 9.7% of a 133pt band, 2026-10-03). The top's
    /// 0.35 fits its own (32.8% of 137pt).
    static let bottomTintHold = 0.097

    /// Peak of the white wash over near-white content.
    static let lightPeak = 0.84
    /// The dark wash's two levels, for mid and for dark content.
    // ponytail: deepDark derived from one measurement; tune by eye.
    static let midDark = 0.27
    static let deepDark = 0.47

    /// Near-white content or not (the white wash's decision).
    static let brightLow = 0.75
    static let brightHigh = 0.85
    /// Among the rest: mid content (the warm gradient, busy, vivid, grey,
    /// cool (~0.42 average luma), all ~27% black on iOS 26, measured
    /// 2026-10-03) or dark content below it, the navy band and black.
    // ponytail: the dark side was never seen on device (black hides the
    // wash); the line sits under the darkest mid band measured.
    static let deepLow = 0.28
    static let deepHigh = 0.34

    /// A dark app: black alone, at three strengths for bright content (white,
    /// the warm gradient), mid content (grey, blue, lavender, vivid, navy),
    /// near-black content. iOS 26, measured frame by frame (2026-10-03).
    static let darkModeBright = 0.31
    static let darkModeMid = 0.60
    static let darkModeDeep = 0.85
    /// A dark app's boundaries, on the bands' average luma: bright from the
    /// warm gradient (~0.67) up, the busy band (~0.59) still mid; deep only
    /// below the navy band (~0.2).
    static let darkModeBrightLow = 0.60
    static let darkModeBrightHigh = 0.64
    static let darkModeDeepLow = 0.08
    static let darkModeDeepHigh = 0.14

    static func smootherstep(_ d: Double) -> Double {
        let x = min(max(d, 0), 1)
        return x * x * x * (x * (x * 6 - 15) + 10)
    }

    /// 1 at the edge down to 0 at the far side; `t` is 0 at the edge.
    static func blur(_ t: Double) -> Double {
        1 - smootherstep((t - blurHold) / (1 - blurHold))
    }

    static func tint(_ t: Double, hold: Double = tintHold) -> Double {
        1 - smootherstep((t - hold) / (1 - hold))
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

/// The system's luminance adjustment settles on three levels, not two: for
/// bright, mid and dark content. A light app shows its bright wash over
/// bright content and black over the rest; a dark app only black, stronger
/// as the content darkens.
@available(iOS 15.0, *)
enum WashLevel {
    case light, mid, deep

    func lightOpacity(dark: Bool) -> Float { self == .light && !dark ? 1 : 0 }

    func darkOpacity(dark: Bool) -> Float {
        switch (self, dark) {
        case (.light, false): return 0
        case (.mid, false): return Float(EdgeBlurProfile.midDark)
        case (.deep, false): return Float(EdgeBlurProfile.deepDark)
        case (.light, true): return Float(EdgeBlurProfile.darkModeBright)
        case (.mid, true): return Float(EdgeBlurProfile.darkModeMid)
        case (.deep, true): return Float(EdgeBlurProfile.darkModeDeep)
        }
    }
}

@available(iOS 15.0, *)
final class EdgeBlurView: UIView {
    private let blur = BackdropBlurView()
    /// Holds the washes, so `intensity` fades them as one.
    private let washLayer = CALayer()
    /// Wash layers: a flat colour shaped by a mask image (the dithered
    /// profile, not a gradient), siblings. The image depends only on the
    /// size and the edge: a theme or page-colour change just recolours them.
    private let fixedWash = CALayer()
    private let lightWash = CALayer()
    private let darkWash = CALayer()
    private let fixedMask = CALayer()
    private let lightMask = CALayer()
    private let darkMask = CALayer()
    /// The wash with the bar's native items cut out (see `applyHoles`).
    private let holeMask = CAShapeLayer()
    private var config = EdgeBlurConfig(nil)
    private var luma: LumaTracker?
    private var darkLuma: LumaTracker?
    /// The app brightness the trackers' boundaries were set for.
    private var trackersDark: Bool?
    /// Latest decisions from the two trackers; nil until they measure.
    private var bright: Bool?
    private var deep: Bool?
    /// Told when the content under the effect turns bright or dark, so the
    /// chrome over it can follow, as the system's bar items do.
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
        for (wash, mask) in [(fixedWash, fixedMask), (lightWash, lightMask), (darkWash, darkMask)] {
            mask.contentsGravity = .resize
            wash.mask = mask
            wash.isHidden = true
            washLayer.addSublayer(wash)
        }
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func apply(_ newConfig: EdgeBlurConfig) {
        config = newConfig
        // `.hard`'s tint is flat to its edge: the profile does not shape it.
        // Set before the layout below, which sizes every mask.
        fixedWash.mask = config.hard ? nil : fixedMask
        blur.configure(
            sigma: config.sigma * config.radiusScale * config.intensity, bottom: config.bottom,
            uniform: config.hard)
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        washLayer.opacity = Float(config.intensity)
        CATransaction.commit()
        // A dark app draws its lines elsewhere: new trackers, measuring from
        // scratch.
        let tracks = config.adaptive || config.tracksLuma
        if !tracks || trackersDark != config.isDark {
            luma?.remove()
            luma = nil
            darkLuma?.remove()
            darkLuma = nil
            bright = nil
            deep = nil
            trackersDark = nil
        }
        if tracks && luma == nil {
            let dark = config.isDark
            trackersDark = dark
            luma = LumaTracker(
                host: self,
                low: dark ? EdgeBlurProfile.darkModeBrightLow : EdgeBlurProfile.brightLow,
                high: dark ? EdgeBlurProfile.darkModeBrightHigh : EdgeBlurProfile.brightHigh
            ) { [weak self] bright in
                self?.bright = bright
                self?.updateLevel()
            }
            darkLuma = LumaTracker(
                host: self,
                low: dark ? EdgeBlurProfile.darkModeDeepLow : EdgeBlurProfile.deepLow,
                high: dark ? EdgeBlurProfile.darkModeDeepHigh : EdgeBlurProfile.deepHigh
            ) { [weak self] aboveDeep in
                self?.deep = !aboveDeep
                self?.updateLevel()
            }
        }
        // Until the first measurement the wash is the app's own: white on a
        // light theme, dark on a dark one, what the system shows on arrival.
        if bright == nil { level = config.isDark ? .deep : .light } else { updateLevel() }
        layer.borderWidth = config.debugPaintRect ? 1 : 0
        layer.borderColor = UIColor.red.cgColor
        // The wash images re-render only if what they draw changed (see
        // `renderWashes`); the levels are re-applied either way.
        setNeedsLayout()
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        blur.frame = bounds
        washLayer.frame = bounds
        // Every mask, attached or not: one detached for `.hard` comes back
        // at its new size.
        for (wash, mask) in [(fixedWash, fixedMask), (lightWash, lightMask), (darkWash, darkMask)] {
            wash.frame = washLayer.bounds
            mask.frame = wash.bounds
        }
        applyHoles()
        let insets = window?.safeAreaInsets ?? .zero
        for tracker in [luma, darkLuma] {
            tracker?.layout(
                in: bounds, bottom: config.bottom,
                inset: config.bottom ? insets.bottom : insets.top)
        }
        renderWashes()
        CATransaction.commit()
    }

    /// Cuts the wash out under the bar's native items. A mask on the wash
    /// layer only, never on this view, which the engine clips.
    private func applyHoles() {
        guard !config.holes.isEmpty else {
            washLayer.mask = nil
            return
        }
        let path = UIBezierPath(rect: washLayer.bounds)
        for hole in config.holes {
            path.append(
                UIBezierPath(
                    roundedRect: hole, cornerRadius: min(hole.width, hole.height) / 2))
        }
        holeMask.frame = washLayer.bounds
        holeMask.fillRule = .evenOdd
        holeMask.path = path.cgPath
        washLayer.mask = holeMask
    }

    /// Colours the washes and shows the level's (cheap, every time) and
    /// re-renders the profile image only when the size or the edge changes:
    /// inline the first time, so the effect never shows up empty, off the
    /// main thread after.
    private func renderWashes() {
        let scale = traitCollection.displayScale > 0 ? traitCollection.displayScale : UIScreen.main.scale
        let width = Int((bounds.width * scale).rounded())
        let height = Int((bounds.height * scale).rounded())
        guard width > 0, height > 0 else { return }
        let adaptive = config.adaptive
        // The bright (or fixed) wash's colour; white unless a tint is given.
        var red: CGFloat = 1, green: CGFloat = 1, blue: CGFloat = 1, alpha: CGFloat = 1
        if let argb = config.tint {
            UIColor(argb: argb).getRed(&red, green: &green, blue: &blue, alpha: &alpha)
        }
        lightWash.backgroundColor =
            UIColor(red: red, green: green, blue: blue, alpha: CGFloat(EdgeBlurProfile.lightPeak)).cgColor
        // Full black: the layer's opacity carries the level.
        darkWash.backgroundColor = UIColor.black.cgColor
        fixedWash.backgroundColor = UIColor(red: red, green: green, blue: blue, alpha: alpha).cgColor
        fixedWash.isHidden = adaptive || config.tint == nil
        lightWash.isHidden = !adaptive
        darkWash.isHidden = !adaptive
        if adaptive {
            lightWash.opacity = level.lightOpacity(dark: config.isDark)
            darkWash.opacity = level.darkOpacity(dark: config.isDark)
        }
        let key = "\(width)x\(height) b\(config.bottom)"
        guard key != renderedKey else { return }
        let first = renderedKey == nil
        renderedKey = key
        let bottom = config.bottom
        let show = { [weak self] (image: CGImage?) in
            guard let self, self.renderedKey == key else { return }
            CATransaction.begin()
            CATransaction.setDisableActions(true)
            for mask in [self.fixedMask, self.lightMask, self.darkMask] {
                mask.contentsScale = scale
                mask.contents = image
            }
            CATransaction.commit()
        }
        if first {
            show(Self.profileImage(width: width, height: height, bottom: bottom))
        } else {
            DispatchQueue.global(qos: .userInitiated).async {
                let image = Self.profileImage(width: width, height: height, bottom: bottom)
                DispatchQueue.main.async { show(image) }
            }
        }
    }

    private func updateLevel() {
        guard let bright else { return }
        // The deep tracker may not have measured yet: mid until it has.
        let next: WashLevel = bright ? .light : (deep == true ? .deep : .mid)
        guard next != level else { return }
        level = next
        // The content's own brightness, whatever the wash: the system's bar
        // items follow it (a light glass over white even in a dark app).
        onLightChange?(next == .light)
        Self.spring(lightWash, to: next.lightOpacity(dark: config.isDark))
        Self.spring(darkWash, to: next.darkOpacity(dark: config.isDark))
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

    /// The washes' shape, as a mask at the layer's own resolution: alpha
    /// follows the tint curve per row, with ±0.5 code of dither per pixel.
    /// A ramp this slow quantises into visible bands otherwise. Shared by all
    /// three washes; their colours are their own.
    // ponytail: full-resolution RGBA (~3MB on a 3x bar); a narrower image
    // would stretch the dither into streaks.
    private static func profileImage(width: Int, height: Int, bottom: Bool) -> CGImage? {
        var pixels = [UInt8](repeating: 0, count: width * height * 4)
        for row in 0..<height {
            let fromTop = (Double(row) + 0.5) / Double(height)
            let alpha =
                EdgeBlurProfile.tint(
                    bottom ? 1 - fromTop : fromTop,
                    hold: bottom ? EdgeBlurProfile.bottomTintHold : EdgeBlurProfile.tintHold)
                * 255
            if alpha <= 0 { continue }
            let base = row * width * 4
            for x in 0..<width {
                // Premultiplied white: every channel carries the alpha.
                let a = UInt8(min(max(alpha + EdgeBlurProfile.hash(x, row) - 0.5, 0), 255).rounded())
                let i = base + x * 4
                pixels[i] = a
                pixels[i + 1] = a
                pixels[i + 2] = a
                pixels[i + 3] = a
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
                NativeLog.log("[EdgeBlur] _UILumaTrackingBackdropView unavailable: the wash stays light")
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

    /// Samples the 44pt bar past the safe-area inset: the system's own
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
    private var uniform = false

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        #if DEBUG
            if filter == nil { NativeLog.log("[EdgeBlur] CAFilter variableBlur is unavailable") }
            if NSClassFromString("CABackdropLayer") == nil { NativeLog.log("[EdgeBlur] CABackdropLayer is unavailable") }
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

    /// `uniform` blurs the whole layer at `sigma`, for `.hard`; otherwise the
    /// radius ramps down from the edge.
    func configure(sigma: CGFloat, bottom: Bool, uniform: Bool = false) {
        self.sigma = sigma
        self.bottom = bottom
        self.uniform = uniform
        // No blur: no backdrop. A hidden backdrop layer is not captured, so
        // the wash alone costs no offscreen pass every frame.
        isHidden = sigma <= 0
        guard sigma > 0, let filter else { return }
        let scale = window?.screen.scale
            ?? (traitCollection.displayScale > 0 ? traitCollection.displayScale : UIScreen.main.scale)
        filter.setValue(max(sigma, 0), forKey: "inputRadius")
        filter.setValue(
            Self.maskImage(sigmaPx: Double(sigma * scale), bottom: bottom, uniform: uniform),
            forKey: "inputMaskImage")
        // Renormalizes the kernel at the layer's bounds instead of averaging
        // in transparent black: no dark rim at the hugged edge.
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
                "cupertino_native_ui.edgeBlur.\(UInt(bitPattern: ObjectIdentifier(self).hashValue))",
                forKey: "groupName")
        }
        CATransaction.commit()
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // The mask's ramp depends on the pixel scale; rebuild it with the real one.
        configure(sigma: sigma, bottom: bottom, uniform: uniform)
    }

    /// 1 × 1024, alpha = fraction of `inputRadius` at that row, on the
    /// blur curve and geometric ramp. Row 0 is the top of the layer.
    private static func maskImage(sigmaPx: Double, bottom: Bool, uniform: Bool) -> CGImage? {
        let height = 1024
        var pixels = [UInt8](repeating: 0, count: height * 4)
        for row in 0..<height {
            let fromTop = (Double(row) + 0.5) / Double(height)
            let t = bottom ? 1 - fromTop : fromTop
            let fraction =
                uniform ? 1 : EdgeBlurProfile.radiusFraction(EdgeBlurProfile.blur(t), sigmaPx: sigmaPx)
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
