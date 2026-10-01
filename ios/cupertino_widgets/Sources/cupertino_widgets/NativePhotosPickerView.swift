import Flutter
import ImageIO
import PhotosUI
import SwiftUI
import UIKit
import UniformTypeIdentifiers

/// The system photo picker embedded in the page (`PhotosPicker` with the
/// `.inline` / `.compact` style, iOS 17+) instead of presented full screen.
/// Needs no photo-library permission: the picker runs out of process and hands
/// over only what the user picks.
///
/// Speed is the point of the loading path:
/// - `preferredItemEncoding: .current` — the system does not transcode (a
///   HEIC to JPEG conversion is the slowest thing it could do for us);
/// - each pick arrives as a *file*, moved into our cache, never read whole
///   into memory;
/// - resizing decodes straight to the target size with ImageIO
///   (`CGImageSourceCreateThumbnailAtIndex`), never the full-resolution
///   bitmap;
/// - every item loads concurrently the moment it is ticked, and reports on
///   its own, so Dart shows the first one without waiting for the last;
/// - results are cached per (photo, size) for the app's run: unticking and
///   re-ticking, or a second picker, costs nothing.
@available(iOS 15.0, *)
class NativePhotosPickerFactory: NSObject, FlutterPlatformViewFactory {
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
        NativePhotosPickerView(viewIdentifier: viewId, arguments: args, messenger: messenger)
    }

    public func createArgsCodec() -> FlutterMessageCodec & NSObjectProtocol {
        FlutterStandardMessageCodec.sharedInstance()
    }
}

@available(iOS 15.0, *)
struct PhotosPickerConfig: Codable, Equatable {
    /// "inline" | "compact"
    let style: String?
    /// "images" | "videos" | "all"
    let filter: String?
    /// 0 = no limit.
    let maxSelection: Int?
    /// Longest side of a delivered image, in pixels; nil keeps the original
    /// file untouched (fastest, but HEIC stays HEIC).
    let maxDimension: Double?
    let jpegQuality: Double?
    /// Keep the picker's own top bar: the Photos / Albums (Collections)
    /// switch. Off, only the grid shows.
    let showsAlbums: Bool?
    let isDark: Bool?
}

@available(iOS 15.0, *)
class NativePhotosPickerView: NativeHostingView {
    private var channel: FlutterMethodChannel?
    private var model: AnyObject?

    init(viewIdentifier viewId: Int64, arguments args: Any?, messenger: FlutterBinaryMessenger) {
        super.init()
        _view.viewId = viewId
        channel = FlutterMethodChannel(
            name: "cupertino_widgets/photos_picker_\(viewId)", binaryMessenger: messenger)
        channel?.setMethodCallHandler { [weak self] call, result in
            self?.handle(call, result: result)
        }
        guard let argsMap = args as? [String: Any],
            let config = decodeConfig(PhotosPickerConfig.self, from: argsMap)
        else { return }
        isDark = config.isDark

        guard #available(iOS 17.0, *) else {
            // The embedded styles are iOS 17; Dart checks `isSupported`.
            attach(AnyView(Color.clear))
            return
        }
        // Platform views are created on the main thread.
        let model = MainActor.assumeIsolated {
            PhotosPickerModel(config: config) { [weak self] items in
                self?.channel?.invokeMethod("onChanged", arguments: items)
            }
        }
        self.model = model
        attach(AnyView(InlinePhotosPickerView(model: model)))
    }

    private func handle(_ call: FlutterMethodCall, result: @escaping FlutterResult) {
        switch call.method {
        case "snapshot":
            result(PlatformViewSnapshot.capture(view()))
        case "update":
            if #available(iOS 17.0, *),
                let argsMap = call.arguments as? [String: Any],
                let config = decodeConfig(PhotosPickerConfig.self, from: argsMap),
                let model = model as? PhotosPickerModel
            {
                isDark = config.isDark
                // Method calls arrive on the main thread.
                MainActor.assumeIsolated { model.config = config }
            }
            result(nil)
        default:
            result(FlutterMethodNotImplemented)
        }
    }
}

