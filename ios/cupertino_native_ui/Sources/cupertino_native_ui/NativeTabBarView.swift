import Flutter
import UIKit

@available(iOS 15.0, *)
class NativeTabBarFactory: NSObject, FlutterPlatformViewFactory {
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
        return NativeTabBarView(
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

/// A bare `UITabBar` (or two, in split mode) inside a transparent container:
/// no UITabBarController/TabView wrapper, so nothing paints a content-area
/// background and Flutter content stays visible around and through the bar.
/// Technique reproduced from the cupertino_native package.
@available(iOS 15.0, *)
class NativeTabBarView: NSObject, FlutterPlatformView, UITabBarDelegate {
    private let channel: FlutterMethodChannel
    private let container: TabBarContainerView
    private var tabBar: UITabBar?
    private var tabBarLeft: UITabBar?
    private var tabBarRight: UITabBar?
    private var isSplit = false
    private var rightCountVal = 1
    private var splitSpacingVal: CGFloat = 8
    private var scrollEdgeEffectVal = "automatic"
    private var currentLabels: [String] = []
    private var currentSymbols: [String] = []
    private var currentBadges: [String] = []

    init(
        frame: CGRect,
        viewIdentifier viewId: Int64,
        arguments args: Any?,
        messenger: FlutterBinaryMessenger
    ) {
        channel = FlutterMethodChannel(
            name: "cupertino_native_ui/tabbar_\(viewId)", binaryMessenger: messenger)
        container = TabBarContainerView(frame: frame)

        var labels: [String] = []
        var symbols: [String] = []
        var badges: [String] = []
        var selectedIndex = 0
        var isDark = false
        var tint: UIColor? = nil
        var bg: UIColor? = nil
        var split = false
        var rightCount = 1

        if let dict = args as? [String: Any] {
            labels = (dict["labels"] as? [String]) ?? []
            symbols = (dict["sfSymbols"] as? [String]) ?? []
            badges = (dict["badges"] as? [String]) ?? []
            if let v = dict["selectedIndex"] as? NSNumber { selectedIndex = v.intValue }
            if let v = dict["isDark"] as? NSNumber { isDark = v.boolValue }
            if let n = dict["tint"] as? NSNumber { tint = UIColor(argb: n.intValue) }
            if let n = dict["backgroundColor"] as? NSNumber { bg = UIColor(argb: n.intValue) }
            if let s = dict["split"] as? NSNumber { split = s.boolValue }
            if let rc = dict["rightCount"] as? NSNumber { rightCount = rc.intValue }
            if let sp = dict["splitSpacing"] as? NSNumber {
                splitSpacingVal = CGFloat(truncating: sp)
            }
            if let se = dict["scrollEdgeEffect"] as? String { scrollEdgeEffectVal = se }
        }

        super.init()

        container.backgroundColor = .clear
        container.overrideUserInterfaceStyle = isDark ? .dark : .light

        currentLabels = labels
        currentSymbols = symbols
        currentBadges = badges
        isSplit = split
        rightCountVal = rightCount

        rebuildBars(selectedIndex: selectedIndex, tint: tint, backgroundColor: bg)

        channel.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
        container.onLayout = { [weak self] in self?.reportPlatters() }
    }

    func view() -> UIView { container }

    /// The glass pills the bars draw, in the view's points, as last reported.
    private var sentPlatters: [CGRect] = []

    /// Tells Dart where each bar's glass pill is. The bar's frame holds more
    /// than the pill (the full width, the space under it), so the scroll edge
    /// effect cuts its wash out under the pill alone. After the bars' own
    /// layout, which follows the container's in the same pass.
    private func reportPlatters() {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let rects = [self.tabBar, self.tabBarLeft, self.tabBarRight]
                .compactMap { $0 }
                .compactMap { self.platterRect(in: $0) }
            guard rects != self.sentPlatters else { return }
            self.sentPlatters = rects
            self.channel.invokeMethod(
                "platters",
                arguments: rects.flatMap {
                    [Double($0.minX), Double($0.minY), Double($0.width), Double($0.height)]
                })
        }
    }

    /// The bar's glass pill: its platter view, or else its buttons with the
    /// platter's padding around them.
    private func platterRect(in bar: UITabBar) -> CGRect? {
        if let platter = Self.firstSubview(of: bar, named: "Platter") {
            return platter.convert(platter.bounds, to: container)
        }
        let buttons = Self.subviews(of: bar, named: "TabBarButton")
        guard let first = buttons.first else { return nil }
        let union = buttons.dropFirst().reduce(first.convert(first.bounds, to: container)) {
            $0.union($1.convert($1.bounds, to: container))
        }
        return union.insetBy(dx: -4, dy: -4)
    }

    private static func firstSubview(of view: UIView, named part: String) -> UIView? {
        for subview in view.subviews {
            if NSStringFromClass(type(of: subview)).contains(part) { return subview }
            if let found = firstSubview(of: subview, named: part) { return found }
        }
        return nil
    }

    private static func subviews(of view: UIView, named part: String) -> [UIView] {
        view.subviews.flatMap { subview -> [UIView] in
            NSStringFromClass(type(of: subview)).contains(part)
                ? [subview] : subviews(of: subview, named: part)
        }
    }

    /// The view and everything in it: the bar's glass lives a few levels down.
    private static func markNeedsLayout(_ view: UIView) {
        view.setNeedsLayout()
        for subview in view.subviews { markNeedsLayout(subview) }
    }

    // MARK: - Bar construction

    private func buildItems(_ range: Range<Int>) -> [UITabBarItem] {
        var items: [UITabBarItem] = []
        for i in range {
            var image: UIImage? = nil
            if i < currentSymbols.count, !currentSymbols[i].isEmpty {
                image = UIImage(systemName: currentSymbols[i])
            }
            let title: String? =
                (i < currentLabels.count && !currentLabels[i].isEmpty) ? currentLabels[i] : nil
            let item = UITabBarItem(title: title, image: image, selectedImage: image)
            if i < currentBadges.count, !currentBadges[i].isEmpty {
                item.badgeValue = currentBadges[i]
            }
            items.append(item)
        }
        return items
    }

    private func makeBar(tint: UIColor?, backgroundColor: UIColor?) -> UITabBar {
        let bar = UITabBar(frame: .zero)
        bar.translatesAutoresizingMaskIntoConstraints = false
        bar.delegate = self
        if let bg = backgroundColor { bar.barTintColor = bg }
        if let tint = tint { bar.tintColor = tint }
        applyAppearance(to: bar)
        return bar
    }

    /// Maps the `scrollEdgeEffect` style to the bar's background material:
    /// `hard` uses an opaque background, everything else the translucent
    /// default (the closest standalone-UIKit equivalent of the iOS 26 effect).
    private func applyAppearance(to bar: UITabBar) {
        let appearance = UITabBarAppearance()
        switch scrollEdgeEffectVal {
        case "hard":
            appearance.configureWithOpaqueBackground()
        default:
            appearance.configureWithDefaultBackground()
        }
        bar.standardAppearance = appearance
        bar.scrollEdgeAppearance = appearance
    }

    /// (Re)creates the bar hierarchy for the current items and layout mode.
    private func rebuildBars(selectedIndex: Int, tint: UIColor? = nil, backgroundColor: UIColor? = nil) {
        tabBar?.removeFromSuperview()
        tabBar = nil
        tabBarLeft?.removeFromSuperview()
        tabBarLeft = nil
        tabBarRight?.removeFromSuperview()
        tabBarRight = nil

        let count = max(currentLabels.count, currentSymbols.count)

        if isSplit && count > rightCountVal {
            let leftEnd = count - rightCountVal
            let left = makeBar(tint: tint, backgroundColor: backgroundColor)
            let right = makeBar(tint: tint, backgroundColor: backgroundColor)
            tabBarLeft = left
            tabBarRight = right
            left.items = buildItems(0..<leftEnd)
            right.items = buildItems(leftEnd..<count)
            applySelection(selectedIndex)
            container.addSubview(left)
            container.addSubview(right)

            let spacing = splitSpacingVal
            let leftWidth = left.sizeThatFits(.zero).width
            let rightWidth = right.sizeThatFits(.zero).width
            let total = leftWidth + rightWidth + spacing
            if total > container.bounds.width {
                // Content wider than the container: fall back to proportional widths.
                let rightFraction = CGFloat(rightCountVal) / CGFloat(count)
                NSLayoutConstraint.activate([
                    right.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    right.topAnchor.constraint(equalTo: container.topAnchor),
                    right.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                    right.widthAnchor.constraint(
                        equalTo: container.widthAnchor, multiplier: rightFraction),
                    left.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    left.trailingAnchor.constraint(
                        equalTo: right.leadingAnchor, constant: -spacing),
                    left.topAnchor.constraint(equalTo: container.topAnchor),
                    left.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                ])
            } else {
                NSLayoutConstraint.activate([
                    right.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                    right.topAnchor.constraint(equalTo: container.topAnchor),
                    right.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                    right.widthAnchor.constraint(equalToConstant: rightWidth),
                    left.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                    left.topAnchor.constraint(equalTo: container.topAnchor),
                    left.bottomAnchor.constraint(equalTo: container.bottomAnchor),
                    left.widthAnchor.constraint(equalToConstant: leftWidth),
                    left.trailingAnchor.constraint(
                        lessThanOrEqualTo: right.leadingAnchor, constant: -spacing),
                ])
            }
        } else {
            let bar = makeBar(tint: tint, backgroundColor: backgroundColor)
            tabBar = bar
            bar.items = buildItems(0..<count)
            applySelection(selectedIndex)
            container.addSubview(bar)
            NSLayoutConstraint.activate([
                bar.leadingAnchor.constraint(equalTo: container.leadingAnchor),
                bar.trailingAnchor.constraint(equalTo: container.trailingAnchor),
                bar.topAnchor.constraint(equalTo: container.topAnchor),
                bar.bottomAnchor.constraint(equalTo: container.bottomAnchor),
            ])
        }
    }

    private func applySelection(_ index: Int) {
        if let bar = tabBar, let items = bar.items, index >= 0, index < items.count {
            bar.selectedItem = items[index]
            return
        }
        guard let left = tabBarLeft, let leftItems = left.items else { return }
        if index >= 0, index < leftItems.count {
            left.selectedItem = leftItems[index]
            tabBarRight?.selectedItem = nil
        } else if let right = tabBarRight, let rightItems = right.items {
            let idx = index - leftItems.count
            if idx >= 0, idx < rightItems.count {
                right.selectedItem = rightItems[idx]
                left.selectedItem = nil
            }
        }
    }

    // MARK: - Method channel

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        // A bitmap of this view, for Flutter to draw while a route
        // transition runs. See PlatformViewSnapshot.
        if call.method == "snapshot" {
            result(PlatformViewSnapshot.capture(view()))
            return
        }
        switch call.method {
        case "getIntrinsicSize":
            if isSplit, let left = tabBarLeft, let right = tabBarRight {
                let leftSize = left.sizeThatFits(.zero)
                let rightSize = right.sizeThatFits(.zero)
                result([
                    "width": Double(leftSize.width + splitSpacingVal + rightSize.width),
                    "height": Double(max(leftSize.height, rightSize.height)),
                ])
            } else if let bar = tabBar {
                let size = bar.sizeThatFits(
                    CGSize(
                        width: CGFloat.greatestFiniteMagnitude,
                        height: CGFloat.greatestFiniteMagnitude))
                result(["width": Double(size.width), "height": Double(size.height)])
            } else {
                result(["width": Double(container.bounds.width), "height": 50.0])
            }
        case "setItems":
            if let args = call.arguments as? [String: Any] {
                currentLabels = (args["labels"] as? [String]) ?? []
                currentSymbols = (args["sfSymbols"] as? [String]) ?? []
                currentBadges = (args["badges"] as? [String]) ?? []
                let selectedIndex = (args["selectedIndex"] as? NSNumber)?.intValue ?? 0
                rebuildBars(selectedIndex: selectedIndex)
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing items", details: nil))
            }
        case "setLayout":
            if let args = call.arguments as? [String: Any] {
                isSplit = (args["split"] as? NSNumber)?.boolValue ?? false
                rightCountVal = (args["rightCount"] as? NSNumber)?.intValue ?? 1
                if let sp = args["splitSpacing"] as? NSNumber {
                    splitSpacingVal = CGFloat(truncating: sp)
                }
                let selectedIndex = (args["selectedIndex"] as? NSNumber)?.intValue ?? 0
                rebuildBars(selectedIndex: selectedIndex)
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing layout", details: nil))
            }
        case "setSelectedIndex":
            if let args = call.arguments as? [String: Any],
                let idx = (args["index"] as? NSNumber)?.intValue
            {
                applySelection(idx)
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing index", details: nil))
            }
        case "setStyle":
            if let args = call.arguments as? [String: Any] {
                if let n = args["tint"] as? NSNumber {
                    let c = UIColor(argb: n.intValue)
                    tabBar?.tintColor = c
                    tabBarLeft?.tintColor = c
                    tabBarRight?.tintColor = c
                }
                if let n = args["backgroundColor"] as? NSNumber {
                    let c = UIColor(argb: n.intValue)
                    tabBar?.barTintColor = c
                    tabBarLeft?.barTintColor = c
                    tabBarRight?.barTintColor = c
                }
                if let se = args["scrollEdgeEffect"] as? String {
                    scrollEdgeEffectVal = se
                    [tabBar, tabBarLeft, tabBarRight].forEach { bar in
                        if let bar = bar { applyAppearance(to: bar) }
                    }
                }
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing style", details: nil))
            }
        case "setBrightness":
            if let args = call.arguments as? [String: Any],
                let isDark = (args["isDark"] as? NSNumber)?.boolValue
            {
                let style: UIUserInterfaceStyle = isDark ? .dark : .light
                // Only on a real change: it is the one moment the bar is
                // re-laid out, never per frame.
                guard container.overrideUserInterfaceStyle != style else {
                    result(nil)
                    return
                }
                // Cross-faded, as the system bar follows the content under it.
                UIView.transition(
                    with: container, duration: 0.35,
                    options: [.transitionCrossDissolve, .allowUserInteraction]
                ) {
                    self.container.overrideUserInterfaceStyle = style
                    // The iOS 26 bar redraws its glass for a new appearance
                    // only when it lays out. Without this the change stayed
                    // unseen until a tap re-laid it out, and every later one
                    // with it. Inside the transition, so the fade ends on the
                    // redrawn bar.
                    Self.markNeedsLayout(self.container)
                    self.container.layoutIfNeeded()
                }
                result(nil)
            } else {
                result(FlutterError(code: "INVALID_ARGS", message: "Missing isDark", details: nil))
            }
        default:
            result(FlutterMethodNotImplemented)
        }
    }

    // MARK: - UITabBarDelegate

    func tabBar(_ tabBar: UITabBar, didSelect item: UITabBarItem) {
        if let single = self.tabBar, single === tabBar, let items = single.items,
            let idx = items.firstIndex(of: item)
        {
            channel.invokeMethod("valueChanged", arguments: ["index": idx])
            return
        }
        if let left = tabBarLeft, left === tabBar, let items = left.items,
            let idx = items.firstIndex(of: item)
        {
            tabBarRight?.selectedItem = nil
            channel.invokeMethod("valueChanged", arguments: ["index": idx])
            return
        }
        if let right = tabBarRight, right === tabBar, let items = right.items,
            let idx = items.firstIndex(of: item),
            let left = tabBarLeft, let leftItems = left.items
        {
            tabBarLeft?.selectedItem = nil
            channel.invokeMethod("valueChanged", arguments: ["index": leftItems.count + idx])
            return
        }
    }
}

/// The tab bar's root view: reports its layout, so the bars' pills can be
/// re-measured whenever they may have moved.
@available(iOS 15.0, *)
final class TabBarContainerView: UIView {
    var onLayout: (() -> Void)?

    override func layoutSubviews() {
        super.layoutSubviews()
        onLayout?()
    }
}
