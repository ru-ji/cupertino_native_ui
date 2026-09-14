import Flutter
import ObjectiveC
import UIKit

/// **Probe.** A progressive blur drawn by Core Animation, the way UIKit's own
/// scroll edge effect draws it, with the system's adaptive wash on top.
///
/// UIKitCore's `ScrollEdgeEffectView.PocketBlur` is a variable blur whose
/// radius follows a mask image (`_effectWithVariableBlurRadius:imageMask:`),
/// i.e. Core Animation's `variableBlur` filter with `inputMaskImage`. This view
/// does the same on the `CABackdropLayer` inside a `UIVisualEffectView`, so it
/// samples everything composited beneath it — Flutter's surface and native
/// controls alike, glass included, live.
///
/// Both curves are Haze's (`haze.dart`): the blur holds, falls on a
/// smootherstep and ramps its radius geometrically; the wash holds for its own
/// fraction and falls on a smootherstep. The wash is rendered per pixel into
/// an image with sub-code dither, not as gradient stops, so it has no steps.
///
/// Built to avoid the ways a hand-made effect renders nothing inside Flutter:
///
/// - **No `layer.mask`, anywhere.** The embedder clips a platform view with a
///   `maskView` on its container; a masked effect view under that is a nested
///   mask, which UIKit renders as nothing.
/// - **Never an alpha on the effect view.** Strength goes into the radius and
///   the wash images.
/// - **Filters re-applied** after every layout and trait change, because
///   `UIVisualEffectView` reinstalls its material filters on its own.
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
    /// Peak radius at the edge, points. Already fitted to the height by Dart
    /// (`Haze.fitSigma`), so this and Haze blur the same amount.
    var sigma: CGFloat
    var bottom: Bool
    /// ARGB32; its alpha is the peak opacity at the edge. Nil for none.
    /// Ignored when `adaptive`.
    var tint: Int?
    /// The system's luma-tracked light/dark wash.
    var adaptive: Bool
    /// Calibration factor on `inputRadius`, which is not documented to be a
    /// Gaussian sigma: the factor that makes this match Haze at equal sigma.
    var radiusScale: CGFloat
    /// The app theme: what the wash shows before the first luma measurement.
    var isDark: Bool
    /// 0…1: scales the blur's radius and fades the washes together — the
    /// system's effect comes up from zero as a collapsing header takes the
    /// content under it.
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

/// The curves, shared with `haze.dart` — keep the constants in step.
enum EdgeBlurProfile {
    static let blurHold = 0.41
    static let tintHold = 0.35

    /// Peak of the white wash over near-white content, measured frame by
    /// frame off iOS 26's own soft effect (light mode, 40pt deep): ~84–85%.
    /// Content hue is not used — equal alpha on R, G and B.
    static let lightPeak = 0.85
    /// The dark wash's two levels. The system's LuminanceAdjustment settles
    /// at three opacities (0.85, 0.6, 0.3); 0.6 is the warm gradient, measured
    /// at black ~27%. If the darkening scales with (1 - opacity) as that one
    /// point implies, 0.3 is ~47% — the darker wash seen past the black band.
    // ponytail: deepDark derived from one measurement; tune by eye against the
    // system page.
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

    /// Fraction of the peak radius at profile `p`, on Haze's geometric ramp
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
        #if DEBUG
            print("[EdgeBlur] apply adaptive=\(config.adaptive) sigma=\(config.sigma) tracker=\(luma != nil)")
        #endif
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
            // The bright wash is the page's own background — white unless the
            // caller says otherwise. Only the colour is used; the peak is the
            // system's.
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

    #if DEBUG
        /// Why Flutter content drawn above this blur can end up inside it: the
        /// FlutterView's stacking, bottom to top, and every backdrop layer over
        /// this rectangle with its capture group. Printed when it changes.
        private var compositionTimer: Timer?
        private var lastComposition = ""

        deinit { compositionTimer?.invalidate() }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            compositionTimer?.invalidate()
            guard window != nil else { return }
            compositionTimer = Timer.scheduledTimer(withTimeInterval: 1, repeats: true) { [weak self] _ in
                self?.dumpComposition()
            }
        }

        private func dumpComposition() {
            guard let window else { return }
            let mine = convert(bounds, to: window)
            var lines = ["this blur \(mine.integral)"]
            var ancestor = superview
            while let view = ancestor, !String(describing: type(of: view)).hasPrefix("FlutterView") {
                ancestor = view.superview
            }
            if let flutterView = ancestor {
                for (index, sub) in flutterView.subviews.enumerated() {
                    var chain: [String] = []
                    var node: UIView? = sub
                    while let current = node, chain.count < 4 {
                        chain.append(String(describing: type(of: current)))
                        node = current.subviews.first
                    }
                    let frame = sub.convert(sub.bounds, to: window).integral
                    let overlapsMe = frame.intersects(mine) ? " OVERLAPS" : ""
                    let isMe = isDescendant(of: sub) ? " <- THIS BLUR" : ""
                    lines.append(
                        "z\(index) \(chain.joined(separator: ">")) frame=\(frame) alpha=\(sub.alpha) hidden=\(sub.isHidden)\(overlapsMe)\(isMe)")
                }
            } else {
                lines.append("no FlutterView ancestor")
            }
            func walk(_ layer: CALayer) {
                if String(describing: type(of: layer)).contains("Backdrop") {
                    let frame = layer.convert(layer.bounds, to: window.layer).integral
                    if frame.intersects(mine) {
                        let group =
                            layer.responds(to: NSSelectorFromString("groupName"))
                            ? String(describing: layer.value(forKey: "groupName")) : "?"
                        lines.append("backdrop \(type(of: layer)) group=\(group) frame=\(frame)")
                    }
                }
                for sub in layer.sublayers ?? [] { walk(sub) }
            }
            walk(window.layer)
            let dump = lines.joined(separator: "\n")
            guard dump != lastComposition else { return }
            lastComposition = dump
            for line in lines { print("[EdgeBlur] composition \(line)") }
        }
    #endif

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

    /// The system's transition, measured: a critically damped spring,
    /// ω ≈ 12.25 rad/s (response ≈ 0.51s) — 50% at +137ms, 90% at +318ms.
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
    /// follows Haze's tint curve per row, with ±0.5 code of dither per pixel —
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

