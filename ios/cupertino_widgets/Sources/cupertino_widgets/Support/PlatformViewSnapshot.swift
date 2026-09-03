import Flutter
import UIKit

/// A raw-pixel capture of a hosted platform view, for Flutter to draw in its
/// own layer tree while a route transition runs.
///
/// The embedder positions a platform view on the platform thread, a step
/// behind the Flutter layer it belongs to, so during a transition the native
/// view does not follow the slide. Handing Flutter a bitmap lets it draw the
/// control itself for the length of the animation, where it moves in step with
/// everything around it.
///
/// This runs on the frame a transition starts — already the busiest frame — so
/// it is kept to a single pass: the view is drawn straight into the buffer that
/// crosses the channel. No intermediate `UIImage`, and no PNG encode, which
/// would cost more than the draw itself several times over. Pixels come back as
/// premultiplied BGRA, which is `ui.PixelFormat.bgra8888` on the Dart side, so
/// nothing has to be converted or decoded there either.
@available(iOS 15.0, *)
enum PlatformViewSnapshot {

    /// Returns `bytes`/`width`/`height`/`rowBytes` for [view], or nil when
    /// there is nothing to capture — the Dart side then falls back to simply
    /// hiding the view for the transition.
    static func capture(_ view: UIView) -> [String: Any]? {
        // The HOSTED view, not the container — and this is the whole trick.
        //
        // The container is where the edge cut lives, and a capture taken while
        // that cut is on comes back with the cut baked in: the picture that
        // replaces the hidden band is itself missing the band, and the next
        // refresh takes a little more. The control fades to nothing in a few
        // frames. Taking the mask off first does not help either, because
        // `afterScreenUpdates: false` means "reuse what is already on screen"
        // and the screen still has the masked version — the change would only
        // land a frame later.
        //
        // The hosted view is never masked. Its own backing store is whole,
        // masking being something the parent applies at composite time, so
        // this is a picture of the control as it would look uncut, taken while
        // it is cut, at no cost.
        let container = view as? HostingContainerView
        let target = container?.hostedController?.view ?? view
        let outset = container?.edgeMaskOutset ?? 0

        // Past the target's own bounds: a UIKit control PAINTS outside the
        // frame it lays out in — the switch's rim, a glass shadow — and a
        // bitmap taken at the bounds loses those sides the moment Flutter
        // draws it in place of the live view.
        let capture = target.bounds.insetBy(dx: -outset, dy: -outset)
        guard capture.width > 0, capture.height > 0 else { return nil }

        // Where that rectangle sits inside the platform view Flutter placed,
        // so Dart can put the picture back exactly where the control is. The
        // hosted view is centred inside its container for the controls that
        // hug their content, so this is rarely zero.
        let origin = target.convert(capture.origin, to: view)

        // The view's own screen, not the main one: correct on an external
        // display, and correct in a scene that is not on screen yet.
        let scale = view.window?.screen.scale ?? UIScreen.main.scale
        let width = Int((capture.width * scale).rounded())
        let height = Int((capture.height * scale).rounded())
        guard width > 0, height > 0 else { return nil }

        let bytesPerRow = width * 4
        var pixels = Data(count: bytesPerRow * height)

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
            // lands `outset` in from the top-left of the bitmap. Dart offsets
            // the destination rectangle by the same amount.
            ctx.translateBy(x: -capture.minX, y: -capture.minY)

            UIGraphicsPushContext(ctx)
            defer { UIGraphicsPopContext() }

            // `afterScreenUpdates: false` reuses what is already on screen: the
            // cheap path, and the only one safe here — `true` forces a
            // synchronous screen update mid-transition. Unlike
            // `layer.render(in:)` it captures `UIVisualEffectView` content, so
            // Liquid Glass survives the round trip.
            //
            // It returns false for a view that has never rendered — a control
            // on a route being pushed for the first time. Reporting that as a
            // failure is deliberate: a blank bitmap laid over the control would
            // be worse than the hole hiding it leaves.
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
