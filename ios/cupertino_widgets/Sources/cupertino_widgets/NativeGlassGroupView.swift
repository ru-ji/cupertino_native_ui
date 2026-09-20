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
            // Centred and otherwise free. The `<= container` pair that used to
            // be here squeezed the glasses into whatever width the Flutter box
            // happened to hold, and the box only catches up once a measurement
            // lands — so a group that grows was clamped for the whole animation
            // and a "Select" capsule could settle at a width it never chose.
            // The container paints unclipped (see HostingContainerView), so
            // the glass is free to overrun its box while the box follows.
            NSLayoutConstraint.activate([
                host.centerXAnchor.constraint(equalTo: container.centerXAnchor),
                host.centerYAnchor.constraint(equalTo: container.centerYAnchor),
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
                withAnimation(.smooth(duration: 0.35)) {
                    model.config = config
                } completion: { [weak self] in
                    // The size it settled at. Any measurement taken while the
                    // animation runs follows the glass rather than its
                    // destination, so without this the box can keep an
                    // intermediate width for good.
                    self?.publishIntrinsicSize()
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

@available(iOS 26.0, *)
final class GlassGroupModel: ObservableObject {
    @Published var config = GlassGroupConfig(
        items: [], spacing: nil, mergeDistance: nil, variant: nil, tint: nil,
        interactive: nil, vertical: nil, cornerRadius: nil, isDark: nil,
        transition: nil, morphOnChange: nil)
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
    private var morphAmount: CGFloat { CGFloat(c.morphOnChange ?? 0) }

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
        PhaseAnimator(
            MorphPhase.script,
            trigger: morphAmount > 0 ? c.items : []
        ) { phase in
            GlassEffectContainer(spacing: containerSpacing) {
                stack { item in
                    glassed(item, morph: phase.morph * morphAmount)
                }
            }
            .scaleEffect(x: phase.scaleX, y: phase.scaleY)
        } animation: { phase in
            .spring(duration: phase.duration, bounce: 0.35)
        }
    }

    /// What the glass does to its own outline while a change plays.
    ///
    /// Measured off a 60fps capture of the system's own bar button swapping its
    /// icon: it does **not** scale. It squares up — the top and bottom edges
    /// flatten first, then the sides — and unwinds back to a circle. What reads
    /// as a press is the outline losing its roundness, not the glass growing.
    ///
    /// The scale left here is the hair of anisotropy that sells which edge went
    /// first; the shape does the rest.
    private enum MorphPhase {
        case rest
        case flattenVertical
        case squared

        /// Rest, out through both stages, back to rest.
        static let script: [MorphPhase] = [.rest, .flattenVertical, .squared, .rest]

        /// How far towards a square, before the caller's amount scales it.
        var morph: CGFloat {
            switch self {
            case .rest: return 0
            case .flattenVertical: return 0.7
            case .squared: return 1
            }
        }

        var scaleX: CGFloat { self == .flattenVertical ? 1.02 : 1 }
        var scaleY: CGFloat { self == .flattenVertical ? 0.98 : 1 }

        /// Out quickly, back at leisure — the timing of a press.
        var duration: Double {
            switch self {
            case .rest: return 0.28
            case .flattenVertical: return 0.09
            case .squared: return 0.11
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
    private func glassed(_ item: GlassGroupItemConfig, morph: CGFloat) -> some View {
        if transitionName(for: item) == "intensity" {
            // Custom, and deliberately not a transition: `materialize` scales
            // the glass in, and the glass this reproduces does not move at all.
            // The material is always mounted and only its opacity travels, so
            // there is nothing for SwiftUI to insert or remove — which is also
            // why this glass cannot merge or match geometry with a neighbour.
            //
            // The material lives in a background layer of its own so the gauge
            // reaches it alone; opacity on the glassed view would take the
            // content down with it.
            let on = item.glassVisible != false
            button(item)
                .opacity(on ? 1 : 0)
                // The content's own blur in and out, which is all it wants —
                // a bare fade reads as a decal being switched off, not as an
                // icon resolving out of the material.
                .blur(radius: on ? 0 : 6)
                .background {
                    Color.clear
                        .glassEffect(glass, in: shape(for: item, morph: morph))
                        .opacity(on ? 1 : 0)
                }
        } else if item.glassVisible == false {
            button(item).hidden()
        } else {
            button(item)
                .glassEffect(glass, in: shape(for: item, morph: morph))
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

    @ViewBuilder
    private func button(_ item: GlassGroupItemConfig) -> some View {
        if let menuItems = item.menuItems, !menuItems.isEmpty {
            // The glass is the `Menu`'s own label, so the system has the
            // capsule as its anchor and grows the menu out of it — the whole
            // shape transforms, which is what it does for a toolbar menu and
            // what a tap gesture presenting something separately cannot give.
            Menu {
                ForEach(menuItems) { entry in
                    MenuItemMapper(item: entry) { actionId, _ in onAction(actionId) }
                }
            } label: {
                label(item).opacity(item.enabled == false ? 0.4 : 1)
            }
            .menuStyle(.button)
            .buttonStyle(.plain)
            .disabled(item.enabled == false)
        } else {
            label(item)
                .opacity(item.enabled == false ? 0.4 : 1)
                .contentShape(Rectangle())
                .onTapGesture { if item.enabled != false { onAction(item.actionId) } }
        }
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
    /// The transition the item asked for, before it is resolved to a SwiftUI
    /// one — `intensity` has no SwiftUI equivalent, so it is read by name.
    private func transitionName(for item: GlassGroupItemConfig) -> String {
        item.transition ?? c.transition ?? "matchedGeometry"
    }

    private func transition(for item: GlassGroupItemConfig) -> GlassEffectTransition {
        switch item.transition ?? c.transition {
        case "materialize": return .materialize
        case "identity": return .identity
        default: return .matchedGeometry
        }
    }

    /// The outline of one glass, `morph` of the way from its own roundness
    /// towards a square.
    ///
    /// One shape covers every case, which is what lets the morph be a single
    /// number instead of a change of shape type — and a change of type is
    /// exactly what matched geometry cannot interpolate across.
    ///
    /// It also settles the union on its own: a union's frame is the whole
    /// group's bounding box, and this fills it, where a `Circle` would be
    /// *inscribed* in it and collapse to one item's worth of glass in the
    /// middle. Measured, not reasoned: see docs/glass-transitions.md.
    private func shape(for item: GlassGroupItemConfig, morph: CGFloat) -> AnyShape {
        if !sharesOneGlass, item.shape == "roundedRect" {
            return AnyShape(
                FixedRadiusShape(
                    radius: CGFloat(c.cornerRadius ?? 16), morph: morph))
        }
        return AnyShape(MorphingCapsule(morph: morph))
    }
}

/// A capsule that can be squared up.
///
/// The radius is half the frame's *short* side, taken from the frame it is
/// handed rather than from the item's declared height — which is the whole
/// point. A `RoundedRectangle` with a hard-coded radius is only a circle when
/// the frame happens to match it, and a glass's frame is its own, larger than
/// the label inside it. At `morph` 0 this is exactly a `Capsule`: a circle on a
/// square frame, a capsule on a wide one, whatever the size.
@available(iOS 26.0, *)
private struct MorphingCapsule: Shape {
    var morph: CGFloat

    var animatableData: CGFloat {
        get { morph }
        set { morph = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let full = min(rect.width, rect.height) / 2
        let clamped = Swift.min(Swift.max(morph, 0), 1)
        return RoundedRectangle(cornerRadius: full * (1 - clamped), style: .continuous)
            .path(in: rect)
    }
}

/// The same, for an item that named its own corner radius.
@available(iOS 26.0, *)
private struct FixedRadiusShape: Shape {
    var radius: CGFloat
    var morph: CGFloat

    var animatableData: CGFloat {
        get { morph }
        set { morph = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let clamped = Swift.min(Swift.max(morph, 0), 1)
        return RoundedRectangle(cornerRadius: radius * (1 - clamped), style: .continuous)
            .path(in: rect)
    }
}
