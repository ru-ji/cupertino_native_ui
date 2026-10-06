import Flutter
import SwiftUI
import UIKit

/// One platform view for the small single-value SwiftUI controls: stepper,
/// color picker, gauge, multi-date picker, text editor. `kind` picks the
/// control; they share the channel, the sizing and the update path, so each
/// one is just its `case` in `AdaptiveControlView`.
@available(iOS 15.0, *)
class NativeControlFactory: NSObject, FlutterPlatformViewFactory {
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
        NativeControlView(viewIdentifier: viewId, arguments: args, messenger: messenger)
    }

    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}

@available(iOS 15.0, *)
struct ControlConfig: Codable {
    /// "stepper" | "colorPicker" | "gauge" | "multiDatePicker" | "textEditor"
    let kind: String
    /// Hug the control's own size (centred) instead of filling the box.
    let hug: Bool?
    let label: String?
    let tint: Int?
    let enabled: Bool?
    let isDark: Bool?

    // Stepper, gauge.
    let value: Double?
    let min: Double?
    let max: Double?
    let step: Double?
    /// Gauge: "automatic" | "linearCapacity" | "circular" | "circularCapacity".
    let gaugeStyle: String?
    let currentValueLabel: String?
    let minimumValueLabel: String?
    let maximumValueLabel: String?

    // Color picker (ARGB).
    let color: Int?
    let supportsOpacity: Bool?

    // Multi-date picker: milliseconds since epoch.
    let dates: [Double]?
    let minimumDate: Double?
    let maximumDate: Double?

    // Text editor.
    let text: String?
    let placeholder: String?
    let fontSize: Double?
    /// Dart `FontWeight.index` (0...8).
    let fontWeight: Int?
    let textColor: Int?
    let cursorColor: Int?
    let backgroundColor: Int?
    let cornerRadius: Double?
    /// The `CupertinoNativeTextField` names: see `BackingTextField`.
    let keyboardType: String?
    let textCapitalization: String?
    let textContentType: String?
    let textAlign: String?
    let autocorrect: Bool?
    let maxLength: Int?
    let readOnly: Bool?
    /// "regular" | "clear" | "identity"; nil = no glass. Always interactive.
    let glass: String?
    let glassTint: Int?
    /// The placeholder's offset from the editor's corner; nil = the default
    /// (see `placeholderInsets`).
    let placeholderTop: Double?
    let placeholderLeading: Double?
    /// Room between the editor and its background / glass edge.
    let padding: EdgeInsetsDTO?
    /// The editor's height, for a native body: there no Flutter box sizes it.
    let height: Double?
    /// A lowered Flutter widget drawn before the text, on its first line.
    /// One node at most; an array because a struct cannot hold itself (a
    /// body node can hold a control config).
    let prefix: [BodyNodeConfig]?
}

/// The shown values, owned by the bridge: a value from Dart and the echo of a
/// user edit land in the same place, and nothing re-attaches mid-gesture.
@available(iOS 15.0, *)
final class ControlModel: ObservableObject {
    @Published var config: ControlConfig
    @Published var value: Double = 0
    @Published var color: Color = .accentColor
    @Published var dates: Set<DateComponents> = []
    @Published var text: String = ""
    /// State of the text editor's lowered `prefix` (its toggles, pickers…).
    let prefixModel = NativeBodyModel()

    init(_ config: ControlConfig) {
        self.config = config
        apply(config)
    }

    func apply(_ config: ControlConfig) {
        self.config = config
        value = config.value ?? 0
        if let argb = config.color { color = Color(argb: argb) }
        dates = Set((config.dates ?? []).map { Self.day(Date(timeIntervalSince1970: $0 / 1000)) })
        // Only when it differs: re-assigning the same text still moves the caret.
        if let text = config.text, text != self.text { self.text = text }
        prefixModel.seedAll(config.prefix ?? [])
        for node in config.prefix ?? [] { prefixModel.applyConfigs(node) }
    }

    static func day(_ date: Date) -> DateComponents {
        Calendar.current.dateComponents([.calendar, .era, .year, .month, .day], from: date)
    }
}

@available(iOS 15.0, *)
class NativeControlView: NativeHostingView {
    private var channel: FlutterMethodChannel?
    private var model: ControlModel?

