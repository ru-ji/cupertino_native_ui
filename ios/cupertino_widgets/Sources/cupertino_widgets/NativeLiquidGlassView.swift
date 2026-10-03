import Flutter
import SwiftUI
import UIKit

@available(iOS 15.0, *)
class NativeLiquidGlassFactory: NSObject, FlutterPlatformViewFactory {
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
        return NativeLiquidGlassView(
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

/// Platform view exposing the iOS 26 Liquid Glass material. Below iOS 26 it
/// renders an `ultraThinMaterial` approximation.
@available(iOS 15.0, *)
class NativeLiquidGlassView: NativeHostingView {
    private var channel: FlutterMethodChannel?
    /// What the SwiftUI view observes.
    private var model: GlassViewModel?
    /// Layout mode the hosting controller was attached with. A config change
    /// that does not cross this line only needs a new root view.
    private var attachedExpanded: Bool?

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        messenger: FlutterBinaryMessenger
    ) {
        super.init()
        _view.viewId = viewId

        channel = FlutterMethodChannel(
            name: "cupertino_widgets/liquid_glass_\(viewId)", binaryMessenger: messenger)
        sizeChannel = channel
        channel?.setMethodCallHandler({
            [weak self] (call: FlutterMethodCall, result: @escaping FlutterResult) in
            self?.handle(call, result: result)
        })

        if let argsMap = args as? [String: Any],
            let config = decodeConfig(GlassConfig.self, from: argsMap)
        {
            setupSwiftUI(with: config)
        }
    }

    /// Attaches the glass. `expand` means the Flutter box, not a native icon,
    /// sizes the container.
    private func setupSwiftUI(with config: GlassConfig) {
        // Appearance is owned by the hosting controller: the model-update path
        // below returns early, so the pin must happen before the branch.
        isDark = config.isDark
        appearanceDark = config.appearanceDark
        let expanded = config.expand == true
        // Filling the box: nothing to measure.
        measuresIntrinsicSize = !expanded

        // Built once, then fed through an observable model: SwiftUI keeps the view
        // identity, so changes redraw minimally and can animate.
        if let model, attachedExpanded == expanded {
            model.update(config, animated: config.animated == true)
            return
        }

        let model = GlassViewModel(config: config)
        self.model = model
        attachedExpanded = expanded
        let content = AnyView(
            AdaptiveLiquidGlassView(model: model) { [weak self] in
                self?.channel?.invokeMethod("pressed", arguments: nil)
            })

        guard !expanded else {
            attach(content)
            return
        }
        // No explicit size: the glass is measured like a button, hugging its
        // content, and `getIntrinsicSize` hands that back so Flutter can build
        // the box.
        attach(content) { host, container in
            host.setContentHuggingPriority(.required, for: .horizontal)
            host.setContentHuggingPriority(.required, for: .vertical)
            NSLayoutConstraint.activate([
                host.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                host.centerYAnchor.constraint(equalTo: container.centerYAnchor),
                host.widthAnchor.constraint(lessThanOrEqualTo: container.widthAnchor),
                host.heightAnchor.constraint(lessThanOrEqualTo: container.heightAnchor),
            ])
        }
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // A bitmap of this view, for Flutter to draw in its own layer tree.
        // See PlatformViewSnapshot.
        if call.method == "snapshot" {
            result(PlatformViewSnapshot.capture(view()))
            return
        }
        switch call.method {
        case "cancelTouches":
            cancelTouches()
            result(nil)
        case "getIntrinsicSize":
            result(intrinsicSize())
        case "updateGlass":
            if let argsMap = call.arguments as? [String: Any],
                let config = decodeConfig(GlassConfig.self, from: argsMap)
            {
                setupSwiftUI(with: config)
                result(nil)
            } else {
                result(
                    FlutterError(code: "INVALID_ARGS", message: "Invalid arguments", details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

/// What the hosted SwiftUI view observes. Publishing configs keeps the view
/// identity stable.
@available(iOS 15.0, *)
final class GlassViewModel: ObservableObject {
    @Published private(set) var config: GlassConfig

    init(config: GlassConfig) {
        self.config = config
    }

    /// Applies a new config, optionally as a spring transition. Identical
    /// configs are dropped: `@Published` fires on every set, animated or not.
    func update(_ config: GlassConfig, animated: Bool) {
        guard config != self.config else { return }
        let apply = { self.config = config }
        if animated {
            withAnimation(.spring(response: 0.45, dampingFraction: 0.75), apply)
        } else {
            apply()
        }
    }
}

@available(iOS 15.0, *)
struct AdaptiveLiquidGlassView: View {
    @ObservedObject var model: GlassViewModel
    let onPressed: () -> Void

    private var config: GlassConfig { model.config }
    private var expand: Bool { config.expand ?? false }
    private var tint: Color? { config.tint.map { Color(argb: $0) } }

    /// In filling mode, drawn only once the Flutter box has a real size, to avoid
    /// a flash of wrong geometry.
    var body: some View {
        if expand {
            GeometryReader { geometry in
                if geometry.size.width > 0, geometry.size.height > 0 {
                    // No transition: `glassEffect`'s own default insertion
                    // animation is what made the container's first
                    // appearance read as sliding up from the bottom.
                    glassBody
                        .transition(.identity)
                }
            }
        } else {
            glassBody
        }
    }

    @ViewBuilder
    private var glassBody: some View {
        // Apple's order: content, padding, frame, then `glassEffect` last.
        if #available(iOS 26.0, *) {
            GlassEffectContainer {
                glassSurface
                    .simultaneousGesture(
                        TapGesture().onEnded { if config.pressable == true { onPressed() } })
            }
        } else {
            content
                .simultaneousGesture(
                    TapGesture().onEnded { if config.pressable == true { onPressed() } })
        }
    }

    /// The glass and its content: the native icon or the child's leaves,
    /// with `glassEffect` applied to it directly.
    @available(iOS 26.0, *)
    @ViewBuilder
    private var glassSurface: some View {
        content.glassEffect(glass, in: glassShape)
    }

    /// What the glass wraps: the native icon, or Apple's invisible placeholder
    /// so the glass has a shape and `.interactive()` something to track.
    @ViewBuilder
    private var base: some View {
        if let icon = config.icon {
            IconView(icon: icon)
        } else {
            Color.white.opacity(0.001)
        }
    }

    /// Inset, sized, ready for the material: the glass either fills the box
    /// Flutter built (`expand` — which is where an explicit width/height from
    /// the caller lands, since that box *is* that size) or hugs its content so
    /// `getIntrinsicSize` can measure it.
    @ViewBuilder
    private var content: some View {
        // Padding before the frame, so it insets the content instead of growing the
        // glass past the Flutter box.
        base
            .padding(insets)
            .applyGlassExpand(expand)
            // Inside what the glass wraps, so the texts and symbols take its
            // vibrancy, as a native label on glass does.
            .overlay(alignment: .topLeading) {
                if let leaves = config.leaves, !leaves.isEmpty {
                    GlassLeavesView(leaves: leaves)
                }
            }
    }

    private var insets: EdgeInsets {
        EdgeInsets(
            top: CGFloat(config.paddingTop ?? 0),
            leading: CGFloat(config.paddingLeft ?? 0),
            bottom: CGFloat(config.paddingBottom ?? 0),
            trailing: CGFloat(config.paddingRight ?? 0))
    }

    private var cornerRadius: CGFloat { CGFloat(config.cornerRadius ?? 26) }

    @available(iOS 26.0, *)
    private var glass: Glass {
        var glass: Glass = config.variant == "clear" ? .clear : .regular
        if let tint { glass = glass.tint(tint) }
        if config.interactive == true { glass = glass.interactive() }
        return glass
    }

    @available(iOS 26.0, *)
    private var glassShape: AnyShape {
        switch config.shape {
        case "capsule":
            return AnyShape(Capsule())
        case "circle":
            return AnyShape(Circle())
        default:
            return AnyShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
        }
    }
}

/// The Flutter child's texts and symbols, each in the frame Flutter laid it
/// out in. Flutter still reads them for accessibility.
@available(iOS 15.0, *)
struct GlassLeavesView: View {
    let leaves: [GlassLeaf]

    var body: some View {
        ZStack(alignment: .topLeading) {
            ForEach(leaves.indices, id: \.self) { i in
                let leaf = leaves[i]
                leafView(leaf)
                    .frame(
                        width: CGFloat(leaf.width), height: CGFloat(leaf.height),
                        alignment: alignment(leaf))
                    .offset(x: CGFloat(leaf.x), y: CGFloat(leaf.y))
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    @ViewBuilder
    private func leafView(_ leaf: GlassLeaf) -> some View {
        if let symbol = leaf.symbol {
            IconView(
                icon: IconConfig(
                    sfSymbol: symbol, renderingMode: leaf.renderingMode,
                    size: leaf.symbolSize, color: leaf.color, weight: leaf.symbolWeight)
            )
            .imageScale(
                leaf.symbolScale == "small" ? .small : leaf.symbolScale == "large" ? .large : .medium)
        } else {
            let text = Text(leaf.text ?? "")
                .font(
                    .system(
                        size: CGFloat(leaf.fontSize ?? 17),
                        weight: Font.Weight(weightIndex: leaf.fontWeight ?? 3)))
            (leaf.italic == true ? text.italic() : text)
                .foregroundColor(leaf.color.map { Color(argb: $0) })
                .multilineTextAlignment(
                    leaf.align == "center" ? .center : leaf.align == "trailing" ? .trailing : .leading)
                .lineLimit(leaf.singleLine == true ? 1 : leaf.maxLines)
                // Flutter's line, kept whole: SwiftUI may measure it a hair
                // wider and would otherwise truncate it.
                .fixedSize(horizontal: leaf.singleLine == true, vertical: true)
        }
    }

    private func alignment(_ leaf: GlassLeaf) -> Alignment {
        switch leaf.align {
        case "center": return .center
        case "trailing": return .trailing
        case nil: return .center  // a symbol
        default: return .leading
        }
    }
}

@available(iOS 15.0, *)
extension View {
    /// Fills the box Flutter built, in both axes — which is where an explicit
    /// width/height from the caller ends up. Left alone otherwise, so an
    /// icon-only container keeps the size SwiftUI measures it at and reports
    /// that back to Flutter.
    @ViewBuilder
    func applyGlassExpand(_ expand: Bool) -> some View {
        if expand {
            self.frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            self
        }
    }
}
