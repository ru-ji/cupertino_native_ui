import UIKit

#if DEBUG
    /// **Debug probe.** Dumps the system scroll edge effect's views, layers,
    /// filters and images to the console, so `NativeEdgeBlurView` can copy
    /// Apple's values instead of values measured off screen recordings.
    ///
    /// Polls every 2s and prints only when the dump changed, so scrolling a
    /// bright band then a dark one under the bar shows what the adaptive tint
    /// actually changes.
    ///
    /// Filter inputs are read only by keys QuartzCore is known to define for
    /// that filter type: a private filter asked for a key it does not have can
    /// raise, and Swift cannot catch that.
    @available(iOS 15.0, *)
    final class EdgeEffectIntrospector {
        private weak var root: UIView?
        private var timer: Timer?
        private var lastDump = ""

        init(root: UIView) {
            self.root = root
            timer = Timer.scheduledTimer(withTimeInterval: 2, repeats: true) { [weak self] _ in
                self?.tick()
            }
        }

        deinit { timer?.invalidate() }

        private func tick() {
            guard let root, root.window != nil else { return }
            var lines: [String] = []

            var scrollViews: [UIScrollView] = []
            Self.collect(in: root, into: &scrollViews)
            for scrollView in scrollViews {
                var line = "scrollView \(type(of: scrollView)) offset=\(Self.point(scrollView.contentOffset))"
                if #available(iOS 26.0, *) {
                    line += " topEdgeEffect=\(scrollView.topEdgeEffect.style) hidden=\(scrollView.topEdgeEffect.isHidden)"
                }
                lines.append(line)
            }

            var effects: [UIView] = []
            Self.effectRoots(in: root, into: &effects)
            if effects.isEmpty { lines.append("no ScrollEdgeEffect/Pocket view under the scaffold") }
            for effect in effects {
                lines.append("=== \(type(of: effect)) in window \(Self.rect(effect.convert(effect.bounds, to: nil)))")
                Self.dump(view: effect, depth: 1, lines: &lines)
            }

            if let window = root.window {
                func walkBackdrops(_ layer: CALayer, _ path: String) {
                    let here = "\(path)/\(type(of: layer))"
                    if String(describing: type(of: layer)).contains("Backdrop") {
                        let group = layer.responds(to: NSSelectorFromString("groupName"))
                            ? String(describing: layer.value(forKey: "groupName")) : "?"
                        lines.append(
                            "window backdrop group=\(group) frame=\(Self.rect(layer.convert(layer.bounds, to: window.layer))) opacity=\(Self.number(CGFloat(layer.opacity))) owner=\(layer.delegate.map { String(describing: type(of: $0)) } ?? "-") path=\(here.suffix(160))")
                    }
                    for sub in layer.sublayers ?? [] { walkBackdrops(sub, here) }
                }
                walkBackdrops(window.layer, "")
            }

            if lines.count > 600 {
                lines = Array(lines.prefix(600)) + ["… truncated"]
            }
            let dump = lines.joined(separator: "\n")
            guard dump != lastDump else { return }
            lastDump = dump
            print("[EdgeEffectDump] ---- \(Date())")
            for line in lines { print("[EdgeEffectDump] \(line)") }
        }

        // MARK: - Walking

        private static func collect(in view: UIView, into out: inout [UIScrollView]) {
            if let scrollView = view as? UIScrollView { out.append(scrollView) }
            for sub in view.subviews { collect(in: sub, into: &out) }
        }

        private static func effectRoots(in view: UIView, into out: inout [UIView]) {
            let name = String(describing: type(of: view))
            if name.contains("ScrollEdgeEffect") || name.contains("Pocket") {
                out.append(view)
                return
            }
            for sub in view.subviews { effectRoots(in: sub, into: &out) }
        }

        private static func dump(view: UIView, depth: Int, lines: inout [String]) {
            guard depth < 14 else { return }
            let pad = String(repeating: "  ", count: depth)
            var line = "\(pad)view \(type(of: view)) frame=\(rect(view.frame)) alpha=\(number(view.alpha))"
            if view.isHidden { line += " HIDDEN" }
            if let background = view.backgroundColor { line += " bg=\(color(background.cgColor))" }
            if let effectView = view as? UIVisualEffectView {
                line += " effect=\(String(describing: effectView.effect))"
            }
            lines.append(line)
            let subviewLayers = Set(view.subviews.map { ObjectIdentifier($0.layer) })
            dump(layer: view.layer, depth: depth + 1, skipping: subviewLayers, lines: &lines)
            for sub in view.subviews { dump(view: sub, depth: depth + 1, lines: &lines) }
        }

        private static func dump(
            layer: CALayer, depth: Int, skipping: Set<ObjectIdentifier>, lines: inout [String]
        ) {
            guard depth < 16 else { return }
            let pad = String(repeating: "  ", count: depth)
            var line = "\(pad)layer \(type(of: layer)) frame=\(rect(layer.frame)) opacity=\(number(CGFloat(layer.opacity)))"
            if layer.isHidden { line += " HIDDEN" }
            if let background = layer.backgroundColor { line += " bg=\(color(background))" }
            if let compositing = layer.compositingFilter { line += " compositingFilter=\(compositing)" }
            if let mask = layer.mask { line += " mask=\(type(of: mask))\(rect(mask.frame))" }
            if layer.cornerRadius > 0 { line += " cornerRadius=\(number(layer.cornerRadius))" }
            if let name = layer.name { line += " name=\(name)" }
            if layer.shadowOpacity > 0 {
                line +=
                    " shadow(color=\(layer.shadowColor.map(color) ?? "nil") opacity=\(number(CGFloat(layer.shadowOpacity))) radius=\(number(layer.shadowRadius)) offset=(\(number(layer.shadowOffset.width)),\(number(layer.shadowOffset.height))) path=\(layer.shadowPath.map { rect($0.boundingBox) } ?? "nil"))"
            }
            // Portals: what they mirror, and how.
            for key in ["sourceLayer", "hidesSourceLayer", "matchesOpacity", "matchesPosition", "matchesTransform"]
            where layer.responds(to: NSSelectorFromString(key)) {
                guard let value = layer.value(forKey: key) else { continue }
                if let source = value as? CALayer {
                    line += " \(key)=\(type(of: source))\(source.name.map { "(\($0))" } ?? "")\(rect(source.frame))"
                } else {
                    line += " \(key)=\(value)"
                }
            }
            // Backdrop properties, only where the layer answers to them.
            for key in ["groupName", "scale", "captureOnly", "tracksLuma", "lumaSubrect", "lumaUpdateRate"]
            where layer.responds(to: NSSelectorFromString(key)) {
                if let value = layer.value(forKey: key) { line += " \(key)=\(value)" }
            }
            lines.append(line)

            if let gradient = layer as? CAGradientLayer {
                let colors = (gradient.colors ?? []).map { color($0 as! CGColor) }
                lines.append(
                    "\(pad)  gradient type=\(gradient.type.rawValue) start=\(point(gradient.startPoint)) end=\(point(gradient.endPoint)) locations=\((gradient.locations ?? []).map { number(CGFloat($0.doubleValue)) }) colors=\(colors)"
                )
            }
            if let contents = layer.contents {
                let object = contents as AnyObject
                if CFGetTypeID(object) == CGImage.typeID {
                    lines.append("\(pad)  contents \(image(object as! CGImage))")
                } else {
                    lines.append("\(pad)  contents \(type(of: contents))")
                }
            }
            for filter in layer.filters ?? [] {
                lines.append("\(pad)  filter \(describe(filter))")
            }
            if layer.responds(to: NSSelectorFromString("backgroundFilters")),
                let filters = layer.value(forKey: "backgroundFilters") as? [Any]
            {
                for filter in filters { lines.append("\(pad)  backgroundFilter \(describe(filter))") }
            }
            for sub in layer.sublayers ?? [] where !skipping.contains(ObjectIdentifier(sub)) {
                dump(layer: sub, depth: depth + 1, skipping: [], lines: &lines)
            }
        }

        // MARK: - Filters

        /// Inputs QuartzCore defines per filter type (from its own strings).
        private static let inputs: [String: [String]] = [
            "variableBlur": [
                "inputRadius", "inputMaskImage", "inputNormalizeEdges",
                "inputNormalizeEdgesTransparent", "inputDither", "inputHardEdges",
            ],
            "gaussianBlur": [
                "inputRadius", "inputQuality", "inputNormalizeEdges", "inputHardEdges",
                "inputDither",
            ],
            "colorMatrix": ["inputColorMatrix"],
            "vibrantColorMatrix": ["inputColorMatrix"],
            "colorSaturate": ["inputAmount"],
            "colorBrightness": ["inputAmount"],
            "colorContrast": ["inputAmount"],
        ]

        private static func describe(_ filter: Any) -> String {
            guard let object = filter as? NSObject else { return String(describing: filter) }
            let name = (object.value(forKey: "name") as? String) ?? "?"
            var out = "\(name) \(object)"
            for key in inputs[name] ?? [] {
                guard let value = object.value(forKey: key) else {
                    if key == "inputMaskImage" { out += " inputMaskImage=nil" }
                    continue
                }
                out += " \(key)=\(describe(value: value))"
            }
            return out
        }

        private static func describe(value: Any) -> String {
            let object = value as AnyObject
            if CFGetTypeID(object) == CGImage.typeID { return image(object as! CGImage) }
            if let nsValue = value as? NSValue, String(cString: nsValue.objCType).contains("CAColorMatrix") {
                var matrix = [Float](repeating: 0, count: 20)
                matrix.withUnsafeMutableBytes { raw in
                    nsValue.getValue(raw.baseAddress!, size: MemoryLayout<Float>.size * 20)
                }
                return "matrix\(matrix.map { String(format: "%.3f", $0) })"
            }
            return String(describing: value)
        }

        // MARK: - Images

        /// Size, then RGBA samples down the middle column and across the
        /// middle row — enough to read a gradient mask's curve.
        private static func image(_ image: CGImage) -> String {
            let side = 64
            var pixels = [UInt8](repeating: 0, count: side * side * 4)
            let drawn = pixels.withUnsafeMutableBytes { raw -> Bool in
                guard
                    let context = CGContext(
                        data: raw.baseAddress, width: side, height: side, bitsPerComponent: 8,
                        bytesPerRow: side * 4, space: CGColorSpaceCreateDeviceRGB(),
                        bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)
                else { return false }
                context.draw(image, in: CGRect(x: 0, y: 0, width: side, height: side))
                return true
            }
            var out = "image \(image.width)x\(image.height)"
            guard drawn else { return out + " (unreadable)" }
            func sample(_ x: Int, _ y: Int) -> String {
                let i = (y * side + x) * 4
                return "\(pixels[i]),\(pixels[i + 1]),\(pixels[i + 2]),\(pixels[i + 3])"
            }
            let steps = 16
            // Buffer row 0 is the image's top row.
            let down = (0...steps).map { sample(side / 2, min($0 * side / steps, side - 1)) }
            let across = (0...8).map { sample(min($0 * side / 8, side - 1), side / 2) }
            out += " down(rgba top→bottom)=\(down) across=\(across)"
            return out
        }

        // MARK: - Formatting

        private static func number(_ value: CGFloat) -> String { String(format: "%.3f", value) }

        private static func point(_ p: CGPoint) -> String {
            "(\(number(p.x)),\(number(p.y)))"
        }

        private static func rect(_ r: CGRect) -> String {
            "[\(number(r.minX)),\(number(r.minY)) \(number(r.width))x\(number(r.height))]"
        }

        private static func color(_ cgColor: CGColor) -> String {
            let space = cgColor.colorSpace?.name.map { $0 as String } ?? "?"
            let components = (cgColor.components ?? []).map { String(format: "%.3f", $0) }
            return "\(components.joined(separator: ","))@\(space.replacingOccurrences(of: "kCGColorSpace", with: ""))"
        }
    }
#endif