    init(viewIdentifier viewId: Int64, arguments args: Any?, messenger: FlutterBinaryMessenger) {
        super.init()
        _view.viewId = viewId

        channel = FlutterMethodChannel(
            name: "cupertino_native_ui/control_\(viewId)", binaryMessenger: messenger)
        sizeChannel = channel
        channel?.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }

        guard let argsMap = args as? [String: Any],
            let config = decodeConfig(ControlConfig.self, from: argsMap)
        else { return }
        let model = ControlModel(config)
        self.model = model
        isDark = config.isDark
        let content = AnyView(
            AdaptiveControlView(
                model: model,
                onChanged: { [weak self] value in
                    self?.channel?.invokeMethod("onChanged", arguments: value)
                },
                onFocus: { [weak self] focused in
                    self?.channel?.invokeMethod("onFocus", arguments: focused)
                },
                onEvent: { [weak self] id, value in
                    self?.channel?.invokeMethod("onEvent", arguments: ["id": id, "value": value])
                },
                onScrollState: { [weak self] state in
                    self?.channel?.invokeMethod("onScrollState", arguments: state)
                }))
        guard config.hug == true else {
            attach(content)
            return
        }
        // Hug the control, centred, inside whatever box Flutter gives it.
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
        switch call.method {
        case "snapshot":
            result(PlatformViewSnapshot.capture(view()))
        case "cancelTouches":
            cancelTouches()
            result(nil)
        case "getIntrinsicSize":
            result(intrinsicSize())
        case "update":
            if let argsMap = call.arguments as? [String: Any],
                let config = decodeConfig(ControlConfig.self, from: argsMap)
            {
                isDark = config.isDark
                model?.apply(config)
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
struct AdaptiveControlView: View {
    @ObservedObject var model: ControlModel
    let onChanged: (Any) -> Void
    /// The text editor's focus: Flutter cannot see a native first responder,
    /// and needs it to lift the editor above the keyboard.
    var onFocus: (Bool) -> Void = { _ in }
    /// An event from a lowered node (the text editor's `prefix`).
    var onEvent: (String, Any?) -> Void = { _, _ in }
    /// Where the text editor's own scrolling stands: Flutter decides from it
    /// whether a drag on the editor scrolls the text or the page.
    var onScrollState: ([String: Bool]) -> Void = { _ in }
    /// The prefix's measured width, added to the placeholder's leading inset.
    @State private var prefixWidth: CGFloat = 0

    private var config: ControlConfig { model.config }

    var body: some View {
        control
            .tint(config.tint.map { Color(argb: $0) })
            .disabled(config.enabled == false)
    }

    @ViewBuilder
    private var control: some View {
        switch config.kind {
        case "stepper": stepper
        case "colorPicker": colorPicker
        case "gauge": gauge
        case "multiDatePicker": multiDatePicker
        case "textEditor": textEditor
        default: EmptyView()
        }
    }

    private var label: Text { Text(config.label ?? "") }

    /// No label → no empty leading slot either.
    @ViewBuilder
    private func hidingEmptyLabel(_ view: some View) -> some View {
        if config.label == nil { view.labelsHidden() } else { view }
    }

    private var stepper: some View {
        hidingEmptyLabel(
            Stepper(
                value: Binding(
                    get: { model.value },
                    set: { model.value = $0; onChanged($0) }),
                in: (config.min ?? -Double.greatestFiniteMagnitude)...(config.max
                    ?? Double.greatestFiniteMagnitude),
                step: config.step ?? 1
            ) { label })
    }

    private var colorPicker: some View {
        hidingEmptyLabel(
            ColorPicker(
                selection: Binding(
                    get: { model.color },
                    set: { model.color = $0; onChanged(Self.argb($0)) }),
                supportsOpacity: config.supportsOpacity ?? true
            ) { label })
    }

    @ViewBuilder
    private var gauge: some View {
        let range = (config.min ?? 0)...(config.max ?? 1)
        if #available(iOS 16.0, *) {
            Gauge(value: model.value, in: range) {
                label
            } currentValueLabel: {
                Text(config.currentValueLabel ?? "")
            } minimumValueLabel: {
                Text(config.minimumValueLabel ?? "")
            } maximumValueLabel: {
                Text(config.maximumValueLabel ?? "")
            }
            .applyGaugeStyle(config.gaugeStyle)
        } else {
            ProgressView(value: model.value - range.lowerBound,
                         total: range.upperBound - range.lowerBound) { label }
        }
    }

    @ViewBuilder
    private var multiDatePicker: some View {
        if #available(iOS 16.0, *) {
            let selection = Binding<Set<DateComponents>>(
                get: { model.dates },
                set: { newValue in
                    model.dates = newValue
                    onChanged(
                        newValue.compactMap { Calendar.current.date(from: $0) }
                            .map { $0.timeIntervalSince1970 * 1000 }.sorted())
                })
            let lower = config.minimumDate.map { Date(timeIntervalSince1970: $0 / 1000) }
            let upper = config.maximumDate.map { Date(timeIntervalSince1970: $0 / 1000) }
            // MultiDatePicker takes a half-open range, so the last day is
            // included by going to the start of the next one.
            let end = upper.flatMap { Calendar.current.date(byAdding: .day, value: 1, to: $0) }
            if let lower, let end {
                MultiDatePicker(selection: selection, in: lower..<end) { label }
            } else if let lower {
                MultiDatePicker(selection: selection, in: lower...) { label }
            } else if let end {
                MultiDatePicker(selection: selection, in: ..<end) { label }
            } else {
                MultiDatePicker(selection: selection) { label }
            }
        }
    }

    private var textEditor: some View {
        HStack(alignment: .top, spacing: 0) {
            if let prefix = config.prefix?.first {
                NativeBodyNode(node: prefix, model: model.prefixModel, onEvent: onEvent)
                    // On the first line, which sits at the text view's own
                    // top inset.
                    .padding(.top, placeholderInsets.top)
                    .background(
                        GeometryReader { geometry in
                            Color.clear.preference(
                                key: PrefixWidthKey.self, value: geometry.size.width)
                        })
            }
            editor
        }
        .onPreferenceChange(PrefixWidthKey.self) { prefixWidth = $0 }
        // TextEditor has no placeholder of its own: draw it over the editor
        // while empty, where typed text starts (the text view's inset plus
        // the padding, past the prefix). Inside the glass, so the glass does
        // not shift it.
        .overlay(alignment: .topLeading) {
            if model.text.isEmpty, let placeholder = config.placeholder {
                Text(placeholder)
                    .font(editorFont)
                    .foregroundStyle(.tertiary)
                    .padding(.top, placeholderInsets.top)
                    .padding(.leading, placeholderInsets.leading + (config.prefix?.first == nil ? 0 : prefixWidth))
                    .allowsHitTesting(false)
            }
        }
        // Sideways the padding is around the text view, so the prefix moves
        // with it; above and below it is inside, see `TextViewScrollProbe`.
        .padding(.leading, CGFloat(config.padding?.left ?? 0))
        .padding(.trailing, CGFloat(config.padding?.right ?? 0))
        .background(config.backgroundColor.map { Color(argb: $0) })
        .clipShape(RoundedRectangle(cornerRadius: config.cornerRadius ?? 0, style: .continuous))
        .modifier(EditorGlass(config: config))
        .frame(height: config.height.map { CGFloat($0) })
    }

    private var editorFont: Font {
        Font.system(
            size: config.fontSize ?? 17,
            weight: Font.Weight(weightIndex: config.fontWeight ?? 3))
    }

    private var editor: some View {
        TextEditor(
            text: Binding(
                get: { model.text },
                set: { new in
                    // Read-only still selects and copies; edits are refused.
                    guard config.readOnly != true else {
                        model.objectWillChange.send()
                        return
                    }
                    let text = config.maxLength.map { String(new.prefix($0)) } ?? new
                    model.text = text
                    if text != new { model.objectWillChange.send() }
                    onChanged(text)
                })
        )
        .font(editorFont)
        .foregroundColor(config.textColor.map { Color(argb: $0) })
        .tint(config.cursorColor.map { Color(argb: $0) })
        .multilineTextAlignment(
            config.textAlign == "center" ? .center
                : config.textAlign == "right" || config.textAlign == "end" ? .trailing : .leading)
        .keyboardType(BackingTextField.keyboardType(config.keyboardType))
        .autocapitalization(BackingTextField.capitalization(config.textCapitalization))
        .disableAutocorrection(config.autocorrect == false)
        .textContentType(config.textContentType.map { UITextContentType(rawValue: $0) })
        .hiddenEditorBackground()
        .background(
            TextViewScrollProbe(
                onScrollState: onScrollState, onFocus: onFocus,
                textInsets: UIEdgeInsets(
                    top: CGFloat(config.padding?.top ?? 0), left: 0,
                    bottom: CGFloat(config.padding?.bottom ?? 0), right: 0)))
    }

    /// Where typed text starts: the UITextView's own inset, 8 top and 5
    /// leading, overridable from Dart (`placeholderPadding`) where a font or
    /// an iOS version moves it, plus the padding above the text.
    private var placeholderInsets: (top: CGFloat, leading: CGFloat) {
        (
            CGFloat((config.placeholderTop ?? 8) + (config.padding?.top ?? 0)),
            CGFloat(config.placeholderLeading ?? 5)
        )
    }

    private struct PrefixWidthKey: PreferenceKey {
        static var defaultValue: CGFloat = 0
        static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) { value = nextValue() }
    }

