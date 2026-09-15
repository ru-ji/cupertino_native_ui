import Flutter
import SwiftUI
import UIKit

@available(iOS 15.0, *)
class NativeGlassGroupFactory: NSObject, FlutterPlatformViewFactory {
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
        return NativeGlassGroupView(
            frame: frame, viewIdentifier: viewId, arguments: args, messenger: messenger)
    }

    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        return FlutterStandardMessageCodec.sharedInstance()
    }
}

/// Several glass controls in ONE platform view, so they can affect each other.
///
/// `GlassEffectContainer` merges glasses only within one SwiftUI tree, so a
/// group is one host.
@available(iOS 15.0, *)
class NativeGlassGroupView: NativeHostingView {
    private var channel: FlutterMethodChannel?
    private let model = GlassGroupModel()

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        messenger: FlutterBinaryMessenger
    ) {
        super.init()
        _view.viewId = viewId

        channel = FlutterMethodChannel(
            name: "cupertino_widgets/glass_group_\(viewId)", binaryMessenger: messenger)
        sizeChannel = channel
        channel?.setMethodCallHandler({ [weak self] call, result in
            self?.handle(call, result: result)
        })

        if let argsMap = args as? [String: Any],
            let config = decodeConfig(GlassGroupConfig.self, from: argsMap)
        {
            model.config = config
        }
        guard #available(iOS 16.0, *) else {
            attach(AnyView(Color.clear))
            return
        }
        // Built once and fed by the model from then on. Re-attaching would
        // rebuild the container, and a container rebuilt mid-morph drops the
        // animation the group exists for.
        attach(
            AnyView(
                AdaptiveGlassGroupView(model: model) { [weak self] actionId in
                    self?.channel?.invokeMethod("onAction", arguments: ["actionId": actionId])
                })
        ) { host, container in
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
        case "getIntrinsicSize":
            result(intrinsicSize())
        case "setConfig":
            if let argsMap = call.arguments as? [String: Any],
                let config = decodeConfig(GlassGroupConfig.self, from: argsMap)
            {
                // Animated: this is where the merge happens.
                if #available(iOS 17.0, *) {
                    withAnimation(.smooth(duration: 0.35)) { model.config = config }
                } else {
                    withAnimation(.easeInOut(duration: 0.35)) { model.config = config }
                }
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

@available(iOS 15.0, *)
final class GlassGroupModel: ObservableObject {
    @Published var config = GlassGroupConfig(
        items: [], spacing: nil, variant: nil, tint: nil, interactive: nil,
        vertical: nil, cornerRadius: nil, isDark: nil)
}

/// iOS 16 is the floor: `AnyShape` is what lets one item be a circle and its
/// neighbour a capsule in the same container.
@available(iOS 16.0, *)
struct AdaptiveGlassGroupView: View {
    @ObservedObject var model: GlassGroupModel
    let onAction: (String) -> Void

    /// The identity space the morph runs in. Two glasses merge because their
    /// `glassEffectID`s live in the same namespace inside the same container —
    /// this is the thing that cannot cross a platform-view boundary.
    @Namespace private var namespace

    private var c: GlassGroupConfig { model.config }
    private var spacing: CGFloat { CGFloat(c.spacing ?? 8) }

    var body: some View {
        content
            .environment(\.colorScheme, c.isDark == true ? .dark : .light)
    }

    @ViewBuilder
    private var content: some View {
        if #available(iOS 26.0, *) {
            if spacing <= 0 {
                // No gap: 44pt glasses united into one capsule, like a toolbar
                // group (`glassEffectUnion`).
                GlassEffectContainer {
                    sharedStack { item in
                        button(item)
                            .glassEffect(glass, in: Capsule())
                            .glassEffectUnion(id: "group", namespace: namespace)
                    }
                }
            } else {
                GlassEffectContainer(spacing: spacing) {
                    stack { item in
                        button(item)
                            .glassEffect(glass, in: shape(for: item))
                            .glassEffectID(item.id, in: namespace)
                    }
                }
            }
        } else {
            // Below 26 there is no merge to have: the same layout, each item on
            // the closest material the system offers.
            stack { item in
                button(item)
                    .background(.ultraThinMaterial, in: shape(for: item))
            }
        }
    }

    /// One row or one column of items, each passed through `decorate` — the
    /// only difference between the iOS 26 branch and the fallback.
    @ViewBuilder
    private func stack<V: View>(
        @ViewBuilder decorate: @escaping (GlassGroupItemConfig) -> V
    ) -> some View {
        if c.vertical == true {
            VStack(spacing: spacing) { ForEach(c.items) { decorate($0) } }
        } else {
            HStack(spacing: spacing) { ForEach(c.items) { decorate($0) } }
        }
    }

    /// The items of a shared glass, 11pt apart like a toolbar group.
    @ViewBuilder
    private func sharedStack<V: View>(
        @ViewBuilder decorate: @escaping (GlassGroupItemConfig) -> V
    ) -> some View {
        if c.vertical == true {
            VStack(spacing: 11) { ForEach(c.items) { decorate($0) } }
        } else {
            HStack(spacing: 11) { ForEach(c.items) { decorate($0) } }
        }
    }

    /// The content of one glass: a native icon, a title, or both.
    private func label(_ item: GlassGroupItemConfig) -> some View {
        let extent = CGFloat(item.height ?? 44)
        return HStack(spacing: 6) {
            // Bar items draw symbols at the large image scale, like UIBarButtonItem.
            if let icon = item.icon { IconView(icon: icon).imageScale(.large) }
            if let title = item.title, !title.isEmpty { Text(title) }
        }
        .frame(
            width: item.width.map { CGFloat($0) } ?? (item.title == nil ? extent : nil),
            height: extent
        )
        .padding(.horizontal, item.title == nil ? 0 : 14)
    }

    private func button(_ item: GlassGroupItemConfig) -> some View {
        label(item)
        .opacity(item.enabled == false ? 0.4 : 1)
        .contentShape(Rectangle())
        .onTapGesture { if item.enabled != false { onAction(item.actionId) } }
    }

    @available(iOS 26.0, *)
    private var glass: Glass {
        var glass: Glass = c.variant == "clear" ? .clear : .regular
        if let argb = c.tint { glass = glass.tint(Color(argb: argb)) }
        if c.interactive != false { glass = glass.interactive() }
        return glass
    }

    private func shape(for item: GlassGroupItemConfig) -> AnyShape {
        switch item.shape {
        case "capsule": return AnyShape(Capsule())
        case "roundedRect":
            return AnyShape(
                RoundedRectangle(
                    cornerRadius: CGFloat(c.cornerRadius ?? 16), style: .continuous))
        default: return AnyShape(Circle())
        }
    }
}
