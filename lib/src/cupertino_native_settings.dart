/// Global defaults for cupertino_widgets.
abstract final class CupertinoWidgetsSettings {
  /// Whether surfaces that boot an embedded Flutter engine — scaffold bodies
  /// and native sheets — show a native spinner until their first frame.
  ///
  /// One switch for every widget at once; individual widgets can still
  /// override it via their own `showLoadingIndicator` parameter. Off by
  /// default.
  static bool showLoadingIndicator = false;
}
