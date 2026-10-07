import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

import 'cupertino_native_body.dart';

import 'cupertino_native_scaffold_navigation_bar.dart';
import 'cupertino_scroll_edge_effect.dart';
import 'cupertino_native_settings.dart';
import 'internal/body_echo.dart';
import 'internal/native_color.dart';

/// The heights a [CupertinoNativeSheet] can rest at, mirroring
/// `UISheetPresentationController.Detent`.
enum CupertinoNativeSheetDetent { medium, large }

/// A native segmented control pinned under the sheet's navigation bar:
/// the `bottom` slot of [CupertinoNativeSheet.show].
class CupertinoNativeSheetSegmentedControl {
  const CupertinoNativeSheetSegmentedControl({
    required this.segments,
    this.selectedIndex = 0,
  });

  final List<String> segments;
  final int selectedIndex;
}

/// Presents a Flutter page as a native iOS sheet
/// (`UISheetPresentationController`): system detents, grabber and
/// swipe-to-dismiss.
///
/// With a [CupertinoNativeScaffoldNavigationBar] the sheet gets a pinned native
/// bar, an optional search field and segmented control, and the body scrolls
/// under it.
///
/// ```dart
/// await CupertinoNativeSheet.show(
///   route: 'newEvent', // same route table as CupertinoNativePageScaffold bodies
///   navigationBar: CupertinoNativeScaffoldNavigationBar(
///     title: 'New Event',
///     leading: [
///       CupertinoNativeToolbarItem(
///         icon: CupertinoNativeIcon.symbol(CupertinoSymbols.xmark),
///         actionId: 'close',
///       ),
///     ],
///     trailing: [CupertinoNativeToolbarItem(title: 'Add', actionId: 'add')],
///   ),
///   bottom: CupertinoNativeSheetSegmentedControl(
///     segments: ['Event', 'Reminder'],
///   ),
///   detents: [CupertinoNativeSheetDetent.medium, CupertinoNativeSheetDetent.large],
///   showDragHandle: true,
///   onToolbarAction: (id) => CupertinoNativeSheet.dismiss(),
/// );
/// // The future completes when the sheet is dismissed.
/// ```
///
/// Inside the sheet's body, call [pop] to dismiss programmatically.
abstract final class CupertinoNativeSheet {
  static const _channel = MethodChannel(
    'com.example.cupertino_native_ui/alert',
  );
  static const _bodyChannel = MethodChannel(
    'cupertino_native_ui/scaffold_body',
  );
  static const _eventsChannel = MethodChannel(
    'cupertino_native_ui/sheet_events',
  );

  static bool _eventsHandlerInstalled = false;
  static void Function(String actionId)? _onToolbarAction;
  static ValueChanged<int>? _onBottomChanged;
  static ValueChanged<String>? _onSearchChanged;
  static ValueChanged<String>? _onSearchSubmitted;
  static void Function(String id, Object? value)? _onBodyEvent;
  static bool _dark = false;

  /// The open sheet's native body as last sent, and encoded: a tree that
  /// encodes the same is not sent again (see [adoptBodyEvent]).
  static Map<String, dynamic>? _sentBody;
  static String? _sentBodyJson;

