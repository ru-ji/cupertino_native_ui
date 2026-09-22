import Flutter
import UIKit

/// A raw-pixel capture of a hosted platform view, for Flutter to draw in its
/// own layer tree while a route transition runs.
///
/// Drawn straight into the buffer sent over the channel, as premultiplied BGRA
/// (`ui.PixelFormat.bgra8888` in Dart): no intermediate image, no PNG.
@available(iOS 15.0, *)
enum PlatformViewSnapshot {

    /// Returns `bytes`/`width`/`height`/`rowBytes` for [view], or nil when
    /// there is nothing to capture — the Dart side then falls back to simply
    /// hiding the view for the transition.
    static func capture(_ view: UIView) -> [String: Any]? {
        // Photographed through the outset clip container, not the view: the
        // container is the view's box grown by the outset, and what a control
        // paints past its box (a switch's rim, a glass shadow) is inside it.
        // Photographing the view itself cut that shadow at the box edge, which
        // read as a grey square around a bar's glass buttons.
        let container = view as? HostingContainerView
        let target: UIView = container?.clipView ?? view
        let capture = target.convert(target.bounds, to: view)
        guard capture.width > 0, capture.height > 0 else { return nil }
        let origin = capture.origin

        // The view's own screen, not the main one: correct on an external
        // display, and correct in a scene that is not on screen yet.
        let scale = view.window?.screen.scale ?? UIScreen.main.scale
        let width = Int((capture.width * scale).rounded())
        let height = Int((capture.height * scale).rounded())
        guard width > 0, height > 0 else { return nil }

        let bytesPerRow = width * 4
        var pixels = Data(count: bytesPerRow * height)

        // Only a view fully on screen: glass laid out off screen has nothing behind
        // it and comes back grey. Declining makes Dart retry.
        // ponytail: polls off-screen views at 10Hz; notify from native on
        // window entry if that ever shows up in a profile.
        guard let window = view.window,
            window.bounds.contains(view.convert(view.bounds, to: window))
        else { return nil }

        let drawn = pixels.withUnsafeMutableBytes { raw -> Bool in
            guard let base = raw.baseAddress,
                let ctx = CGContext(
                    data: base,
                    width: width,
                    height: height,
                    bitsPerComponent: 8,
                    bytesPerRow: bytesPerRow,
                    space: CGColorSpaceCreateDeviceRGB(),
                    bitmapInfo: CGImageAlphaInfo.premultipliedFirst.rawValue
                        | CGBitmapInfo.byteOrder32Little.rawValue)
            else { return false }

            // CoreGraphics draws from the bottom-left, UIKit from the top-left.
            ctx.translateBy(x: 0, y: CGFloat(height))
            ctx.scaleBy(x: scale, y: -scale)

            UIGraphicsPushContext(ctx)
            defer { UIGraphicsPopContext() }

            // `afterScreenUpdates: false` avoids a flash; unlike `layer.render(in:)`
            // it captures Liquid Glass. The target's own bounds, which is the
            // bitmap's size: `rect` is where the whole hierarchy is drawn,
            // scaled to fit, so a rectangle of any other size resizes it.
            return target.drawHierarchy(in: target.bounds, afterScreenUpdates: false)
        }
        guard drawn else { return nil }

        return [
            "bytes": FlutterStandardTypedData(bytes: pixels),
            "width": width,
            "height": height,
            "rowBytes": bytesPerRow,
            // Where to put it back, in points, in the platform view's own
            // coordinates. Dart adds this to the widget's top-left and draws
            // the bitmap at this size — no arithmetic to keep in step on two
            // sides of the channel.
            "dx": Double(origin.x),
            "dy": Double(origin.y),
            "dw": Double(capture.width),
            "dh": Double(capture.height),
        ]
    }
}
