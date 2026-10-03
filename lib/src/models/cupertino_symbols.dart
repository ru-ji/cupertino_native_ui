/// A curated, typo-safe set of common [SF Symbols](https://developer.apple.com/sf-symbols/).
///
/// Enum case names use camelCase; each case carries the real SF Symbol string
/// in [value] (which may contain dots, e.g. `star.fill`). This list is not
/// exhaustive: SF Symbols ships thousands of glyphs. For any symbol not listed
/// here, use `CupertinoNativeIcon.named('some.symbol')` with the raw string.
enum CupertinoSymbols {
  // Navigation & chevrons
  chevronLeft('chevron.left'),
  chevronRight('chevron.right'),
  chevronUp('chevron.up'),
  chevronDown('chevron.down'),
  chevronBackward('chevron.backward'),
  chevronForward('chevron.forward'),
  arrowLeft('arrow.left'),
  arrowRight('arrow.right'),
  arrowUp('arrow.up'),
  arrowDown('arrow.down'),
  arrowUpArrowDown('arrow.up.arrow.down'),
  arrowClockwise('arrow.clockwise'),
  arrowCounterclockwise('arrow.counterclockwise'),
  arrowUturnBackward('arrow.uturn.backward'),
  arrowUturnForward('arrow.uturn.forward'),

  // Common actions
  plus('plus'),
  plusCircle('plus.circle'),
  plusCircleFill('plus.circle.fill'),
  minus('minus'),
  minusCircle('minus.circle'),
  xmark('xmark'),
  xmarkCircle('xmark.circle'),
  xmarkCircleFill('xmark.circle.fill'),
  checkmark('checkmark'),
  checkmarkCircle('checkmark.circle'),
  checkmarkCircleFill('checkmark.circle.fill'),
  checkmarkSeal('checkmark.seal'),
  ellipsis('ellipsis'),
  ellipsisCircle('ellipsis.circle'),
  ellipsisCircleFill('ellipsis.circle.fill'),

  // Editing
  pencil('pencil'),
  pencilCircle('pencil.circle'),
  squareAndPencil('square.and.pencil'),
  trash('trash'),
  trashFill('trash.fill'),
  docOnDoc('doc.on.doc'),
  scissors('scissors'),
  arrowUpBin('arrow.up.bin'),
  squareAndArrowUp('square.and.arrow.up'),
  squareAndArrowDown('square.and.arrow.down'),

  // People & accounts
  person('person'),
  personFill('person.fill'),
  personCircle('person.circle'),
  personCircleFill('person.circle.fill'),
  person2('person.2'),
  person2Fill('person.2.fill'),
  personCropCircle('person.crop.circle'),
  personCropCircleBadgePlus('person.crop.circle.badge.plus'),

  // Home & structure
  house('house'),
  houseFill('house.fill'),
  building('building'),
  building2('building.2'),
  folder('folder'),
  folderFill('folder.fill'),
  tray('tray'),
  trayFull('tray.full'),
  archivebox('archivebox'),

  // Media playback
  play('play'),
  playFill('play.fill'),
  playCircle('play.circle'),
  pause('pause'),
  pauseFill('pause.fill'),
  stop('stop'),
  stopFill('stop.fill'),
  backwardFill('backward.fill'),
  forwardFill('forward.fill'),
  speakerWave2('speaker.wave.2'),
  speakerSlash('speaker.slash'),
  mic('mic'),
  micFill('mic.fill'),
  micSlash('mic.slash'),

  // Communication
  phone('phone'),
  phoneFill('phone.fill'),
  message('message'),
  messageFill('message.fill'),
  envelope('envelope'),
  envelopeFill('envelope.fill'),
  bell('bell'),
  bellFill('bell.fill'),
  bellSlash('bell.slash'),
  paperplane('paperplane'),
  paperplaneFill('paperplane.fill'),
  bubbleLeft('bubble.left'),

