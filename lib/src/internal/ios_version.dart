import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// Whether the app is running on iOS 26 or later (the Liquid Glass design).
///
/// Parsed once from `Platform.operatingSystemVersion`
/// (e.g. `"Version 26.0 (Build 23A341)"`).
final bool isIOS26OrLater = _computeIsIOS26OrLater();

bool _computeIsIOS26OrLater() {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return false;
  final match = RegExp(r'\d+').firstMatch(Platform.operatingSystemVersion);
  final major = match == null ? null : int.tryParse(match.group(0)!);
  return major != null && major >= 26;
}
