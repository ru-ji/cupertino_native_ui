import Flutter
import UIKit

/// The iOS 15–18 navigation bar's material: the system chrome blur plus its
/// hairline, drawn natively so it blurs everything beneath it, native views
/// included, which a Flutter `BackdropFilter` cannot sample.
@available(iOS 15.0, *)
final class NativeBarMaterialFactory: NSObject, FlutterPlatformViewFactory {
    private let messenger: FlutterBinaryMessenger

    init(messenger: FlutterBinaryMessenger) {
        self.messenger = messenger
        super.init()
    }

    func create(
        withFrame frame: CGRect, viewIdentifier viewId: Int64, arguments args: Any?
    ) -> FlutterPlatformView {
        NativeBarMaterialPlatformView(viewId: viewId, arguments: args, messenger: messenger)
    }

    func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}

@available(iOS 15.0, *)
final class BarMaterialView: UIView {
    private let effectView = UIVisualEffectView(effect: nil)
    private let hairline = CALayer()
    /// Over the blur, so the bar reads more opaque than the bare material.
    /// ponytail: tuned by eye, raise the alpha for a denser bar.
    private let wash = UIView()
    private static let washAlpha: CGFloat = 0.45
    // A blur cannot take a fractional alpha; a paused animator scrubs the effect in.
    private var animator: UIViewPropertyAnimator?

    override init(frame: CGRect) {
        super.init(frame: frame)
        isUserInteractionEnabled = false
        effectView.frame = bounds
        effectView.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(effectView)
        wash.frame = bounds
        wash.autoresizingMask = [.flexibleWidth, .flexibleHeight]
        addSubview(wash)
        layer.addSublayer(hairline)
        let animator = UIViewPropertyAnimator(duration: 1, curve: .linear) { [effectView] in
            effectView.effect = UIBlurEffect(style: .systemChromeMaterial)
        }
        animator.pausesOnCompletion = true
        self.animator = animator
    }

    required init?(coder: NSCoder) { fatalError("init(coder:) is not supported") }

    deinit {
        animator?.stopAnimation(false)
        animator?.finishAnimation(at: .current)
    }

    func apply(progress: CGFloat, isDark: Bool) {
        overrideUserInterfaceStyle = isDark ? .dark : .light
        animator?.fractionComplete = min(max(progress, 0), 0.999)
        wash.backgroundColor = (isDark ? UIColor(white: 0.1, alpha: 1) : .white)
            .withAlphaComponent(Self.washAlpha * min(max(progress, 0), 1))
        hairline.backgroundColor = UIColor.separator.resolvedColor(with: traitCollection).cgColor
        hairline.opacity = Float(min(max(progress, 0), 1))
    }

    override func layoutSubviews() {
        super.layoutSubviews()
        let scale = window?.screen.scale ?? UIScreen.main.scale
        hairline.frame = CGRect(x: 0, y: bounds.height - 1 / scale, width: bounds.width, height: 1 / scale)
    }
}

@available(iOS 15.0, *)
final class NativeBarMaterialPlatformView: NSObject, FlutterPlatformView {
    private let barView = BarMaterialView()
    private let channel: FlutterMethodChannel

    init(viewId: Int64, arguments args: Any?, messenger: FlutterBinaryMessenger) {
        channel = FlutterMethodChannel(
            name: "cupertino_native_ui/bar_material_\(viewId)", binaryMessenger: messenger)
        super.init()
        apply(args)
        channel.setMethodCallHandler { [weak self] call, result in
            guard call.method == "update" else { return result(FlutterMethodNotImplemented) }
            self?.apply(call.arguments)
            result(nil)
        }
    }

    private func apply(_ args: Any?) {
        let map = args as? [String: Any] ?? [:]
        barView.apply(
            progress: CGFloat(map["progress"] as? Double ?? 0),
            isDark: map["isDark"] as? Bool ?? false)
    }

    func view() -> UIView { barView }
}