  // Symbols & status
  star('star'),
  starFill('star.fill'),
  starLeadinghalfFilled('star.leadinghalf.filled'),
  heart('heart'),
  heartFill('heart.fill'),
  bookmark('bookmark'),
  bookmarkFill('bookmark.fill'),
  flag('flag'),
  flagFill('flag.fill'),
  tag('tag'),
  tagFill('tag.fill'),
  bolt('bolt'),
  boltFill('bolt.fill'),
  exclamationmarkTriangle('exclamationmark.triangle'),
  exclamationmarkTriangleFill('exclamationmark.triangle.fill'),
  infoCircle('info.circle'),
  infoCircleFill('info.circle.fill'),
  questionmarkCircle('questionmark.circle'),

  // Search & discovery
  magnifyingglass('magnifyingglass'),
  magnifyingglassCircle('magnifyingglass.circle'),
  line3HorizontalDecrease('line.3.horizontal.decrease'),
  line3HorizontalDecreaseCircle('line.3.horizontal.decrease.circle'),
  slider('slider.horizontal.3'),

  // Settings & tools
  gear('gear'),
  gearshape('gearshape'),
  gearshapeFill('gearshape.fill'),
  wrenchAndScrewdriver('wrench.and.screwdriver'),
  hammer('hammer'),
  wandAndStars('wand.and.stars'),
  paintbrush('paintbrush'),

  // Layout & lists
  line3Horizontal('line.3.horizontal'),
  listBullet('list.bullet'),
  listNumber('list.number'),
  squareGrid2x2('square.grid.2x2'),
  rectangleGrid1x2('rectangle.grid.1x2'),
  sidebarLeft('sidebar.left'),

  // Media & files
  photo('photo'),
  photoFill('photo.fill'),
  camera('camera'),
  cameraFill('camera.fill'),
  doc('doc'),
  docFill('doc.fill'),
  docText('doc.text'),
  book('book'),
  bookFill('book.fill'),
  calendar('calendar'),
  clock('clock'),
  clockFill('clock.fill'),
  map('map'),
  mapFill('map.fill'),
  location('location'),
  locationFill('location.fill'),

  // Commerce
  cart('cart'),
  cartFill('cart.fill'),
  bag('bag'),
  bagFill('bag.fill'),
  creditcard('creditcard'),
  creditcardFill('creditcard.fill'),
  giftFill('gift.fill'),

  // Weather & nature
  sunMax('sun.max'),
  sunMaxFill('sun.max.fill'),
  moon('moon'),
  moonFill('moon.fill'),
  cloud('cloud'),
  cloudFill('cloud.fill'),
  cloudRain('cloud.rain'),
  flame('flame'),
  flameFill('flame.fill'),
  drop('drop'),
  leaf('leaf'),

  // Connectivity & devices
  wifi('wifi'),
  wifiSlash('wifi.slash'),
  antennaRadiowavesLeftAndRight('antenna.radiowaves.left.and.right'),
  lock('lock'),
  lockFill('lock.fill'),
  lockOpen('lock.open'),
  key('key'),
  eye('eye'),
  eyeFill('eye.fill'),
  eyeSlash('eye.slash'),
  battery100('battery.100'),
  powerButton('power'),

  // Misc
  globe('globe'),
  circle('circle'),
  circleFill('circle.fill'),
  square('square'),
  squareFill('square.fill'),
  hand('hand.raised'),
  handThumbsup('hand.thumbsup'),
  handThumbsupFill('hand.thumbsup.fill'),
  handThumbsdown('hand.thumbsdown'),
  faceSmiling('face.smiling');

  const CupertinoSymbols(this.value);

  /// The underlying SF Symbol name passed to `UIImage(systemName:)` /
  /// `Image(systemName:)` on the native side.
  final String value;
}

/// SF Symbol rendering mode, mapped to SwiftUI `.symbolRenderingMode(...)`.
///
/// - [monochrome]: a single color (the tint).
/// - [hierarchical]: one color at varying opacities across symbol layers.
/// - [palette]: distinct colors per layer (uses the symbol's default palette
///   here since a single tint color is provided).
/// - [multicolor]: the symbol's intrinsic multicolor rendering.
enum CupertinoSymbolRenderingMode {
  monochrome,
  hierarchical,
  palette,
  multicolor,
}