    /// `.glassEffect`, always interactive, in the editor's rounded shape.
    private struct EditorGlass: ViewModifier {
        let config: ControlConfig

        func body(content: Content) -> some View {
            if let variant = config.glass, #available(iOS 26.0, *) {
                content.glassEffect(
                    glass(variant),
                    in: RoundedRectangle(
                        cornerRadius: config.cornerRadius ?? 16, style: .continuous))
            } else {
                content
            }
        }

        @available(iOS 26.0, *)
        private func glass(_ variant: String) -> Glass {
            var style: Glass
            switch variant {
            case "clear": style = .clear
            case "identity": style = .identity
            default: style = .regular
            }
            if let tint = config.glassTint { style = style.tint(Color(argb: tint)) }
            return style.interactive()
        }
    }

    private static func argb(_ color: Color) -> Int {
        var r: CGFloat = 0, g: CGFloat = 0, b: CGFloat = 0, a: CGFloat = 0
        UIColor(color).getRed(&r, green: &g, blue: &b, alpha: &a)
        func byte(_ v: CGFloat) -> Int { Int((Swift.max(0, Swift.min(1, v)) * 255).rounded()) }
        return (byte(a) << 24) | (byte(r) << 16) | (byte(g) << 8) | byte(b)
    }
}

@available(iOS 16.0, *)
extension View {
    @ViewBuilder
    fileprivate func applyGaugeStyle(_ style: String?) -> some View {
        switch style {
        case "linearCapacity": self.gaugeStyle(.linearCapacity)
        case "circular": self.gaugeStyle(.accessoryCircular)
        case "circularCapacity": self.gaugeStyle(.accessoryCircularCapacity)
        default: self.gaugeStyle(.automatic)
        }
    }
}