@available(iOS 17.0, *)
@MainActor
final class PhotosPickerModel: ObservableObject {
    @Published var config: PhotosPickerConfig
    @Published var selection: [PhotosPickerItem] = [] {
        didSet { sync() }
    }

    /// Finished payloads by item key, and the loads still running.
    private var results: [String: [String: Any]] = [:]
    private var tasks: [String: Task<Void, Never>] = [:]
    /// Where selections go; settable so a native body can point it at the
    /// node's event without recreating the picker.
    var onChange: ([[String: Any]]) -> Void

    init(config: PhotosPickerConfig, onChange: @escaping ([[String: Any]]) -> Void) {
        self.config = config
        self.onChange = onChange
    }

    private static func key(_ item: PhotosPickerItem) -> String {
        item.itemIdentifier ?? String(item.hashValue)
    }

    /// Starts a load for every newly ticked item, cancels the ones unticked,
    /// and reports the selection at once — loading items without a path —
    /// so Dart can lay out placeholders before any file is ready.
    private func sync() {
        let keys = Set(selection.map(Self.key))
        for (key, task) in tasks where !keys.contains(key) {
            task.cancel()
            tasks[key] = nil
        }
        for item in selection {
            let key = Self.key(item)
            guard results[key] == nil, tasks[key] == nil else { continue }
            let config = config
            tasks[key] = Task { [weak self] in
                let payload = await Task.detached(priority: .userInitiated) {
                    await PhotoCache.load(item, key: key, config: config)
                }.value
                guard let self, !Task.isCancelled else { return }
                self.tasks[key] = nil
                self.results[key] = payload
                self.report()
            }
        }
        report()
    }

    private func report() {
        onChange(
            selection.map { item in
                let key = Self.key(item)
                return results[key] ?? ["id": key]
            })
    }
}

/// Where picked media land, and the index that makes a second pick of the
/// same photo free. Lives for the app's run; `clear()` empties both.
@available(iOS 17.0, *)
enum PhotoCache {
    static let directory = FileManager.default.temporaryDirectory
        .appendingPathComponent("cupertino_widgets_photos", isDirectory: true)

    private static let lock = NSLock()
    private static var index: [String: [String: Any]] = [:]

    static func clear() {
        lock.withLock { index.removeAll() }
        try? FileManager.default.removeItem(at: directory)
    }

    /// The payload for one item: `id`, `path`, `isVideo`, `width`, `height`
    /// — or `id` + `error` when it could not be loaded.
    static func load(_ item: PhotosPickerItem, key: String, config: PhotosPickerConfig) async
        -> [String: Any]
    {
        let size = config.maxDimension.map { "\(Int($0))q\(Int((config.jpegQuality ?? 0.8) * 100))" }
        let cacheKey = "\(key)|\(size ?? "original")"
        if let hit = lock.withLock({ index[cacheKey] }),
            let path = hit["path"] as? String, FileManager.default.fileExists(atPath: path)
        {
            return hit
        }
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)

