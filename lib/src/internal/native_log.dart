import 'package:flutter/foundation.dart';

/// The package's own diagnostics: off unless the app is built with
/// `--dart-define=CUPERTINO_NATIVE_UI_LOG=true`. They are for working on the
/// package itself, so an app that only uses it never sees them. Off, the
/// call and its message compile away.
const bool _enabled = bool.fromEnvironment('CUPERTINO_NATIVE_UI_LOG');

/// Logs [message] under the package's prefix, when enabled.
void nativeLog(String Function() message) {
  if (_enabled) debugPrint('[cupertino_native_ui] ${message()}');
}
