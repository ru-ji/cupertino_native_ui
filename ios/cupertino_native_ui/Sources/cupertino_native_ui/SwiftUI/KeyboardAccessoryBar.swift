import SwiftUI
import UIKit

/// The bar above the keyboard, installed as the focused field's real input
/// accessory.
///
/// ## Why UIKit `inputAccessoryView`, not SwiftUI's `.keyboard` toolbar
///
/// `ToolbarItemGroup(placement: .keyboard)` is the documented SwiftUI way, and
/// it is what this used to be, but it resolves to nothing, or crashes on the
/// first focus, when the SwiftUI tree is a child `UIHostingController` embedded
/// in a Flutter platform view, which is how every widget in this package is
/// hosted. The system negotiates an accessory region with no bar in it and the
/// keyboard never shows one, and there is no public SwiftUI way to control the
/// bar's material either (the `.keyboard` chrome belongs to the system).
///
/// The supported UIKit route is `UITextField.inputAccessoryView` (read-write on
/// the field types SwiftUI's `TextField` is backed by) with a transparent
/// accessory view. UIKit gives the accessory its own strip above the keyboard,
/// so the bar lands inside the keyboard's own frame, it makes the keyboard
/// taller rather than floating over it, and the bar draws no slab of its own
/// where the SwiftUI placement drew one. The strip is left unpainted, so the
/// page shows through it; see [KeyboardInputView].
///
/// ## What the first cut got wrong
///
/// Three faults, all of them visible in the log long before they were visible
/// on screen, which is why the install path logs where the bar ended up.
///
/// 1. **The bar was one point wide.** `KeyboardInputView` was built with a frame
///    width of `UIView.noIntrinsicMetric` and answered `intrinsicContentSize`
///    with the same value. `UIPeripheralHost` took that literally and installed
///    the accessory at `frame = (-1 0; 1 48)`: an invisible sliver. The frame
///    and the intrinsic size both need real numbers now; the keyboard stretches
///    the bar to its own width once it is placed.
///
/// 2. **The accessory was never placed without a reload.** Assigning
///    `inputAccessoryView` on a field that is already the responder registers
///    the view (it comes back from the property, and UIKit lists it in the
///    input view set) but does not add it to the hierarchy. Measured: the bar
///    stayed a root view, `superview == nil`, `window == nil`, with the
///    SwiftUI content never laid out (`contentSubviews == 0`) and nothing on
///    screen. `reloadInputViews()` is what makes UIKit rebuild the input views
///    around it. (The `.keyboard` style of `UIInputView` makes no difference
///    either way: it is not placed with the style, without it, or as a plain
///    `UIView`, so a plain view is what this uses.)
///
/// 3. **The bar was rebuilt on every config push, which is the choppiness.**
///    The "did the toolbar change?" test compared a `JSONEncoder` re-encoding
///    of the decoded config, and that is not a stable identity: measured, two
///    encodes of one unchanged three-node toolbar came back with the keys in
///    different orders (`{"type","id","isDark"}` against
///    `{"type","isDark","id"}`). Every push therefore looked like a change, so
///    the bar was rebuilt and `reloadInputViews()` ran *under a keyboard that
///    was already up*: tearing down and rebuilding the input view set
///    mid-edit. Three rebuilds in a twenty-second run that typed nothing.
///    The identity is now the payload Dart sent, compared with `isEqual:` the
///    way the rest of this file compares configs.
///
/// ## Attached before focus
///
/// The field is a `UITextField` we own ([BackingTextField]), so the bar is set
/// as its accessory while the field is still unfocused and rides up in the
/// keyboard's own presentation. (With SwiftUI's `TextField` it had to be
/// attached after focus plus `reloadInputViews()`, which made the bar land a
/// beat late and broke it on field-to-field switches.)
///
/// ## Why the hosting controller lives as long as the bar
///
/// A hosting view only weakly references its controller, and an accessory that
/// outlives a released host is exactly the invalid SwiftUI state that crashed
/// the previous `.keyboard`-based toolbar. The bar therefore owns its
/// `UIHostingController` for its whole lifetime, and the bar itself is retained
/// by the platform view until the toolbar's nodes change, so the keyboard walk
/// never touches a dead host.
///
/// The SwiftUI content is the same lowered `BodyNodeConfig` tree a native body
/// renders, so a `CupertinoNativeButton` in `toolbarActions` becomes a real
/// SwiftUI button here.
@available(iOS 15.0, *)
final class KeyboardAccessoryBar: NSObject {
    /// Height for a bar whose content states no size of its own. The bar
    /// otherwise measures its SwiftUI content, so what surrounds the items is
    /// the caller's padding, not a number invented here. UIKit puts no ceiling
    /// on an accessory's height: it is added to the keyboard's frame.
    static let fallbackHeight: CGFloat = 44

