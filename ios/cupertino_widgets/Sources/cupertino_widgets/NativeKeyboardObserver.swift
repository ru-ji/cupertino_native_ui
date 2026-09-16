import Flutter
import UIKit

/// Reports the keyboard's position **every frame**, not just its final height.
///
/// Flutter only learns the keyboard's end state (`viewInsets` jumps to the
/// final value) and then runs its own animation over it, so anything that
/// moves with the keyboard drifts out of step with it. This observer follows
/// the real thing instead, in the two ways it can move:
///
/// * **Animating** (show/hide): a `CADisplayLink` reads the tracking view's
///   *presentation* layer each frame — the value Core Animation is actually
///   drawing, mid-flight, rather than the model value that already jumped to
///   the destination.
/// * **Interactively** (dragged down over the keyboard, with
///   `scrollDismissesKeyboard(.interactively)`): no animation is running, so
///   the display link has nothing to read. KVO on the tracking view's centre
///   catches each drag step instead.
///
/// The tracking view is a zero-height view pinned to the host view's
/// `keyboardLayoutGuide.topAnchor` — public API. The equivalent trick below
/// iOS 26 has to find the keyboard's own window by private class name; this
/// package is 26+, so it doesn't.
///
/// The technique is the one `react-native-keyboard-controller` uses.
@available(iOS 26.0, *)
final class NativeKeyboardObserver: NSObject {
    static let shared = NativeKeyboardObserver()

    /// One channel per engine that has registered the plugin — the host and
    /// every scaffold body / sheet. Events go to all of them: a body engine
    /// is a separate isolate with its own messenger, so a single channel
    /// would reach the host and leave every scaffold body deaf.
    private var channels: [FlutterMethodChannel] = []

    private let trackingView = KeyboardTrackingView()
    private var displayLink: CADisplayLink?
    private var centerObservation: NSKeyValueObservation?

    /// Target height of the current transition, for `progress`.
    private var targetHeight: CGFloat = 0
    private var lastReported: CGFloat = -1
    private var started = false

    func register(messenger: FlutterBinaryMessenger) {
        channels.append(
            FlutterMethodChannel(
                name: "cupertino_widgets/keyboard", binaryMessenger: messenger))
    }

