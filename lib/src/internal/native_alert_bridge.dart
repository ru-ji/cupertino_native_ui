import 'dart:async';
import 'dart:convert';
import 'dart:ffi' show Void;

import 'package:flutter/foundation.dart';
import 'package:objective_c/objective_c.dart';

import 'native_interop_bindings.g.dart';

/// Replaces the FFI call in tests, where there is no Objective-C runtime to
/// reach. Receives the same map the native side would get as JSON.
@visibleForTesting
Future<Object?> Function(
  Map<String, Object?> args, {
  required bool actionSheet,
})?
presentNativeAlertOverride;

/// Presents a native alert or action sheet through a direct FFI call and
/// completes with the decoded outcome: the tapped action's index, a
/// `{index, texts}` map when the alert has text fields, or null (dismissed,
/// unsupported host, or a failure on the native side).
Future<Object?> presentNativeAlert(
  Map<String, Object?> args, {
  required bool actionSheet,
}) {
  final override = presentNativeAlertOverride;
  if (override != null) return override(args, actionSheet: actionSheet);
  if (defaultTargetPlatform != TargetPlatform.iOS) return Future.value();
  final completer = Completer<Object?>();
  late final ObjCBlock<Void Function(NSString?)> block;
  block = ObjCBlock_ffiVoid_NSString.listener((reply) {
    try {
      final text = reply?.toDartString();
      // The native side wraps the value in a one-element array so a bare
      // number is valid JSON.
      completer.complete(
        text == null ? null : (jsonDecode(text) as List<Object?>).first,
      );
    } on Object catch (e, s) {
      completer.completeError(e, s);
    }
  });
  try {
    final json = jsonEncode(args).toNSString();
    if (actionSheet) {
      CNUNativeInterop.showActionSheetWithJson(json, completion: block);
    } else {
      CNUNativeInterop.showAlertWithJson(json, completion: block);
    }
  } on Object catch (e, s) {
    completer.completeError(e, s);
  }
  return completer.future;
}
