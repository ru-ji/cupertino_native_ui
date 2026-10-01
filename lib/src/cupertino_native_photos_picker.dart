import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart' show Theme;
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import 'internal/ios_version.dart';
import 'internal/native_platform_view_mixin.dart';

/// How the embedded picker lays out.
enum CupertinoNativePhotosPickerStyle {
  /// The full grid, scrolling vertically — the body of an attachment sheet.
  inline,

  /// One row of thumbnails scrolling sideways — above a message field.
  compact,
}

/// What the picker shows.
enum CupertinoNativePhotosPickerFilter { all, images, videos }

/// One picked photo or video, as [CupertinoNativePhotosPicker.onChanged]
/// reports it. Reported as soon as it is ticked, with no [path] yet; reported
/// again once its file is ready.
@immutable
class CupertinoNativePickedMedia {
  const CupertinoNativePickedMedia({
    required this.id,
    this.path,
    this.isVideo = false,
    this.thumbnailPath,
    this.width,
    this.height,
    this.failed = false,
  });

  /// Stable per photo-library item, across picks and pickers.
  final String id;

  /// The file, once loaded: a JPEG no larger than
  /// [CupertinoNativePhotosPicker.maxDimension], the original file when that
  /// is null, or the video as is. Lives in the app's temporary directory
  /// until [CupertinoNativePhotosPicker.clearCache] (or iOS) removes it —
  /// copy it elsewhere to keep it.
  final String? path;
  final bool isVideo;

  /// For a video: its first frame, as a JPEG no larger than
  /// [CupertinoNativePhotosPicker.maxDimension] (600 when null) — what to
  /// show in a grid. Same lifetime as [path]. Null for an image, or when no
  /// frame could be read.
  final String? thumbnailPath;

  /// Pixel size: the image's, or the video thumbnail's.
  final int? width;
  final int? height;

  /// The item could not be loaded (an iCloud photo offline, for one).
  final bool failed;

  bool get isLoading => path == null && !failed;

  /// Reads the value a photos-picker node reports through `onBodyEvent` (a
  /// [CupertinoNativeBody.photosPicker], e.g. in a native sheet).
  static List<CupertinoNativePickedMedia> listFrom(Object? value) => [
    for (final item in (value as List?) ?? const [])
      CupertinoNativePickedMedia._fromMap(item as Map),
  ];

  factory CupertinoNativePickedMedia._fromMap(Map map) =>
      CupertinoNativePickedMedia(
        id: map['id'] as String,
        path: map['path'] as String?,
        isVideo: map['isVideo'] as bool? ?? false,
        thumbnailPath: map['thumbnail'] as String?,
        width: map['width'] as int?,
        height: map['height'] as int?,
        failed: map['error'] as bool? ?? false,
      );
}

/// The system photo picker **embedded in your page** — SwiftUI's
/// `PhotosPicker` with the inline or compact style (iOS 17+) — rather than
/// presented full screen. Put it in your own sheet for a WhatsApp-style
/// attachment panel.
///
/// It needs no photo-library permission: the picker runs out of process and
/// hands over only what the user ticks. Ticks report live through
/// [onChanged], in selection order.
///
/// ```dart
/// if (CupertinoNativePhotosPicker.isSupported)
///   SizedBox(
///     height: 420,
///     child: CupertinoNativePhotosPicker(
///       maxSelection: 10,
///       onChanged: (media) => setState(() => _media = media),
///     ),
///   )
/// ```
///
/// Built to be fast: no system transcoding, files moved rather than read into
/// memory, images decoded straight at [maxDimension], every item loading in
/// parallel and reported on its own, and a per-run cache that makes picking
/// the same photo again free.
class CupertinoNativePhotosPicker extends StatefulWidget {
  const CupertinoNativePhotosPicker({
    super.key,
    required this.onChanged,
    this.style = CupertinoNativePhotosPickerStyle.inline,
    this.filter = CupertinoNativePhotosPickerFilter.all,
    this.maxSelection,
    this.maxDimension = 2048,
    this.jpegQuality = 0.8,
    this.showsAlbums = false,
  });

  final ValueChanged<List<CupertinoNativePickedMedia>> onChanged;
  final CupertinoNativePhotosPickerStyle style;
  final CupertinoNativePhotosPickerFilter filter;

