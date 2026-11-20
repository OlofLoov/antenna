# Design

## Context

Prominent buttons take the profile's accent as their tint on iPhone, iPad and Mac (`design-system/one-accent-color-per-profile`). The system draws their label white. `add-accent-and-app-icons` measured it and left it open:

| Accent | White label (before) | Ground #0B0E13 label (after) |
|---|---|---|
| Blue #5BB8FF | 2.15 | 8.97 |
| Teal #4FD1C5 | 1.87 | 10.36 |
| Amber #FFB454 | 1.76 | 10.96 |
| Pink #F472B6 | 2.65 | 7.30 |
| Violet #C084FC | 2.64 | 7.32 |

WCAG 2.x ratios. No accent can pass both on the dark ground and under a white label, so the label changes, not the accent.

The badges, the now line's time tag and the check marks in accent circles already draw `Palette.ground` on the accent. The boards draw every prominent button with a #0B0E13 label too (50 places). Only the code was white.

The Apple TV guide (`GuideGrid.Screen`) padded its page 64 pt at each side, inside a tab that ignores the safe area. The channel overlay, Settings, the player error and the hints legend use `Metrics.televisionSafeArea`, 80 pt at the sides, and `ChannelOverlayUITests.testTheColumnsKeepTheSafeEdgeWhileSwitchingGroups` pins the overlay at 80. The owner chose 80 pt sides and 60 pt top and bottom for the guide.

## Boards

- `TV-Guide`, `TV-Guide-Future`, `TV-Guide-Placeholders`, `TV-Guide-Empty`, `TV-Guide-RTL`: 80 pt sides, 365 pt half-hour columns, block widths and now line positions recomputed.
- Boards with prominent buttons (`iPhone-Onboard-2`, `iPad-Onboard-2`, `iPhone-Settings` and the rest) already draw a dark label and do not change.

Design-system requirements followed: `design-system/text-on-the-accent-is-dark` (new), `design-system/text-meets-contrast-minimums`, `design-system/controls-use-system-styles`, `design-system/focus-is-the-lifted-white-card`, `design-system/apple-tv-content-stays-in-the-safe-area`, `design-system/liquid-glass-stays-on-the-navigation-layer`.

## Decisions

### The label is the ground color, set on the system style

`prominentStyle(_:)` applies `.glassProminent` or `.borderedProminent` and sets `.foregroundStyle(Palette.onAccent)`. `primaryActionStyle()` and `chipStyle(isPicked:on:)` call it, as do the Up Next card's Play and the reminder banner's Watch. `Palette.onAccent` is `Palette.ground`; AntennaCore holds the value as `ProfileAccent.label` so `ProfileAccentTests` can measure it against each accent.

`scripts/check-rules.sh` fails on `.glassProminent` or `.borderedProminent` anywhere outside `PrimaryAction.swift`, so a new prominent button cannot skip the dark label. The glass-alone check also treats `prominentStyle(.glass)` as glass.

Options considered:
- A custom `ButtonStyle` that draws the fill and the label (rejected): `design-system/controls-use-system-styles` keeps the system's pressed, hover and disabled looks.
- Darker accents so white passes (rejected): links and progress then fail 4.5:1 on the ground; the accent table in `add-accent-and-app-icons` shows no color does both.
- `.foregroundStyle` at each call site (rejected): the next button forgets it. One modifier and a grep rule keep it in one place.

### Apple TV

Apple TV keeps the system tint, and its primary actions are bordered, so no Apple TV button rests on the accent. The one prominent button there was Save under a source's fields, glass prominent, which rests white with a white label. It takes `primaryActionStyle()`, like Connect on the add-source page. The reminder banner's Watch goes through `prominentStyle(.bordered)` on every platform; on Apple TV the dark label sits on the system's light fill.

### The guide keeps 80 pt sides; the half-hour column gives up 5 pt

80 + 300 + 4 x 370 + 80 is 1940, 20 pt wider than the screen. The half-hour column goes from 370 to 365 pt (`GuideScale.television`), so 80 + 300 + 1460 + 80 = 1920. `GuideGrid.Screen` pads with `Metrics.televisionSafeArea.leading` and `.trailing`. Top and bottom stay as they are: the picture starts at 120 pt under the tab bar's band and the grid ends 40 pt above the bottom of a region that already clears 60 pt.

Options considered:
- Narrow the channel column to 280 pt (rejected): the channel name loses 20 of its 140 pt and truncates sooner, and names are what the viewer scans.
- Keep 64 pt (rejected): the owner chose Apple's safe area, and the overlay, the tab pages and the hints legend already use 80.

### Other Apple TV screens with 64 pt edges

Not changed here. Each needs a look at whether it sits inside the system safe area already:
- `SearchTVScreen` pads its results 64 pt in a tab that ignores the safe area.
- `TV-GuideSources` (the board) draws 64 pt sides.
- `HeroScrim`, `ShelfPreview`, `ShelfBannerLayouts` and `PaywallTelevision` place copy 64 pt from the leading edge over full-bleed art.
- `NumberBox` puts the typed channel digits 64 pt from the leading edge.

### Identifiers

No new identifiers. The frame test reads `shell.player`, `guide.channel.<row>`, `guide.day.0` and `guide.column`; the label test reads `onboarding.addSource` and `onboarding.connect`.

## Risks

- The navigation bar ignores a button's foreground style. Connect in the add-source bar is glass prominent and drew white even through `prominentStyle(_:)`, so its `Text` sets `Palette.onAccent` itself. `ProminentLabelUITests` checks Add a source and Connect by their pixels on iPhone. The bar's other confirmation actions (Save in the profile editor, Done) draw accent text on plain glass, not a filled button, and stay as they are.
- Glass prominent changes its fill with what is behind it; the label test samples the middle of the button, away from the edge highlight.
