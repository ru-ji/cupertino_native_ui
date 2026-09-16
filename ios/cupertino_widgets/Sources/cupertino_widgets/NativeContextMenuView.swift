import Flutter
import UIKit

@available(iOS 26.0, *)
class NativeContextMenuFactory: NSObject, FlutterPlatformViewFactory {
    private var messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?
    ) -> FlutterPlatformView {
        return NativeContextMenuView(
            frame: frame,
            viewIdentifier: viewId,
            arguments: args,
            messenger: messenger
        )
    }

    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

/// Transparent surface owning a `UIContextMenuInteraction`, composited BEHIND
/// a Flutter child (the Dart widget stacks the child on top and lets touches
/// fall through to this view). Long-press opens a native context menu built
/// from the same `MenuItemConfig` tree the popup menu uses.
///
/// The lifted preview is either an image pushed from Dart (a custom "menu
/// open" view rendered by Flutter) or, by default, a snapshot of the window
/// region this surface covers — which is exactly the Flutter child's current
/// pixels, since the child is composited directly above.
@available(iOS 26.0, *)
class NativeContextMenuView: NSObject, FlutterPlatformView, UIContextMenuInteractionDelegate {
    private let channel: FlutterMethodChannel
    private let container = UIView()
    private var items: [MenuItemConfig] = []
    private var previewImage: UIImage?
    /// The child rendered by Flutter itself. Preferred over any window
    /// snapshot: `drawHierarchy` cannot reliably capture Flutter's Metal
    /// layer, which drops composited content (text, shaders) from the lift.
    private var childImage: UIImage?
    /// Child snapshot captured once when an interaction begins, reused by the
    /// highlight and dismiss previews.
    private var sessionSnapshot: UIImage?
    private var blurBackground = false
    private var backgroundBlurView: UIVisualEffectView?
    private var isDark: Bool?
    /// The child's corner radius, from Dart. UIKit shapes the lift's plate and
    /// shadow from `UIPreviewParameters.visiblePath`, and its default is the
    /// preview's full rectangle — square corners around a rounded child.
    private var previewCornerRadius: CGFloat = 0

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        messenger: FlutterBinaryMessenger
    ) {
        channel = FlutterMethodChannel(
            name: "cupertino_widgets/context_menu_\(viewId)", binaryMessenger: messenger)
        super.init()

        container.backgroundColor = .clear
        // Not opaque: the default promises the render server a full box of
        // pixels this view never draws, and the lift's snapshot is where that
        // shows as a plate around the child.
        container.isOpaque = false
        container.addInteraction(UIContextMenuInteraction(delegate: self))

        if let dict = args as? [String: Any] {
            apply(dict)
        }
        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
    }

    deinit {
        // Never strand the blur over the app if the view goes away mid-menu.
        backgroundBlurView?.removeFromSuperview()
    }

    func view() -> UIView { container }

    private func apply(_ args: [String: Any]) {
        if let itemMaps = args["items"] as? [[String: Any]] {
            items = itemMaps.compactMap { decodeConfig(MenuItemConfig.self, from: $0) }
        }
        blurBackground = args["blurBackground"] as? Bool ?? false
        previewCornerRadius = CGFloat(args["previewCornerRadius"] as? Double ?? 0)
        if let dark = args["isDark"] as? Bool {
            isDark = dark
            container.overrideUserInterfaceStyle = dark ? .dark : .light
        }
    }

    /// `UIContextMenuInteraction` presents its lifted content and menu chrome
    /// in a separate system overlay window, not as a subview of `container` —
    /// setting the style on `container` alone doesn't reach it. Override every
    /// window in the scene so whichever one the system parents the menu chrome
    /// to follows the app's own (possibly forced) theme, not the device's.
    private func applyWindowStyle() {
        guard let isDark else { return }
        NativeHostingView.syncWindowStyle(isDark: isDark)
    }

    /// Blurs the app behind the menu, in the app's own window, so it covers
    /// Flutter content and native views alike.
    private func setBackgroundBlur(_ on: Bool) {
        guard blurBackground else { return }
        if on {
            guard backgroundBlurView == nil, let window = container.window else { return }
            let effectView = UIVisualEffectView(effect: nil)
            // The blur must follow the app's forced theme, not the device's —
            // a dark device otherwise renders a darkened material over a
            // light-themed app.
            if let isDark {
                effectView.overrideUserInterfaceStyle = isDark ? .dark : .light
            }
            effectView.frame = window.bounds
            effectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
            effectView.isUserInteractionEnabled = false
            window.addSubview(effectView)
            backgroundBlurView = effectView
            UIView.animate(withDuration: 0.25) {
                effectView.effect = UIBlurEffect(style: .systemThinMaterial)
            }
        } else {
            guard let effectView = backgroundBlurView else { return }
            backgroundBlurView = nil
            UIView.animate(
                withDuration: 0.2,
                animations: { effectView.effect = nil },
                completion: { _ in effectView.removeFromSuperview() })
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // No `snapshot` handler: this is a transparent overlay on a child Flutter
        // already paints.
        switch call.method {
        case "updateContextMenu":
            if let args = call.arguments as? [String: Any] { apply(args) }
            result(nil)
        case "setPreview":
            previewImage = decodeImage(call.arguments)
            result(nil)
        case "setChildImage":
            childImage = decodeImage(call.arguments)
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    /// Decodes a `{bytes, scale}` payload pushed from Dart.
    private func decodeImage(_ arguments: Any?) -> UIImage? {
        guard let args = arguments as? [String: Any],
            let bytes = args["bytes"] as? FlutterStandardTypedData
        else { return nil }
        let scale = (args["scale"] as? NSNumber)?.doubleValue ?? 1
        return UIImage(data: bytes.data, scale: CGFloat(scale))
    }

    // MARK: - UIContextMenuInteractionDelegate

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        configurationForMenuAtLocation location: CGPoint
    ) -> UIContextMenuConfiguration? {
        guard !items.isEmpty else { return nil }
        applyWindowStyle()
        // Resolve the lift image ONCE per interaction: highlight, dismiss and
        // (absent a custom preview) the lift itself all reuse it. Flutter's
        // own render when available; the window snapshot only as a stopgap
        // before the first capture arrives.
        sessionSnapshot = childImage ?? snapshotChild()
        return UIContextMenuConfiguration(
            identifier: nil,
            // A custom preview replaces the lifted content; without one the
            // highlight preview below IS the lift (the classic behavior).
            previewProvider: previewImage == nil
                ? nil
                : { [weak self] in self?.makePreviewController() },
            actionProvider: { [weak self] _ in
                guard let self else { return UIMenu() }
                return UIMenu(children: self.items.map { self.element(from: $0) })
            })
    }

    /// Where the lift animates FROM: the child's pixels, in the child's own
    /// place. Without this the system lifts our transparent view.
    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        previewForHighlightingMenuWithConfiguration configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        return targetedPreview()
    }

    /// Where the menu animates BACK TO on dismiss. Without it UIKit has no
    /// target and the preview just vanishes instantly instead of settling
    /// back into the child.
    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        previewForDismissingMenuWithConfiguration configuration: UIContextMenuConfiguration
    ) -> UITargetedPreview? {
        return targetedPreview()
    }

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willDisplayMenuFor configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionAnimating?
    ) {
        // Hide the Flutter child for the duration: UIKit hides the original
        // of a lifted UIView automatically, but it can't touch Flutter's
        // layer — leaving the child duplicated under the lifted snapshot.
        channel.invokeMethod("onOpenChanged", arguments: ["open": true])
        setBackgroundBlur(true)
    }

    func contextMenuInteraction(
        _ interaction: UIContextMenuInteraction,
        willEndFor configuration: UIContextMenuConfiguration,
        animator: UIContextMenuInteractionAnimating?
    ) {
        // Two separate signals, because two things depend on them at
        // different times: anything the app draws for the menu (a background
        // blur) must clear NOW, as the dismissal starts, while the child
        // itself must stay hidden until the preview has finished flying home.
        channel.invokeMethod("onOpenChanged", arguments: ["open": false])
        setBackgroundBlur(false)
        let restore = { [weak self] in
            self?.channel.invokeMethod("onDismissComplete", arguments: nil)
            self?.sessionSnapshot = nil
        }
        if let animator = animator {
            animator.addCompletion(restore)
        } else {
            restore()
        }
    }

    // MARK: - Preview

    /// The custom Dart-rendered "menu open" view.
    private func makePreviewController() -> UIViewController? {
        guard let image = previewImage else { return nil }
        let controller = UIViewController()
        let imageView = UIImageView(image: image)
        imageView.contentMode = .scaleAspectFit
        imageView.backgroundColor = .clear
        controller.view = imageView
        controller.preferredContentSize = image.size
        return controller
    }

    /// The child's pixels anchored in the child's own frame — the source and
    /// destination of the lift/dismiss morph.
    private func targetedPreview() -> UITargetedPreview? {
        guard let image = sessionSnapshot ?? childImage ?? snapshotChild(),
            container.window != nil,
            container.bounds.width > 0, container.bounds.height > 0
        else {
            return nil
        }
        let imageView = UIImageView(image: image)
        imageView.frame = CGRect(origin: .zero, size: container.bounds.size)
        imageView.contentMode = .scaleAspectFill
        imageView.clipsToBounds = true
        let parameters = UIPreviewParameters()
        parameters.backgroundColor = .clear
        if previewCornerRadius > 0 {
            parameters.visiblePath = UIBezierPath(
                roundedRect: imageView.bounds, cornerRadius: previewCornerRadius)
        }
        let target = UIPreviewTarget(
            container: container,
            center: CGPoint(x: container.bounds.midX, y: container.bounds.midY))
        return UITargetedPreview(
            view: imageView, parameters: parameters, target: target)
    }

    /// `drawHierarchy` (not `layer.render`) so the Metal-backed FlutterView's
    /// content is actually captured.
    private func snapshotChild() -> UIImage? {
        guard let window = container.window else { return nil }
        let rect = container.convert(container.bounds, to: window)
        guard rect.width > 0, rect.height > 0 else { return nil }
        let renderer = UIGraphicsImageRenderer(size: rect.size)
        return renderer.image { _ in
            window.drawHierarchy(
                in: CGRect(
                    origin: CGPoint(x: -rect.minX, y: -rect.minY),
                    size: window.bounds.size),
                afterScreenUpdates: false)
        }
    }

    // MARK: - Menu building

    private func element(from item: MenuItemConfig) -> UIMenuElement {
        let image = item.systemImage.flatMap { UIImage(systemName: $0) }
        switch item.type {
        case .submenu:
            return UIMenu(
                title: item.title ?? "", image: image,
                children: (item.items ?? []).map { element(from: $0) })
        case .section:
            return UIMenu(
                title: item.title ?? "", options: .displayInline,
                children: (item.items ?? []).map { element(from: $0) })
        case .toggle:
            return UIAction(
                title: item.title ?? "", image: image,
                state: item.value == true ? .on : .off
            ) { [weak self] _ in
                if let id = item.actionId {
                    self?.channel.invokeMethod(
                        "onAction", arguments: ["id": id, "value": !(item.value ?? false)])
                }
            }
        case .action:
            var attributes: UIMenuElement.Attributes = []
            if item.isDestructive == true { attributes.insert(.destructive) }
            if item.isDisabled == true { attributes.insert(.disabled) }
            let action = UIAction(
                title: item.title ?? "", image: image, attributes: attributes
            ) { [weak self] _ in
                if let id = item.actionId {
                    self?.channel.invokeMethod("onAction", arguments: ["id": id, "value": nil])
                }
            }
            if let subtitle = item.subtitle { action.subtitle = subtitle }
            return action
        }
    }
}