/// Luminance of what is behind the bar, measured by the render server through
/// the same `_UILumaTrackingBackdropView` UIKit's scroll pocket uses, reduced
/// to the system's two states with hysteresis.
///
/// Every call here is checked against UIKitCore's own metadata:
/// `initWithTransitionBoundaries:delegate:frame:` takes `{?=dd}`, an object
/// and a CGRect; its delegate protocol requires
/// `backgroundLumaView:didTransitionToLevel:` with an NSUInteger, which is the
/// only callback that actually arrives.
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
        #if DEBUG
            startDiagnostics()
        #endif
    }

    #if DEBUG
        /// Why no luma arrives: what the tracking view is made of, and its level
        /// read directly — in case it measures without calling its delegate.
        private var diagnostics: Timer?
        private var lastPoll = ""

        deinit { diagnostics?.invalidate() }

        private func startDiagnostics() {
            guard let view = trackingView else { return }
            print(
                "[EdgeBlur] luma view \(type(of: view)) delegate=\(String(describing: view.value(forKey: "delegate"))) paused=\(String(describing: view.value(forKey: "paused"))) boundaries=\(String(describing: view.value(forKey: "transitionBoundaries")))"
            )
            func walk(_ layer: CALayer, _ depth: Int) {
                var line = String(repeating: "  ", count: depth) + "\(type(of: layer)) frame=\(layer.frame)"
                for key in ["tracksLuma", "tracksLumaWhileHidden", "lumaSubrect", "lumaUpdateRate", "groupName", "scale"]
                where layer.responds(to: NSSelectorFromString(key)) {
                    line += " \(key)=\(String(describing: layer.value(forKey: key)))"
                }
                print("[EdgeBlur]   layer \(line)")
                for sub in layer.sublayers ?? [] { walk(sub, depth + 1) }
            }
            walk(view.layer, 0)
            diagnostics = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
                guard let self, let view = self.trackingView else { return }
                let poll =
                    "level=\(String(describing: view.value(forKey: "backgroundLuminanceLevel"))) window=\(view.window != nil) frame=\(view.frame) paused=\(String(describing: view.value(forKey: "paused")))"
                guard poll != self.lastPoll else { return }
                self.lastPoll = poll
                print("[EdgeBlur] poll \(poll)")
            }
        }
    #endif

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
        #if DEBUG
            diagnostics?.invalidate()
        #endif
        trackingView?.removeFromSuperview()
        trackingView = nil
    }

    /// The only callback `_UILumaTrackingBackdropView` delivers (verified on
    /// device: `didChangeLuma:` never arrives). With the boundaries passed at
    /// init, level 1 is content ABOVE them and 2 below — checked on device:
    /// white bands report 1, black ones 2 — and 0 is "not measured yet".
    /// UIKit applies the hysteresis itself.
    @objc(backgroundLumaView:didTransitionToLevel:)
    func backgroundLumaView(_ source: UIView, didTransitionToLevel level: UInt) {
        #if DEBUG
            print("[EdgeBlur] luma \(low)-\(high) level \(level)")
        #endif
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
/// Not a `UIVisualEffectView`. On device, the title Flutter draws ABOVE this
/// blur — in its own overlay view, higher in the stacking, with this layer in
/// a capture group of its own — still came back blurred inside it. UIKit's
/// backdrop layer takes part in UIKit's visual-effect capture groups
/// (`_UIVisualEffectViewBackdropCaptureGroup`); a plain `CABackdropLayer` is
/// outside that machinery. It also means UIKit never reinstalls its material
/// filters over ours, so nothing has to be re-applied on layout or traits.
// ponytail: that the capture groups are the cause is the hypothesis this
// class tests; the DEBUG log prints the layer's capture flags for the next step.
@available(iOS 15.0, *)
final class BackdropBlurView: UIView {
    override class var layerClass: AnyClass {
        NSClassFromString("CABackdropLayer") ?? CALayer.self
    }

    private let filter: NSObject? = BackdropBlurView.makeFilter()
    /// Kept so the mask can be rebuilt once the real screen scale is known.
    private var sigma: CGFloat = 0
    private var bottom = false
    #if DEBUG
        private var logged = false
    #endif

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

        #if DEBUG
            if !logged {
                logged = true
                let keys = [
                    "captureOnly", "windowServerAware", "allowsInPlaceFiltering",
                    "disablesOccludedBackdropBlurs", "ignoresOffscreenGroups",
                    "usesGlobalGroupNamespace", "scale", "groupName",
                ]
                let flags = keys.map { "\($0)=\(String(describing: layer.value(forKey: $0)))" }
                print("[EdgeBlur] backdrop \(type(of: layer)) \(flags.joined(separator: " "))")
            }
        #endif
    }

    override func didMoveToWindow() {
        super.didMoveToWindow()
        // The mask's ramp depends on the pixel scale; rebuild it with the real one.
        configure(sigma: sigma, bottom: bottom)
    }

    /// 1 × 1024, alpha = fraction of `inputRadius` at that row, on Haze's
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
