# Design

## Context

`fix-prominent-labels-and-tv-guide-edges` moved the Apple TV guide to `Metrics.televisionSafeArea` (80 pt sides, 60 pt top and bottom) and listed the screens it left at 64 pt: `SearchTVScreen`, the `TV-GuideSources` board, the copy over `HeroScrim`, `ShelfPreview`, `ShelfBannerLayouts`, `PaywallTelevision` and the typed digits in `NumberBox`. This change checks each one and sweeps the rest.

The Movies, Series and Guide tabs and the person page ignore the system safe area (`ShellView.page(_:)`, `PersonPageLayout.Television`), so a 64 pt padding there is 64 pt from the screen edge. The Search tab ignores it too, but its results sit in a `NavigationStack` that applies the system's 80 pt again, so they started 144 pt from the side. The paywall did not ignore it, so its wordmark sat at 80 + 64 = 144 pt and its legal line 60 + 56 pt above the bottom, while the board drew 64 and 56.

In Arabic the bars and skip buttons mirror (`design-system/progress-runs-in-the-reading-direction`, `design-system/playback-glyphs-keep-their-meaning`). The Siri Remote's clicks already skip toward the side they press (`TitleRemote` and `ShellTimeshift` use `isTrailing(right:)`, `ShellView.zap` uses `reading(_:)`). The keyboard did not: `ShelfPlayerView.keys`, `LiveSkipKeys` and the Playback menu bound Back to Left Arrow and Forward to Right Arrow in every language, and `reference.md` said so.

## Boards

