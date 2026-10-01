import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

/// The running iOS major version, 0 off iOS.
///
/// Parsed once from `Platform.operatingSystemVersion`
/// (e.g. `"Version 26.0 (Build 23A341)"`).
final int iosMajorVersion = _computeIOSMajorVersion();

/// Whether the app is running on iOS 26 or later (the Liquid Glass design).
final bool isIOS26OrLater = iosMajorVersion >= 26;

int _computeIOSMajorVersion() {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return 0;
  final match = RegExp(r'\d+').firstMatch(Platform.operatingSystemVersion);
  return (match == null ? null : int.tryParse(match.group(0)!)) ?? 0;
}
