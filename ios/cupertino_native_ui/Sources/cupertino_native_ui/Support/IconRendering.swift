import CoreGraphics
import CoreText
import Flutter
import SwiftUI
import UIKit

/// A native icon, decoded from `CupertinoNativeIcon.toMap()` on the Dart side.
@available(iOS 15.0, *)
struct IconConfig: Codable, Hashable {
    let sfSymbol: String?
    let renderingMode: String?  // "monochrome" | "hierarchical" | "palette" | "multicolor"
    let size: Double?
    let color: Int?  // ARGB
    /// SF Symbol stroke weight: "light" | "medium" | "semibold" | "bold".
    let weight: String?
    /// An icon font glyph (`IconData`): its code point, font family and the
    /// package that bundles the font.
    var glyph: Int? = nil
    var fontFamily: String? = nil
    var fontPackage: String? = nil
    /// An image asset's key, as Flutter bundles it.
    var asset: String? = nil
}

/// Custom icons: drawn from the app's own bundle, the font through
/// Flutter's `FontManifest.json`, the asset with its `2.0x` / `3.0x`
/// variant. Nothing crosses the channel but the names.
@available(iOS 15.0, *)
extension IconConfig {
    /// A custom icon's default size, close to an SF Symbol at body size.
    static let defaultPointSize: CGFloat = 22
    /// A tab bar item's, the system's 25pt.
    static let tabPointSize: CGFloat = 25

    /// The custom icon as a template image, `size` (or `pointSize`) points
    /// square. Nil for an SF Symbol, or when the font or asset is not bundled.
    func customImage(pointSize: CGFloat = defaultPointSize) -> UIImage? {
        let side = size.map { CGFloat($0) } ?? pointSize
        let key = "\(glyph ?? 0)|\(fontFamily ?? "")|\(fontPackage ?? "")|\(asset ?? "")|\(side)" as NSString
        if let cached = Self.images.object(forKey: key) { return cached }
        let image: UIImage?
        if let glyph, let fontFamily {
            let family = fontPackage.map { "packages/\($0)/\(fontFamily)" } ?? fontFamily
            image = Self.glyphImage(glyph, family: family, side: side)
        } else if let asset {
            image = Self.assetImage(asset, side: side)
        } else {
            image = nil
        }
        if let image { Self.images.setObject(image, forKey: key) }
        return image
    }

    private static let images = NSCache<NSString, UIImage>()
    private static let fonts = NSCache<NSString, CGFont>()

    private static func bundlePath(_ asset: String) -> String? {
        Bundle.main.path(forResource: FlutterDartProject.lookupKey(forAsset: asset), ofType: nil)
    }

    /// Drawn as Flutter's `Icon` does: the glyph at a font size of `side`,
    /// centred in a `side` square.
    private static func glyphImage(_ codePoint: Int, family: String, side: CGFloat) -> UIImage? {
        guard let cgFont = font(family: family), let scalar = Unicode.Scalar(codePoint) else {
            return nil
        }
        let font = CTFontCreateWithGraphicsFont(cgFont, side, nil, nil) as UIFont
        let text = NSAttributedString(string: String(Character(scalar)), attributes: [.font: font])
        let box = text.size()
        let square = CGSize(width: side, height: side)
        return UIGraphicsImageRenderer(size: square).image { _ in
            text.draw(at: CGPoint(x: (side - box.width) / 2, y: (side - box.height) / 2))
        }.withRenderingMode(.alwaysTemplate)
    }

    private static func font(family: String) -> CGFont? {
        if let cached = fonts.object(forKey: family as NSString) { return cached }
        guard let manifest = bundlePath("FontManifest.json"),
            let data = FileManager.default.contents(atPath: manifest),
            let families = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]],
            let entry = families.first(where: { $0["family"] as? String == family }),
            let file = (entry["fonts"] as? [[String: Any]])?.first?["asset"] as? String,
            let path = bundlePath(file),
            let provider = CGDataProvider(filename: path),
            let font = CGFont(provider)
        else { return nil }
        fonts.setObject(font, forKey: family as NSString)
        return font
    }

    /// The variant for the screen's scale first, then the sharper ones, then
    /// the base file; aspect-fitted in a `side` square.
    private static func assetImage(_ key: String, side: CGFloat) -> UIImage? {
        let dir = (key as NSString).deletingLastPathComponent
        let name = (key as NSString).lastPathComponent
        let screen = UIScreen.main.scale
        let scales = [screen] + [3, 2].filter { $0 != screen } + [1]
        for scale in scales {
            let candidate = scale == 1
                ? key : (dir as NSString).appendingPathComponent(String(format: "%.1fx/%@", scale, name))
            guard let path = bundlePath(candidate), let loaded = UIImage(contentsOfFile: path),
                let cgImage = loaded.cgImage
            else { continue }
            let image = UIImage(cgImage: cgImage, scale: scale, orientation: .up)
            let fit = min(side / image.size.width, side / image.size.height)
            let drawn = CGSize(width: image.size.width * fit, height: image.size.height * fit)
            return UIGraphicsImageRenderer(size: CGSize(width: side, height: side)).image { _ in
                image.draw(in: CGRect(
                    x: (side - drawn.width) / 2, y: (side - drawn.height) / 2,
                    width: drawn.width, height: drawn.height))
            }.withRenderingMode(.alwaysTemplate)
        }
        return nil
    }
}

/// Renders an [IconConfig] as a SwiftUI view: an SF Symbol `Image`, or a
/// custom icon's template image. Used by buttons, bars and list rows so they
/// all draw an icon the same way.
@available(iOS 15.0, *)
struct IconView: View {
    let icon: IconConfig

    var body: some View {
        if let sf = icon.sfSymbol {
            symbolBody(sf)
        } else if let image = icon.customImage() {
            applyColor(Image(uiImage: image).renderingMode(.template))
        } else {
            Image(systemName: "questionmark")
        }
    }

    private var iconColor: Color? {
        guard let argb = icon.color else { return nil }
        return Color(argb: argb)
    }

    private var symbolWeight: Font.Weight? {
        switch icon.weight {
        case "light": return .light
        case "medium": return .medium
        case "semibold": return .semibold
        case "bold": return .bold
        default: return nil
        }
    }

    private func symbolBody(_ name: String) -> some View {
        let base = Image(systemName: name)
        let weight = symbolWeight
        let sized: AnyView
        switch (icon.size, weight) {
        case let (size?, weight):
            sized = AnyView(base.font(.system(size: CGFloat(size), weight: weight ?? .regular)))
        case (nil, let weight?):
            sized = AnyView(base.font(.body.weight(weight)))
        default:
            sized = AnyView(base)
        }
        return applyColor(applyRenderingMode(sized))
    }

    @ViewBuilder
    private func applyRenderingMode(_ view: some View) -> some View {
        switch icon.renderingMode {
        case "hierarchical": view.symbolRenderingMode(.hierarchical)
        case "palette": view.symbolRenderingMode(.palette)
        case "multicolor": view.symbolRenderingMode(.multicolor)
        case "monochrome": view.symbolRenderingMode(.monochrome)
        default: view
        }
    }

    @ViewBuilder
    private func applyColor(_ view: some View) -> some View {
        if let color = iconColor {
            view.foregroundStyle(color)
        } else {
            view
        }
    }
}