@available(iOS 15.0, *)
extension View {
    /// TextEditor paints the system background (white / black) whatever sits
    /// behind it: hidden, it is transparent like a text field, and
    /// `backgroundColor` is the only fill. iOS 16+; below, it stays.
    @ViewBuilder fileprivate func hiddenEditorBackground() -> some View {
        if #available(iOS 16.0, *) {
            self.scrollContentBackground(.hidden)
        } else {
            self
        }
    }
}

/// Finds the `UITextView` under a SwiftUI `TextEditor` and reports where its
/// own scrolling stands, each time that changes: whether the text overflows
/// (`scrolls`), whether it rests at the top or the bottom (`atTop`,
/// `atBottom`), and whether it is still moving, dragged, decelerating or
/// bouncing (`moving`).
///
/// Flutter hands a drag on the editor to the text or to the page from this,
/// the way UIKit does with a text view nested in a scroll view: the text
/// keeps every drag while it is in between, or still moving; at rest at an
/// edge, a drag past that edge scrolls the page instead.
@available(iOS 15.0, *)
private struct TextViewScrollProbe: UIViewRepresentable {
    let onScrollState: ([String: Bool]) -> Void
    /// The text view's focus, straight from UIKit's begin / end editing
    /// notifications: posted as it takes the responder, before the keyboard
    /// starts to rise. Not `@FocusState` + `.onChange`: that waited for the
    /// next view update, and on a first focus the keyboard had already risen
    /// when Flutter learned which field to lift.
    let onFocus: (Bool) -> Void
    /// Added to the text view's own `textContainerInset`: room inside the
    /// scrolling text, which scrolls through it up to the editor's edge.
    /// SwiftUI has no inset for a `TextEditor`'s text.
    let textInsets: UIEdgeInsets

