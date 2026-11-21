# Apple TV safe edges and right-to-left skip keys

## Why

The owner chose Apple's tvOS safe area for Apple TV: 80 pt at the left and
right, 60 pt at the top and bottom. The guide moved to it in
`fix-prominent-labels-and-tv-guide-edges`. Search, the Movies and Series
hero, preview and rows, the person page and the paywall still drew their
text and cards 64 pt from the side, and most Apple TV boards still drew
64 pt sides where the code already used 80. A living-room viewer whose TV
crops the picture loses the start of a title or the first poster.

In Arabic the player's bar and skip buttons mirror, so the bar starts at
the right. On iPhone, iPad and Mac the Left and Right Arrow keys still
skipped back and forward by their physical side, so Right Arrow moved the
knob away from the side it points at. A viewer reading Arabic presses the
arrow that points where they want the knob to go and gets the other way.

## What Changes

- Apple TV: Search results and recent searches, the Movies and Series hero
  copy and dots, the Apple TV preview's copy, the poster and card rows and
  grids, the person page and the paywall's wordmark and legal line take the
  80 pt sides of `Metrics.televisionSafeArea`. Art, scrims and video still
  run to the edge.
- The number box for typed channel digits already sat at 80 and 60 in the
  app; its previews did not. Previews and the screen now share the safe area
  value.
- The Apple TV boards draw 80 pt sides; the number box, the multi-view swap
  badge and the paywall wordmark sit 60 pt from the top, as the code does.
- In a right-to-left language Right Arrow skips back and Left Arrow skips
  forward, in the movie player, on Live with timeshift and in the Playback
  menu on Mac and iPad. The Siri Remote already worked this way.
- The design-system reference drops the rule that kept the keyboard's skip
  keys physical.

Out of scope:
- Top insets other than the number box, the multi-view badge and the
  paywall wordmark. Clocks and screen titles drawn at 44 pt on the boards
  line up with the system tab bar and stay as they are.
- The title page copy column, already 96 pt from the side, and the channel
  overlay's 20 pt trailing edge under its scrim.

## Capabilities

### Modified Capabilities

- `design-system`: `Apple TV content stays in the safe area` gains
  scenarios for Movies and Series, Search, the number box and the paywall.
  `Progress runs in the reading direction` says which way the arrow keys and
  the Playback menu skip in a right-to-left language.

## Impact

- `Apps/Shared/Components/` Shelf, Search, Person, Paywall, ZapBar,
  HeroScrim, ReadingDirection; `Apps/Shared/Views/` Search, Shelf, Live,
  ZapBar; `Apps/Shared/Commands/AntennaCommands.swift`.
- `KeyCommand` in AntennaCore gains the right-to-left key for the skips.
- Apple TV boards in `openspec/specs/design-system/boards/` and
  `reference.md`.
- Builds on `fix-prominent-labels-and-tv-guide-edges` (archived). Nothing
  blocks it.
