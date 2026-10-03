import UIKit
import UIKit.UIGestureRecognizerSubclass

/// Takes a touch back from a platform view's content, the way a
/// `UIScrollView` takes it back from its content when its pan begins.
///
/// A still finger reaches the native content after UIKit's 150ms
/// `delaysContentTouches` window — that is what highlights a row — while
/// Flutter's arena is still open. If the Flutter page then scrolls, Dart sends
/// `cancelTouches` (see `ScrollFriendlyPlatformViewRecognizer.onLost`) and this
/// recognizer recognizes: UIKit sends the content `touchesCancelled`, so the
/// row lets go of its highlight and no tap fires, and every recognizer in the
/// content is reset.
final class TouchCancelRecognizer: UIGestureRecognizer, UIGestureRecognizerDelegate {
    init() {
        super.init(target: nil, action: nil)
        cancelsTouchesInView = true
        delaysTouchesBegan = false
        delaysTouchesEnded = false
        delegate = self
    }

    /// Nothing to take back unless a touch is still down.
    func cancelTouches() {
        guard state == .possible, numberOfTouches > 0, let view else { return }
        state = .ended
        // `touchesCancelled` reaches the views; recognizers already tracking
        // the touch keep it unless reset — a disabled recognizer cancels.
        reset(in: view)
    }

    private func reset(in view: UIView) {
        for recognizer in view.gestureRecognizers ?? []
        where recognizer !== self && recognizer.isEnabled {
            recognizer.isEnabled = false
            recognizer.isEnabled = true
        }
        for subview in view.subviews { reset(in: subview) }
    }

    override func touchesEnded(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .failed
    }

    override func touchesCancelled(_ touches: Set<UITouch>, with event: UIEvent) {
        state = .failed
    }

    /// Never in anyone's way, until it takes the touch.
    func gestureRecognizer(
        _ gestureRecognizer: UIGestureRecognizer,
        shouldRecognizeSimultaneouslyWith other: UIGestureRecognizer
    ) -> Bool {
        true
    }
}