    func makeUIView(context: Context) -> Probe {
        let probe = Probe(onScrollState: onScrollState, onFocus: onFocus)
        probe.textInsets = textInsets
        return probe
    }
    func updateUIView(_ probe: Probe, context: Context) {
        probe.onScrollState = onScrollState
        probe.onFocus = onFocus
        probe.textInsets = textInsets
    }

    final class Probe: UIView {
        var onScrollState: ([String: Bool]) -> Void
        var onFocus: (Bool) -> Void
        private var observations: [NSKeyValueObservation] = []
        private var focusObservers: [NSObjectProtocol] = []
        private weak var textView: UITextView?
        private var reported: [String: Bool]?
        /// Polls while the text moves: the end of a deceleration or a bounce
        /// changes no observable property of its own.
        private var link: CADisplayLink?
        var textInsets: UIEdgeInsets = .zero {
            didSet { if textInsets != oldValue { applyInsets() } }
        }
        /// The text view's own inset, as found.
        private var baseInset: UIEdgeInsets?

        init(
            onScrollState: @escaping ([String: Bool]) -> Void,
            onFocus: @escaping (Bool) -> Void
        ) {
            self.onScrollState = onScrollState
            self.onFocus = onFocus
            super.init(frame: .zero)
            isUserInteractionEnabled = false
        }
        required init?(coder: NSCoder) { fatalError() }

        override func didMoveToWindow() {
            super.didMoveToWindow()
            if window == nil {
                link?.invalidate()
                link = nil
                return
            }
            guard observations.isEmpty else { return }
            // After this pass: the text view is laid out next to the probe.
            DispatchQueue.main.async { [weak self] in self?.observe() }
        }

        private func observe() {
            var ancestor = superview
            var found: UITextView?
            while let view = ancestor, found == nil {
                found = Self.textView(in: view, depth: 0)
                ancestor = view.superview
            }
            guard let found else { return }
            textView = found
            baseInset = found.textContainerInset
            applyInsets()
            let center = NotificationCenter.default
            focusObservers = [
                center.addObserver(
                    forName: UITextView.textDidBeginEditingNotification, object: found,
                    queue: nil
                ) { [weak self] _ in self?.onFocus(true) },
                center.addObserver(
                    forName: UITextView.textDidEndEditingNotification, object: found,
                    queue: nil
                ) { [weak self] _ in self?.onFocus(false) },
            ]
            let changed: (UITextView) -> Void = { [weak self] _ in
                DispatchQueue.main.async { self?.check() }
            }
            observations = [
                found.observe(\.contentOffset, options: [.new]) { view, _ in changed(view) },
                found.observe(\.contentSize, options: [.initial, .new]) { view, _ in changed(view) },
                found.observe(\.bounds, options: [.new]) { view, _ in changed(view) },
            ]
        }

        private func check() {
            guard let view = textView else { return }
            let inset = view.adjustedContentInset
            let top = -inset.top
            let bottom = max(top, view.contentSize.height - view.bounds.height + inset.bottom)
            let y = view.contentOffset.y
            let bouncing = y < top - 0.5 || y > bottom + 0.5
            let moving = view.isDragging || view.isDecelerating || bouncing
            let state = [
                "scrolls": view.contentSize.height > view.bounds.height + 1,
                "atTop": y <= top + 0.5,
                "atBottom": y >= bottom - 0.5,
                "moving": moving,
            ]
            if moving, link == nil {
                let link = CADisplayLink(target: self, selector: #selector(tick))
                link.add(to: .main, forMode: .common)
                self.link = link
            } else if !moving {
                link?.invalidate()
                link = nil
            }
            guard state != reported else { return }
            reported = state
            onScrollState(state)
        }

        @objc private func tick() { check() }

        private func applyInsets() {
            guard let view = textView, let base = baseInset else { return }
            view.textContainerInset = UIEdgeInsets(
                top: base.top + textInsets.top, left: base.left + textInsets.left,
                bottom: base.bottom + textInsets.bottom, right: base.right + textInsets.right)
        }

        deinit {
            focusObservers.forEach(NotificationCenter.default.removeObserver)
        }

        private static func textView(in view: UIView, depth: Int) -> UITextView? {
            if let textView = view as? UITextView { return textView }
            guard depth < 12 else { return nil }
            for subview in view.subviews {
                if let found = textView(in: subview, depth: depth + 1) { return found }
            }
            return nil
        }
    }
}
