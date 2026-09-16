import CoreGraphics
import CoreText
import Flutter
import SwiftUI
import UIKit

/// A native icon, decoded from `CupertinoNativeIcon.toMap()` on the Dart side.
/// Exactly one of `sfSymbol` (an SF Symbol name) or `codePoint`+`fontFamily`
/// (a Flutter glyph from a bundled icon font) is expected to be non-nil.
@available(iOS 26.0, *)
struct IconConfig: Codable, Hashable {
    let sfSymbol: String?
    let renderingMode: String?  // "monochrome" | "hierarchical" | "palette" | "multicolor"
    let codePoint: Int?
    let fontFamily: String?  // effective Flutter family, e.g. "packages/cupertino_icons/CupertinoIcons"
    let fontPackage: String?
    let size: Double?
    let color: Int?  // ARGB
}

/// Loads and registers Flutter icon fonts (CupertinoIcons, MaterialIcons,
/// FontAwesome, custom packages, …) with CoreText so their glyphs can be drawn
/// natively. Package-agnostic: it resolves any family declared in the app's
/// `FontManifest.json`. Results are cached; runs on the main thread only
/// (platform views and SwiftUI bodies are main-thread).
@available(iOS 26.0, *)
final class FlutterIconFontRegistry {
    static let shared = FlutterIconFontRegistry()

    /// family -> registered PostScript name. An empty string is a negative
    /// cache entry (family not found / not registerable).
    private var postScriptNamesByFamily: [String: String] = [:]
    /// Flutter font family -> asset path (relative to `flutter_assets`).
    private var manifest: [String: String]?

    /// Returns a usable PostScript font name for the given Flutter font family,
    /// or nil if it can't be resolved.
    func postScriptName(forFamily family: String) -> String? {
        if let cached = postScriptNamesByFamily[family] {
            return cached.isEmpty ? nil : cached
        }
        guard let asset = manifestMap()[family],
            let psName = registerFont(assetPath: asset)
        else {
            postScriptNamesByFamily[family] = ""  // negative cache
            return nil
        }
        postScriptNamesByFamily[family] = psName
        return psName
    }

    private func manifestMap() -> [String: String] {
        if let manifest = manifest { return manifest }
        var map: [String: String] = [:]
        let key = FlutterDartProject.lookupKey(forAsset: "FontManifest.json")
        if let url = Bundle.main.url(forResource: key, withExtension: nil),
            let data = try? Data(contentsOf: url),
            let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        {
            for entry in arr {
                if let family = entry["family"] as? String,
                    let fonts = entry["fonts"] as? [[String: Any]],
                    let asset = fonts.first?["asset"] as? String
                {
                    map[family] = asset
                }
            }
        }
        manifest = map
        return map
    }

    private func registerFont(assetPath: String) -> String? {
        let key = FlutterDartProject.lookupKey(forAsset: assetPath)
        guard let url = Bundle.main.url(forResource: key, withExtension: nil),
            let data = try? Data(contentsOf: url),
            let provider = CGDataProvider(data: data as CFData),
            let cgFont = CGFont(provider)
        else {
            return nil
        }
        // Register with CoreText. If it's already registered (e.g. a second
        // call for a shared asset), the PostScript name is still valid.
        CTFontManagerRegisterGraphicsFont(cgFont, nil)
        return cgFont.postScriptName as String?
    }
}

/// Renders an [IconConfig] as a SwiftUI view: an SF Symbol `Image` or a Flutter
/// glyph `Text` drawn with the bundled icon font. Used by buttons and toolbar
/// items so both icon kinds go through one path.
@available(iOS 26.0, *)
struct IconView: View {
    let icon: IconConfig

    var body: some View {
        if let sf = icon.sfSymbol {
            symbolBody(sf)
        } else if let code = icon.codePoint, let family = icon.fontFamily,
            let scalar = UnicodeScalar(code)
        {
            glyphBody(String(Character(scalar)), family: family)
        } else {
            Image(systemName: "questionmark")
        }
    }

    private var iconColor: Color? {
        guard let argb = icon.color else { return nil }
        return Color(argb: argb)
    }

    private func symbolBody(_ name: String) -> some View {
        let base = Image(systemName: name)
        let sized =
            icon.size.map { AnyView(base.font(.system(size: CGFloat($0)))) } ?? AnyView(base)
        return applyColor(applyRenderingMode(sized))
    }

    private func glyphBody(_ glyph: String, family: String) -> some View {
        let size = CGFloat(icon.size ?? 17)
        let font: Font
        if let ps = FlutterIconFontRegistry.shared.postScriptName(forFamily: family) {
            font = .custom(ps, size: size)
        } else {
            font = .system(size: size)
        }
        return applyColor(Text(glyph).font(font))
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
