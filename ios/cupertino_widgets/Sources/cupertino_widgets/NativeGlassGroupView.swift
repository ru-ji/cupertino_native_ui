import Flutter
import SwiftUI
import UIKit

@available(iOS 26.0, *)
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
@available(iOS 26.0, *)
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
                // Animated: this is where the merge happens — and, since the
                // container no longer changes identity with the spacing, where
                // a split, an arrival and a replacement happen too. The whole
                // config goes over at once, so `items` gaining, losing or
                // re-identifying an entry is what drives the transitions.
                withAnimation(.smooth(duration: 0.35)) { model.config = config }
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

@available(iOS 26.0, *)
final class GlassGroupModel: ObservableObject {
    @Published var config = GlassGroupConfig(
        items: [], spacing: nil, mergeDistance: nil, variant: nil, tint: nil,
        interactive: nil, vertical: nil, cornerRadius: nil, isDark: nil,
        transition: nil)
}

/// iOS 16 is the floor: `AnyShape` is what lets one item be a circle and its
/// neighbour a capsule in the same container.
@available(iOS 26.0, *)
struct AdaptiveGlassGroupView: View {
    @ObservedObject var model: GlassGroupModel
    let onAction: (String) -> Void

    /// The identity space the morph runs in. Two glasses merge because their
    /// `glassEffectID`s live in the same namespace inside the same container —
    /// this is the thing that cannot cross a platform-view boundary.
    @Namespace private var namespace

    private var c: GlassGroupConfig { model.config }
    private var spacing: CGFloat { CGFloat(c.spacing ?? 8) }

    /// No gap: the old "44pt glasses united into one capsule, like a toolbar
    /// group" mode.
    private var sharesOneGlass: Bool { spacing <= 0 }

    /// What the container is told — the radius within which two glasses blend,
    /// which is a different question from the gap they are laid out with.
    ///
    /// `mergeDistance` answers it outright. Without one, a shared glass needs
    /// no radius (the union is stated, not inferred) and keeps the container's
    /// default, exactly as the union branch passed before; anything else
    /// inherits the gap, which is what this widget has always done.
    private var containerSpacing: CGFloat? {
        if let d = c.mergeDistance { return CGFloat(d) }
        return sharesOneGlass ? nil : spacing
    }

    /// How far apart the items sit. A shared glass keeps the 11pt of a toolbar
    /// group; otherwise the gap is the spacing the caller asked for.
    private var layoutSpacing: CGFloat { sharesOneGlass ? 11 : spacing }

    var body: some View {
        content
            .environment(\.colorScheme, c.isDark == true ? .dark : .light)
    }

    /// ONE container, whatever the spacing.
    ///
    /// This used to be an `if spacing <= 0` with a container in each branch,
    /// and that is why the merge never animated: swapping branches changes the
    /// container's identity, so SwiftUI tore it down and built another one
    /// instead of interpolating between the two. Which glasses are united is
    /// now a *value* — the union id below — so a single container can carry
    /// the group from two glasses to one and back.
    ///
    /// The container also has to be the same one across an item's arrival and
    /// departure, which is what `glassEffectID` and `glassEffectTransition`
    /// are for. Apple: those two "only affect their content during view
    /// hierarchy transitions or animations".
    @ViewBuilder
    private var content: some View {
        GlassEffectContainer(spacing: containerSpacing) {
            stack { item in
                glassed(item)
            }
        }
    }

    /// One row or one column of items, each passed through `decorate`.
    @ViewBuilder
    private func stack<V: View>(
        @ViewBuilder decorate: @escaping (GlassGroupItemConfig) -> V
    ) -> some View {
        if c.vertical == true {
            VStack(spacing: layoutSpacing) { ForEach(c.items) { decorate($0) } }
        } else {
            HStack(spacing: layoutSpacing) { ForEach(c.items) { decorate($0) } }
        }
    }

    /// One item, with or without a glass.
    ///
    /// An item that is present but has no glass keeps its slot and loses only
    /// the material. That matters for a glass arriving from nothing: if the
    /// item also left the layout, the group's box would shrink underneath the
    /// transition and there would be nowhere for the new glass to land.
    @ViewBuilder
    private func glassed(_ item: GlassGroupItemConfig) -> some View {
        if item.glassVisible == false {
            button(item).hidden()
        } else {
            button(item)
                .glassEffect(glass, in: shape(for: item))
                .glassEffectID(item.actionId, in: namespace)
                .glassEffectUnion(id: unionId(for: item), namespace: namespace)
                .glassEffectTransition(transition(for: item))
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

    /// The id this item contributes its glass under. Glasses that share an id
    /// are drawn as one shape.
    ///
    /// A shared glass puts every item under one id, which is the old
    /// `glassEffectUnion(id: "group")` behaviour. Otherwise an item stands
    /// alone unless it names a partner — and "alone" is still an explicit id,
    /// never a missing modifier, so moving an item in or out of a union is a
    /// change of value rather than a change of view.
    private func unionId(for item: GlassGroupItemConfig) -> String {
        if sharesOneGlass { return Self.sharedGlassUnionId }
        return item.unionId ?? item.actionId
    }

    private static let sharedGlassUnionId = "group"

    /// How the glass arrives and leaves.
    ///
    /// Apple's default inside a container is `matchedGeometry` for effects
    /// positioned within the container's spacing, and `materialize` for effects
    /// farther apart. `matchedGeometry` is what makes two glasses travel into
    /// each other; `materialize` fades the content in while the material
    /// animates in or out, without matching any geometry — which is the effect
    /// for a glass that appears from nothing, or replaces another one in the
    /// same place.
    private func transition(for item: GlassGroupItemConfig) -> GlassEffectTransition {
        switch item.transition ?? c.transition {
        case "materialize": return .materialize
        case "identity": return .identity
        default: return .matchedGeometry
        }
    }

    /// How many items share this item's union id. One means it stands alone.
    private func unionSize(of item: GlassGroupItemConfig) -> Int {
        let id = unionId(for: item)
        return c.items.filter { unionId(for: $0) == id }.count
    }

    private func shape(for item: GlassGroupItemConfig) -> AnyShape {
        // `glassEffectUnion` only combines effects that share a shape, so a
        // shared glass has to give every item the same one.
        if sharesOneGlass { return AnyShape(Capsule()) }
        switch item.shape {
        case "capsule": return AnyShape(Capsule())
        case "roundedRect":
            return AnyShape(
                RoundedRectangle(
                    cornerRadius: CGFloat(c.cornerRadius ?? 16), style: .continuous))
        default:
            // A circle is *inscribed* in whatever frame it is handed. Alone,
            // that frame is the item's own 44pt box and it looks right.
            // Unioned, the frame is the union's bounding box — and a circle
            // inscribed in a 108x44 box is a 44pt circle, so the union
            // collapses back to one item's worth of glass sitting in the
            // middle with the content hanging outside it. Measured, not
            // reasoned: see docs/glass-transitions.md.
            //
            // `Capsule` fills its frame instead, and is the shape SwiftUI's
            // own `glassEffect()` defaults to — which is why Apple's union
            // examples work and a circle override does not.
            return unionSize(of: item) > 1
                ? AnyShape(Capsule())
                : AnyShape(Circle())
        }
    }
}
