import 'package:flutter/widgets.dart';

import 'pages/edge_effect_probe_page.dart';
import 'pages/glass_body.dart';
import 'pages/mail_bodies.dart';
import 'pages/new_event_sheet_body.dart';
import 'pages/search_body.dart';

/// Route builders for every CupertinoNativePageScaffold body (tab roots and
/// pushed pages alike). Consumed by `CupertinoNativePageScaffold.maybeRun` at the
/// top of `main()` — no `@pragma('vm:entry-point')` function needed.
Map<String, Widget Function()> scaffoldRoutes() {
  return {
    // The Mail demo (NativeScaffoldDemoPage): the inbox, and one route per
    // message — a pushed body has no arguments, so the route is the message.
    'inbox': () => const MailInboxBody(),
    for (var i = 0; i < mails.length; i++)
      'mail$i': () => MailMessageBody(index: i),
    'searchBody': () => const SearchBody(),
    'newEvent': () => const NewEventSheetBody(),
    // Hosted inside a glass container (see LiquidGlassDemoPage).
    'glassNowPlaying': () => const GlassNowPlayingBody(),
    'glassCard': () => const GlassCardBody(),
    'edgeEffectProbe': () => const EdgeEffectProbeBody(),
  };
}
