import Flutter
import UIKit

/// A raw-pixel capture of a hosted platform view, for Flutter to draw in its
/// own layer tree while a route transition runs.
///
/// Drawn straight into the buffer sent over the channel, as premultiplied BGRA
/// (`ui.PixelFormat.bgra8888` in Dart): no intermediate image, no PNG.
@available(iOS 26.0, *)
enum PlatformViewSnapshot {

    /// Returns `bytes`/`width`/`height`/`rowBytes` for [view], or nil when
    /// there is nothing to capture — the Dart side then falls back to simply
    /// hiding the view for the transition.
    static func capture(_ view: UIView) -> [String: Any]? {
        let container = view as? HostingContainerView
        let outset = container?.edgeMaskOutset ?? 0

        // The container grown by the outset: `drawHierarchy` then includes what
        // subviews paint past their box (a switch's rim, a glass shadow).
        let capture = view.bounds.insetBy(dx: -outset, dy: -outset)
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
            // The capture starts outside the view, so the view's own origin
            // lands `outset` in from the top-left of the bitmap. This is the
            // ONLY place that offset is applied; `dx`/`dy` below tell Dart
            // where to put the result back.
            ctx.translateBy(x: -capture.minX, y: -capture.minY)

            UIGraphicsPushContext(ctx)
            defer { UIGraphicsPopContext() }

            // `afterScreenUpdates: false` avoids a flash; unlike `layer.render(in:)` it
            // captures Liquid Glass. `view.bounds`, not the enlarged rectangle: the
            // context is already translated.
            return view.drawHierarchy(in: view.bounds, afterScreenUpdates: false)
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
