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
        let container = view as? HostingContainerView
        let outset = container?.edgeMaskOutset ?? 0

        // The CONTAINER, and its own rectangle grown by the margin the cut
        // works in.
        //
        // `drawHierarchy(in:)` renders a view's hierarchy — anything a subview
        // paints outside the box it lays out in comes along, which is the only
        // way to keep the switch's rim or a glass shadow. Rendering the hosted
        // child instead loses exactly those, because they fall outside the
        // child and the child is all that is drawn: the switch comes back with
        // its ends shaved.
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

        // Off for the duration, and restored after. See `afterScreenUpdates`
        // below for why the two go together.
        let mask = view.layer.mask
        view.layer.mask = nil
        defer { view.layer.mask = mask }

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

            // `afterScreenUpdates: true`, which the cheap path (`false`) cannot
            // replace here. `false` reuses what is already on screen, and what
            // is already on screen is very often the CUT view — the picture
            // that replaces the hidden band would come back missing the band,
            // and each refresh would take a little more until the control
            // faded to nothing. Taking the mask off first does not help
            // either: with `false` the change has not reached the screen yet.
            //
            // `true` commits the pending state — mask removed, just above —
            // and renders fresh. It is the expensive call, and it is affordable
            // precisely because this is no longer taken on approach: a control
            // is photographed when it appears and when its state changes, not
            // while it is moving.
            //
            // Unlike `layer.render(in:)` it captures `UIVisualEffectView`
            // content, so Liquid Glass survives the round trip. It returns
            // false for a view that has never rendered, which the Dart side
            // answers by asking again.
            // `view.bounds`, not the enlarged rectangle: the context has
            // already been translated so that the enlarged rectangle's origin
            // is at 0,0. Passing the enlarged one here as well applies the
            // offset twice — the control lands a margin down and to the right,
            // and the band drawn in the bar is the empty margin.
            return view.drawHierarchy(in: view.bounds, afterScreenUpdates: true)
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