  /// Presents the sheet and completes when it has been dismissed (either by
  /// [dismiss]/[pop], a bar action calling them, or the user's swipe).
  ///
  /// [navigationBar] pins native chrome above the content; its
  /// [CupertinoNativeScaffoldNavigationBar.search] field reports through [onSearchChanged] /
  /// [onSearchSubmitted]. [bottom] pins a native segmented control under the
  /// bar, reporting through [onBottomChanged]. Bar item taps report their
  /// `actionId` through [onToolbarAction].
  ///
  /// [isDark] pins the sheet's appearance; when null it follows the platform
  /// brightness.
  ///
  /// [detentHeights] adds stops at fixed heights in points, next to
  /// [detents] (`.custom`, iOS 16+). [undimmedUpTo] leaves the content behind
  /// the sheet undimmed and interactive up to that detent (Maps' search
  /// sheet). `dismissible: false` blocks swipe-to-dismiss
  /// (`isModalInPresentation`).
  ///
  /// Give [nativeBody] instead of [route] for a sheet whose content is pure
  /// SwiftUI (a native list, a form of transcribed controls) with no
  /// FlutterEngine behind it: it opens faster and costs no isolate. Its
  /// controls report through [onBodyEvent] as `(nodeId, value)`; push a
  /// changed tree with [updateNativeBody].
  ///
  /// Pass [anchor] to present a **popover** instead: the same engine and the
  /// same chrome, pointing at the control it came from rather than rising
  /// from the bottom, and staying a popover on iPhone instead of adapting
  /// back to a sheet. [detents], [showDragHandle] and [cornerRadius] belong
  /// to the sheet presentation and are ignored; [preferredSize] sizes the
  /// popover. See [CupertinoNativePopover] for the direct call.
  static Future<void> show({
    String? route,
    CupertinoNativeBody? nativeBody,
    void Function(String id, Object? value)? onBodyEvent,
    CupertinoNativeScaffoldNavigationBar? navigationBar,
    CupertinoNativeSheetSegmentedControl? bottom,
    List<CupertinoNativeSheetDetent> detents = const [
      CupertinoNativeSheetDetent.large,
    ],
    bool showDragHandle = false,
    List<double> detentHeights = const [],
    CupertinoNativeSheetDetent? undimmedUpTo,
    bool dismissible = true,
    double? cornerRadius,
    CupertinoScrollEdgeEffectStyle scrollEdgeEffect =
        CupertinoScrollEdgeEffectStyle.soft,
    Color? backgroundColor,
    bool? showLoadingIndicator,
    bool? isDark,
    void Function(String actionId)? onToolbarAction,
    ValueChanged<int>? onBottomChanged,
    ValueChanged<String>? onSearchChanged,
    ValueChanged<String>? onSearchSubmitted,
    Rect? anchor,
    Size? preferredSize,
  }) async {
    assert(
      (route == null) != (nativeBody == null),
      'Give CupertinoNativeSheet.show a route or a nativeBody: exactly one.',
    );
    if (defaultTargetPlatform != TargetPlatform.iOS) return;

    _onToolbarAction = onToolbarAction;
    _onBodyEvent = onBodyEvent;
    _onBottomChanged = onBottomChanged;
    _onSearchChanged = onSearchChanged;
    _onSearchSubmitted = onSearchSubmitted;
    _ensureEventsHandler();

    final dark =
        isDark ??
        ui.PlatformDispatcher.instance.platformBrightness == ui.Brightness.dark;
    _dark = dark;
    final body = _sentBody = nativeBody?.toMap(isDark: dark);
    _sentBodyJson = body == null ? null : jsonEncode(body);
    try {
      await _channel.invokeMethod<void>('showSheet', {
        'route': route,
        'nativeBody': body,
        'navigationBar': navigationBar?.toMap(),
        'bottomSegments': bottom?.segments,
        'bottomSelectedIndex': bottom?.selectedIndex,
        'detents': detents.map((d) => d.name).toList(),
        'detentHeights': detentHeights,
        'undimmedUpTo': undimmedUpTo?.name,
        'dismissible': dismissible,
        'showGrabber': showDragHandle,
        'cornerRadius': cornerRadius,
        'scrollEdgeEffect': scrollEdgeEffect.name,
        'backgroundColor': nativeArgb(backgroundColor, isDark: dark),
        'showLoadingIndicator':
            showLoadingIndicator ??
            CupertinoNativeSettings.showLoadingIndicator,
        'isDark': dark,
        if (anchor != null)
          'sourceRect': {
            'x': anchor.left,
            'y': anchor.top,
            'width': anchor.width,
            'height': anchor.height,
          },
        if (preferredSize != null)
          'preferredSize': {
            'width': preferredSize.width,
            'height': preferredSize.height,
          },
      });
    } finally {
      _onToolbarAction = null;
      _onBottomChanged = null;
      _onSearchChanged = null;
      _onSearchSubmitted = null;
      _onBodyEvent = null;
      _sentBody = null;
      _sentBodyJson = null;
    }
  }

  /// Replaces the open sheet's [show] `nativeBody`: how a controlled value
  /// (a stepper's count, a toggle) gets back to the native side.
  static Future<void> updateNativeBody(CupertinoNativeBody nativeBody) async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    final body = nativeBody.toMap(isDark: _dark);
    final json = jsonEncode(body);
    if (json == _sentBodyJson) return;
    _sentBody = body;
    _sentBodyJson = json;
    await _channel.invokeMethod<void>('updateSheetBody', body);
  }

  static void _ensureEventsHandler() {
    if (_eventsHandlerInstalled) return;
    _eventsHandlerInstalled = true;
    _eventsChannel.setMethodCallHandler((call) async {
      switch (call.method) {
        case 'toolbarAction':
          _onToolbarAction?.call(call.arguments as String);
        case 'segmentChanged':
          _onBottomChanged?.call(call.arguments as int);
        case 'searchChanged':
          _onSearchChanged?.call(call.arguments as String);
        case 'searchSubmitted':
          _onSearchSubmitted?.call(call.arguments as String);
        case 'bodyEvent':
          final args = call.arguments as Map;
          final id = args['id'] as String;
          if (adoptBodyEvent(_sentBody, id, args['value'])) {
            _sentBodyJson = jsonEncode(_sentBody);
          }
          _onBodyEvent?.call(id, args['value']);
      }
    });
  }

  /// Dismisses the currently presented sheet (from the main app's isolate).
  static Future<void> dismiss() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    await _channel.invokeMethod<void>('dismissSheet');
  }

  /// Dismisses the sheet from **inside its own body** (the sheet's isolate).
  static Future<void> pop() async {
    if (defaultTargetPlatform != TargetPlatform.iOS) return;
    await _bodyChannel.invokeMethod<void>('pop');
  }
}
