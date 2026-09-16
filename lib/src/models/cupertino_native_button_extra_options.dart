/// Button border shapes for native iOS buttons.
enum CupertinoNativeButtonBorderShape {
  automatic,
  capsule,
  circle,
  roundedRectangle,
  // roundedRectangle(radius) is complex to map simply via enum,
  // so we'll stick to standard shapes for now or add a separate radius param later.
}

enum CupertinoNativeButtonLabelStyle { titleAndIcon, titleOnly, iconOnly }