    /// The keyboard-styled, transparent accessory view handed to the field.
    let inputView: KeyboardInputView

    /// Hosts the lowered toolbar tree. Retained here for the whole bar's
    /// lifetime, so the hosting view is never left pointing at a dead host.
    private let contentHost: ClearHostingController<AnyView>

    init(
        nodes: [BodyNodeConfig],
        isDark: Bool,
        onEvent: @escaping (String, Any?) -> Void
    ) {
        let model = NativeBodyModel()
        model.seedAll(nodes)

        let bar = AnyView(
            HStack(spacing: 16) {
                ForEach(Array(nodes.enumerated()), id: \.offset) { index, node in
                    NativeBodyNode(node: node, model: model, onEvent: onEvent)
                        .id(node.id ?? "\(node.type)-\(index)")
                }
            }
            // Width fills the bar; height is the content's own, so measuring
            // it gives the bar its height.
            .frame(maxWidth: .infinity)
        )

        let host = ClearHostingController(rootView: bar)
        host.overrideUserInterfaceStyle = isDark ? .dark : .light
        // The bar lives in the keyboard's window, which carries its own
        // safe-area region; honouring it would push the content off-centre in
        // a bar this short.
        if #available(iOS 16.4, *) { host.safeAreaRegions = [] }
        contentHost = host

        // The content decides the bar's height: a caller who wants room
        // around the items adds padding to them, the way they would anywhere
        // else. `fallbackHeight` only covers content that measures to nothing.
        let fitted = host.sizeThatFits(
            in: CGSize(
                width: KeyboardInputView.startingWidth,
                height: UIView.layoutFittingCompressedSize.height))
        let inputView = KeyboardInputView(
            height: fitted.height > 0 ? ceil(fitted.height) : Self.fallbackHeight)
        // Autoresizing, not constraints: the keyboard resizes the accessory as
        // it presents, and a constraint solve in the middle of that animation
        // is work nobody asked for.
        host.view.frame = inputView.bounds
        host.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        inputView.addSubview(host.view)
        self.inputView = inputView

        super.init()

        NativeLog.log(
            "KeyboardAccessoryBar created: nodes=\(nodes.count) isDark=\(isDark) "
                + "host=\(ObjectIdentifier(host)) inputView=\(ObjectIdentifier(inputView))")
    }

    /// Bars live here, one per field id, for the process's life.
    ///
    /// They cannot be owned by a SwiftUI view: `init` runs on every
    /// re-evaluation, so building one there churned a bar per frame, and the
    /// accessory a focused field pointed at had already been deallocated.
    /// Measured: two builds and two deallocations per frame, forever.
    private static var cache: [String: KeyboardAccessoryBar] = [:]

    /// The bar for `key`, built once. `signature` rebuilds it when the items
    /// themselves changed.
    static func shared(
        key: String,
        signature: String,
        nodes: [BodyNodeConfig],
        isDark: Bool,
        onEvent: @escaping (String, Any?) -> Void
    ) -> KeyboardAccessoryBar {
        let cacheKey = "\(key)|\(signature)"
        if let existing = cache[cacheKey] {
            existing.applyBrightness(isDark)
            return existing
        }
        let bar = KeyboardAccessoryBar(nodes: nodes, isDark: isDark, onEvent: onEvent)
        // Drop any older signature for this key: the items changed, and the
        // old bar is no longer reachable from any field.
        for staleKey in cache.keys where staleKey.hasPrefix("\(key)|") {
            cache.removeValue(forKey: staleKey)
        }
        cache[cacheKey] = bar
        return bar
    }