    /// Starts observing. Idempotent — Dart calls it when the first listener
    /// attaches.
    func start() {
        guard !started else { return }
        started = true

        let link = CADisplayLink(target: self, selector: #selector(readFrame))
        // Falls back to 60 on displays without ProMotion.
        link.preferredFramesPerSecond = 120
        link.add(to: .main, forMode: .common)
        link.isPaused = true
        displayLink = link

        for name in [
            UIResponder.keyboardWillShowNotification,
            UIResponder.keyboardWillHideNotification,
            UIResponder.keyboardWillChangeFrameNotification,
        ] {
            NotificationCenter.default.addObserver(
                self, selector: #selector(keyboardWillMove(_:)), name: name, object: nil)
        }
        for name in [
            UIResponder.keyboardDidShowNotification,
            UIResponder.keyboardDidHideNotification,
        ] {
            NotificationCenter.default.addObserver(
                self, selector: #selector(keyboardDidMove(_:)), name: name, object: nil)
        }
    }

    func stop() {
        guard started else { return }
        started = false
        displayLink?.invalidate()
        displayLink = nil
        centerObservation?.invalidate()
        centerObservation = nil
        NotificationCenter.default.removeObserver(self)
        trackingView.detach()
    }

    deinit { stop() }

    // MARK: - Notifications

    @objc private func keyboardWillMove(_ notification: Notification) {
        let info = notification.userInfo
        let end = (info?[UIResponder.keyboardFrameEndUserInfoKey] as? NSValue)?.cgRectValue
        let screenHeight = trackingView.hostWindowHeight
        // A keyboard parked off the bottom of the screen is a hide.
        let height: CGFloat
        if notification.name == UIResponder.keyboardWillHideNotification {
            height = 0
        } else if let end = end, screenHeight > 0 {
            height = max(0, screenHeight - end.origin.y)
        } else {
            height = 0
        }
        targetHeight = height

        trackingView.attachToTopmostView()
        let duration = (info?[UIResponder.keyboardAnimationDurationUserInfoKey] as? Double) ?? 0.25
        let curve = (info?[UIResponder.keyboardAnimationCurveUserInfoKey] as? Int) ?? 7

        // The tracking view follows `keyboardLayoutGuide` through a
        // constraint, and a constraint-driven frame change only animates
        // inside an animation block. Without this its layer jumps straight to
        // the final position, `layer.presentation()` has nothing to
        // interpolate, and the display link reads the destination on its very
        // first tick — the keyboard slides while the reported height has
        // already arrived.
        UIView.animate(
            withDuration: duration, delay: 0,
            options: UIView.AnimationOptions(rawValue: UInt(curve) << 16)
        ) {
            self.trackingView.superview?.layoutIfNeeded()
        }

        send(
            event: "willChange", height: height,
            progress: height > 0 ? 0 : 1, duration: duration)

        // Interactive drags publish through KVO; an animation publishes
        // through the display link. They must not both run.
        centerObservation?.invalidate()
        centerObservation = nil
        displayLink?.isPaused = false
    }

    @objc private func keyboardDidMove(_ notification: Notification) {
        displayLink?.isPaused = true
        lastReported = -1
        let settled = notification.name == UIResponder.keyboardDidHideNotification ? 0 : targetHeight
        send(event: "didChange", height: settled, progress: settled > 0 ? 1 : 0, duration: 0)
        // Only once the keyboard is up does a drag-to-dismiss make sense.
        if settled > 0 { observeInteractiveDrag() }
    }

    // MARK: - Frame-by-frame

    @objc private func readFrame() {
        let height = trackingView.presentedHeight
        guard height >= 0, height != lastReported else { return }
        lastReported = height
        send(
            event: "move", height: height,
            progress: targetHeight > 0 ? min(1, height / targetHeight) : 0, duration: 0)
    }

    /// The keyboard being dragged down with a finger: no animation, so the
    /// presentation layer never changes and only KVO sees the movement.
    private func observeInteractiveDrag() {
        centerObservation?.invalidate()
        centerObservation = trackingView.observe(\.center, options: [.new]) {
            [weak self] view, _ in
            guard let self = self, self.displayLink?.isPaused == true else { return }
            let height = view.heightFromCenter
            guard height >= 0, height != self.lastReported else { return }
            self.lastReported = height
            self.send(
                event: "interactive", height: height,
                progress: self.targetHeight > 0 ? min(1, height / self.targetHeight) : 0,
                duration: 0)
        }
    }

    private func send(event: String, height: CGFloat, progress: CGFloat, duration: Double) {
        let arguments: [String: Any] = [
            "event": event,
            "height": Double(height),
            "progress": Double(progress),
            "duration": duration,
        ]
        for channel in channels {
            channel.invokeMethod("keyboard", arguments: arguments)
        }
    }
}

/// A zero-height view pinned to the host view's `keyboardLayoutGuide`, so its
/// own frame *is* the keyboard's top edge — including while UIKit animates it,
/// which is what the presentation layer exposes.
@available(iOS 26.0, *)
private final class KeyboardTrackingView: UIView {
    private weak var attachedTo: UIView?

    init() {
        super.init(frame: .zero)
        isUserInteractionEnabled = false
        isHidden = true
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    var hostWindowHeight: CGFloat {
        window?.bounds.height ?? UIScreen.main.bounds.height
    }

    /// Height read off the layer Core Animation is drawing right now.
    var presentedHeight: CGFloat {
        guard let presentation = layer.presentation(), let window = window else { return -1 }
        let y = presentation.frame.origin.y
        guard y > 0 else { return -1 }
        return max(0, window.bounds.height - y)
    }

    /// Same, from the KVO-observed centre (a drag moves the model layer, not
    /// a presentation one).
    var heightFromCenter: CGFloat {
        guard let window = window else { return -1 }
        return max(0, window.bounds.height - center.y)
    }

    func attachToTopmostView() {
        guard let host = Self.topView(), host !== attachedTo else { return }
        removeFromSuperview()
        host.addSubview(self)
        attachedTo = host
        translatesAutoresizingMaskIntoConstraints = false
        // Without this the guide stops at the safe area when the keyboard is
        // down, and every reported height is short by the home indicator.
        host.keyboardLayoutGuide.usesBottomSafeArea = false
        NSLayoutConstraint.activate([
            leadingAnchor.constraint(equalTo: host.leadingAnchor),
            trailingAnchor.constraint(equalTo: host.trailingAnchor),
            heightAnchor.constraint(equalToConstant: 0),
            bottomAnchor.constraint(equalTo: host.keyboardLayoutGuide.topAnchor),
        ])
    }

    func detach() {
        removeFromSuperview()
        attachedTo = nil
    }

    private static func topView() -> UIView? {
        let root = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController
        var top = root
        while let presented = top?.presentedViewController {
            top = presented
        }
        return top?.view
    }
}
