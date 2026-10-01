import Flutter
import SwiftUI
import UIKit

/// One platform view for the small single-value SwiftUI controls — stepper,
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
            name: "cupertino_widgets/control_\(viewId)", binaryMessenger: messenger)
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
    @FocusState private var editorFocused: Bool
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
        // while empty, where typed text starts — the text view's inset, past
        // the prefix. Inside the glass, so the glass does not shift it.
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
        .padding(.top, CGFloat(config.padding?.top ?? 0))
        .padding(.leading, CGFloat(config.padding?.left ?? 0))
        .padding(.trailing, CGFloat(config.padding?.right ?? 0))
        .padding(.bottom, CGFloat(config.padding?.bottom ?? 0))
        .background(config.backgroundColor.map { Color(argb: $0) })
        .clipShape(RoundedRectangle(cornerRadius: config.cornerRadius ?? 0, style: .continuous))
        .modifier(EditorGlass(config: config))
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
        .focused($editorFocused)
        .onChange(of: editorFocused) { onFocus($0) }
    }

    /// Where typed text starts: the UITextView's own inset, 8 top and 5
    /// leading. Overridable from Dart (`placeholderPadding`) where a font or
    /// an iOS version moves it.
    private var placeholderInsets: (top: CGFloat, leading: CGFloat) {
        (CGFloat(config.placeholderTop ?? 8), CGFloat(config.placeholderLeading ?? 5))
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