- Every Apple TV board except the guide boards (already 80) and the title boards: side insets of 64 pt become 80 pt. This covers `TV-Movies*`, `TV-Series`, `TV-Search*`, `TV-GuideSources`, `TV-Person`, `TV-Paywall*`, `TV-ZapBar*`, `TV-Player*`, `TV-Groups*`, `TV-Hints-*`, `TV-Onboard-*`, `TV-Overlay-New`, `TV-Reminder-Banner`, `TV-Settings-Lookups`, `TV-MultiView-Swap` and `TV-Shell-TabView-*`. Most of them already matched the code at 80 (the zap bar, the player panel, the hints legend); only the boards were behind.
- `TV-ZapBar` and the `TV-ZapBar-Pill*` boards, `TV-MultiView-Swap` and `TV-Paywall*`: the number box, the swap badge and the wordmark sit at y 60, as the code does. The paywall's legal line ends 60 pt above the bottom.
- `TV-Shell-TabView-Guide`: the detail beside the small picture starts at 600 (80 + 480 + 40).
- Not changed: the Done and Continue buttons in `TV-Onboard-Help` and `TV-Paywall-Restored` (64 pt is the button's own padding), the failed tile in `TV-MultiView-Failed` (inside a tile), `TV-Title*` (the copy column is 96 pt from the side in the code, inside the safe area), clocks and titles drawn at y 44 (they line up with the system tab bar).

Design-system requirements followed: `design-system/apple-tv-content-stays-in-the-safe-area`, `design-system/progress-runs-in-the-reading-direction`, `design-system/playback-glyphs-keep-their-meaning`, `design-system/focus-moves-where-the-remote-points`, `design-system/one-spacing-and-radius-scale`.

## Decisions

### Each 64 pt edge, checked

| Place | Before | After | Why |
|---|---|---|---|
| `SearchTVScreen` results and recents | 64 sides and foot inside the `NavigationStack`, which keeps the system safe area, so 144 pt from the side | no side padding, `Metrics.televisionSafeArea.bottom` at the foot | The frame test measured 144, then 160 with 80 pt padding; the stack's own 80 is the edge |
| `ShelfBanner.Television` copy and dots | 64 | 80 | Copy and buttons; the art and scrim stay full bleed |
| `ShelfPreview.Television` copy | 64 | 80 | Copy; the picture stays full bleed |
| `ShelfView.Metrics.tv.gutter` (rows, grids, chips, headers) | 64 | 80 | Focusable cards. Written as 80 because `ShelfView.Metrics` hides the app-wide `Metrics` |
| `PersonPageLayout.Sizes.tv.gutter` | 64 | 80 | Same rows on a page that ignores the safe area |
| `HeroScrim` previews | copy at 64 | 80 | The scrim itself is full bleed and has no inset |
| `NumberBox` previews | 64, 44 | `Metrics.televisionSafeArea` | The screen (`NumberEntryInput`) already used 80, 60; both now read the constant |
| `Paywall.Television` | wordmark 64, 44 and legal 56 inside the system safe area | ignores the safe area and pads with `Metrics.televisionSafeArea`; the wordmark and legal line take no padding of their own, the legal line keeps 160 pt from each screen edge | Previews and the screen then draw the same frame |
| `Transport.Bar` | 90 sides | unchanged | Already inside the safe area |
| `ChannelOverlay` trailing 20 | 20 | unchanged | The overlay's scrim edge; its frame test pins the 80 pt leading |
| `TopShelfTiles` 64 inset | 64 | unchanged | Drawn into a Top Shelf image, not on screen |
| Guide and search previews with `.padding(64)` | 64 | `Metrics.televisionSafeArea` | The guide preview's rows are 1756 pt wide and fit in 1920 - 160 |

Options considered for the rows:
- Keep 64 pt for the rows and move only the copy (rejected): the first poster would then start left of the title above it, and posters are focusable, which the requirement covers.
- 80 pt (chosen): rows, copy and the guide line up on one edge. Six 212 pt posters with 20 pt gaps take 1372 pt, so the Apple TV grid still fits.

### Right to left: Apple flips progress controls, so the keys follow the bar

Apple's Human Interface Guidelines, "Right to left", Controls (developer.apple.com/design/human-interface-guidelines/right-to-left, read 2026-11-21):

> Flip controls that show progress from one value to another. Because people tend to view forward progress as moving in the same direction as the language they read, it makes sense to flip controls like sliders and progress indicators in the RTL context. When you do this, also be sure to reverse the positions of the accompanying glyphs or images that depict the beginning and ending values of the control.

> Preserve the direction of a control that refers to an actual direction or points to an onscreen area. For example, if you provide a control that means "to the right," it must always point right, regardless of the current context.

The page has no separate rule for media timelines; a playback bar is a progress control, and the page says to flip it. Our bars and skip buttons already flip. An arrow key means "to the right" or "to the left", so it keeps pointing at that side of the screen, where the mirrored bar's end is. Right Arrow therefore moves the knob right, which in Arabic is back toward the start, and Left Arrow moves it left, forward. This is what the Siri Remote already does.

Options considered:
- Stop mirroring the bars and keep the keys physical (rejected): the guide is the one page that would back it, and it says the opposite.
- Keep the mirrored bar and the physical keys (rejected): Right Arrow moved the knob left, away from the side it points at.
- Keys follow the bar (chosen), in the movie player, on Live with timeshift and in the Playback menu.

The menu items keep their names (Back, Forward) and swap keys. `KeyCommand.combination(rightToLeft:)` in AntennaCore gives Back Right Arrow and Forward Left Arrow in a right-to-left language and every other command its usual key. The menus sit outside every view's environment, so `AntennaCommands` reads the direction from the app's language (`LayoutDirection.ofApp`, from `Bundle.main.preferredLocalizations`). The hidden key buttons read `\.layoutDirection` and use `leadingArrow` and `trailingArrow`.

### Identifiers

No new identifiers. The frame tests read `movies.hero.title`, `movies.hero.play`, `movies.hero.pager`, `movies.preview.title`, `movies.card.*`, `search.result.programme.0`, `paywall.legal` and `paywall.title`. The Arabic key test reads `title.transport.elapsed`, `title.transport.remaining`, `title.transport.skipBack`, `title.transport.skipForward` and `shelf.debug.position`.

## Risks

- The focused poster grows about its middle, so its frame starts a few points left of the 80 pt margin. The frame test allows 12 pt for that, as the requirement's row scenario describes.
- The typed number box has no Apple TV UI test: the simulator's remote has no digit keys. It reads `Metrics.televisionSafeArea` in the screen and in its previews.