    /// Keeps the toolbar's appearance in step with the app theme. Called on
    /// `setBrightness`, which can arrive without a toolbar rebuild (the nodes
    /// themselves did not change), so the retained host's style is re-pinned.
    func applyBrightness(_ isDark: Bool) {
        let style: UIUserInterfaceStyle = isDark ? .dark : .light
        guard contentHost.overrideUserInterfaceStyle != style else { return }
        contentHost.overrideUserInterfaceStyle = style
        NativeLog.log(
            "KeyboardAccessoryBar brightness → \(isDark ? "dark" : "light") "
                + "host=\(ObjectIdentifier(contentHost))")
    }
}

/// The accessory root handed to the field.
///
/// A plain `UIView`, deliberately: `UIInputView` is the documented class for an
/// input accessory, but `UIPeripheralHost` accepts one into its input view set
/// and then never adds it to the hierarchy. The bar stayed a root view with no
/// superview, `window == nil`, and nothing on screen, with `.keyboard` style,
/// with `.default` style, and with no style override at all. A plain view is
/// what the keyboard actually places.
///
/// ## Unpainted
///
/// UIKit places the accessory in its own strip above the keyboard, and the
/// keyboard's own backdrop does not extend under it: measured on a red page,
/// the strip behind the bar came back red while the keyboard's suggestion row
/// stayed grey. So the bar shows the page through itself, which is what the
/// toolbar wants: the capsule in it is a `CupertinoNativeGlassContainer`, and
/// glass is only worth having if there is something behind it to refract. A
/// material painted under the glass would be glass over a slab of keyboard
/// chrome.
///
/// The one consequence to know about is the seam. The strip is page-coloured,
/// so a light keyboard under a dark page meets that dark colour at the top of
/// the strip and steps back to grey below it.
@available(iOS 15.0, *)
final class KeyboardInputView: UIView {
    private let barHeight: CGFloat

    init(height: CGFloat) {
        barHeight = height
        // A *real* width, not `UIView.noIntrinsicMetric`: `UIPeripheralHost`
        // reads the accessory's size from this frame, and the first version
        // handed it -1, which the keyboard installed as `frame = (-1 0; 1 48)`,
        // an invisible one-point sliver. The keyboard stretches the bar to its
        // own width once it is placed, so this only has to be a sane starting
        // point.
        super.init(frame: CGRect(x: 0, y: 0, width: Self.startingWidth, height: height))
        // `.flexibleWidth` so the stretch above actually happens.
        autoresizingMask = [.flexibleWidth]
        // The bar paints nothing at all: the SwiftUI content added on top is
        // the whole of what is drawn.
        isOpaque = false
        backgroundColor = .clear
    }

    @available(*, unavailable)
    required init?(coder: NSCoder) {
        fatalError("init(coder:) is not supported")
    }

    /// The keyboard stretches the bar to the screen's width as it presents,
    /// and the hosted SwiftUI content would animate along with that resize:
    /// the buttons visibly sliding in from the middle while the bar rises.
    /// The content is laid out to the new bounds in one step instead.
    override func layoutSubviews() {
        UIView.performWithoutAnimation {
            super.layoutSubviews()
            for subview in subviews where subview.frame != bounds {
                subview.frame = bounds
                subview.layoutIfNeeded()
            }
        }
    }

    /// The size the keyboard takes the accessory from. Both axes need a real
    /// number: `UIView.noIntrinsicMetric` (-1) made the bar one point wide, and
    /// leaving the default `(-1, -1)` stopped it being placed at all.
    override var intrinsicContentSize: CGSize {
        CGSize(width: Self.startingWidth, height: barHeight)
    }

    /// The window's width, or the narrowest current iPhone when there is no
    /// window yet. Only a starting value, see `init`.
    static var startingWidth: CGFloat {
        for case let scene as UIWindowScene in UIApplication.shared.connectedScenes {
            for window in scene.windows where window.bounds.width > 0 {
                return window.bounds.width
            }
        }
        return 375
    }
}