  /// Null: no limit.
  final int? maxSelection;

  /// Longest side of a delivered image, in pixels. Null delivers the original
  /// file untouched — the fastest, but a HEIC stays a HEIC.
  final double? maxDimension;

  /// 0...1, for the resized JPEGs.
  final double jpegQuality;

  /// Keep the picker's own top bar with its Photos / Albums switch, so the
  /// user can browse albums. Off (the default) shows the grid alone.
  final bool showsAlbums;

  /// The picker's settings as the native side reads them — shared by the
  /// platform view and the native-body node.
  Map<String, Object?> get nativeConfig => {
    'style': style.name,
    'filter': filter.name,
    'maxSelection': maxSelection ?? 0,
    'maxDimension': maxDimension,
    'jpegQuality': jpegQuality,
    'showsAlbums': showsAlbums,
  };

  /// The embedded picker needs iOS 17. Below it, use a full-screen picker
  /// such as `image_picker`.
  static bool get isSupported =>
      debugIsSupportedOverride ?? iosMajorVersion >= 17;

  /// Forces [isSupported] in tests, where the host is not an iPhone.
  @visibleForTesting
  static bool? debugIsSupportedOverride;

  /// Deletes every file the pickers delivered this run, and the cache index.
  /// Call it once you have copied or uploaded what you keep.
  static Future<void> clearCache() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    await const MethodChannel('com.example.cupertino_widgets/alert')
        .invokeMethod<void>('clearPhotoCache');
  }

  @override
  State<CupertinoNativePhotosPicker> createState() =>
      _CupertinoNativePhotosPickerState();
}

class _CupertinoNativePhotosPickerState
    extends State<CupertinoNativePhotosPicker>
    with NativePlatformViewStateMixin {
  bool get _isDark => Theme.of(context).brightness == Brightness.dark;

  Map<String, Object?> _config() => {...widget.nativeConfig, 'isDark': _isDark};

  bool? _lastIsDark;

  /// Follows the app switching light / dark while the picker is up.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_lastIsDark != null && _lastIsDark != _isDark) {
      updateNativeView('update', _config(), refreshIntrinsicSize: false);
    }
    _lastIsDark = _isDark;
  }

  @override
  void didUpdateWidget(covariant CupertinoNativePhotosPicker oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.style != widget.style ||
        oldWidget.filter != widget.filter ||
        oldWidget.maxSelection != widget.maxSelection ||
        oldWidget.maxDimension != widget.maxDimension ||
        oldWidget.jpegQuality != widget.jpegQuality ||
        oldWidget.showsAlbums != widget.showsAlbums) {
      updateNativeView('update', _config(), refreshIntrinsicSize: false);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (!CupertinoNativePhotosPicker.isSupported) {
      return const SizedBox.shrink();
    }
    final view = wrapForTransition(
      UiKitView(
        viewType:
            'com.example.cupertino_widgets/cupertino_native_photos_picker',
        layoutDirection: TextDirection.ltr,
        creationParams: _config(),
        creationParamsCodec: const StandardMessageCodec(),
        onPlatformViewCreated: (id) => setUpChannel(
          id,
          'cupertino_widgets/photos_picker_$id',
          onMethodCall: (call) async {
            if (call.method != 'onChanged') return;
            widget.onChanged(
              CupertinoNativePickedMedia.listFrom(call.arguments),
            );
          },
        ),
        hitTestBehavior: PlatformViewHitTestBehavior.opaque,
        // The grid scrolls itself: drags belong to it, not to the page.
        gestureRecognizers: {
          Factory<OneSequenceGestureRecognizer>(EagerGestureRecognizer.new),
        },
      ),
    );
    // It fills its box. In a scroll view or a Column the box has no height
    // — the picker would take an infinite one and throw — so it falls back
    // to a sensible one: a row of thumbnails, or a few rows of the grid.
    return LayoutBuilder(
      builder: (context, constraints) => constraints.hasBoundedHeight
          ? view
          : SizedBox(
              height: widget.style == CupertinoNativePhotosPickerStyle.compact
                  ? 96
                  : 420,
              child: view,
            ),
    );
  }
}
