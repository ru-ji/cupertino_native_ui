import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:cupertino_widgets/cupertino_widgets.dart';

/// [CupertinoNativePhotosPicker]: the system photo picker embedded in the
/// page (iOS 17+), no photo-library permission.
/// - A compact strip of recents, the row above a message field.
/// - An attachment panel with the full grid and the Photos / Albums switch,
///   like the one Messages slides up.
/// Picks appear at once as placeholders and fill in as their files land.
class PhotosPickerDemoPage extends StatefulWidget {
  const PhotosPickerDemoPage({super.key});

  @override
  State<PhotosPickerDemoPage> createState() => _PhotosPickerDemoPageState();
}

class _PhotosPickerDemoPageState extends State<PhotosPickerDemoPage> {
  List<CupertinoNativePickedMedia> _media = [];

  /// A real native sheet (UIKit): the system dims the whole screen, native
  /// views included, and gives it its own background and grabber. Its body
  /// is the picker alone — a native-body node, no Flutter engine — with the
  /// picker's own Photos / Collections bar as the only header.
  Future<void> _openPanel() => CupertinoNativeSheet.show(
    nativeBody: CupertinoNativeBody.photosPicker(
      id: 'photos',
      picker: CupertinoNativePhotosPicker(
        maxSelection: 10,
        showsAlbums: true,
        onChanged: (_) {},
      ),
    ),
    detents: const [
      CupertinoNativeSheetDetent.medium,
      CupertinoNativeSheetDetent.large,
    ],
    showDragHandle: true,
    onBodyEvent: (id, value) =>
        setState(() => _media = CupertinoNativePickedMedia.listFrom(value)),
  );

  Future<void> _clear() async {
    // Once the files are copied or uploaded, the cache can go.
    await CupertinoNativePhotosPicker.clearCache();
    setState(() => _media = []);
  }

  @override
  Widget build(BuildContext context) {
    final supported = CupertinoNativePhotosPicker.isSupported;
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: CustomScrollView(
        slivers: [
          CupertinoNativeSliverNavigationBar(
            largeTitle: 'Photos',
            leading: Navigator.canPop(context)
                ? CupertinoNativeButton.glass(
                    borderShape: CupertinoNativeButtonBorderShape.circle,
                    onPressed: () => Navigator.pop(context),
                    child: CupertinoSymbolImage.symbol(
                      CupertinoSymbols.chevronBackward,
                    ),
                  )
                : null,
          ),
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom + 40,
            ),
            sliver: SliverList.list(
              children: [
                if (!supported)
                  const CupertinoNativeList(
                    sections: [
                      CupertinoNativeListSection(
                        footer:
                            'The embedded picker needs iOS 17. Below it, fall '
                            'back to a full-screen picker such as image_picker.',
                        children: [
                          CupertinoNativeListTile(
                            id: 'unsupported',
                            title: 'Not available on this iOS',
                          ),
                        ],
                      ),
                    ],
                  )
                else ...[
                  const _SectionHeader('Recents'),
                  _Card(
                    height: 104,
                    child: CupertinoNativePhotosPicker(
                      style: CupertinoNativePhotosPickerStyle.compact,
                      filter: CupertinoNativePhotosPickerFilter.images,
                      onChanged: (media) => setState(() => _media = media),
                    ),
                  ),
                  const _SectionFooter(
                    'The compact style: one scrolling row, the strip above '
                    'a message field.',
                  ),
                  CupertinoNativeList(
                    onRowTap: (id) => switch (id) {
                      'panel' => _openPanel(),
                      'clear' => _clear(),
                      _ => null,
                    },
                    sections: [
                      CupertinoNativeListSection(
                        header: 'Attachment Panel',
                        footer:
                            'The inline style with the Photos / Albums switch. '
                            'No permission prompt: the picker runs out of '
                            'process and hands over only what is ticked.',
                        children: [
                          const CupertinoNativeListTile(
                            id: 'panel',
                            title: 'Choose Photos',
                            leading: CupertinoNativeIcon.named(
                              'photo.on.rectangle.angled',
                            ),
                            showChevron: true,
                          ),
                          CupertinoNativeListTile(
                            id: 'clear',
                            title: 'Clear Cache',
                            type: CupertinoNativeListTileType.button,
                            enabled: _media.isNotEmpty,
                          ),
                        ],
                      ),
                    ],
                  ),
                  _SectionHeader('Selected · ${_media.length}'),
                  _MediaGrid(media: _media),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// A grouped-list card: the list's side inset and corner radius.
class _Card extends StatelessWidget {
  const _Card({required this.height, required this.child});

  final double height;
  final Widget child;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.symmetric(horizontal: 16),
    child: ClipRRect(
      borderRadius: BorderRadius.circular(26),
      child: ColoredBox(
        color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
          context,
        ),
        child: SizedBox(height: height, child: child),
      ),
    ),
  );
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(36, 20, 36, 8),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 15,
        fontWeight: FontWeight.w600,
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
    ),
  );
}

class _SectionFooter extends StatelessWidget {
  const _SectionFooter(this.text);

  final String text;

  @override
  Widget build(BuildContext context) => Padding(
    padding: const EdgeInsets.fromLTRB(36, 8, 36, 4),
    child: Text(
      text,
      style: TextStyle(
        fontSize: 13,
        color: CupertinoColors.secondaryLabel.resolveFrom(context),
      ),
    ),
  );
}

/// Picks in a 4-column grid: a spinner while a file loads, then the image.
class _MediaGrid extends StatelessWidget {
  const _MediaGrid({required this.media});

  final List<CupertinoNativePickedMedia> media;

  @override
  Widget build(BuildContext context) {
    final secondary = CupertinoColors.secondaryLabel.resolveFrom(context);
    if (media.isEmpty) {
      return Padding(
        padding: const EdgeInsets.fromLTRB(36, 4, 36, 0),
        child: Text(
          'Nothing selected yet.',
          style: TextStyle(color: secondary),
        ),
      );
    }
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: GridView.count(
        crossAxisCount: 4,
        mainAxisSpacing: 4,
        crossAxisSpacing: 4,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        padding: EdgeInsets.zero,
        children: [
          for (final m in media)
            ClipRRect(
              borderRadius: BorderRadius.circular(10),
              child: ColoredBox(
                color: CupertinoColors.systemFill.resolveFrom(context),
                child: switch (m) {
                  CupertinoNativePickedMedia(failed: true) => Icon(
                    CupertinoIcons.exclamationmark_triangle,
                    color: secondary,
                  ),
                  CupertinoNativePickedMedia(path: null) =>
                    const CupertinoActivityIndicator(),
                  CupertinoNativePickedMedia(isVideo: true) => Icon(
                    CupertinoIcons.play_fill,
                    color: secondary,
                  ),
                  // Decoded at thumbnail size, not the file's.
                  CupertinoNativePickedMedia(:final path?) => Image.file(
                    File(path),
                    fit: BoxFit.cover,
                    cacheWidth: 300,
                  ),
                },
              ),
            ),
        ],
      ),
    );
  }
}
