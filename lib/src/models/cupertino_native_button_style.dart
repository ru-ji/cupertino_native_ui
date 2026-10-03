/// Styles for the native iOS button
enum CupertinoNativeButtonStyle {
  automatic,
  filled,
  tinted,
  plain,
  glass,
  glassProminent,
}

/// SwiftUI's `ControlSize`, which sets a control's metrics (height, padding
/// and font) rather than an explicit size.
enum CupertinoNativeControlSize {
  /// Tight spaces, like a sidebar.
  mini,

  /// Secondary toolbar options.
  small,

  /// Standard, everyday controls. The default.
  regular,

  /// Call-to-action controls.
  large,

  /// Full-width or otherwise prominent controls. Falls back to [large] below
  /// iOS 17, where `ControlSize.extraLarge` does not exist.
  extraLarge,
}