        let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
        var payload: [String: Any] = ["id": key, "isVideo": isVideo]
        do {
            if isVideo {
                guard let file = try await item.loadTransferable(type: PickedMovie.self) else {
                    throw CocoaError(.fileReadUnknown)
                }
                payload["path"] = file.url.path
            } else {
                guard let file = try await item.loadTransferable(type: PickedImage.self) else {
                    throw CocoaError(.fileReadUnknown)
                }
                if let maxDimension = config.maxDimension {
                    let out = directory.appendingPathComponent(UUID().uuidString + ".jpg")
                    guard
                        let (w, h) = downsample(
                            file.url, to: out, maxPixel: maxDimension,
                            quality: config.jpegQuality ?? 0.8)
                    else { throw CocoaError(.fileReadCorruptFile) }
                    // Only the resized JPEG is kept.
                    try? FileManager.default.removeItem(at: file.url)
                    payload["path"] = out.path
                    payload["width"] = w
                    payload["height"] = h
                } else {
                    payload["path"] = file.url.path
                    if let (w, h) = pixelSize(of: file.url) {
                        payload["width"] = w
                        payload["height"] = h
                    }
                }
            }
        } catch {
            return ["id": key, "isVideo": isVideo, "error": true]
        }
        lock.withLock { index[cacheKey] = payload }
        return payload
    }

    /// Decodes at the target size directly — never the full-resolution
    /// bitmap — and writes a JPEG. EXIF orientation is applied.
    private static func downsample(_ source: URL, to dest: URL, maxPixel: Double, quality: Double)
        -> (Int, Int)?
    {
        guard
            let src = CGImageSourceCreateWithURL(
                source as CFURL, [kCGImageSourceShouldCache: false] as CFDictionary)
        else { return nil }
        let options: [CFString: Any] = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixel,
        ]
        guard let image = CGImageSourceCreateThumbnailAtIndex(src, 0, options as CFDictionary),
            let out = CGImageDestinationCreateWithURL(
                dest as CFURL, UTType.jpeg.identifier as CFString, 1, nil)
        else { return nil }
        CGImageDestinationAddImage(
            out, image, [kCGImageDestinationLossyCompressionQuality: quality] as CFDictionary)
        guard CGImageDestinationFinalize(out) else { return nil }
        return (image.width, image.height)
    }

    /// Reads the size from the file header only, as displayed (orientation
    /// 5–8 swaps the sides).
    private static func pixelSize(of url: URL) -> (Int, Int)? {
        guard let src = CGImageSourceCreateWithURL(url as CFURL, nil),
            let props = CGImageSourceCopyPropertiesAtIndex(src, 0, nil) as? [CFString: Any],
            let w = props[kCGImagePropertyPixelWidth] as? Int,
            let h = props[kCGImagePropertyPixelHeight] as? Int
        else { return nil }
        let orientation = props[kCGImagePropertyOrientation] as? Int ?? 1
        return orientation >= 5 ? (h, w) : (w, h)
    }

    /// The picker hands over a temporary file that is deleted when the import
    /// closure returns: move it into the cache (same volume, so a rename, not
    /// a copy).
    fileprivate static func adopt(_ received: URL) throws -> URL {
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let dest = directory.appendingPathComponent(
            UUID().uuidString + "." + received.pathExtension)
        do {
            try FileManager.default.moveItem(at: received, to: dest)
        } catch {
            try FileManager.default.copyItem(at: received, to: dest)
        }
        return dest
    }
}

@available(iOS 17.0, *)
private struct PickedImage: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .image) { received in
            PickedImage(url: try PhotoCache.adopt(received.file))
        }
    }
}

@available(iOS 17.0, *)
private struct PickedMovie: Transferable {
    let url: URL
    static var transferRepresentation: some TransferRepresentation {
        FileRepresentation(importedContentType: .movie) { received in
            PickedMovie(url: try PhotoCache.adopt(received.file))
        }
    }
}

@available(iOS 17.0, *)
struct InlinePhotosPickerView: View {
    @ObservedObject var model: PhotosPickerModel

    private var config: PhotosPickerConfig { model.config }

    var body: some View {
        PhotosPicker(
            selection: $model.selection,
            maxSelectionCount: (config.maxSelection ?? 0) > 0 ? config.maxSelection : nil,
            // Live selection: every tick reports at once, no "Add" button.
            selectionBehavior: .continuousAndOrdered,
            matching: filter,
            // No transcoding: the fastest hand-over there is.
            preferredItemEncoding: .current,
            // Gives each item a stable `itemIdentifier` — the cache key.
            photoLibrary: .shared()
        ) {
            Text("Photos")
        }
        .photosPickerStyle(config.style == "compact" ? .compact : .inline)
        // The top bar carries the Photos / Albums switch; the bottom bar is
        // the "Add" confirmation continuous selection makes pointless.
        .photosPickerAccessoryVisibility(
            .hidden, edges: config.showsAlbums == true ? .bottom : .all)
        .photosPickerDisabledCapabilities([.selectionActions])
        .ignoresSafeArea()
    }

    private var filter: PHPickerFilter? {
        switch config.filter {
        case "images": .images
        case "videos": .videos
        default: nil
        }
    }
}
