import UIKit

/// Entry points Dart calls directly through FFI (package:objective_c), with no
/// platform channel in between: no codec, no async hop, callable from any
/// isolate. The Dart side is generated from `tool/ffigen/native_interop.h`,
/// which must be kept in sync with the signatures here.
@objc(CNUNativeInterop)
public final class NativeInterop: NSObject {

    @objc public static func isLiquidGlassSupported() -> Bool {
        if #available(iOS 26.0, *) { return true }
        return false
    }

    @objc public static func clearPhotoCache() {
        if #available(iOS 17.0, *) { PhotoCache.clear() }
    }

    /// Rasterizes an SF Symbol to PNG bytes, or nil for an unknown name.
    /// `weight` is light/medium/semibold/bold (anything else is regular),
    /// `symbolScale` is small/large (anything else is medium). `argb` is
    /// ignored unless `hasColor`.
    @objc public static func renderSymbol(
        name: String, size: Double, argb: Int, hasColor: Bool,
        weight: String, symbolScale: String, scale: Double
    ) -> Data? {
        FlutterCupertinoPlugin.renderSymbol(
            name: name, size: size, argb: hasColor ? argb : nil,
            weight: weight, symbolScale: symbolScale, scale: scale)
    }
}
