import 'dart:io' show Platform;

import 'package:flutter/foundation.dart';

import 'foundation_bindings.g.dart';

/// The running iOS major version, 0 off iOS.
///
/// Read once from `NSProcessInfo.operatingSystemVersion` through a direct
/// ffigen binding. Where that is unavailable, parsed from
/// `Platform.operatingSystemVersion` (e.g. `"Version 26.0 (Build 23A341)"`).
final int iosMajorVersion = _computeIOSMajorVersion();

/// Whether the app is running on iOS 26 or later (the Liquid Glass design).
final bool isIOS26OrLater = iosMajorVersion >= 26;

int _computeIOSMajorVersion() {
  if (kIsWeb || defaultTargetPlatform != TargetPlatform.iOS) return 0;
  if (Platform.isIOS) {
    try {
      return NSProcessInfo.getProcessInfo().operatingSystemVersion.majorVersion;
    } on Object {
      // Fall through to the string parse below.
    }
  }
  final match = RegExp(r'\d+').firstMatch(Platform.operatingSystemVersion);
  return (match == null ? null : int.tryParse(match.group(0)!)) ?? 0;
}
