import 'dart:io';

import 'package:flutter/cupertino.dart';
import 'package:cupertino_native_ui/cupertino_native_ui.dart';

/// Every way to pick a value, on one page: segmented controls, a menu, the
/// date pickers in their three styles, the multi-date calendar, the color well
/// and the embedded photo picker. The color picked at the top tints the rest.
class PickersDemoPage extends StatefulWidget {
  const PickersDemoPage({super.key});

  @override
  State<PickersDemoPage> createState() => _PickersDemoPageState();
}

class _PickersDemoPageState extends State<PickersDemoPage> {
  static const _ranges = ['Day', 'Week', 'Month', 'Year'];
  static const _filters = ['All', 'Missed'];
  static const _sorts = ['Date', 'Name', 'Size'];

  Color _color = CupertinoColors.systemIndigo;

  int _range = 1;
  int _filter = 0;
  int _sort = 0;

  DateTime _starts = DateTime.now();
  DateTime _ends = DateTime.now().add(const Duration(hours: 1));
  DateTime _alarm = DateTime(2026, 1, 1, 7, 30);
  DateTime _day = DateTime.now();
  Set<DateTime> _days = {};

  List<CupertinoNativePickedMedia> _media = [];

  /// A real native sheet: the system dims the whole screen, native views
  /// included. Its body is the picker alone (a native-body node, no Flutter
  /// engine) with the picker's own Photos / Collections bar as the header.
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
    return CupertinoPageScaffold(
      backgroundColor: CupertinoColors.systemGroupedBackground,
      child: CustomScrollView(
        slivers: [
          CupertinoNativeSliverNavigationBar(largeTitle: 'Pickers'),
          SliverPadding(
            padding: EdgeInsets.only(
              bottom: MediaQuery.paddingOf(context).bottom + 40,
            ),
            sliver: SliverList.list(
              children: [
                // Straight on the page, the way iOS puts a segmented control
                // over the content it filters.
                _Header('Segmented'),
                Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16),
                  child: CupertinoNativeSlidingSegmentedControl(
                    children: {
                      for (final (i, l) in _ranges.indexed) i: Text(l),
                    },
                    groupValue: _range,
                    thumbColor: _color,
                    onValueChanged: (v) => setState(() => _range = v!),
                  ),
                ),
                const SizedBox(height: 12),
                Center(
                  child: SizedBox(
                    width: 200,
                    child: CupertinoNativeSlidingSegmentedControl(
                      children: {
                        for (final (i, l) in _filters.indexed) i: Text(l),
                      },
                      groupValue: _filter,
                      onValueChanged: (v) => setState(() => _filter = v!),
                    ),
                  ),
                ),
                const SizedBox(height: 8),
                CupertinoNativeList(
                  activeColor: _color,
                  sections: [
                    CupertinoNativeListSection(
                      header: 'Choice',
                      footer:
                          'The color well tints the segmented control above '
                          'and every picker below.',
                      children: [
                        CupertinoNativeListTile(
                          id: 'color',
                          title: 'Accent Color',
                          trailing: CupertinoNativeColorPicker(
                            color: _color,
                            onChanged: (c) => setState(() => _color = c),
                          ),
                        ),
                        CupertinoNativeListTile(
                          id: 'sort',
                          title: 'Sort By',
                          trailing:
                              CupertinoNativeSlidingSegmentedControl<int>.menu(
                                children: {
                                  for (final (i, l) in _sorts.indexed)
                                    i: Text(l),
                                },
                                groupValue: _sort,
                                onValueChanged: (v) =>
                                    setState(() => _sort = v!),
                              ),
                        ),
                      ],
                    ),
                    CupertinoNativeListSection(
                      header: 'Event',
                      footer:
                          'Compact pickers: tap a pill for the calendar or '
                          'the time wheel · '
                          '${_ends.difference(_starts).inMinutes} min.',
                      children: [
                        CupertinoNativeListTile(
                          id: 'starts',
                          title: 'Starts',
                          trailing: CupertinoNativeDatePicker(
                            initialDateTime: _starts,
                            mode: CupertinoDatePickerMode.dateAndTime,
                            onDateTimeChanged: (d) =>
                                setState(() => _starts = d),
                          ),
                        ),
                        CupertinoNativeListTile(
                          id: 'ends',
                          title: 'Ends',
                          trailing: CupertinoNativeDatePicker(
                            initialDateTime: _ends,
                            mode: CupertinoDatePickerMode.dateAndTime,
                            minimumDate: _starts,
                            onDateTimeChanged: (d) => setState(() => _ends = d),
                          ),
                        ),
                        CupertinoNativeListTile(
                          id: 'alarm',
                          title: 'Wake Up',
                          trailing: CupertinoNativeDatePicker(
                            initialDateTime: _alarm,
                            mode: CupertinoDatePickerMode.time,
                            onDateTimeChanged: (d) =>
                                setState(() => _alarm = d),
                          ),
                        ),
                      ],
                    ),
                    CupertinoNativeListSection(
                      header: 'Calendar & Wheel',
                      children: [
                        CupertinoNativeListTile(
                          id: 'calendar',
                          title: 'Day',
                          trailing: CupertinoNativeDatePicker(
                            mode: CupertinoDatePickerMode.date,
                            style: CupertinoNativeDatePickerStyle.graphical,
                            initialDateTime: _day,
                            onDateTimeChanged: (d) => setState(() => _day = d),
                          ),
                        ),
                        CupertinoNativeListTile(
                          id: 'time',
                          title: 'Time',
                          trailing: CupertinoNativeDatePicker(
                            mode: CupertinoDatePickerMode.time,
                            style: CupertinoNativeDatePickerStyle.wheel,
                            initialDateTime: _day,
                            onDateTimeChanged: (d) => setState(() => _day = d),
                          ),
                        ),
                      ],
                    ),
                    CupertinoNativeListSection(
                      header: 'Days Off',
                      footer: '${_days.length} days picked (iOS 16+).',
                      children: [
                        CupertinoNativeListTile(
                          id: 'days',
                          title: 'Pick several days',
                          trailing: CupertinoNativeMultiDatePicker(
                            dates: _days,
                            minimumDate: DateTime.now(),
                            onChanged: (d) => setState(() => _days = d),
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
                ..._photos(),
              ],
            ),
          ),
        ],
      ),
    );
  }

  /// The embedded photo picker: a compact strip of recents, and the full
  /// grid in a sheet. Picks appear at once as placeholders and fill in as
  /// their files land.
  List<Widget> _photos() {
    if (!CupertinoNativePhotosPicker.isSupported) {
      return const [
        CupertinoNativeList(
          sections: [
            CupertinoNativeListSection(
              header: 'Photos',
              footer:
                  'The embedded picker needs iOS 17. Below it, fall back to a '
                  'full-screen picker such as image_picker.',
              children: [
                CupertinoNativeListTile(
                  id: 'unsupported',
                  title: 'Not available on this iOS',
                ),
              ],
            ),
          ],
        ),
      ];
    }
    return [
      _Header('Photos'),
      Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16),
        // A rounded background, not a ClipRRect: a Flutter clip around a
        // native view applies to the other native views on the page too.
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: CupertinoColors.secondarySystemGroupedBackground.resolveFrom(
              context,
            ),
            borderRadius: BorderRadius.circular(26),
          ),
          child: SizedBox(
            height: 104,
            child: CupertinoNativePhotosPicker(
              style: CupertinoNativePhotosPickerStyle.compact,
              filter: CupertinoNativePhotosPickerFilter.images,
              onChanged: (media) => setState(() => _media = media),
            ),
          ),
        ),
      ),
      CupertinoNativeList(
        activeColor: _color,
        onRowTap: (id) => switch (id) {
          'panel' => _openPanel(),
          'clear' => _clear(),
          _ => null,
        },
        sections: [
          CupertinoNativeListSection(
            footer:
                'The strip above is the compact style. The panel is the '
                'inline style with the Photos / Albums switch. No permission '
                'prompt: the picker runs out of process and hands over only '
                'what is ticked.',
            children: [
              const CupertinoNativeListTile(
                id: 'panel',
                title: 'Choose Photos & Videos',
                leading: CupertinoNativeIcon.named('photo.on.rectangle.angled'),
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
      _Header('Selected · ${_media.length}'),
      _MediaGrid(media: _media),
    ];
  }
}

/// A section title for what sits straight on the page, aligned with the
/// native lists' own headers.
class _Header extends StatelessWidget {
  const _Header(this.text);

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

/// Picks in a 4-column grid: a spinner while a file loads, then the image or
/// the video's first frame.
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
                  CupertinoNativePickedMedia(
                    isVideo: true,
                    :final thumbnailPath,
                  ) =>
                    Stack(
                      fit: StackFit.expand,
                      children: [
                        if (thumbnailPath != null)
                          Image.file(
                            File(thumbnailPath),
                            fit: BoxFit.cover,
                            cacheWidth: 300,
                          ),
                        const Align(
                          alignment: Alignment.bottomLeft,
                          child: Padding(
                            padding: EdgeInsets.all(6),
                            child: Icon(
                              CupertinoIcons.play_fill,
                              size: 16,
                              color: CupertinoColors.white,
                            ),
                          ),
                        ),
                      ],
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
